"""Reglas de negocio del escaneo de riesgo de una ruta."""
from dataclasses import dataclass

import shapely
from pyproj import Transformer
from shapely.geometry import LineString, mapping

from src.domain.models import CategoriaIncidente, Incidente

RADIO_BUSQUEDA_M = 500
PESO_POR_CATEGORIA = {CategoriaIncidente.SEGURIDAD: 5, CategoriaIncidente.TRAFICO: 1}
UMBRALES_NIVEL = [(50, "CRÍTICO"), (25, "ALTO"), (10, "MEDIO")]

# UTM zona 18N (EPSG:32618) cubre Cartagena: permite trabajar en metros sin distorsión apreciable.
_A_METROS = Transformer.from_crs("EPSG:4326", "EPSG:32618", always_xy=True).transform
_A_GRADOS = Transformer.from_crs("EPSG:32618", "EPSG:4326", always_xy=True).transform


@dataclass(frozen=True)
class ResultadoRiesgo:
    score: int
    nivel: str
    incidentes: list[Incidente]


def corredor_de_ruta(puntos_lon_lat: list[tuple[float, float]], radio_m: float = RADIO_BUSQUEDA_M) -> dict:
    """Polígono GeoJSON que cubre todo lo que está a menos de `radio_m` metros de la ruta."""
    # Simplificar a 10 m reduce los vértices del polígono sin cambiar el área cubierta de forma apreciable.
    ruta_en_metros = shapely.transform(LineString(puntos_lon_lat), _A_METROS, interleaved=False).simplify(10)
    return mapping(shapely.transform(ruta_en_metros.buffer(radio_m), _A_GRADOS, interleaved=False))


def evaluar_riesgo(incidentes: list[Incidente]) -> ResultadoRiesgo:
    """Suma intensidad × peso de la categoría y clasifica el total por umbrales."""
    score = sum(i.intensidad * PESO_POR_CATEGORIA[i.categoria] for i in incidentes)
    nivel = next((n for umbral, n in UMBRALES_NIVEL if score > umbral), "BAJO")
    return ResultadoRiesgo(score=score, nivel=nivel, incidentes=incidentes)
