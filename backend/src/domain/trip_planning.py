"""
Planificación de viajes: caminata sola, o caminata + una ruta de Transcaribe + caminata.
No contempla transbordos entre rutas. Los tiempos son estimaciones con velocidades promedio.
"""
from dataclasses import dataclass, field

import numpy as np
import shapely
from shapely.geometry import LineString, Point
from shapely.ops import substring

from src.domain.geo import a_grados, a_metros
from src.domain.models import Estacion, RutaTransporte

VELOCIDAD_CAMINATA_M_POR_MIN = 75   # 4,5 km/h
FACTOR_RODEO = 1.3                  # las calles no van en línea recta
CAMINATA_MAXIMA_DE_ACCESO_M = 800   # lo máximo que se camina hasta o desde una ruta
CAMINATA_DIRECTA_MAXIMA_M = 2500    # distancia en línea recta para ofrecer ir a pie
PASO_DE_MUESTREO_M = 25
RADIO_DE_ESTACION_M = 60            # en el corredor de la troncal solo se sube o baja en estaciones
ANCHO_CORREDOR_TRONCAL_M = 700      # más lejos de toda estación, la troncal va en vía mixta con paraderos
MAX_CORTES_CONFIABLES = 2           # rutas con más huecos en OSM no se usan para planificar

VELOCIDAD_BUS_KMH = {"troncal": 22, "pretroncal": 18, "alimentadora": 15, "complementaria": 15}
ESPERA_ESTIMADA_MIN = {"troncal": 5, "pretroncal": 8, "alimentadora": 10, "complementaria": 10}


@dataclass(frozen=True)
class Tramo:
    modo: str  # "caminata" | "bus"
    coordenadas: tuple[tuple[float, float], ...]  # (lon, lat)
    distancia_m: float
    duracion_min: float
    espera_min: float = 0.0
    ruta: RutaTransporte | None = None
    desde: str = ""
    hasta: str = ""


@dataclass(frozen=True)
class OpcionViaje:
    tramos: tuple[Tramo, ...] = field(default_factory=tuple)

    @property
    def tiempo_total_min(self) -> float:
        return sum(t.duracion_min + t.espera_min for t in self.tramos)

    @property
    def distancia_caminata_m(self) -> float:
        return sum(t.distancia_m for t in self.tramos if t.modo == "caminata")

    @property
    def ruta(self) -> RutaTransporte | None:
        return next((t.ruta for t in self.tramos if t.ruta), None)

    @property
    def coordenadas(self) -> list[tuple[float, float]]:
        puntos: list[tuple[float, float]] = []
        for tramo in self.tramos:
            puntos.extend(tramo.coordenadas[1:] if puntos else tramo.coordenadas)
        return puntos


def minutos_caminando(distancia_m: float) -> float:
    return distancia_m * FACTOR_RODEO / VELOCIDAD_CAMINATA_M_POR_MIN


def _caminata(desde: tuple[float, float], hasta: tuple[float, float], distancia_m: float) -> Tramo:
    distancia_m = float(distancia_m)
    return Tramo(modo="caminata", coordenadas=(desde, hasta),
                 distancia_m=distancia_m * FACTOR_RODEO, duracion_min=minutos_caminando(distancia_m))


def opcion_caminando(origen: tuple[float, float], destino: tuple[float, float]) -> OpcionViaje | None:
    o, d = a_metros(Point(origen)), a_metros(Point(destino))
    distancia = o.distance(d)
    if distancia > CAMINATA_DIRECTA_MAXIMA_M:
        return None
    return OpcionViaje(tramos=(_caminata(origen, destino, distancia),))


def _mejor_subida_y_bajada(avance, dist_origen, dist_destino, puede_subir, puede_bajar, velocidad):
    """
    Recorre los puntos en orden de avance y devuelve (minutos, i, j) del mejor par subida→bajada,
    con i antes que j. El costo de subir en i descuenta lo ya recorrido, así el total de subir
    en i y bajar en j es costo[i] + avance[j] / velocidad + caminata final: un solo recorrido.
    """
    mejor_subida, mejor_costo, mejor = None, np.inf, None
    for j in range(len(avance)):
        if mejor_subida is not None and puede_bajar[j]:
            total = mejor_costo + avance[j] / velocidad + minutos_caminando(dist_destino[j])
            if mejor is None or total < mejor[0]:
                mejor = (total, mejor_subida, j)
        if puede_subir[j]:
            costo = minutos_caminando(dist_origen[j]) - avance[j] / velocidad
            if costo < mejor_costo:
                mejor_subida, mejor_costo = j, costo
    return mejor


