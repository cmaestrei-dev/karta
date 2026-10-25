"""«¿Cómo pediste la parada?» (D12): se responde sin decir quién, y solo con una mayoría clara se dice qué funciona."""
from datetime import datetime, timezone

from src.domain.conocimiento import ComoSePidio, RespuestaDeParada, como_se_pide

AHORA = datetime(2026, 10, 25, 8, tzinfo=timezone.utc)
# Un paradero de la Avenida Pedro de Heredia (lon, lat).
PARADERO = (-75.5040, 10.4040)
TIMBRE, SOLO, CONDUCTOR = ComoSePidio.TIMBRE, ComoSePidio.PARO_SOLO, ComoSePidio.CONDUCTOR


def _r(como, metros_al_este=0):
    return RespuestaDeParada(como, PARADERO[0] + metros_al_este / 109_500, PARADERO[1], AHORA)


def test_con_menos_de_tres_respuestas_no_se_dice_nada():
    assert como_se_pide([_r(TIMBRE), _r(TIMBRE)], *PARADERO) is None


def test_la_mayoria_clara_dice_como_se_pide():
    sabido = como_se_pide([_r(TIMBRE), _r(TIMBRE, 30), _r(TIMBRE), _r(SOLO)], *PARADERO)
    assert (sabido.como, sabido.viajeros, sabido.respuestas) == (TIMBRE, 3, 4)


def test_sin_mayoria_clara_no_se_dice_nada():
    assert como_se_pide([_r(TIMBRE), _r(TIMBRE), _r(SOLO), _r(CONDUCTOR), _r(SOLO)], *PARADERO) is None


def test_solo_cuentan_las_respuestas_de_ese_paradero():
    # Las del paradero siguiente (a 400 m) no cuentan.
    lejos = [_r(SOLO, 400) for _ in range(5)]
    assert como_se_pide(lejos + [_r(TIMBRE), _r(TIMBRE)], *PARADERO) is None


def test_se_responde_sin_decir_quien_y_se_consulta(api, registrar):
    punto = {"latitud": PARADERO[1], "longitud": PARADERO[0]}
    consulta = {"latitud": PARADERO[1], "longitud": PARADERO[0]}
    assert api.get("/api/v1/routes/T103/stop-request", params=consulta).json() == {
        "como": None, "viajeros": 0, "respuestas": 0}

    for como in ("timbre", "timbre", "paro_solo", "timbre"):
        token, _ = registrar()
        respuesta = api.post("/api/v1/stop-requests", json={"ruta": "T103", "como": como, **punto},
                             headers={"Authorization": f"Bearer {token}"})
        assert respuesta.status_code == 201, respuesta.text

    assert api.get("/api/v1/routes/T103/stop-request", params=consulta).json() == {
        "como": "timbre", "viajeros": 3, "respuestas": 4}
    # Otra ruta en el mismo punto no sabe nada todavía.
    assert api.get("/api/v1/routes/X103/stop-request", params=consulta).json()["como"] is None

    from src.infrastructure.database import get_database
    assert all(set(d) <= {"_id", "ruta", "ubicacion", "como", "en", "expira_en"}
               for d in get_database().stop_answers.find())

    token, _ = registrar()
    auth = {"Authorization": f"Bearer {token}"}
    assert api.post("/api/v1/stop-requests", json={"ruta": "T103", "como": "timbre", **punto}).status_code == 401
    assert api.post("/api/v1/stop-requests", json={"ruta": "T103", "como": "grite", **punto},
                    headers=auth).status_code == 422
    assert api.post("/api/v1/stop-requests", json={"ruta": "T999", "como": "timbre", **punto},
                    headers=auth).status_code == 422
    assert api.get("/api/v1/routes/T999/stop-request", params=consulta).status_code == 404
