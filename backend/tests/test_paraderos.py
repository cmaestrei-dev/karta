"""Paraderos oficiales: en qué módulo para cada ruta según el sentido del viaje, y hacia dónde va."""
from src.domain.paraderos import ParaderoOficial, abordaje

HACIA = {"T101-ida": "Centro", "T101-vuelta": "Patio Portal", "A107-ida": "Blas de Lezo", "A107-vuelta": "Santa Lucía"}


def _p(ruta, sentido, orden, estacion, modulo=None):
    return ParaderoOficial(ruta, sentido, orden, f"{estacion} {modulo or ''}".strip(), estacion, modulo, "estacion", 0, 0)


PARADEROS = [
    _p("T101", "ida", 1, "portal", "A2"), _p("T101", "ida", 3, "madre-bernarda", "A1"),
    _p("T101", "ida", 7, "la-castellana", "B1"), _p("T101", "ida", 20, "la-bodeguita", "A1"),
    _p("T101", "vuelta", 1, "la-bodeguita", "A2"), _p("T101", "vuelta", 14, "la-castellana", "B2"),
    _p("T101", "vuelta", 18, "madre-bernarda", "A2"), _p("T101", "vuelta", 21, "portal", "A1"),
    _p("A107", "ida", 1, "santa-lucia"), _p("A107", "vuelta", 43, "santa-lucia"),
]


def test_el_modulo_y_el_sentido_salen_del_orden_de_las_dos_estaciones():
    assert abordaje("T101", "madre-bernarda", "la-bodeguita", PARADEROS, HACIA).modulo == "A1"
    hacia_el_portal = abordaje("T101", "la-castellana", "madre-bernarda", PARADEROS, HACIA)
    assert (hacia_el_portal.modulo, hacia_el_portal.hacia) == ("B2", "Patio Portal")
    assert abordaje("T101", "madre-bernarda", "la-bodeguita", PARADEROS, HACIA).hacia == "Centro"


def test_una_alimentadora_que_baja_en_santa_lucia_va_de_vuelta():
    como = abordaje("A107", None, "santa-lucia", PARADEROS, HACIA)
    assert (como.modulo, como.hacia) == (None, "Santa Lucía")
    assert abordaje("A107", "santa-lucia", None, PARADEROS, HACIA).hacia == "Blas de Lezo"
    assert abordaje("A107", None, None, PARADEROS, HACIA) is None
    assert abordaje("X999", "portal", "centro", PARADEROS, HACIA) is None


def test_las_opciones_dicen_el_modulo_y_hacia_donde_va_el_bus(api):
    # De Madre Bernarda a La Bodeguita en la troncal, un día hábil por la mañana.
    respuesta = api.post("/api/v1/routes/suggest", json={
        "origen": {"lat": 10.395141, "lon": -75.478607}, "destino": {"lat": 10.420019, "lon": -75.55141},
        "salida": "2026-10-27T08:00:00-05:00", "criterio": "sin_transbordo"}).json()
    # La T101 viene junto con la T103 («el que pase primero»): las dos paran en el módulo A1.
    buses = [t for o in respuesta["opciones"] for t in o["tramos"]
             if t["modo"] == "bus" and "T101" in [t["ruta"], *t["alternativas"]]]
    assert buses and buses[0]["modulo"] == "A1" and "el Centro" in buses[0]["hacia"]


def test_al_subir_en_madre_bernarda_advierte_que_santa_lucia_es_de_alimentadoras(api):
    from src.domain.trip_planning import advertencia_de_estacion
    assert "Santa Lucía" in advertencia_de_estacion("madre-bernarda", "troncal")
    assert advertencia_de_estacion("madre-bernarda", "alimentadora") is None
    assert "Santa Lucía" in advertencia_de_estacion("santa-lucia", "alimentadora")
    assert advertencia_de_estacion("la-bodeguita", "troncal") is None

    # Llegando desde la calle a Madre Bernarda para tomar la troncal hacia La Bodeguita.
    viaje = lambda origen, destino: api.post("/api/v1/routes/suggest", json={
        "origen": origen, "destino": destino, "salida": "2026-10-27T08:00:00-05:00"}).json()["opciones"]
    opciones = viaje({"lat": 10.395141, "lon": -75.478607}, {"lat": 10.420019, "lon": -75.55141})
    primer_bus = next(t for t in opciones[0]["tramos"] if t["modo"] == "bus")
    assert primer_bus["advertencia"].startswith("Ojo: Santa Lucía")
    # De la A107 al Centro se cambia en Santa Lucía y se cruza: el segundo bus ya trae su indicación, sin advertencia.
    con_cambio = [o for o in viaje({"lat": 10.380317, "lon": -75.490698}, {"lat": 10.42304, "lon": -75.549219})
                  if o["transbordos"] == 1 and o["tramos"][1]["ruta"] == "A107"]
    segundo = [t for t in con_cambio[0]["tramos"] if t["modo"] == "bus"][1]
    assert segundo["desde"] == "Estación Madre Bernarda" and segundo["advertencia"] is None
