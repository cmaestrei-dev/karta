"""Pruebas unitarias del planificador de viajes con una ruta sintética (no necesitan base de datos)."""
import pytest

from src.domain.models import Estacion, RutaTransporte
from src.domain.trip_planning import ESPERA_ESTIMADA_MIN, mejor_opcion_en_ruta, planificar

METROS_POR_GRADO_LAT = 110_600  # aprox. a la latitud de Cartagena

# Ruta recta de oeste a este sobre la latitud 10.40, de unos 5,5 km.
RECTA = [(-75.55, 10.40), (-75.53, 10.40), (-75.50, 10.40)]


def _ruta(tipo="pretroncal", id_ruta="X999"):
    return RutaTransporte(id=id_ruta, nombre="Ruta de prueba", tipo=tipo, coordenadas=RECTA, cortes_en_osm=0)


def _al_norte(lon, metros):
    return (lon, 10.40 + metros / METROS_POR_GRADO_LAT)


def test_sube_cerca_del_origen_y_baja_cerca_del_destino():
    opcion = mejor_opcion_en_ruta(_ruta(), [], _al_norte(-75.545, 200), _al_norte(-75.505, 200))

    assert [t.modo for t in opcion.tramos] == ["caminata", "bus", "caminata"]
    caminata_inicial, bus, _ = opcion.tramos
    assert caminata_inicial.distancia_m < 300          # ~200 m con rodeo
    assert 4000 < bus.distancia_m < 4500               # ~4,4 km sobre la ruta
    assert bus.espera_min == ESPERA_ESTIMADA_MIN["pretroncal"]


def test_tambien_funciona_en_sentido_contrario_al_de_la_relacion():
    opcion = mejor_opcion_en_ruta(_ruta(), [], _al_norte(-75.505, 200), _al_norte(-75.545, 200))

    assert opcion is not None
    bus = opcion.tramos[1]
    assert bus.coordenadas[0][0] > bus.coordenadas[-1][0]  # avanza de este a oeste


def test_sin_opcion_si_el_destino_queda_lejos_de_la_ruta():
    assert mejor_opcion_en_ruta(_ruta(), [], _al_norte(-75.545, 200), _al_norte(-75.505, 3000)) is None


# Estaciones cada ~1 km, como en el corredor real de la troncal.
ESTACIONES = [
    Estacion(id=str(k), nombre=f"Estación {k}", latitud=10.40, longitud=lon, rutas=["T999"])
    for k, lon in enumerate([-75.540, -75.531, -75.522, -75.513])
]


def test_en_el_corredor_de_la_troncal_solo_se_sube_en_estaciones():
    # El origen queda entre dos estaciones: hay que caminar hasta la más conveniente, no subir en la vía.
    opcion = mejor_opcion_en_ruta(_ruta("troncal", "T999"), ESTACIONES, _al_norte(-75.537, 100), _al_norte(-75.512, 100))

    subida, bajada = opcion.tramos[1].coordenadas[0], opcion.tramos[1].coordenadas[-1]
    assert subida[0] == pytest.approx(-75.540, abs=0.001)
    assert bajada[0] == pytest.approx(-75.513, abs=0.001)


def test_fuera_del_corredor_la_troncal_para_en_la_via():
    # A más de 700 m de toda estación (como T103 en Bocagrande) se sube donde pasa el bus.
    opcion = mejor_opcion_en_ruta(_ruta("troncal", "T999"), ESTACIONES, _al_norte(-75.549, 100), _al_norte(-75.512, 100))

    subida = opcion.tramos[1].coordenadas[0]
    assert subida[0] == pytest.approx(-75.549, abs=0.001)


def test_troncal_sin_estaciones_no_sirve():
    assert mejor_opcion_en_ruta(_ruta("troncal", "T999"), [], _al_norte(-75.545, 100), _al_norte(-75.505, 100)) is None


def test_trayecto_corto_se_hace_a_pie():
    opciones = planificar([_ruta()], [], _al_norte(-75.545, 50), _al_norte(-75.541, 50))

    assert len(opciones) == 1
    assert [t.modo for t in opciones[0].tramos] == ["caminata"]


def test_ruta_con_muchos_cortes_en_osm_se_descarta():
    rota = RutaTransporte(id="X998", nombre="Rota", tipo="pretroncal", coordenadas=RECTA, cortes_en_osm=10)
    assert planificar([rota], [], _al_norte(-75.545, 200), _al_norte(-75.505, 200)) == []


