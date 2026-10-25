"""Pruebas de integración de los reportes v2: catálogo, detalles, votos, reputación y límites."""
from datetime import datetime

BAZURTO = {"latitud": 10.4139, "longitud": -75.5244}


def _auth(token):
    return {"Authorization": f"Bearer {token}"}


def _reportar(api, token, tipo="bus_no_pasa", detalles=None, **lugar):
    cuerpo = {"tipo": tipo, "detalles": {"ruta": "T103"} if detalles is None else detalles, **(lugar or BAZURTO)}
    return api.post("/api/v1/incidents/", headers=_auth(token), json=cuerpo)


def _votar(api, token, incidente_id, sigue):
    return api.post(f"/api/v1/incidents/{incidente_id}/votes", headers=_auth(token), json={"sigue": sigue})


def _yo(api, token):
    return api.get("/api/v1/users/me", headers=_auth(token)).json()


def test_el_catalogo_agrupa_los_tipos_con_sus_preguntas(api):
    grupos = api.get("/api/v1/incidents/types").json()
    assert [g["clave"] for g in grupos] == ["servicio", "via", "seguridad"]
    servicio = {t["clave"]: t for t in grupos[0]["tipos"]}
    no_pasa = servicio["bus_no_pasa"]
    assert no_pasa["vigencia_min"] == 60
    ruta, espera = no_pasa["campos"]
    assert (ruta["clave"], ruta["tipo"], ruta["obligatorio"]) == ("ruta", "ruta", True)
    assert [o["etiqueta"] for o in espera["opciones"]] == ["10 min", "20 min", "30 min o más"]


def test_reportar_guarda_los_detalles_y_nombra_el_lugar(api, registrar):
    token, _ = registrar()
    respuesta = _reportar(api, token, detalles={"ruta": "t103", "espera": "20"})
    assert respuesta.status_code == 201, respuesta.text
    reporte = respuesta.json()
    assert (reporte["grupo"], reporte["tipo"]) == ("servicio", "bus_no_pasa")
    assert reporte["detalles"] == {"ruta": "T103", "espera": "20"}
    assert reporte["lugar"] and "Bazurto" in reporte["lugar"]
    assert (reporte["votos_si"], reporte["votos_no"]) == (0, 0)
    vida = datetime.fromisoformat(reporte["expira_en"]) - datetime.fromisoformat(reporte["creado_en"])
    assert vida.total_seconds() == 3600


def test_reportes_con_datos_que_no_cuadran_se_rechazan(api, registrar):
    token, _ = registrar()
    assert _reportar(api, token, detalles={}).status_code == 422  # falta la ruta
    assert _reportar(api, token, detalles={"ruta": "Z999"}).status_code == 422
    assert _reportar(api, token, tipo="ovni", detalles={}).status_code == 422
    malicioso = _reportar(api, token, detalles={"ruta": {"$ne": None}})
    assert malicioso.status_code == 422  # un objeto nunca llega a MongoDB como filtro


def test_el_detalle_muestra_el_alias_y_si_ya_votaste(api, registrar):
    token_autor, _ = registrar(nombre="Ana Pérez Gómez")
    reporte = _reportar(api, token_autor).json()

    anonimo = api.get(f"/api/v1/incidents/{reporte['id']}").json()
    assert anonimo["reportado_por_alias"] == "Ana P."
    assert (anonimo["es_mio"], anonimo["mi_voto"]) == (False, None)
    assert "reportado_por" not in anonimo

    propio = api.get(f"/api/v1/incidents/{reporte['id']}", headers=_auth(token_autor)).json()
    assert propio["es_mio"] is True


def test_confirmar_renueva_el_reporte_y_reparte_reputacion(api, registrar):
    token_autor, _ = registrar()
    token_viajero, _ = registrar()
    reporte = _reportar(api, token_autor, tipo="trancon", detalles={"estado": "detenido"}).json()

    voto = _votar(api, token_viajero, reporte["id"], sigue=True)
    assert voto.status_code == 200, voto.text
    cuerpo = voto.json()
    assert cuerpo["retirado"] is False
    assert cuerpo["incidente"]["votos_si"] == 1
    assert cuerpo["incidente"]["expira_en"] >= reporte["expira_en"]

    assert _yo(api, token_autor)["reputacion"] == 102  # 100 + 2 por la confirmación
    # Votar no da puntos por sí solo: llegan cuando otro viajero le da la razón.
    assert _yo(api, token_viajero)["reputacion"] == 100
    assert _votar(api, registrar()[0], reporte["id"], sigue=True).status_code == 200
    assert _yo(api, token_viajero)["reputacion"] == 101
    assert _yo(api, token_autor)["impacto"]["confirmaciones"] == 2
    detalle = api.get(f"/api/v1/incidents/{reporte['id']}", headers=_auth(token_viajero)).json()
    assert detalle["mi_voto"] is True


def test_un_voto_por_viajero_y_nunca_sobre_el_propio(api, registrar):
    token_autor, _ = registrar()
    token_viajero, _ = registrar()
    reporte = _reportar(api, token_autor).json()

    assert _votar(api, token_autor, reporte["id"], sigue=True).status_code == 403
    assert _votar(api, token_viajero, reporte["id"], sigue=True).status_code == 200
    assert _votar(api, token_viajero, reporte["id"], sigue=False).status_code == 409


