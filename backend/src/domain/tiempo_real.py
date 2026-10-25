"""
Tiempo real hecho por los viajeros: dónde va cada bus según quienes lo ven pasar o van en él, y cuánto le falta
para llegar a una parada. No hay GPS en los buses: si nadie lo ha visto, no se inventa una estimación.

- Una posición compartida (desde dentro del bus) dice dónde está el bus en ese momento.
- Un avistamiento («lo vi pasar») dice dónde estaba; desde ahí avanza a la velocidad promedio de su tipo de ruta.
- El sentido del viaje lo dan la subida y la bajada: muchas relaciones de OSM son de ida y vuelta.
"""
from dataclasses import dataclass
from datetime import datetime
from enum import Enum

import numpy as np
import shapely
from shapely.geometry import LineString, Point

from src.domain.geo import a_metros
from src.domain.models import RutaTransporte
from src.domain.trip_planning import PASO_DE_MUESTREO_M, VELOCIDAD_BUS_KMH

CERCA_DE_LA_RUTA_M = 120          # un punto más lejos que esto de la ruta no se puede ubicar en ella
CERCA_DEL_VARADO_M = 250          # lo que se ve a esta distancia de un bus varado es ese mismo bus
HORIZONTE_M = 12_000              # un bus a más de esto, aguas arriba, aún no cuenta para la llegada
YA_PASO_M = 150                   # un bus más allá de la parada ya pasó
COINCIDENCIA_MIN = 5              # observaciones que llegan con menos de esto de diferencia hablan del mismo bus


class Ocupacion(str, Enum):
    CON_PUESTOS = "con_puestos"
    DE_PIE = "de_pie"
    MUY_LLENO = "muy_lleno"


@dataclass(frozen=True)
class Observacion:
    """Un bus visto: dónde y cuándo, si iba lleno y si es un viaje compartido (posición en vivo) o un avistamiento."""
    longitud: float
    latitud: float
    en: datetime
    en_vivo: bool
    ocupacion: Ocupacion | None = None


@dataclass(frozen=True)
class BusVarado:
    """Un bus de la ruta reportado como varado por los viajeros."""
    longitud: float
    latitud: float
    en: datetime
    confirmaciones: int
    lugar: str | None = None


@dataclass(frozen=True)
class Estimacion:
    minutos: int                      # cuánto falta para que el bus llegue a la parada
    fuentes: int                      # cuántas observaciones lo respaldan («según 3 viajeros»)
    ocupacion: Ocupacion | None       # la más reciente de esas observaciones
    visto_hace_min: int               # hace cuánto fue la observación más reciente


def _muestreo(ruta: RutaTransporte):
    linea = a_metros(LineString(ruta.coordenadas))
    posiciones = np.append(np.arange(0, linea.length, PASO_DE_MUESTREO_M), linea.length)
    puntos = shapely.get_coordinates(shapely.line_interpolate_point(linea, posiciones))
    return posiciones, puntos


def pasadas(posiciones: np.ndarray, puntos: np.ndarray, lonlat: tuple[float, float]) -> list[float]:
    """Cada vez que la ruta pasa cerca del punto, la posición (metros desde el inicio) del paso más cercano.
    Una ruta de ida y vuelta pasa dos veces por la misma calle."""
    p = a_metros(Point(lonlat))
    distancias = np.hypot(puntos[:, 0] - p.x, puntos[:, 1] - p.y)
    cerca = distancias <= CERCA_DE_LA_RUTA_M
    resultado, k = [], 0
    while k < len(cerca):
        if not cerca[k]:
            k += 1
            continue
        fin = k
        while fin + 1 < len(cerca) and cerca[fin + 1]:
            fin += 1
        tramo = slice(k, fin + 1)
        resultado.append(float(posiciones[tramo][np.argmin(distancias[tramo])]))
        k = fin + 1
    return resultado


