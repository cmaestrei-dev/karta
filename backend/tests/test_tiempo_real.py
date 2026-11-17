"""Estimación de llegada con observaciones de viajeros, sobre rutas sintéticas (sin base de datos)."""
from datetime import datetime, timedelta, timezone

from src.domain.models import RutaTransporte
from src.domain.tiempo_real import (
    BusVarado, Observacion, Ocupacion, _muestreo, estimar_llegada, pasadas, varado_antes_de_la_parada,
)

METROS_POR_GRADO_LON = 109_400  # aprox. a la latitud de Cartagena
AHORA = datetime(2026, 10, 27, 15, 0, tzinfo=timezone.utc)


def _x(metros_al_este: float) -> tuple[float, float]:
    return (-75.55 + metros_al_este / METROS_POR_GRADO_LON, 10.40)


# Troncal recta de 6 km de oeste a este (22 km/h ≈ 367 m/min).
RECTA = RutaTransporte(id="T999", nombre="Recta", tipo="troncal", cortes_en_osm=0,
                       coordenadas=[_x(0), _x(6000)])
# La misma recta de ida y vuelta: llega al este y regresa por el mismo carril.
IDA_Y_VUELTA = RutaTransporte(id="T998", nombre="Ida y vuelta", tipo="troncal", cortes_en_osm=0,
                              coordenadas=[_x(0), _x(6000), _x(0.5)])


def _visto(metros: float, hace_min: float, en_vivo=False, ocupacion=None) -> Observacion:
    lon, lat = _x(metros)
    return Observacion(longitud=lon, latitud=lat, en=AHORA - timedelta(minutes=hace_min), en_vivo=en_vivo,
                       ocupacion=ocupacion)


def test_un_bus_en_vivo_aguas_arriba_da_la_llegada():
    # Bus a 1100 m de la parada (en 3000 m), visto ahora: 1100 / 367 ≈ 3 min.
    e = estimar_llegada(RECTA, _x(3000), _x(5000), [_visto(1900, 0, en_vivo=True)], AHORA)
    assert e.minutos == 3 and e.fuentes == 1 and e.visto_hace_min == 0


def test_un_avistamiento_viejo_avanza_con_el_tiempo():
    # Visto hace 2 min a 2200 m de la parada: ya recorrió ~730 m, faltan ~1470 m ≈ 4 min.
    e = estimar_llegada(RECTA, _x(3000), _x(5000), [_visto(800, 2)], AHORA)
    assert e.minutos == 4 and e.visto_hace_min == 2


def test_varias_observaciones_del_mismo_bus_suman_fuentes():
    obs = [_visto(1900, 0, en_vivo=True, ocupacion=Ocupacion.DE_PIE), _visto(1500, 1),
           _visto(1800, 0.5, ocupacion=Ocupacion.MUY_LLENO)]
    e = estimar_llegada(RECTA, _x(3000), _x(5000), obs, AHORA)
    assert e.fuentes == 3
    assert e.ocupacion == Ocupacion.DE_PIE  # la más reciente


def test_un_bus_que_ya_paso_no_cuenta():
    assert estimar_llegada(RECTA, _x(3000), _x(5000), [_visto(3500, 0, en_vivo=True)], AHORA) is None
    assert estimar_llegada(RECTA, _x(3000), _x(5000), [_visto(2900, 3)], AHORA) is None   # pasó hace rato
    assert estimar_llegada(RECTA, _x(3000), _x(5000), [], AHORA) is None


def test_los_buses_van_en_los_dos_sentidos_de_la_relacion():
    # Hacia el oeste (subida en 3000, bajada en 1000): el que viene del este cuenta, el del oeste no.
    e = estimar_llegada(RECTA, _x(3000), _x(1000), [_visto(4100, 0, en_vivo=True)], AHORA)
    assert e is not None and e.minutos == 3
    assert estimar_llegada(RECTA, _x(3000), _x(1000), [_visto(1900, 0, en_vivo=True)], AHORA) is None


def test_en_una_ruta_de_ida_y_vuelta_el_sentido_lo_da_la_bajada():
    posiciones, puntos = _muestreo(IDA_Y_VUELTA)
    assert len(pasadas(posiciones, puntos, _x(3000))) == 2
    # Hacia el oeste (vuelta): el bus que viene del este, visto en 4000 m, llega a 3000 en ~3 min.
    e = estimar_llegada(IDA_Y_VUELTA, _x(3000), _x(1000), [_visto(4000, 0, en_vivo=True)], AHORA)
    assert e is not None and e.minutos == 3


def _varado(metros: float, hace_min: float = 5) -> BusVarado:
    lon, lat = _x(metros)
    return BusVarado(longitud=lon, latitud=lat, en=AHORA - timedelta(minutes=hace_min), confirmaciones=1,
                     lugar="Cerca de Bazurto")


def test_un_bus_varado_no_cuenta_como_el_que_viene():
    # El único bus visto (a 1100 m) es el que se varó: no hay llegada que anunciar.
    visto_en_el_varado = [_visto(1900, 0, en_vivo=True)]
    assert estimar_llegada(RECTA, _x(3000), _x(5000), visto_en_el_varado, AHORA, [_varado(1950)]) is None
    # Otro bus, más atrás, sí cuenta.
    e = estimar_llegada(RECTA, _x(3000), _x(5000), visto_en_el_varado + [_visto(800, 0)], AHORA, [_varado(1950)])
    assert e is not None and e.fuentes == 1


def test_quien_espera_sabe_del_varado_que_viene_hacia_su_parada():
    hallado = varado_antes_de_la_parada(RECTA, _x(3000), _x(5000), [_varado(1900)])
    assert hallado is not None and round(hallado[1], -2) == 1100
    # Uno que ya pasó la parada, o en el otro sentido, no afecta.
    assert varado_antes_de_la_parada(RECTA, _x(3000), _x(5000), [_varado(3500)]) is None
    assert varado_antes_de_la_parada(RECTA, _x(3000), _x(1000), [_varado(1900)]) is None
