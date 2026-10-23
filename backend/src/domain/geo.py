"""Utilidades geográficas: medir en metros (UTM 18N) y volver a coordenadas GeoJSON."""
import math

import shapely
from pyproj import Transformer
from shapely.geometry import LineString, Point, mapping

# UTM zona 18N (EPSG:32618) cubre Cartagena: permite medir en metros sin distorsión apreciable.
_A_METROS = Transformer.from_crs("EPSG:4326", "EPSG:32618", always_xy=True).transform
_A_GRADOS = Transformer.from_crs("EPSG:32618", "EPSG:4326", always_xy=True).transform

# Área de cobertura del prototipo: zona urbana de Cartagena de Indias, con margen.
LAT_MIN, LAT_MAX = 10.30, 10.50
LON_MIN, LON_MAX = -75.60, -75.40
MENSAJE_FUERA_DE_COBERTURA = "Fuera del área de cobertura: Karta funciona en Cartagena de Indias."


def en_cobertura(lat: float, lon: float) -> bool:
    return LAT_MIN <= lat <= LAT_MAX and LON_MIN <= lon <= LON_MAX


def validar_cobertura(lat: float, lon: float) -> None:
    if not en_cobertura(lat, lon):
        raise ValueError(MENSAJE_FUERA_DE_COBERTURA)


def a_metros(geometria):
    return shapely.transform(geometria, _A_METROS, interleaved=False)


def a_grados(geometria):
    return shapely.transform(geometria, _A_GRADOS, interleaved=False)


def corredor_de_ruta(puntos_lon_lat: list[tuple[float, float]], radio_m: float) -> dict:
    """Polígono GeoJSON que cubre todo lo que está a menos de `radio_m` metros de la ruta."""
    # Simplificar a 10 m reduce los vértices del polígono sin cambiar el área cubierta de forma apreciable.
    ruta_en_metros = a_metros(LineString(puntos_lon_lat)).simplify(10)
    return mapping(a_grados(ruta_en_metros.buffer(radio_m)))


def circulo(lon: float, lat: float, radio_m: float) -> dict:
    """Polígono GeoJSON aproximado de un círculo de `radio_m` metros."""
    return mapping(a_grados(a_metros(Point(lon, lat)).buffer(radio_m)))


def distancia_m(a: tuple[float, float], b: tuple[float, float]) -> float:
    """Distancia en metros entre dos puntos (lon, lat)."""
    pa, pb = a_metros(Point(a)), a_metros(Point(b))
    return math.hypot(pa.x - pb.x, pa.y - pb.y)
