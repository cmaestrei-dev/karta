"""«Marca este paradero»: la comunidad ubica los paraderos oficiales que no tienen coordenadas."""
from datetime import datetime, timezone

from src.domain.mapeo import EstadoDeMarca, Marca, Voto, acertaron, estado_por_apoyo, peso, pistas

AHORA = datetime(2026, 10, 25, 12, tzinfo=timezone.utc)


def test_una_marca_queda_con_tres_de_apoyo_y_se_descarta_con_dos_en_contra():
    assert peso(1) == 1 and peso(4) == 2
    assert estado_por_apoyo(1) == EstadoDeMarca.POR_CONFIRMAR
    assert estado_por_apoyo(3) == EstadoDeMarca.UBICADA
    assert estado_por_apoyo(-2) == EstadoDeMarca.DESCARTADA
    marca = Marca("m", "A107-ida-05", "A107", 0, 0, "ana", 3,
                  (Voto("beto", True, 1), Voto("caro", False, 1), Voto("dani", True, 1)), EstadoDeMarca.UBICADA, AHORA)
    assert acertaron(marca) == ["beto", "dani"]


def test_las_pistas_solo_salen_con_tres_subidas_en_el_mismo_lugar():
    aqui = [(-75.48, 10.39), (-75.48001, 10.39001), (-75.47999, 10.39)]
    lejos = [(-75.49, 10.40), (-75.49, 10.40001)]
    resultado = pistas(aqui + lejos)
    assert len(resultado) == 1 and resultado[0].subidas == 3


def _ruta_sin_ubicar(api, codigo="A107"):
    sentidos = api.get(f"/api/v1/routes/{codigo}/stops").json()["sentidos"]
    return next(p for s in sentidos for p in s["paraderos"] if p["estado"] == "sin_ubicar")


def test_marcar_confirmar_y_quedar_en_el_mapa(api, registrar):
    from src.infrastructure.database import get_database
    respuesta = api.get("/api/v1/routes/A107/stops").json()
    assert respuesta["total"] == 43 and 0 < respuesta["ubicados"] < respuesta["total"]
    assert {s["sentido"] for s in respuesta["sentidos"]} == {"ida", "vuelta"}

    paradero = _ruta_sin_ubicar(api)
    # Un punto sobre el recorrido de la A107 (Tv. 54, cerca de Santa Lucía).
    punto = {"latitud": 10.3925, "longitud": -75.4850}
    lejos = {"latitud": 10.4236, "longitud": -75.5480}  # el Centro, lejos de la A107
    token_ana, ana = registrar()
    auth = lambda t: {"Authorization": f"Bearer {t}"}
    assert api.post(f"/api/v1/stops/{paradero['id']}/marks", json=lejos, headers=auth(token_ana)).status_code == 422
    marca = api.post(f"/api/v1/stops/{paradero['id']}/marks", json=punto, headers=auth(token_ana))
    assert marca.status_code == 201, marca.text
    marca = marca.json()
    assert marca["mia"] and marca["apoyo"] == 1 and marca["estado"] == "por_confirmar"
    # Otra marca para el mismo paradero espera a que esta se resuelva.
    token_beto, _ = registrar()
    assert api.post(f"/api/v1/stops/{paradero['id']}/marks", json=punto, headers=auth(token_beto)).status_code == 409

    # No se confirma la propia, ni desde lejos.
    votar = lambda t, aqui, donde=punto: api.post(f"/api/v1/stops/marks/{marca['id']}/votes",
                                                   json={**donde, "esta_aqui": aqui}, headers=auth(t))
    assert votar(token_ana, True).status_code == 403
    assert votar(token_beto, True, lejos).status_code == 422
    assert votar(token_beto, True).json()["apoyo"] == 2
    assert votar(token_beto, True).status_code == 409
    token_caro, _ = registrar()
    assert votar(token_caro, True).json()["estado"] == "ubicada"

    # Queda en el mapa y Ana es Kartógrafa: +5 de reputación y la insignia.
    ubicado = next(p for s in api.get("/api/v1/routes/A107/stops").json()["sentidos"] for p in s["paraderos"]
                   if p["id"] == paradero["id"])
    assert ubicado["estado"] == "comunidad" and ubicado["latitud"] is not None
    yo = api.get("/api/v1/users/me", headers=auth(token_ana)).json()
    assert yo["reputacion"] == 105 and yo["impacto"]["paraderos"] == 1
    assert "kartografo" in [i["clave"] for i in yo["insignias"]]
    # Recargar los datos oficiales no borra lo que ubicó la comunidad.
    from src.infrastructure.reference_data import cargar_datos_de_referencia
    cargar_datos_de_referencia(get_database(), forzar=True)
    assert next(p for s in api.get("/api/v1/routes/A107/stops").json()["sentidos"] for p in s["paraderos"]
                if p["id"] == paradero["id"])["estado"] == "comunidad"


