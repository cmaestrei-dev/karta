"""Reglas de negocio del escaneo de riesgo de una ruta."""
from dataclasses import dataclass

from src.domain.models import Incidente
from src.domain.reportes import CATALOGO, peso_en_riesgo

RADIO_BUSQUEDA_M = 500
UMBRALES_NIVEL = [(50, "CRÍTICO"), (25, "ALTO"), (10, "MEDIO")]

# Minutos que "cuesta" el riesgo al ordenar rutas sugeridas: una ruta un poco más lenta
# pero segura debe quedar por encima de una más rápida que pasa por incidentes graves.
PENALIZACION_RIESGO_MIN = {"BAJO": 0, "MEDIO": 3, "ALTO": 8, "CRÍTICO": 15}


@dataclass(frozen=True)
class ResultadoRiesgo:
    score: int
    nivel: str
    incidentes: list[Incidente]


def evaluar_riesgo(incidentes: list[Incidente]) -> ResultadoRiesgo:
    """
    Suma el peso de cada reporte (más si la comunidad lo confirmó) y clasifica el total por umbrales.
    Los que siguen por confirmar (de alguien sin cuenta, sin confirmaciones) no pesan.
    """
    total = sum(peso_en_riesgo(CATALOGO[i.tipo], i.votos_si, i.nivel_autor) for i in incidentes
                if i.tipo in CATALOGO and not i.por_confirmar)
    score = round(total)
    nivel = next((n for umbral, n in UMBRALES_NIVEL if score > umbral), "BAJO")
    return ResultadoRiesgo(score=score, nivel=nivel, incidentes=incidentes)
