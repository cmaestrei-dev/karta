"""Los indicadores del piloto: conteos diarios sin cuentas ni puntos, y su informe sin cifras de menos de 10."""
from datetime import date, datetime, timezone

from src.domain.indicadores import consulta_de_llegada, dia, indicadores

BAZURTO = {"latitud": 10.413958, "longitud": -75.524358}
LOS_EJECUTIVOS = {"latitud": 10.399489, "longitud": -75.493651}


def _auth(token):
    return {"Authorization": f"Bearer {token}"}


def test_el_dia_y_la_hora_son_los_de_colombia():
    # 3:30 a. m. UTC del 19 es todavía el 18 a las 10:30 p. m. en Cartagena.
    tarde = datetime(2026, 11, 19, 3, 30, tzinfo=timezone.utc)
    assert dia(tarde) == "2026-11-18"
    assert consulta_de_llegada(tarde, troncal=True, con_datos=False) == {"llegadas.troncal.consultas.22": 1}
    assert consulta_de_llegada(datetime(2026, 11, 18, 12, 5, tzinfo=timezone.utc), troncal=False, con_datos=True) == {
        "llegadas.otras.consultas.7": 1, "llegadas.otras.con_datos.7": 1}


def test_los_indicadores_no_dan_cifras_de_menos_de_10():
    pico = {"llegadas": {"troncal": {"consultas": {"7": 20, "17": 10, "12": 50}, "con_datos": {"7": 9, "17": 3}}},
            "reportes": {"creados": 12, "confirmaciones": 9, "desmentidos": 3}, "viajes_compartidos": 4,
            "personas": {"vieron_reportes": 10, "agradecieron": 4}}
    hecho = indicadores([pico], cuentas_nuevas=8, volvieron=6)
    assert hecho.llegadas_con_datos_en_pico == 12 / 30  # las 12:00 no son hora pico
    assert hecho.confirmaciones_por_desmentido == 3.0
    assert hecho.agradecieron_de_los_que_vieron == 0.4
    assert hecho.reportes == 12
    assert hecho.viajes_compartidos is None  # 4 viajes: no se da la cifra
    assert hecho.volvieron_la_semana_siguiente is None  # 8 cuentas
    sin_desmentidos = indicadores([{"reportes": {"confirmaciones": 10}}], 0, 0)
    assert sin_desmentidos.confirmaciones_por_desmentido == float("inf")
    assert indicadores([], 0, 0).confirmaciones_por_desmentido is None


def test_el_informe_dice_menos_de_10_en_vez_de_la_cifra():
    from scripts.indicadores_del_piloto import en_markdown
    texto = en_markdown(indicadores([{"reportes": {"confirmaciones": 10}, "viajes_compartidos": 3}], 0, 0),
                        date(2026, 11, 18), date(2026, 11, 23))
    assert "| Reportes confirmados frente a desmentidos | ≥ 3 a 1 | sin desmentidos |" in texto
    assert "menos de 10 viajes compartidos" in texto and "| Reportes hechos | — | menos de 10 |" in texto


def test_la_api_cuenta_sin_guardar_quien(api, registrar):
    from src.infrastructure.database import get_database
    db = get_database()
    hoy = dia(datetime.now(timezone.utc))

    def conteos() -> dict:
        return db.daily_counts.find_one({"_id": hoy}) or {}

    def valor(doc: dict, *ruta: str) -> int:
        for clave in ruta:
            doc = doc.get(clave, {})
        return doc or 0

    antes = conteos()
    autor, _ = registrar()
    otro, otro_usuario = registrar()
    reporte = api.post("/api/v1/incidents/", headers=_auth(autor),
                       json={"tipo": "trancon", "detalles": {"estado": "lento"}, **BAZURTO}).json()
    for _ in range(2):  # abrirlo dos veces es una sola vista y una sola persona
        assert api.get(f"/api/v1/incidents/{reporte['id']}", headers=_auth(otro)).status_code == 200
    assert api.post(f"/api/v1/incidents/{reporte['id']}/thanks", headers=_auth(otro)).status_code == 200
    assert api.post(f"/api/v1/incidents/{reporte['id']}/votes", headers=_auth(otro), json={"sigue": True}).status_code == 200
    viaje = api.post("/api/v1/trips", json={"ruta": "T103", **LOS_EJECUTIVOS}, headers=_auth(otro))
    assert viaje.status_code == 201
    # Se termina en el acto: un T103 en vivo cambiaría las llegadas de las otras pruebas.
    assert api.delete(f"/api/v1/trips/{viaje.json()['viaje']}", headers=_auth(otro)).status_code == 204
    assert api.get("/api/v1/routes/T103/live", params={"desde_lat": 10.413958, "desde_lon": -75.524358,
                                                         "hasta_lat": 10.420019, "hasta_lon": -75.55141}).status_code == 200

    despues = conteos()
    for ruta, suma in [(("reportes", "creados"), 1), (("vistas",), 1), (("personas", "vieron_reportes"), 1),
                       (("gracias",), 1), (("personas", "agradecieron"), 1), (("reportes", "confirmaciones"), 1),
                       (("viajes_compartidos",), 1)]:
        assert valor(despues, *ruta) - valor(antes, *ruta) == suma, ruta
    consultas = sum(despues["llegadas"]["troncal"]["consultas"].values())
    assert consultas - sum(antes.get("llegadas", {}).get("troncal", {}).get("consultas", {}).values()) == 1
    assert str(otro_usuario["id"]) not in str(despues)
