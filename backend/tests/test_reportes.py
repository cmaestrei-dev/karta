"""Pruebas unitarias del catálogo de reportes y de las reglas de validación comunitaria."""
from datetime import datetime, timedelta, timezone

import pytest

from src.domain.reportes import (
    CATALOGO, DetallesInvalidos, Grupo, alias_publico, debe_retirarse, expiracion_al_confirmar, nivel,
    peso_en_riesgo, validar_detalles,
)

RUTAS = {"T101", "T103", "X104", "A101", "C016", "T100E"}
AHORA = datetime(2026, 10, 28, 18, 0, tzinfo=timezone.utc)


def test_el_catalogo_tiene_los_diez_tipos_ilustrados_de_la_app():
    # Las claves deben coincidir con frontend/assets/ilustraciones/<clave>.svg.
    assert set(CATALOGO) == {
        "bus_no_pasa", "bus_lleno", "bus_varado", "estacion_cerrada", "trancon", "accidente", "calle_inundada",
        "robo", "calle_sola", "acoso",
    }
    assert {t.grupo for t in CATALOGO.values()} == set(Grupo)
    for tipo in CATALOGO.values():
        assert tipo.vigencia >= timedelta(minutes=30)
        assert tipo.peso > 0


def test_el_bus_no_pasa_exige_la_ruta_y_acepta_la_espera():
    tipo = CATALOGO["bus_no_pasa"]
    assert validar_detalles(tipo, {"ruta": "t103", "espera": "20"}, RUTAS) == {"ruta": "T103", "espera": "20"}
    assert validar_detalles(tipo, {"ruta": "T103"}, RUTAS) == {"ruta": "T103"}  # la espera es opcional
    with pytest.raises(DetallesInvalidos, match="¿Qué ruta esperas?"):
        validar_detalles(tipo, {"espera": "20"}, RUTAS)


@pytest.mark.parametrize("detalles, mensaje", [
    ({"ruta": "T999"}, "no es una ruta"),  # formato válido pero no existe
    ({"ruta": "$where"}, "no es una ruta"),  # nunca llega a la base de datos
    ({"ruta": "T103", "espera": "90"}, "Respuesta no válida"),
    ({"ruta": "T103", "color": "rojo"}, "no lleva estos datos"),
])
def test_detalles_invalidos_se_rechazan_con_un_mensaje_claro(detalles, mensaje):
    with pytest.raises(DetallesInvalidos, match=mensaje):
        validar_detalles(CATALOGO["bus_no_pasa"], detalles, RUTAS)


def test_un_tipo_sin_preguntas_no_acepta_detalles():
    assert validar_detalles(CATALOGO["robo"], {}, RUTAS) == {}
    with pytest.raises(DetallesInvalidos):
        validar_detalles(CATALOGO["robo"], {"arma": "si"}, RUTAS)


def test_confirmar_renueva_la_vigencia_completa_sin_acortarla_nunca():
    tipo = CATALOGO["trancon"]  # vive 1 h sin confirmaciones
    casi_vencido = AHORA + timedelta(minutes=5)
    assert expiracion_al_confirmar(tipo, casi_vencido, AHORA) == AHORA + timedelta(hours=1)
    lejano = AHORA + timedelta(hours=3)
    assert expiracion_al_confirmar(tipo, lejano, AHORA) == lejano


def test_dos_ya_no_seguidos_retiran_el_reporte():
    assert not debe_retirarse(1)
    assert debe_retirarse(2)


def test_las_confirmaciones_aumentan_el_peso_hasta_el_doble():
    robo = CATALOGO["robo"]
    assert peso_en_riesgo(robo, 0) == robo.peso
    assert peso_en_riesgo(robo, 2) == robo.peso * 1.5
    assert peso_en_riesgo(robo, 4) == peso_en_riesgo(robo, 20) == robo.peso * 2


@pytest.mark.parametrize("reputacion, esperado", [(100, 1), (149, 1), (150, 2), (230, 3), (300, 4), (999, 5), (40, 1)])
def test_nivel_segun_reputacion(reputacion, esperado):
    assert nivel(reputacion) == esperado


@pytest.mark.parametrize("nombre, alias", [
    ("Camilo Maestre Iglesias", "Camilo M."), ("ana", "ana"), ("  María  josé ", "María J."), ("", "Viajero"),
])
def test_el_alias_publico_no_expone_el_nombre_completo(nombre, alias):
    assert alias_publico(nombre) == alias
