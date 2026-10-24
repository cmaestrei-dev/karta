from datetime import date, datetime, timezone

from src.domain.horarios import (
    HORA_DE_COLOMBIA, HorarioRuta, domingo_de_pascua, festivos_de_colombia, opera, proximo_servicio, tipo_de_dia,
)

T103 = HorarioRuta.desde_texto("T103", {
    "lunes_a_viernes": ["05:00", "21:00"], "sabado": ["05:30", "20:30"], "domingo_y_festivos": ["06:00", "20:00"],
})
C016 = HorarioRuta.desde_texto("C016", {"lunes_a_viernes": ["05:30", "07:45"], "sabado": None,
                                        "domingo_y_festivos": None})


def cartagena(*args) -> datetime:
    return datetime(*args, tzinfo=HORA_DE_COLOMBIA)


def test_pascua_y_festivos_de_2026():
    assert domingo_de_pascua(2026) == date(2026, 4, 5)
    festivos = festivos_de_colombia(2026)
    # Corridos al lunes por la Ley Emiliani
    assert date(2026, 1, 12) in festivos        # Reyes Magos (6 de enero, martes)
    assert date(2026, 11, 16) in festivos       # Independencia de Cartagena (11 de noviembre, miércoles)
    assert date(2026, 5, 18) in festivos        # Ascensión
    assert date(2026, 6, 8) in festivos         # Corpus Christi
    # Fijos
    assert date(2026, 4, 3) in festivos         # Viernes Santo
    assert date(2026, 12, 8) in festivos
    assert date(2026, 11, 11) not in festivos
    assert len(festivos) == 18


def test_tipo_de_dia():
    assert tipo_de_dia(date(2026, 10, 23)) == "lunes_a_viernes"
    assert tipo_de_dia(date(2026, 10, 24)) == "sabado"
    assert tipo_de_dia(date(2026, 10, 25)) == "domingo_y_festivos"
    assert tipo_de_dia(date(2026, 11, 16)) == "domingo_y_festivos"   # lunes festivo


def test_una_ruta_opera_entre_el_primer_y_el_ultimo_despacho():
    assert opera(T103, cartagena(2026, 10, 23, 5, 0))
    assert opera(T103, cartagena(2026, 10, 23, 21, 25))     # el último bus aún va en camino
    assert not opera(T103, cartagena(2026, 10, 23, 21, 40))
    assert not opera(T103, cartagena(2026, 10, 23, 4, 30))
    assert not opera(T103, cartagena(2026, 10, 25, 5, 45))  # el domingo empieza a las 6:00


def test_las_rutas_de_hora_pico_y_sin_horario():
    assert opera(C016, cartagena(2026, 10, 23, 7, 0))
    assert not opera(C016, cartagena(2026, 10, 23, 12, 0))
    assert not opera(C016, cartagena(2026, 10, 24, 7, 0))   # no opera los sábados
    assert opera(None, cartagena(2026, 10, 24, 3, 0))       # sin horario publicado no se descarta


def test_la_hora_se_lleva_a_cartagena():
    # 02:00 UTC del sábado son las 21:00 del viernes en Cartagena.
    assert opera(T103, datetime(2026, 10, 24, 2, 0, tzinfo=timezone.utc))


def test_proximo_servicio_de_madrugada_y_en_festivo():
    assert proximo_servicio([T103, C016], cartagena(2026, 10, 23, 23, 0)) == cartagena(2026, 10, 24, 5, 30)
    # El lunes 16 de noviembre es festivo: la T103 abre a las 6:00 y la C016 no opera.
    assert proximo_servicio([T103, C016], cartagena(2026, 11, 16, 2, 0)) == cartagena(2026, 11, 16, 6, 0)


def test_horas_y_dias_en_palabras():
    from src.domain.horarios import cuando, hora_legible
    noche = cartagena(2026, 10, 23, 23, 0)          # viernes
    assert hora_legible(cartagena(2026, 10, 24, 5, 30)) == "5:30 a. m."
    assert hora_legible(cartagena(2026, 10, 24, 12, 15)) == "12:15 p. m."
    assert cuando(cartagena(2026, 10, 23, 23, 30), noche) == "a las 11:30 p. m."
    assert cuando(cartagena(2026, 10, 24, 5, 30), noche) == "mañana a las 5:30 a. m."
    assert cuando(cartagena(2026, 10, 24, 1, 0), noche) == "mañana a la 1:00 a. m."
    assert cuando(cartagena(2026, 10, 26, 5, 0), noche) == "el lunes a las 5:00 a. m."