def test_dos_ya_no_seguidos_retiran_el_reporte_y_restan_reputacion(api, registrar):
    token_autor, _ = registrar()
    reporte = _reportar(api, token_autor).json()

    token_primero, token_segundo = registrar()[0], registrar()[0]
    primero = _votar(api, token_primero, reporte["id"], sigue=False).json()
    assert primero["retirado"] is False
    segundo = _votar(api, token_segundo, reporte["id"], sigue=False).json()
    assert segundo["retirado"] is True
    # Los dos tenían razón: cada uno gana su punto.
    assert (_yo(api, token_primero)["reputacion"], _yo(api, token_segundo)["reputacion"]) == (101, 101)

    vigentes = {i["id"] for i in api.get("/api/v1/incidents/").json()}
    assert reporte["id"] not in vigentes
    assert api.get(f"/api/v1/incidents/{reporte['id']}").status_code == 404
    assert _votar(api, registrar()[0], reporte["id"], sigue=True).status_code == 404
    assert _yo(api, token_autor)["reputacion"] == 95


def test_un_sigue_ahi_en_medio_reinicia_la_racha_de_ya_no(api, registrar):
    reporte = _reportar(api, registrar()[0]).json()
    for sigue in (False, True, False):
        assert _votar(api, registrar()[0], reporte["id"], sigue).json()["retirado"] is False
    vigentes = {i["id"] for i in api.get("/api/v1/incidents/").json()}
    assert reporte["id"] in vigentes


def test_el_mapa_puede_pedir_solo_el_area_visible(api, registrar):
    token, _ = registrar()
    en_bazurto = _reportar(api, token).json()["id"]
    en_bocagrande = _reportar(api, token, tipo="calle_inundada", detalles={"paso": "con_cuidado"},
                              latitud=10.3990, longitud=-75.5545).json()["id"]
    caja_bazurto = {"lon_min": -75.53, "lat_min": 10.41, "lon_max": -75.52, "lat_max": 10.42}
    visibles = {i["id"] for i in api.get("/api/v1/incidents/", params=caja_bazurto).json()}
    assert en_bazurto in visibles and en_bocagrande not in visibles


def test_reportar_demasiado_seguido_da_429_con_retry_after(api, registrar, monkeypatch):
    from src.infrastructure import config
    monkeypatch.setattr(config, "LIMITE_REPORTES", (2, 600))
    token, _ = registrar()
    assert _reportar(api, token).status_code == 201
    assert _reportar(api, token).status_code == 201
    tercero = _reportar(api, token)
    assert tercero.status_code == 429
    assert int(tercero.headers["Retry-After"]) > 0


def test_el_perfil_trae_alias_y_nivel(api, registrar):
    token, usuario = registrar(nombre="Camilo Maestre")
    assert (usuario["alias"], usuario["nivel"]) == ("Camilo M.", 1)
    assert _yo(api, token)["alias"] == "Camilo M."


def test_la_troncal_se_puede_dibujar_en_el_mapa(api):
    troncales = api.get("/api/v1/routes/", params={"tipo": "troncal"}).json()
    codigos = {r["codigo"] for r in troncales}
    assert {"T101", "T103"} <= codigos and all(c.startswith("T") for c in codigos)
    assert troncales[0]["geometria"]["type"] == "LineString"
    assert len(troncales[0]["geometria"]["coordinates"]) > 10


def test_con_nivel_de_confianza_un_solo_ya_no_retira_el_reporte(api, registrar):
    from bson import ObjectId
    from src.infrastructure.database import get_database
    reporte = _reportar(api, registrar()[0]).json()
    token, usuario = registrar()
    get_database().users.update_one({"_id": ObjectId(usuario["id"])}, {"$set": {"reputacion": 200}})  # nivel 3
    assert _votar(api, token, reporte["id"], sigue=False).json()["retirado"] is True


def test_gracias_y_vistas_suman_al_impacto_de_quien_reporto(api, registrar):
    token_autor, _ = registrar()
    reporte = _reportar(api, token_autor).json()
    token_viajero, _ = registrar()

    # Abrir el reporte cuenta una vez por persona; el autor no se cuenta a sí mismo.
    for _ in range(2):
        api.get(f"/api/v1/incidents/{reporte['id']}", headers=_auth(token_viajero))
    api.get(f"/api/v1/incidents/{reporte['id']}", headers=_auth(token_autor))

    gracias = api.post(f"/api/v1/incidents/{reporte['id']}/thanks", headers=_auth(token_viajero))
    assert gracias.status_code == 200, gracias.text
    assert gracias.json()["gracias"] == 1
    assert api.post(f"/api/v1/incidents/{reporte['id']}/thanks", headers=_auth(token_viajero)).status_code == 409
    assert api.post(f"/api/v1/incidents/{reporte['id']}/thanks", headers=_auth(token_autor)).status_code == 403
    detalle = api.get(f"/api/v1/incidents/{reporte['id']}", headers=_auth(token_viajero)).json()
    assert detalle["mis_gracias"] is True

    impacto = _yo(api, token_autor)["impacto"]
    assert (impacto["reportes"], impacto["vistas"], impacto["gracias"]) == (1, 1, 1)

