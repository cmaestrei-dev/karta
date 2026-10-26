"""Qué tan exacto es Karta (D17): el resultado de cada viaje y las cifras publicables (al menos 10 viajes)."""
from datetime import datetime, timezone

from src.domain.horarios import HORA_DE_COLOMBIA
from src.domain.precision import MINIMO_POR_CIFRA, BusMedido, ResultadoDeViaje, informe, precision, resultado

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


def test_con_menos_de_10_viajes_no_hay_cifra():
    assert precision([2] * (MINIMO_POR_CIFRA - 1)) is None
    assert precision([2] * MINIMO_POR_CIFRA) is not None


def test_las_cifras_de_un_grupo():
    p = precision([-3, -1, 0, 1, 2, 4, 4, 6, 8, 15])
    assert p.viajes == 10
    assert p.mediana_min == 3.0  # entre 2 y 4
    assert p.p90_min == 8  # 9 de 10 se equivocan 8 minutos o menos
    assert p.cerca == 0.7  # -3, -1, 0, 1, 2, 4, 4


def test_el_informe_solo_publica_los_grupos_con_10_viajes():
    a101 = BusMedido("A101", 5, None, 15, 18)  # la espera no se pudo medir
    viajes = [_viaje(2) for _ in range(10)] + [_viaje(-1, hora=18, buses=(T103, a101)) for _ in range(4)]
    hecho = informe(viajes)
    assert hecho.viajes == 14 and hecho.total.viajes == 14
    assert list(hecho.por_hora) == [7]  # las 6 p. m. tienen solo 4 viajes
    assert hecho.espera_por_ruta["T103"].mediana_min == 3.0 and "A101" not in hecho.espera_por_ruta
    assert hecho.a_bordo_por_ruta["T103"].viajes == 14 and "A101" not in hecho.a_bordo_por_ruta


def test_el_informe_en_markdown_no_muestra_grupos_pequenos():
    from scripts.informe_de_precision import en_markdown
    desde = datetime(2026, 11, 18, tzinfo=HORA_DE_COLOMBIA)
    assert "Aún no hay 10 viajes" in en_markdown(informe([_viaje(2)] * 3), desde)
    texto = en_markdown(informe([_viaje(2)] * 10 + [_viaje(-1, hora=18)] * 4), desde)
    assert "| Todos | 14 |" in texto and "| 7:00 | 10 | +2 min |" in texto
    assert "18:00" not in texto
