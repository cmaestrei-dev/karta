"""Las coronas por la API (docs/plan-juego.md, fase B): participar, reinar, el apodo del día y sus reportes."""
from datetime import datetime, timedelta, timezone

from bson import ObjectId

from src.domain.coronas import dia_de

BAZURTO = {"latitud": 10.4139, "longitud": -75.5244}
CORONA = "/api/v1/stations/bazurto/crown"


def _auth(token):
    return {"Authorization": f"Bearer {token}"}


def _db():
    from src.infrastructure.database import get_database
    return get_database()


def _participar(api, token, **ajustes):
    return api.put("/api/v1/users/me/crown", headers=_auth(token), json={"participa": True, **ajustes})


def _aportes_pasados(usuario_id, dias, estacion="bazurto"):
    """Aportes de [dias] días anteriores a hoy, como si los hubiera hecho (la corona se calcula con esos)."""
    hoy = dia_de(datetime.now(timezone.utc))
    _db().crown_contributions.insert_many([
        {"usuario": ObjectId(usuario_id), "estacion": estacion, "dia": (hoy - timedelta(days=k)).isoformat(),
         "expira_en": datetime.now(timezone.utc) + timedelta(days=31)}
        for k in range(1, dias + 1)
    ])


def _nueva_estacion_cada_vez():
    """Cada prueba arranca sin corona calculada en Bazurto ni aportes de otras pruebas."""
    db = _db()
    db.crowns.delete_many({})
    db.crown_contributions.delete_many({})
    db.crown_bans.delete_many({})


def test_sin_participar_no_se_anota_nada_y_participando_si(api, registrar):
    _nueva_estacion_cada_vez()
    token_autor, autor = registrar()
    token_otro, _ = registrar()
    reporte = api.post("/api/v1/incidents/", headers=_auth(token_autor),
                       json={"tipo": "bus_no_pasa", "detalles": {"ruta": "T103"}, **BAZURTO}).json()
    api.post(f"/api/v1/incidents/{reporte['id']}/votes", headers=_auth(token_otro), json={"sigue": True})
    assert _db().crown_contributions.count_documents({"usuario": ObjectId(autor["id"])}) == 0
    assert api.get(CORONA, headers=_auth(token_autor)).json()["tu"]["participas"] is None

    assert _participar(api, token_autor).json() == {"participa": True, "visible": False, "apodo": None}
    reporte = api.post("/api/v1/incidents/", headers=_auth(token_autor),
                       json={"tipo": "trancon", "detalles": {"estado": "lento"}, **BAZURTO}).json()
    api.post(f"/api/v1/incidents/{reporte['id']}/votes", headers=_auth(token_otro), json={"sigue": True})
    tu = api.get(CORONA, headers=_auth(token_autor)).json()["tu"]
    assert (tu["participas"], tu["llevas"], tu["faltan"]) == (True, 1, 1)


def test_reina_quien_mas_dias_aporto_y_se_ve_como_un_karteno(api, registrar):
    _nueva_estacion_cada_vez()
    token_ana, ana = registrar(nombre="Ana Pérez")
    token_beto, beto = registrar()
    for token in (token_ana, token_beto):
        _participar(api, token)
    _aportes_pasados(ana["id"], 4)
    _aportes_pasados(beto["id"], 2)

    anonimo = api.get(CORONA).json()
    assert anonimo["rey"]["nombre"] == "un karteño"  # nunca su nombre
    assert "Ana" not in str(anonimo) and anonimo["tu"] is None
    assert api.get(CORONA, headers=_auth(token_ana)).json()["eres_rey"] is True
    del_beto = api.get(CORONA, headers=_auth(token_beto)).json()
    assert (del_beto["eres_rey"], del_beto["tu"]["llevas"], del_beto["tu"]["faltan"]) == (False, 2, 3)

    # Si pide mostrarse, se ve su apodo de karteño, no su nombre.
    assert _participar(api, token_ana, visible=True, apodo="Iguana viajera").status_code == 200
    assert api.get(CORONA).json()["rey"]["nombre"] == "Iguana viajera"
    assert _participar(api, token_ana, apodo="Gonorrea").status_code == 422


