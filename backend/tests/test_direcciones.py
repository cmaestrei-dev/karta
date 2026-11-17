"""Direcciones con la nomenclatura colombiana: leerlas y ubicarlas en los cruces de calles."""
import pytest

from src.domain.direcciones import Cruce, Direccion, Via, leer_direccion, leer_via, ubicar, vias_del_cruce

CALLE_9 = Via("calle", "9")


@pytest.mark.parametrize("texto, esperado", [
    ("Calle 9 # 3-50", Direccion(CALLE_9, "3", 50)),
    ("calle 9 #3 - 50", Direccion(CALLE_9, "3", 50)),
    ("Cl 9 3 50", Direccion(CALLE_9, "3", 50)),
    ("Cll. 9 No. 3-50", Direccion(CALLE_9, "3", 50)),
    ("C 9 N° 3 50", Direccion(CALLE_9, "3", 50)),
    ("Cra. 3 # 8-129", Direccion(Via("carrera", "3"), "8", 129)),
    ("Kr 3 8 129", Direccion(Via("carrera", "3"), "8", 129)),
    ("Carrera 3 número 8-129", Direccion(Via("carrera", "3"), "8", 129)),
    ("Calle 10A # 3-15", Direccion(Via("calle", "10a"), "3", 15)),
    ("Calle 10 A # 3B-15", Direccion(Via("calle", "10a"), "3b", 15)),
    ("Tv 54 # 21 bis - 30", Direccion(Via("transversal", "54"), "21bis", 30)),
    ("Diagonal 21 Bis # 53A", Direccion(Via("diagonal", "21bis"), "53a", None)),
    ("Calle 30", Direccion(Via("calle", "30"))),
])
def test_lee_las_formas_comunes_de_escribir_una_direccion(texto, esperado):
    assert leer_direccion(texto) == esperado


@pytest.mark.parametrize("texto", ["Bocagrande", "Estación Bazurto", "centro", "calle", "Calle de la Media Luna",
                                   "Av. Pedro de Heredia", "9 # 3-50"])
def test_lo_que_no_es_una_direccion_numerada_se_deja_al_buscador_de_lugares(texto):
    assert leer_direccion(texto) is None


def test_una_placa_absurda_se_ignora_pero_se_ubica_el_cruce():
    assert leer_direccion("Calle 9 # 3-5000") is None or leer_direccion("Calle 9 # 3-500").placa is None


def test_lee_las_vias_como_las_nombra_openstreetmap():
    assert leer_via("Cra. 3") == Via("carrera", "3")
    assert leer_via("Tv. 45A Bis") == Via("transversal", "45abis")
    assert leer_via("Dg. 21 Bis") == Via("diagonal", "21bis")
    assert leer_via("Av. Pedro de Heredia") is None
    assert vias_del_cruce("Cra. 3 con Calle 9") == (Via("carrera", "3"), CALLE_9)
    assert vias_del_cruce("Av. Chile con Calle 9") == (CALLE_9,)


# Una cuadrícula de Bocagrande (calles hacia el norte, carreras hacia el este, cuadras de ~110 m) y otra Calle 9
# en otro sector, cruzando la Cra. 82: la numeración se repite en Cartagena.
def _cruce(calle: int | str, carrera: int | str, lon: float, lat: float) -> Cruce:
    return Cruce(f"Cra. {carrera} con Calle {calle}", (Via("carrera", str(carrera).lower()), Via("calle", str(calle))),
                 lon, lat)


CRUCES = [
    _cruce(9, 2, -75.5560, 10.4030), _cruce(9, 3, -75.5550, 10.4030), _cruce(9, 4, -75.5540, 10.4030),
    _cruce(8, 3, -75.5550, 10.4020), _cruce(9, 82, -75.4600, 10.3900),
]


def test_ubica_la_direccion_desde_el_cruce_hacia_la_via_siguiente():
    [u] = ubicar(Direccion(CALLE_9, "3", 50), CRUCES)
    assert u.nombre == "Calle 9 # 3-50"
    assert u.referencia == "Cra. 3 con Calle 9"
    assert u.exacta
    # 50 m hacia la Cra. 4 (al este), sin cambiar de calle.
    assert u.latitud == pytest.approx(10.4030, abs=1e-6)
    assert -75.5550 < u.longitud < -75.5540
    assert (u.longitud - -75.5550) * 109_500 == pytest.approx(50, abs=3)


def test_sin_via_siguiente_avanza_en_sentido_contrario_a_la_anterior():
    [u] = ubicar(Direccion(CALLE_9, "4", 30), CRUCES)  # no hay Cra. 5: se aleja de la Cra. 3
    assert u.longitud > -75.5540


def test_sin_placa_es_el_cruce_y_sin_cruce_es_la_via():
    [u] = ubicar(Direccion(CALLE_9, "3"), CRUCES)
    assert (u.longitud, u.latitud) == (-75.5550, 10.4030)
    [via] = ubicar(Direccion(CALLE_9), CRUCES)
    assert via.nombre == "Calle 9" and not via.exacta


def test_el_numero_del_cruce_distingue_la_misma_calle_en_otro_sector():
    [lejos] = ubicar(Direccion(CALLE_9, "82", 20), CRUCES)
    assert lejos.longitud == pytest.approx(-75.4600, abs=0.001)
    assert ubicar(Direccion(CALLE_9, "77", 20), CRUCES) == []


def test_buscar_una_direccion_en_la_api_la_ubica_en_bocagrande(api):
    resultados = api.get("/api/v1/places/search", params={"q": "Calle 9 # 3-50"}).json()
    assert resultados, "debería encontrar la dirección"
    primera = resultados[0]
    assert (primera["tipo"], primera["nombre"]) == ("Dirección", "Calle 9 # 3-50")
    assert primera["detalle"].startswith("Dirección aproximada")
    # Bocagrande, a la altura de la Cra. 3 con Calle 9.
    assert primera["latitud"] == pytest.approx(10.403, abs=0.002)
    assert primera["longitud"] == pytest.approx(-75.554, abs=0.002)
    # Un nombre que no es dirección sigue siendo una búsqueda de lugares.
    assert api.get("/api/v1/places/search", params={"q": "bocagrande"}).json()[0]["tipo"] != "Dirección"
