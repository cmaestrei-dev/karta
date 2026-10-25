"""
«Marca este paradero» (D12, D16): los Kartógrafos ubican en el mapa los paraderos oficiales que no tienen
coordenadas (734 de 948 en el archivo de Transcaribe de 2025). Una marca queda en el mapa cuando otros viajeros
que están allí la confirman; si dicen que no está, se descarta y se puede marcar otra vez.

Las subidas fuera de las estaciones (anónimas: solo la ruta y el punto) son pistas: donde mucha gente se sube,
casi seguro hay un paradero. Solo se muestran agrupadas y con al menos 3 subidas, para no revelar a nadie.

Todo aquí es puro: sin base de datos ni HTTP.
"""
import enum
import math
from dataclasses import dataclass
from datetime import datetime

PESO_PARA_UBICAR = 3          # la marca (1) y dos confirmaciones (1 + 1)
PESO_PARA_DESCARTAR = -2      # «no está aquí» de más
NIVEL_DE_GUARDIAN = 4         # desde aquí la marca o la confirmación cuenta doble
CERCA_DEL_RECORRIDO_M = 80    # el paradero está sobre la calle por donde pasa la ruta
CERCA_PARA_CONFIRMAR_M = 300  # se confirma estando allí
REPUTACION_POR_PARADERO = 5   # para quien lo marcó, cuando queda en el mapa
REPUTACION_POR_CONFIRMAR = 1  # para quien acertó: confirmó una marca que quedó, o descartó una que no
SUBIDAS_PARA_PISTA = 3        # menos que esto no se muestra
RADIO_DE_PISTA_M = 30


class EstadoDeMarca(str, enum.Enum):
    POR_CONFIRMAR = "por_confirmar"
    UBICADA = "ubicada"
    DESCARTADA = "descartada"


@dataclass(frozen=True)
class Voto:
    usuario: str
    esta_aqui: bool
    peso: int


@dataclass(frozen=True)
class Marca:
    id: str
    paradero: str          # id del paradero oficial («A117-vuelta-05»)
    ruta: str
    longitud: float
    latitud: float
    propuesto_por: str
    apoyo: int
    votos: tuple[Voto, ...]
    estado: EstadoDeMarca
    creado_en: datetime


@dataclass(frozen=True)
class Pista:
    """Varias subidas a la ruta en el mismo lugar."""
    longitud: float
    latitud: float
    subidas: int


def peso(nivel: int) -> int:
    return 2 if nivel >= NIVEL_DE_GUARDIAN else 1


def estado_por_apoyo(apoyo: int) -> EstadoDeMarca:
    if apoyo >= PESO_PARA_UBICAR:
        return EstadoDeMarca.UBICADA
    if apoyo <= PESO_PARA_DESCARTAR:
        return EstadoDeMarca.DESCARTADA
    return EstadoDeMarca.POR_CONFIRMAR


def acertaron(marca: Marca) -> list[str]:
    """Quienes votaron en el sentido en que se resolvió la marca."""
    if marca.estado == EstadoDeMarca.POR_CONFIRMAR:
        return []
    ubicada = marca.estado == EstadoDeMarca.UBICADA
    return [v.usuario for v in marca.votos if v.esta_aqui == ubicada]


def pistas(subidas: list[tuple[float, float]]) -> list[Pista]:
    """Las subidas agrupadas: cada una se suma al grupo cuyo centro está a menos de 30 m. Solo grupos de 3 o más."""
    grupos: list[list[tuple[float, float]]] = []
    centros: list[tuple[float, float]] = []
    for punto in subidas:
        k = next((i for i, c in enumerate(centros) if _metros(punto, c) <= RADIO_DE_PISTA_M), None)
        if k is None:
            grupos.append([punto])
            centros.append(punto)
        else:
            grupos[k].append(punto)
            g = grupos[k]
            centros[k] = (sum(p[0] for p in g) / len(g), sum(p[1] for p in g) / len(g))
    return sorted((Pista(round(c[0], 6), round(c[1], 6), len(g)) for g, c in zip(grupos, centros)
                   if len(g) >= SUBIDAS_PARA_PISTA), key=lambda p: -p.subidas)


def _metros(a: tuple[float, float], b: tuple[float, float]) -> float:
    lat = math.radians((a[1] + b[1]) / 2)
    return math.hypot((b[0] - a[0]) * 111_320 * math.cos(lat), (b[1] - a[1]) * 110_540)


class ParaderoNoEncontrado(Exception):
    pass


class ParaderoYaUbicado(Exception):
    pass


class MarcaPendiente(Exception):
    """Ya hay una marca por confirmar para ese paradero: se confirma o se descarta antes de marcar otra."""


class LejosDelRecorrido(Exception):
    pass


class LejosParaConfirmar(Exception):
    pass


class MarcaNoEncontrada(Exception):
    pass


class VotoPropio(Exception):
    pass


class VotoRepetido(Exception):
    pass