def test_el_expreso_no_para_en_estaciones_que_no_son_suyas():
    # La estación 1 (-75.531) es de otra ruta: el expreso pasa sin parar, así que aunque quede
    # más cerca del origen hay que caminar hasta la estación 0 (-75.540), que sí es suya.
    expreso = [e if e.id != "1" else Estacion(id="1", nombre="Solo T101", latitud=10.40, longitud=-75.531,
                                                 rutas=["T101"]) for e in ESTACIONES]
    opcion = mejor_opcion_en_ruta(_ruta("troncal", "T999"), expreso, _al_norte(-75.534, 50), _al_norte(-75.512, 100))

    subida = opcion.tramos[1].coordenadas[0]
    assert subida[0] == pytest.approx(-75.540, abs=0.001)


# ---------------------------------------------------------------- transbordos

# Una ruta de norte a sur que cruza la RECTA en -75.52 y sigue 4,4 km al norte.
VERTICAL = [(-75.52, 10.36), (-75.52, 10.40), (-75.52, 10.44)]


def _vertical(tipo="alimentadora", id_ruta="A999"):
    return RutaTransporte(id=id_ruta, nombre="Vertical", tipo=tipo, coordenadas=VERTICAL, cortes_en_osm=0)


def test_con_transbordo_se_llega_a_donde_ninguna_ruta_sola_llega():
    origen = _al_norte(-75.548, 100)              # junto al inicio de la recta
    destino = (-75.5195, 10.435)                   # junto al final de la vertical

    sin = planificar([_ruta(), _vertical()], [], origen, destino, con_transbordos=False)
    assert sin == []

    opcion = planificar([_ruta(), _vertical()], [], origen, destino)[0]
    assert [t.modo for t in opcion.tramos] == ["caminata", "bus", "caminata", "bus", "caminata"]
    assert [r.id for r in opcion.rutas] == ["X999", "A999"]
    assert opcion.transbordos == 1
    # Se cambia de bus en el cruce de las dos rutas.
    bajada_de_la_primera = opcion.tramos[1].coordenadas[-1]
    subida_a_la_segunda = opcion.tramos[3].coordenadas[0]
    assert bajada_de_la_primera[0] == pytest.approx(-75.52, abs=0.002)
    assert subida_a_la_segunda[1] == pytest.approx(10.40, abs=0.002)
    # La segunda ruta se toma hacia el norte, en el sentido de la relación.
    assert opcion.tramos[3].coordenadas[-1][1] > subida_a_la_segunda[1]
    # El tiempo incluye las dos esperas.
    assert opcion.tiempo_total_min > ESPERA_ESTIMADA_MIN["pretroncal"] + ESPERA_ESTIMADA_MIN["alimentadora"]


def test_el_transbordo_funciona_en_contra_del_sentido_de_las_relaciones():
    # Del norte de la vertical al oeste de la recta: las dos rutas se recorren al revés.
    opcion = planificar([_ruta(), _vertical()], [], (-75.5195, 10.435), _al_norte(-75.548, 100))[0]
    assert [r.id for r in opcion.rutas] == ["A999", "X999"]
    assert opcion.tramos[1].coordenadas[-1][1] < opcion.tramos[1].coordenadas[0][1]   # baja hacia el sur
    assert opcion.tramos[3].coordenadas[-1][0] < opcion.tramos[3].coordenadas[0][0]   # va hacia el oeste


def test_rutas_que_no_se_acercan_no_ofrecen_transbordo():
    lejana = RutaTransporte(id="A998", nombre="Lejana", tipo="alimentadora", cortes_en_osm=0,
                            coordenadas=[(-75.46, 10.45), (-75.46, 10.50)])
    assert planificar([_ruta(), lejana], [], _al_norte(-75.548, 100), (-75.4595, 10.49)) == []


def test_un_transbordo_que_no_gana_a_ir_directo_se_descarta():
    # Las dos rutas van por la misma recta: cambiar de una a otra no ahorra nada.
    otra = _ruta(tipo="pretroncal", id_ruta="X998")
    opciones = planificar([_ruta(), otra], [], _al_norte(-75.545, 200), _al_norte(-75.505, 200))
    assert all(o.transbordos == 0 for o in opciones)
    assert sorted(o.ruta.id for o in opciones) == ["X998", "X999"]


def test_un_transbordo_que_gana_solo_un_minuto_no_compensa():
    from src.domain.trip_planning import PENALIZACION_TRANSBORDO_MIN, Tramo, OpcionViaje, _depurar
    def opcion(*rutas, minutos):
        tramos = tuple(Tramo(modo="bus", coordenadas=((0, 0), (1, 1)), distancia_m=1, duracion_min=minutos / len(rutas),
                             ruta=r) for r in rutas)
        return OpcionViaje(tramos=tramos)
    x105, t103 = _ruta(id_ruta="X105"), _ruta(tipo="troncal", id_ruta="T103")
    directa = opcion(x105, minutos=59)
    casi_igual = opcion(x105, t103, minutos=58)
    mucho_mejor = opcion(x105, t103, minutos=59 - PENALIZACION_TRANSBORDO_MIN - 5)
    assert _depurar([directa, casi_igual]) == [directa]
    assert _depurar([directa, mucho_mejor]) == [directa, mucho_mejor]


