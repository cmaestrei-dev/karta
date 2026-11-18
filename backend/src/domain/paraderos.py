"""
Los paraderos oficiales de cada ruta (data/paraderos.json, de scripts/importar_paraderos.py) y lo que dicen de cómo
abordar: en qué módulo de la estación para la ruta en el sentido del viaje («Madre Bernarda A1») y hacia dónde va
(«hacia Bocagrande»). Todo aquí es puro.
"""
import math
from dataclasses import dataclass


@dataclass(frozen=True)
class ParaderoOficial:
    ruta: str
    sentido: str          # ida | vuelta | circular
    orden: int
    nombre: str           # «Madre Bernarda A1», «Kr 68 entre Cl 16 y 17»
    estacion: str | None  # id de la estación, si es una
    modulo: str | None    # «A1»: el 1 es hacia el Centro, el 2 hacia el Portal; la letra, la mitad de la plataforma
    precision: str | None  # estacion | direccion | estimado | comunidad (lo ubicó la comunidad) | None (sin ubicar)
    longitud: float | None = None
    latitud: float | None = None
    id: str | None = None  # «A107-ida-05»


@dataclass(frozen=True)
class Abordaje:
    modulo: str | None
    hacia: str | None


def abordaje(ruta: str, sube_en: str | None, baja_en: str | None, paraderos: list[ParaderoOficial],
             hacia: dict[str, str], rumbo: tuple[tuple[float, float], tuple[float, float]] | None = None
             ) -> Abordaje | None:
    """
    Cómo tomar la ruta en este tramo. Con las dos estaciones, el sentido es aquel en que la de subida va antes que la
    de bajada. Con una sola, el sentido que sigue el [rumbo] del tramo junto a esa estación (dos puntos (lon, lat) en
    el orden del viaje): la X103 pasa por Bazurto en los dos sentidos, y quien sube allí para bajarse en la Calle 30
    va hacia el Portal. Sin rumbo, o si no alcanza para decidir, el sentido en que esa estación queda más al final, si
    se baja en ella, o más al principio, si se sube: el recorrido de ida de la A107 empieza en Santa Lucía y el de
    vuelta termina allí.
    """
    if not sube_en and not baja_en:
        return None
    sentidos: dict[str, dict[str, ParaderoOficial]] = {}
    for p in sorted((p for p in paraderos if p.ruta == ruta and p.estacion), key=lambda p: p.orden):
        sentidos.setdefault(p.sentido, {}).setdefault(p.estacion, p)
    if sube_en and baja_en:
        sentido = next((s for s, e in sentidos.items()
                        if sube_en in e and baja_en in e and e[sube_en].orden < e[baja_en].orden), None)
    else:
        estacion = baja_en or sube_en
        con_ella = [(e[estacion].orden, s) for s, e in sentidos.items() if estacion in e]
        sentido = _sentido_por_rumbo(sentidos, estacion, rumbo) if rumbo else None
        if sentido is None:
            sentido = (max if baja_en else min)(con_ella)[1] if con_ella else None
    if sentido is None:
        return None
    modulo = sentidos[sentido][sube_en].modulo if sube_en in sentidos[sentido] else None
    return Abordaje(modulo=modulo, hacia=hacia.get(f"{ruta}-{sentido}"))


def _sentido_por_rumbo(sentidos: dict[str, dict[str, ParaderoOficial]], estacion: str,
                       rumbo: tuple[tuple[float, float], tuple[float, float]]) -> str | None:
    """
    El sentido en que la ruta, al pasar por [estacion], avanza como el tramo: compara el rumbo con la dirección de la
    estación anterior a la siguiente en cada sentido. None si ningún sentido coincide con claridad o faltan las
    coordenadas de las estaciones.
    """
    (ax, ay), (bx, by) = rumbo
    escala = math.cos(math.radians(ay))  # un grado de longitud mide menos que uno de latitud
    vx, vy = (bx - ax) * escala, by - ay
    largo_v = math.hypot(vx, vy)
    if largo_v == 0:
        return None
    mejor, elegido = 0.5, None  # se exige un ángulo de menos de 60° con el rumbo
    for s, por_estacion in sentidos.items():
        if estacion not in por_estacion:
            continue
        orden = list(por_estacion.values())
        i = orden.index(por_estacion[estacion])
        antes, despues = orden[max(i - 1, 0)], orden[min(i + 1, len(orden) - 1)]
        if None in (antes.longitud, antes.latitud, despues.longitud, despues.latitud) or antes is despues:
            continue
        dx, dy = (despues.longitud - antes.longitud) * escala, despues.latitud - antes.latitud
        largo_d = math.hypot(dx, dy)
        if largo_d == 0:
            continue
        coseno = (vx * dx + vy * dy) / (largo_v * largo_d)
        if coseno > mejor:
            mejor, elegido = coseno, s
    return elegido
