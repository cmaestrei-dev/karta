"""Pruebas unitarias de las reglas de riesgo (no necesitan base de datos)."""
from datetime import datetime, timezone

import pytest
from shapely.geometry import Point, shape

from src.domain.models import CategoriaIncidente, Incidente
from src.domain.geo import corredor_de_ruta, en_cobertura
from src.domain.route_risk import evaluar_riesgo

METROS_POR_GRADO_LAT = 110_600  # aprox. a la latitud de Cartagena


def _incidente(categoria, intensidad):
    ahora = datetime.now(timezone.utc)
    return Incidente(id="x", reportado_por="u", categoria=categoria, intensidad=intensidad,
                     latitud=10.4, longitud=-75.5, creado_en=ahora, expira_en=ahora)


@pytest.mark.parametrize("incidentes, score, nivel", [
    ([], 0, "BAJO"),
    ([_incidente(CategoriaIncidente.TRAFICO, 5)] * 2, 10, "BAJO"),
    ([_incidente(CategoriaIncidente.TRAFICO, 5)] * 3, 15, "MEDIO"),
    ([_incidente(CategoriaIncidente.SEGURIDAD, 5)] * 1, 25, "MEDIO"),
    ([_incidente(CategoriaIncidente.SEGURIDAD, 5)] * 2, 50, "ALTO"),
    ([_incidente(CategoriaIncidente.SEGURIDAD, 5)] * 3, 75, "CRÍTICO"),
])
def test_evaluar_riesgo_pondera_seguridad_y_clasifica_por_umbrales(incidentes, score, nivel):
    resultado = evaluar_riesgo(incidentes)
    assert (resultado.score, resultado.nivel) == (score, nivel)


def test_corredor_incluye_lo_cercano_y_excluye_lo_lejano():
    # Ruta este-oeste sobre la latitud 10.40 (Bocagrande–Manga, ~2 km)
    ruta = [(-75.55, 10.40), (-75.53, 10.40)]
    corredor = shape(corredor_de_ruta(ruta, radio_m=500))

    a_400_m = Point(-75.54, 10.40 + 400 / METROS_POR_GRADO_LAT)
    a_700_m = Point(-75.54, 10.40 + 700 / METROS_POR_GRADO_LAT)

    assert corredor.contains(a_400_m)
    assert not corredor.contains(a_700_m)


def test_cobertura_solo_cartagena():
    assert en_cobertura(10.4236, -75.5510)        # Centro Histórico
    assert not en_cobertura(11.2408, -74.1990)    # Santa Marta
    assert not en_cobertura(4.7110, -74.0721)     # Bogotá
