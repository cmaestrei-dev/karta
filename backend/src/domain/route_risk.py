"""Reglas de negocio del escaneo de riesgo de una ruta."""
from dataclasses import dataclass

from src.domain.models import CategoriaIncidente, Incidente

RADIO_BUSQUEDA_M = 500
PESO_POR_CATEGORIA = {CategoriaIncidente.SEGURIDAD: 5, CategoriaIncidente.TRAFICO: 1}
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
    """Suma intensidad × peso de la categoría y clasifica el total por umbrales."""
    score = sum(i.intensidad * PESO_POR_CATEGORIA[i.categoria] for i in incidentes)
    nivel = next((n for umbral, n in UMBRALES_NIVEL if score > umbral), "BAJO")
    return ResultadoRiesgo(score=score, nivel=nivel, incidentes=incidentes)
