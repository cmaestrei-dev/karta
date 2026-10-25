"""
Lo que la comunidad sabe de las rutas (D12): cómo se pide la parada en cada paradero. Se pregunta al bajarse, una
vez por viaje y sin guardar quién respondió. Con suficientes respuestas que coinciden, el aviso de pedir la parada
dice lo que de verdad funciona allí («según 4 viajeros»). Todo aquí es puro.
"""
import enum
from collections import Counter
from dataclasses import dataclass
from datetime import datetime

from src.domain.direcciones import distancia_m


class ComoSePidio(str, enum.Enum):
    TIMBRE = "timbre"        # tocó el timbre
    PARO_SOLO = "paro_solo"  # el bus paró sin que nadie lo pidiera
    CONDUCTOR = "conductor"  # le avisó al conductor


@dataclass(frozen=True)
class RespuestaDeParada:
    como: ComoSePidio
    longitud: float
    latitud: float
    en: datetime


@dataclass(frozen=True)
class LoQueSeSabe:
    como: ComoSePidio
    viajeros: int    # cuántos respondieron eso
    respuestas: int  # cuántos respondieron en total


CERCA_DEL_PARADERO_M = 120  # el GPS al bajarse cae a unos metros del paradero
RESPUESTAS_MINIMAS = 3
MAYORIA = 0.6


def como_se_pide(respuestas: list[RespuestaDeParada], longitud: float, latitud: float) -> LoQueSeSabe | None:
    """La forma de pedir la parada en ese punto, si al menos 3 viajeros respondieron y la mayoría coincide."""
    cerca = [r for r in respuestas
             if distancia_m((longitud, latitud), (r.longitud, r.latitud)) <= CERCA_DEL_PARADERO_M]
    if len(cerca) < RESPUESTAS_MINIMAS:
        return None
    como, viajeros = Counter(r.como for r in cerca).most_common(1)[0]
    return LoQueSeSabe(como, viajeros, len(cerca)) if viajeros / len(cerca) >= MAYORIA else None
