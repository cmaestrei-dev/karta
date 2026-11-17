"""
De qué lado de la estación queda cada módulo (D18).

Las estaciones dobles (Bazurto, Centro, Cuatro Vientos, Delicias, La Bodeguita, La Castellana y Madre Bernarda)
tienen dos vagones, A y B, y en cada uno paran rutas distintas. Ningún documento público dice cuál es el extremo
hacia el Centro (se pidió a Transcaribe en el derecho de petición). Lo aprenden las subidas: quien va con el viaje
compartido y sube en una estación deja, sin su nombre, el punto donde esperó y el módulo de su bus. Con al menos
3 subidas en cada vagón y una separación clara, el vagón cuyas subidas quedan más cerca de la estación vecina hacia
el Centro es el extremo hacia el Centro.

Todo aquí es puro: sin base de datos ni HTTP.
"""
from dataclasses import dataclass

from src.domain.direcciones import distancia_m

# Las estaciones con dos vagones (módulos A y B, cada uno con su cara 1 hacia el Centro y 2 hacia el Portal).
# En el Patio Portal las letras A a D son plataformas distintas, no mitades: ahí no aplica.
ESTACIONES_DOBLES = frozenset({"bazurto", "centro", "cuatro-vientos", "las-delicias", "la-bodeguita",
                               "la-castellana", "madre-bernarda"})
SUBIDAS_PARA_SABER = 3       # por vagón; con menos, no se dice nada
SEPARACION_MINIMA_M = 10     # los dos grupos de subidas deben quedar claramente en extremos distintos
CERCA_DE_LA_ESTACION_M = 150  # una subida más lejos no es de esa estación


@dataclass(frozen=True)
class LadoDeModulo:
    letra: str      # «A»
    hacia: str      # «el Centro» o «el Portal»
    viajeros: int
    centro: tuple[float, float]  # (lon, lat): dónde esperan, en promedio, los que suben en ese vagón


def _centro(puntos: list[tuple[float, float]]) -> tuple[float, float]:
    return sum(p[0] for p in puntos) / len(puntos), sum(p[1] for p in puntos) / len(puntos)


def lados_de_la_estacion(subidas: dict[str, list[tuple[float, float]]],
                         hacia_el_centro: tuple[float, float]) -> dict[str, LadoDeModulo]:
    """
    Para cada vagón («A», «B»), hacia dónde queda, a partir de las subidas (lon, lat) en cada uno y de un punto
    hacia el Centro (la estación vecina en ese sentido). Vacío si no hay subidas suficientes o no se separan.
    """
    a, b = subidas.get("A", []), subidas.get("B", [])
    if len(a) < SUBIDAS_PARA_SABER or len(b) < SUBIDAS_PARA_SABER:
        return {}
    centros = {"A": _centro(a), "B": _centro(b)}
    distancia_a, distancia_b = distancia_m(centros["A"], hacia_el_centro), distancia_m(centros["B"], hacia_el_centro)
    if abs(distancia_a - distancia_b) < SEPARACION_MINIMA_M:
        return {}
    cerca, lejos = ("A", "B") if distancia_a < distancia_b else ("B", "A")
    return {cerca: LadoDeModulo(cerca, "el Centro", len(subidas[cerca]), centros[cerca]),
            lejos: LadoDeModulo(lejos, "el Portal", len(subidas[lejos]), centros[lejos])}
