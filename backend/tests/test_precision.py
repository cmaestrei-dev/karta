"""Qué tan exacto es Karta (D17): el resultado de cada viaje y las cifras publicables (al menos 10 personas)."""
from datetime import datetime, timezone

from src.domain.horarios import HORA_DE_COLOMBIA
from src.domain.precision import (
    MINIMO_POR_CIFRA, BusMedido, ResultadoDeViaje, celdas_de, informe, mes_de, precision, resultado,
)

T103 = BusMedido("T103", espera_estimada_min=6, espera_real_min=9, a_bordo_estimado_min=20, a_bordo_real_min=24)


def _viaje(error: int, hora: int = 7, buses=(T103,)) -> ResultadoDeViaje:
    return ResultadoDeViaje(30, 30 + error, datetime(2026, 11, 18, hora, 0, tzinfo=HORA_DE_COLOMBIA),
                            "lunes_a_viernes", tuple(buses))


def test_la_salida_se_deduce_de_la_llegada_y_se_redondea_al_cuarto_de_hora():
    # Llegó a las 8:44 de Colombia (13:44 UTC) tras 37 minutos: salió a las 8:07, que queda en la franja de las 8:00.
    r = resultado(34, 37, [T103], datetime(2026, 11, 18, 13, 44, 51, tzinfo=timezone.utc))
    assert (r.franja.hour, r.franja.minute, r.franja.second) == (8, 0, 0)
    assert r.franja.utcoffset() == HORA_DE_COLOMBIA.utcoffset(None)
    assert r.tipo_de_dia == "lunes_a_viernes" and r.error_min == 3
    # Un domingo cuenta como domingo.
    assert resultado(20, 20, [T103], datetime(2026, 11, 22, 15, 0, tzinfo=timezone.utc)).tipo_de_dia == "domingo_y_festivos"


def test_lo_que_cuenta_es_cuantas_personas_hay_detras_no_cuantos_viajes():
    # 30 viajes de la misma persona no son una cifra publicable; 10 personas sí.
    assert precision([2] * 30, personas=1) is None
    assert precision([2] * 10, personas=MINIMO_POR_CIFRA - 1) is None
    assert precision([2] * 10, personas=MINIMO_POR_CIFRA) is not None
    assert precision([], personas=50) is None


def test_las_cifras_de_un_grupo():
    p = precision([-3, -1, 0, 1, 2, 4, 4, 6, 8, 15], personas=10)
    assert p.viajes == 10
    assert p.mediana_min == 3.0  # entre 2 y 4
    assert p.p90_min == 8  # 9 de 10 se equivocan 8 minutos o menos
    assert p.cerca == 0.7  # -3, -1, 0, 1, 2, 4, 4


def test_cada_viaje_aporta_a_su_total_su_hora_y_sus_rutas():
    a101 = BusMedido("A101", 5, None, 15, 18)  # la espera no se pudo medir: no aporta a la espera de la A101
    assert celdas_de(_viaje(2, hora=18, buses=(T103, a101))) == [
        "total", "hora:18", "espera:T103", "a_bordo:T103", "a_bordo:A101"]
    assert mes_de(datetime(2026, 12, 1, 3, 0, tzinfo=timezone.utc)) == "2026-11"  # aún 30 de noviembre en Cartagena


def test_el_informe_solo_publica_los_grupos_con_10_personas():
    a101 = BusMedido("A101", 5, None, 15, 18)
    viajes = [_viaje(2) for _ in range(12)] + [_viaje(-1, hora=18, buses=(T103, a101)) for _ in range(12)]
    # Las 6 p. m. tienen 12 viajes, pero de 3 personas: no se publican.
    personas = {"total": 14, "hora:7": 11, "hora:18": 3, "espera:T103": 14, "a_bordo:T103": 14, "a_bordo:A101": 3}
    hecho = informe(viajes, personas)
    assert hecho.viajes == 24 and hecho.total.viajes == 24
    assert list(hecho.por_hora) == [7]
    assert hecho.espera_por_ruta["T103"].viajes == 24 and "A101" not in hecho.espera_por_ruta
    assert list(hecho.a_bordo_por_ruta) == ["T103"]
    assert informe(viajes, {}).total is None  # sin saber cuántas personas hay, no se publica nada


def test_el_informe_en_markdown_no_muestra_grupos_pequenos():
    from scripts.informe_de_precision import en_markdown
    desde = datetime(2026, 11, 18, tzinfo=HORA_DE_COLOMBIA)
    assert "Aún no hay viajes de 10 personas distintas" in en_markdown(informe([_viaje(2)] * 30, {"total": 1}), desde)
    texto = en_markdown(informe([_viaje(2)] * 10 + [_viaje(-1, hora=18)] * 4,
                                {"total": 12, "hora:7": 10, "hora:18": 2}), desde)
    assert "| Todos | 14 |" in texto and "| 7:00 | 10 | +2 min |" in texto
    assert "18:00" not in texto