def test_las_estaciones_de_una_ruta_de_ida_y_vuelta_salen_en_el_orden_de_la_ida():
    from src.domain.trip_planning import estaciones_en_orden
    ida_y_vuelta = RutaTransporte(id="T999", nombre="Ida y vuelta", tipo="troncal", cortes_en_osm=0,
                                  coordenadas=[(-75.55, 10.40), (-75.50, 10.40), (-75.55, 10.4001)])
    estaciones = [Estacion(id=str(k), nombre=f"E{k}", latitud=10.40, longitud=lon, rutas=["T999"])
                  for k, lon in enumerate([-75.51, -75.54, -75.525])]
    assert [e.nombre for e in estaciones_en_orden(ida_y_vuelta, estaciones)] == ["E1", "E2", "E0"]


def test_de_la_a107_al_centro_se_cambia_en_santa_lucia_y_se_cruza_a_madre_bernarda():
    # Con los datos reales, a lo largo del recorrido de la A107 (Blas de Lezo), lejos de la troncal.
    from scripts.analizar_transbordos import cargar, origenes
    from src.domain.trip_planning import costo_percibido
    rutas, estaciones = cargar()
    a107 = next(r for r in rutas if r.id == "A107")
    troncales = [e for e in estaciones if any(r.startswith(("T", "X")) for r in e.rutas)]
    bodeguita = next(e for e in estaciones if e.id == "la-bodeguita")
    por_la_a107 = 0
    for origen in origenes(a107, troncales):
        opciones = [o for o in planificar(rutas, estaciones, origen, (bodeguita.longitud, bodeguita.latitud)) if o.rutas]
        # Ninguna opción hace caminar más de 200 m entre un bus y otro.
        assert all(t.distancia_m <= 200 for o in opciones for k, t in enumerate(o.tramos)
                   if t.modo == "caminata" and 0 < k < len(o.tramos) - 1)
        mejor = min(opciones, key=costo_percibido)
        if mejor.rutas[0].id == "A107" and mejor.transbordos == 1:
            por_la_a107 += 1
            cambio = mejor.tramos[2]
            assert cambio.integrado and cambio.distancia_m == 40
            assert "cruza por la cebra hasta Madre Bernarda" in cambio.indicacion
    assert por_la_a107 > 0


def test_con_un_limite_de_caminata_nadie_camina_mas_que_eso_hasta_la_ruta():
    # La ruta pasa a 400 m en línea recta del origen: unos 520 m a pie con el rodeo.
    from src.domain.trip_planning import FACTOR_RODEO
    ruta = _ruta()
    origen, destino = _al_norte(-75.545, 400), _al_norte(-75.505, 0)
    con_ruta = [o for o in planificar([ruta], [], origen, destino) if o.rutas]
    assert con_ruta and con_ruta[0].tramos[0].distancia_m == pytest.approx(400 * FACTOR_RODEO, rel=0.05)
    assert not [o for o in planificar([ruta], [], origen, destino, caminata_maxima_m=500) if o.rutas]
    assert [o for o in planificar([ruta], [], origen, destino, caminata_maxima_m=600) if o.rutas]


def test_el_que_pase_primero_junta_las_rutas_iguales_y_deja_aparte_el_expreso():
    from scripts.analizar_transbordos import cargar
    from src.domain.trip_planning import el_que_pase_primero
    rutas, estaciones = cargar()
    madre_bernarda = next(e for e in estaciones if e.id == "madre-bernarda")
    bodeguita = next(e for e in estaciones if e.id == "la-bodeguita")
    troncales = [r for r in rutas if r.id in ("T100E", "T101", "T103")]
    opciones = planificar(troncales, estaciones, (madre_bernarda.longitud, madre_bernarda.latitud),
                          (bodeguita.longitud, bodeguita.latitud), con_transbordos=False)
    juntas = el_que_pase_primero([o for o in opciones if o.rutas], estaciones)
    buses = [next(t for t in o.tramos if t.modo == "bus") for o in juntas]
    por_ruta = {b.ruta.id: b for b in buses}
    # T101 y T103 en una sola opción, con la mitad de la espera; la T100E, expresa, aparte.
    juntada = next(b for b in buses if b.alternativas)
    assert {juntada.ruta.id, *(r.id for r in juntada.alternativas)} == {"T101", "T103"}
    assert juntada.espera_min == pytest.approx(ESPERA_ESTIMADA_MIN["troncal"] / 2)
    assert "T100E" in por_ruta and not por_ruta["T100E"].alternativas
