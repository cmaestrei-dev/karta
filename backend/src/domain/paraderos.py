"""
Los paraderos oficiales de cada ruta (data/paraderos.json, de scripts/importar_paraderos.py) y lo que dicen de cómo
abordar: en qué módulo de la estación para la ruta en el sentido del viaje («Madre Bernarda A1») y hacia dónde va
(«hacia Bocagrande»). Todo aquí es puro.
"""
from dataclasses import dataclass


@dataclass(frozen=True)
class ParaderoOficial:
    ruta: str
    sentido: str          # ida | vuelta | circular
    orden: int
    nombre: str           # «Madre Bernarda A1», «Kr 68 entre Cl 16 y 17»
    estacion: str | None  # id de la estación, si es una
    modulo: str | None    # «A1»: el 1 es hacia el Centro, el 2 hacia el Portal; la letra, la mitad de la plataforma
    precision: str        # estacion | direccion
    longitud: float
    latitud: float


@dataclass(frozen=True)
class Abordaje:
    modulo: str | None
    hacia: str | None


def abordaje(ruta: str, sube_en: str | None, baja_en: str | None, paraderos: list[ParaderoOficial],
             hacia: dict[str, str]) -> Abordaje | None:
    """
    Cómo tomar la ruta en este tramo. Con las dos estaciones, el sentido es aquel en que la de subida va antes que la
    de bajada. Con una sola (una alimentadora que sube en la calle y baja en Santa Lucía), el sentido en que esa
    estación queda más al final, si se baja en ella, o más al principio, si se sube: el recorrido de ida de la A107
    empieza en Santa Lucía y el de vuelta termina allí.
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
        sentido = (max if baja_en else min)(con_ella)[1] if con_ella else None
    if sentido is None:
        return None
    modulo = sentidos[sentido][sube_en].modulo if sube_en in sentidos[sentido] else None
    return Abordaje(modulo=modulo, hacia=hacia.get(f"{ruta}-{sentido}"))