def _distancia_minima(puntos: np.ndarray, estaciones: list[Estacion]) -> np.ndarray:
    """Para cada punto (en metros), la distancia a la estación más cercana."""
    en_metros = shapely.get_coordinates(a_metros(shapely.points([(e.longitud, e.latitud) for e in estaciones])))
    return np.hypot(puntos[:, None, 0] - en_metros[None, :, 0], puntos[:, None, 1] - en_metros[None, :, 1]).min(axis=1)


def mejor_opcion_en_ruta(ruta: RutaTransporte, estaciones: list[Estacion],
                         origen: tuple[float, float], destino: tuple[float, float]) -> OpcionViaje | None:
    """
    Busca dónde subirse y bajarse de la ruta para llegar lo antes posible.
    OSM guarda una sola relación por ruta aunque los buses operan ida y vuelta,
    así que se evalúan ambos sentidos del recorrido.
    """
    linea = a_metros(LineString(ruta.coordenadas))
    posiciones = np.append(np.arange(0, linea.length, PASO_DE_MUESTREO_M), linea.length)
    puntos = shapely.get_coordinates(shapely.line_interpolate_point(linea, posiciones))

    o, d = a_metros(Point(origen)), a_metros(Point(destino))
    dist_origen = np.hypot(puntos[:, 0] - o.x, puntos[:, 1] - o.y)
    dist_destino = np.hypot(puntos[:, 0] - d.x, puntos[:, 1] - d.y)

    abordable = np.ones(len(posiciones), dtype=bool)
    if ruta.tipo == "troncal":
        propias = [e for e in estaciones if ruta.id in e.rutas]
        if not propias:
            return None
        # Dentro del corredor (cerca de cualquier estación) solo se sube en las estaciones de esta
        # ruta: el expreso T100E pasa por Los Ejecutivos sin parar. Fuera del corredor va en vía mixta.
        cerca_de_propia = _distancia_minima(puntos, propias) <= RADIO_DE_ESTACION_M
        fuera_del_corredor = _distancia_minima(puntos, estaciones) > ANCHO_CORREDOR_TRONCAL_M
        abordable = cerca_de_propia | fuera_del_corredor

    velocidad = VELOCIDAD_BUS_KMH[ruta.tipo] * 1000 / 60  # m/min
    puede_subir = abordable & (dist_origen <= CAMINATA_MAXIMA_DE_ACCESO_M)
    puede_bajar = abordable & (dist_destino <= CAMINATA_MAXIMA_DE_ACCESO_M)

    candidatos = []
    ida = _mejor_subida_y_bajada(posiciones, dist_origen, dist_destino, puede_subir, puede_bajar, velocidad)
    if ida:
        candidatos.append(ida)
    ultimo = len(posiciones) - 1
    vuelta = _mejor_subida_y_bajada(linea.length - posiciones[::-1], dist_origen[::-1], dist_destino[::-1],
                                    puede_subir[::-1], puede_bajar[::-1], velocidad)
    if vuelta:
        total, i, j = vuelta
        candidatos.append((total, ultimo - i, ultimo - j))
    if not candidatos:
        return None

    _, i, j = min(candidatos)
    subida = tuple(a_grados(Point(puntos[i])).coords[0])
    bajada = tuple(a_grados(Point(puntos[j])).coords[0])
    # Si se viaja en sentido contrario al de la relación, substring devuelve el tramo invertido.
    recorrido = a_grados(substring(linea, posiciones[i], posiciones[j]))
    distancia_bus = float(abs(posiciones[j] - posiciones[i]))
    return OpcionViaje(tramos=(
        _caminata(origen, subida, dist_origen[i]),
        Tramo(modo="bus", coordenadas=tuple(recorrido.coords), distancia_m=distancia_bus,
              duracion_min=distancia_bus / velocidad, espera_min=ESPERA_ESTIMADA_MIN[ruta.tipo], ruta=ruta),
        _caminata(bajada, destino, dist_destino[j]),
    ))


def planificar(rutas: list[RutaTransporte], estaciones: list[Estacion],
               origen: tuple[float, float], destino: tuple[float, float]) -> list[OpcionViaje]:
    """Opciones posibles: a pie (si es cerca) y una por cada ruta útil, descartando las más lentas que caminar."""
    caminando = opcion_caminando(origen, destino)
    opciones = []
    for ruta in rutas:
        if ruta.cortes_en_osm > MAX_CORTES_CONFIABLES:
            continue
        opcion = mejor_opcion_en_ruta(ruta, estaciones, origen, destino)
        if opcion and (caminando is None or opcion.tiempo_total_min < caminando.tiempo_total_min):
            opciones.append(opcion)
    if caminando:
        opciones.append(caminando)
    return opciones