def test_con_dos_no_esta_aqui_la_marca_se_descarta_y_se_puede_marcar_otra_vez(api, registrar):
    paradero = _ruta_sin_ubicar(api, "A108")
    punto = {"latitud": 10.3925, "longitud": -75.4850}
    auth = lambda t: {"Authorization": f"Bearer {t}"}
    token, _ = registrar()
    marca = api.post(f"/api/v1/stops/{paradero['id']}/marks", json=punto, headers=auth(token)).json()
    for _ in range(3):
        otro, _ = registrar()
        resultado = api.post(f"/api/v1/stops/marks/{marca['id']}/votes", json={**punto, "esta_aqui": False},
                             headers=auth(otro)).json()
        if resultado.get("estado") == "descartada":
            break
    assert resultado["estado"] == "descartada"
    nuevo, _ = registrar()
    assert api.post(f"/api/v1/stops/{paradero['id']}/marks", json=punto, headers=auth(nuevo)).status_code == 201


def test_las_subidas_son_anonimas_y_dan_pistas(api, registrar):
    from src.infrastructure.database import get_database
    token, _ = registrar()
    for dx in (0, 0.00001, -0.00001):
        assert api.post("/api/v1/stops/boardings", json={"ruta": "A107", "latitud": 10.3925, "longitud": -75.4850 + dx},
                        headers={"Authorization": f"Bearer {token}"}).status_code == 204
    pistas_ = api.get("/api/v1/routes/A107/stops").json()["pistas"]
    assert pistas_ and pistas_[0]["subidas"] >= 3
    assert all(set(d) <= {"_id", "ruta", "ubicacion", "en", "expira_en"} for d in get_database().boardings.find())


def test_viaje_de_mapeo_marca_confirma_y_contradice(api, registrar):
    from shapely.geometry import LineString, Point
    from src.domain.geo import a_grados, a_metros

    from src.domain.mapeo import respuesta_del_viaje
    assert respuesta_del_viaje(10) is True and respuesta_del_viaje(200) is False and respuesta_del_viaje(80) is None

    sentidos = {s["sentido"]: s["paraderos"] for s in api.get("/api/v1/routes/A107/stops").json()["sentidos"]}
    sin_ubicar = next(p for p in sentidos["ida"] if p["estado"] == "sin_ubicar")
    ubicado = next(p for p in sentidos["ida"] if p["estado"] == "estacion")
    de_vuelta = next(p for p in sentidos["vuelta"] if p["estado"] == "sin_ubicar")
    # Puntos sobre el recorrido de la A107: donde paró el bus, a 10 m, a 80 m y a 200 m de ahí.
    linea = a_metros(LineString(api.get("/api/v1/routes/A107").json()["geometria"]["coordinates"]))
    base = linea.project(a_metros(Point(-75.4850, 10.3925)))
    def sobre_la_ruta(metros):
        p = a_grados(linea.interpolate(base + metros))
        return {"longitud": p.x, "latitud": p.y}
    auth = lambda t: {"Authorization": f"Bearer {t}"}
    viaje = lambda t, paradas: api.post("/api/v1/routes/A107/mapping-rides", headers=auth(t),
                                        json={"sentido": "ida", "paradas": paradas})

    token_ana, _ = registrar()
    r = viaje(token_ana, [{"paradero": sin_ubicar["id"], **sobre_la_ruta(0)},
                          {"paradero": ubicado["id"], **sobre_la_ruta(0)},
                          {"paradero": de_vuelta["id"], **sobre_la_ruta(0)}])
    assert r.status_code == 200, r.text
    assert r.json()["marcados"] == 1
    assert [p["resultado"] for p in r.json()["paradas"]] == ["marcado", "ya_ubicado", "otra_ruta"]
    # Otro viaje de Ana no cuenta dos veces.
    assert viaje(token_ana, [{"paradero": sin_ubicar["id"], **sobre_la_ruta(0)}]).json()["paradas"][0]["resultado"] \
        == "ya_respondido"

    # Beto paró a 10 m: la confirma. Caro, a 80 m: no dice nada. Dani, a 200 m: dice que no está ahí.
    resultado = lambda t, m: viaje(t, [{"paradero": sin_ubicar["id"], **sobre_la_ruta(m)}]).json()["paradas"][0]
    assert resultado(registrar()[0], 10)["resultado"] == "confirmado"
    assert resultado(registrar()[0], 80)["resultado"] == "dudoso"
    assert resultado(registrar()[0], 200)["resultado"] == "contradicho"
    marca = next(p for s in api.get("/api/v1/routes/A107/stops").json()["sentidos"] for p in s["paraderos"]
                 if p["id"] == sin_ubicar["id"])["marca"]
    assert marca["apoyo"] == 1 and marca["estado"] == "por_confirmar"
    # Con otros dos que paran ahí, queda en el mapa.
    assert resultado(registrar()[0], 5)["resultado"] == "confirmado"
    assert resultado(registrar()[0], 0)["resultado"] == "confirmado"
    assert next(p for s in api.get("/api/v1/routes/A107/stops").json()["sentidos"] for p in s["paraderos"]
                if p["id"] == sin_ubicar["id"])["estado"] == "comunidad"

    # Sin sesión no se puede, y la ruta tiene que existir.
    assert api.post("/api/v1/routes/A107/mapping-rides", json={"sentido": "ida", "paradas": []}).status_code in (401, 422)
    assert viaje(token_ana, [{"paradero": "x", **sobre_la_ruta(0)}]).json()["paradas"][0]["resultado"] == "otra_ruta"
    assert api.post("/api/v1/routes/A999/mapping-rides", headers=auth(token_ana),
                    json={"sentido": "ida", "paradas": [{"paradero": "x", **sobre_la_ruta(0)}]}).status_code == 404
