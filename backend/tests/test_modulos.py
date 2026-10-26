"""De qué lado de la estación queda cada vagón, aprendido de las subidas de los viajeros (D18)."""
from src.domain.modulos import lados_de_la_estacion

GRADO = 1 / 111_000  # ~1 m en grados, cerca del ecuador


def m(x):
    return (-75.48 + x * GRADO, 10.395)


HACIA_EL_CENTRO = m(800)  # la estación vecina hacia el Centro, 800 m al este


def test_el_vagon_mas_cerca_de_la_vecina_hacia_el_centro_es_el_extremo_hacia_el_centro():
    lados = lados_de_la_estacion({"A": [m(25), m(30), m(20)], "B": [m(-25), m(-20), m(-30), m(-28)]}, HACIA_EL_CENTRO)
    assert (lados["A"].hacia, lados["A"].viajeros) == ("el Centro", 3)
    assert lados["A"].centro == m(25)
    assert (lados["B"].hacia, lados["B"].viajeros) == ("el Portal", 4)


def test_sin_subidas_suficientes_o_sin_separacion_no_dice_nada():
    assert lados_de_la_estacion({"A": [m(25), m(30)], "B": [m(-25), m(-20), m(-30)]}, HACIA_EL_CENTRO) == {}
    assert lados_de_la_estacion({"A": [m(2), m(3), m(1)], "B": [m(-2), m(-1), m(0)]}, HACIA_EL_CENTRO) == {}


def test_las_subidas_en_estaciones_ensenan_el_lado_y_no_son_pistas_de_paraderos(api, registrar):
    estaciones = {e["id"]: e for e in api.get("/api/v1/routes/T101").json()["estaciones"]}
    mb, castellana = estaciones["madre-bernarda"], estaciones["la-castellana"]
    # Un punto a `metros` de Madre Bernarda, hacia La Castellana (hacia el Centro) o al revés.
    def hacia(metros):
        dlat, dlon = castellana["latitud"] - mb["latitud"], castellana["longitud"] - mb["longitud"]
        largo = (dlat ** 2 + dlon ** 2) ** 0.5 * 111_000
        return {"latitud": mb["latitud"] + dlat * metros / largo, "longitud": mb["longitud"] + dlon * metros / largo}
    token, _ = registrar()
    for metros, modulo in [(25, "A1"), (30, "A2"), (20, "A1"), (-25, "B1"), (-30, "B2"), (-20, "B1")]:
        assert api.post("/api/v1/stops/boardings", headers={"Authorization": f"Bearer {token}"},
                        json={"ruta": "T101", "modulo": modulo, **hacia(metros)}).status_code == 204
    # Un módulo mal escrito se rechaza.
    assert api.post("/api/v1/stops/boardings", headers={"Authorization": f"Bearer {token}"},
                    json={"ruta": "T101", "modulo": "Z9", **hacia(0)}).status_code == 422

    opciones = api.post("/api/v1/routes/suggest", json={
        "origen": {"lat": 10.395141, "lon": -75.478607}, "destino": {"lat": 10.420019, "lon": -75.55141},
        "salida": "2026-10-27T08:00:00-05:00", "criterio": "sin_transbordo"}).json()["opciones"]
    bus = next(t for o in opciones for t in o["tramos"] if t["modo"] == "bus" and t["modulo"] == "A1")
    assert (bus["lado_del_modulo"], bus["lado_segun"]) == ("el Centro", 3)
    # Para el plano: el vagón del bus primero, donde esperaron en promedio sus viajeros (25 m hacia el Centro).
    assert [(v["letra"], v["hacia"]) for v in bus["vagones"]] == [("A", "el Centro"), ("B", "el Portal")]
    assert abs(bus["vagones"][0]["latitud"] - hacia(25)["latitud"]) < 1e-5
    # No aparecen como pistas para ubicar paraderos.
    assert api.get("/api/v1/routes/T101/stops").json()["pistas"] == []