def test_el_apodo_del_dia_lo_pone_quien_reina_una_vez_por_semana(api, registrar):
    _nueva_estacion_cada_vez()
    token_ana, ana = registrar()
    token_beto, _ = registrar()
    _participar(api, token_ana)
    _aportes_pasados(ana["id"], 3)
    apodo = lambda token, texto: api.put(f"{CORONA}/nickname", headers=_auth(token), json={"texto": texto})

    assert api.get(CORONA, headers=_auth(token_ana)).json()["tu"]["puedes_poner_apodo"] is True
    rechazado = apodo(token_ana, "Escríbeme al 3001234567")
    assert rechazado.status_code == 422 and "teléfono" in rechazado.json()["detail"]
    puesto = apodo(token_ana, "  La esquina del raspao ")
    assert puesto.status_code == 200, puesto.text
    assert puesto.json()["apodo_del_dia"]["texto"] == "La esquina del raspao"
    assert puesto.json()["tu"]["puedes_poner_apodo"] is False
    assert apodo(token_ana, "Otro apodo").status_code == 409
    assert apodo(token_beto, "Me lo robo").status_code == 403
    assert api.get(CORONA).json()["apodo_del_dia"]["texto"] == "La esquina del raspao"  # lo ve cualquiera
    assert api.get("/api/v1/stations/narnia/crown").status_code == 404


def test_dos_reportes_de_confianza_ocultan_el_apodo_y_quitan_la_corona(api, registrar):
    _nueva_estacion_cada_vez()
    token_ana, ana = registrar()
    _participar(api, token_ana)
    _aportes_pasados(ana["id"], 3)
    api.put(f"{CORONA}/nickname", headers=_auth(token_ana), json={"texto": "Aquí sí pasa el X103"})
    jueces = [registrar() for _ in range(2)]
    for _, juez in jueces:
        _db().users.update_one({"_id": ObjectId(juez["id"])}, {"$set": {"reputacion": 250}})  # nivel 3

    assert api.post(f"{CORONA}/nickname/reports", headers=_auth(token_ana)).status_code == 403  # el propio no
    primero = api.post(f"{CORONA}/nickname/reports", headers=_auth(jueces[0][0]))
    assert primero.json() == {"oculto": False}
    assert api.get(CORONA, headers=_auth(jueces[0][0])).json()["tu"]["reportaste_el_apodo"] is True
    assert api.post(f"{CORONA}/nickname/reports", headers=_auth(jueces[1][0])).json() == {"oculto": True}
    despues = api.get(CORONA).json()
    assert (despues["apodo_del_dia"], despues["rey"]) == (None, None)
    assert _db().crown_bans.find_one({"_id": ObjectId(ana["id"])}) is not None  # 30 días sin reinar


def test_dejar_de_participar_o_borrar_la_cuenta_borra_sus_aportes(api, registrar):
    _nueva_estacion_cada_vez()
    token_ana, ana = registrar()
    _participar(api, token_ana)
    _aportes_pasados(ana["id"], 3)
    assert api.get(CORONA, headers=_auth(token_ana)).json()["eres_rey"] is True
    assert api.put("/api/v1/users/me/crown", headers=_auth(token_ana), json={"visible": False}).status_code == 200
    respuesta = api.put("/api/v1/users/me/crown", headers=_auth(token_ana), json={"participa": False})
    assert respuesta.json() == {"participa": False, "visible": False, "apodo": None}
    assert _db().crown_contributions.count_documents({"usuario": ObjectId(ana["id"])}) == 0
    assert api.get(CORONA).json()["rey"] is None
    assert api.put("/api/v1/users/me/crown", headers=_auth(token_ana), json={"visible": True}).status_code == 409

    token_beto, beto = registrar()
    _participar(api, token_beto)
    _aportes_pasados(beto["id"], 2)
    api.get(CORONA)
    assert api.delete("/api/v1/users/me", headers=_auth(token_beto)).status_code == 204
    assert _db().crown_contributions.count_documents({"usuario": ObjectId(beto["id"])}) == 0
    assert _db().crowns.find_one({"rey": ObjectId(beto["id"])}) is None


def test_el_apodo_vencido_se_borra(api, registrar):
    _nueva_estacion_cada_vez()
    token_ana, ana = registrar()
    _participar(api, token_ana)
    _aportes_pasados(ana["id"], 3)
    api.put(f"{CORONA}/nickname", headers=_auth(token_ana), json={"texto": "Aquí sí pasa el X103"})
    _db().crowns.update_one({"_id": "bazurto"}, {"$set": {"apodo.hasta": datetime.now(timezone.utc) - timedelta(minutes=1)}})
    assert api.get(CORONA).json()["apodo_del_dia"] is None
    assert _db().crowns.find_one({"_id": "bazurto"})["apodo"] is None  # no queda guardado