def _parada_y_sentido(posiciones: np.ndarray, puntos: np.ndarray, subida: tuple[float, float],
                      bajada: tuple[float, float]) -> tuple[float, int] | None:
    """Dónde queda la subida sobre la ruta y en qué sentido se viaja (el par subida → bajada más corto)."""
    candidatos = [(s, b) for s in pasadas(posiciones, puntos, subida) for b in pasadas(posiciones, puntos, bajada)
                  if b != s]
    if not candidatos:
        return None
    parada, hacia = min(candidatos, key=lambda par: abs(par[1] - par[0]))
    return parada, (1 if hacia > parada else -1)


def _cerca(a: tuple[float, float], b: tuple[float, float], metros: float) -> bool:
    pa, pb = a_metros(Point(a)), a_metros(Point(b))
    return pa.distance(pb) <= metros


def estimar_llegada(ruta: RutaTransporte, subida: tuple[float, float], bajada: tuple[float, float],
                    observaciones: list[Observacion], ahora: datetime,
                    varados: list[BusVarado] = ()) -> Estimacion | None:
    """
    Cuánto le falta al próximo bus de la ruta para llegar a [subida] yendo hacia [bajada], según lo visto.
    Los buses recorren la relación de OSM en los dos sentidos: el sentido lo da el par subida → bajada más corto.
    Lo que se ve junto a un bus varado es ese bus: no cuenta como uno que viene.
    """
    posiciones, puntos = _muestreo(ruta)
    ubicada = _parada_y_sentido(posiciones, puntos, subida, bajada)
    if ubicada is None:
        return None
    parada, sentido = ubicada
    velocidad = VELOCIDAD_BUS_KMH[ruta.tipo] * 1000 / 60  # m/min

    llegadas: list[tuple[float, Observacion]] = []
    for obs in observaciones:
        if any(_cerca((obs.longitud, obs.latitud), (v.longitud, v.latitud), CERCA_DEL_VARADO_M) for v in varados):
            continue
        transcurrido = max(0.0, (ahora - obs.en).total_seconds() / 60)
        posibles = []
        for b in pasadas(posiciones, puntos, (obs.longitud, obs.latitud)):
            # Todo en «metros hacia la parada»: positivo si el bus viene detrás, en el sentido del viaje.
            detras = (parada - b) * sentido
            falta = detras - velocidad * transcurrido     # lo que le falta ahora, si siguió a velocidad promedio
            if 0 <= detras <= HORIZONTE_M and falta >= -YA_PASO_M:
                posibles.append(max(0.0, falta / velocidad))
        if posibles:
            llegadas.append((min(posibles), obs))
    if not llegadas:
        return None

    primera = min(m for m, _ in llegadas)
    mismo_bus = [(m, o) for m, o in llegadas if m - primera <= COINCIDENCIA_MIN]
    recientes = sorted((o for _, o in mismo_bus), key=lambda o: o.en, reverse=True)
    return Estimacion(
        minutos=round(primera),
        fuentes=len(mismo_bus),
        ocupacion=next((o.ocupacion for o in recientes if o.ocupacion), None),
        visto_hace_min=max(0, round((ahora - recientes[0].en).total_seconds() / 60)),
    )


def varado_antes_de_la_parada(ruta: RutaTransporte, subida: tuple[float, float], bajada: tuple[float, float],
                              varados: list[BusVarado]) -> tuple[BusVarado, float] | None:
    """El bus varado más cercano que viene hacia la subida (aguas arriba, en el sentido del viaje), y a cuántos
    metros está. Uno que ya pasó la parada, o que va en el otro sentido, no afecta a quien espera."""
    posiciones, puntos = _muestreo(ruta)
    ubicada = _parada_y_sentido(posiciones, puntos, subida, bajada)
    if ubicada is None:
        return None
    parada, sentido = ubicada
    cercanos = []
    for v in varados:
        detras = [(parada - b) * sentido for b in pasadas(posiciones, puntos, (v.longitud, v.latitud))]
        if validos := [d for d in detras if 0 <= d <= HORIZONTE_M]:
            cercanos.append((min(validos), v))
    if not cercanos:
        return None
    metros, varado = min(cercanos, key=lambda par: par[0])
    return varado, metros
