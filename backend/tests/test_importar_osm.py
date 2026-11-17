"""El encadenado de las vías de una relación de OSM en un solo recorrido (no necesita base de datos)."""
from scripts.importar_osm import encadenar_vias

GRADO = 1 / 111_000  # ~1 m en grados, cerca del ecuador


def m(x, y):
    return (round(-75.5 + x * GRADO, 7), round(10.4 + y * GRADO, 7))


def test_une_vias_que_no_comparten_el_nodo_y_la_vuelta_por_las_mismas():
    # Ida por A y B, que quedan a 8 m sin compartir nodo; la vuelta repite B y A al revés (como la A104).
    a = [m(0, 0), m(100, 0)]
    b = [m(200, 0), m(108, 0)]          # viene al revés y empieza a 8 m del final de A
    linea, cortes = encadenar_vias([a, b, b, a])
    assert cortes == 0
    assert linea[0] == m(0, 0) and linea[-1] == m(0, 0)
    assert m(200, 0) in linea


def test_recorre_la_glorieta_en_su_sentido_hasta_la_salida():
    # Se llega a la glorieta por el sur y se sale por el este: se recorre en el orden de sus nodos.
    glorieta = [m(0, -20), m(20, 0), m(0, 20), m(-20, 0), m(0, -20)]
    llega = [m(0, -100), m(0, -20)]
    sale = [m(20, 0), m(100, 0)]
    linea, cortes = encadenar_vias([llega, glorieta, sale])
    assert cortes == 0
    assert linea == [m(0, -100), m(0, -20), m(20, 0), m(100, 0)]


def test_un_hueco_grande_es_un_corte():
    linea, cortes = encadenar_vias([[m(0, 0), m(100, 0)], [m(400, 0), m(500, 0)]])
    assert cortes == 1 and linea[-1] == m(500, 0)
    # Uno chico se cruza sin contarlo.
    assert encadenar_vias([[m(0, 0), m(100, 0)], [m(180, 0), m(300, 0)]])[1] == 0


def test_entra_a_una_via_por_la_mitad_y_sigue_hacia_la_siguiente():
    # La vía larga va de oeste a este; la ruta llega a su mitad desde el sur y sigue hacia el oeste.
    llega = [m(0, -100), m(0, 0)]
    larga = [m(-300, 0), m(0, 0), m(300, 0)]
    oeste = [m(-300, 0), m(-400, 0)]
    linea, cortes = encadenar_vias([llega, larga, oeste])
    assert cortes == 0
    assert linea == [m(0, -100), m(0, 0), m(-300, 0), m(-400, 0)]


def test_salta_la_via_repetida_por_error_pero_no_un_retorno_de_verdad():
    # La misma vía dos veces seguidas y la siguiente arranca al final de la primera pasada (la C001).
    a, b, c = [m(0, 0), m(100, 0)], [m(100, 0), m(200, 0)], [m(200, 0), m(300, 0)]
    linea, cortes = encadenar_vias([a, b, b, c])
    assert cortes == 0 and linea == [m(0, 0), m(100, 0), m(200, 0), m(300, 0)]
    # Al final de una calle ciega el bus vuelve: la siguiente arranca donde empezó la vía repetida.
    ciega, vuelve = [m(100, 0), m(100, 100)], [m(100, 0), m(100, -100)]
    linea, _ = encadenar_vias([a, ciega, ciega, vuelve])
    assert linea == [m(0, 0), m(100, 0), m(100, 100), m(100, 0), m(100, -100)]
