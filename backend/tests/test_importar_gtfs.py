"""La importación del GTFS de Transcaribe, con un GTFS inventado de dos rutas (no necesita base de datos)."""
import csv
import json
import zipfile

import pytest

from scripts.importar_gtfs import (
    Recorrido, con_rutas_del_gtfs, estacion_y_modulo, hacia, horarios, importar, leer, paraderos, recorridos,
    sentido_de,
)

ESTACIONES = {
    "bazurto": {"_id": "bazurto", "nombre": "Bazurto", "rutas": ["X103"],
                "ubicacion": {"type": "Point", "coordinates": [-75.5243, 10.4139]}},
    "portal": {"_id": "portal", "nombre": "Patio Portal", "rutas": ["X103"],
               "ubicacion": {"type": "Point", "coordinates": [-75.4712, 10.3955]}},
    "santa-lucia": {"_id": "santa-lucia", "nombre": "Santa Lucía", "rutas": [],
                    "ubicacion": {"type": "Point", "coordinates": [-75.4950, 10.3920]}},
}
TODOS_LOS_DIAS, ENTRE_SEMANA = "1111111", "1111100"


def _tabla(carpeta, nombre, filas):
    with open(carpeta / nombre, "w", newline="", encoding="utf-8") as f:
        escritor = csv.DictWriter(f, fieldnames=list(filas[0]))
        escritor.writeheader()
        escritor.writerows(filas)


def _parada(ident, nombre, lon, lat):
    return {"stop_id": ident, "stop_name": nombre, "stop_lat": lat, "stop_lon": lon}


def _viajes(ruta, servicio, sentido, paradas, salidas, minutos_entre=5):
    """Viajes de [ruta] que salen a cada hora de [salidas] («05:00») y recorren [paradas]."""
    viajes, horas = [], []
    for k, salida in enumerate(salidas):
        viaje = f"{ruta}-{k}"
        viajes.append({"route_id": ruta, "service_id": servicio, "trip_id": viaje, "trip_headsign": sentido,
                       "shape_id": ruta})
        h, m = (int(x) for x in salida.split(":"))
        for orden, parada in enumerate(paradas, start=1):
            total = h * 60 + m + (orden - 1) * minutos_entre
            hora = f"{total // 60:02d}:{total % 60:02d}:00"
            horas.append({"trip_id": viaje, "arrival_time": hora, "departure_time": hora, "stop_id": parada,
                          "stop_sequence": orden})
    return viajes, horas


@pytest.fixture
def gtfs(tmp_path):
    """La X103 de ida (Portal → Bazurto), su vuelta, y la A105 de vuelta solo entre semana, con una extensión."""
    carpeta = tmp_path / "gtfs"
    carpeta.mkdir()
    _tabla(carpeta, "routes.txt", [
        {"route_id": "1", "route_short_name": "X103", "route_long_name": "Ida - portal - centro"},
        {"route_id": "2", "route_short_name": "X103", "route_long_name": "Vuelta - portal - centro"},
        {"route_id": "3", "route_short_name": "A105", "route_long_name": "Vuelta - simon bolivar - socorro - portal"},
        {"route_id": "4", "route_short_name": "A105", "route_long_name": "Extensión"},
    ])
    _tabla(carpeta, "stops.txt", [
        _parada("p1", "Patio Portal B3", -75.4712, 10.3955),
        _parada("p2", "Antiguo telecom- D1", -75.4900, 10.4000),
        _parada("p3", "Bazurto  A1", -75.5245, 10.4140),
        _parada("p4", "Bazurto B2", -75.5241, 10.4138),
        _parada("p5", "Inicio Simon Bolivar", -75.4800, 10.3800),
        _parada("p6", "Transferencia Santa Lucia Desc", -75.4950, 10.3920),
    ])
    _tabla(carpeta, "calendar.txt", [
        {"service_id": "s1", **dict(zip(("monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"),
                                        TODOS_LOS_DIAS)), "start_date": "20260101", "end_date": "20261231"},
        {"service_id": "s2", **dict(zip(("monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"),
                                        ENTRE_SEMANA)), "start_date": "20260101", "end_date": "20261231"},
    ])
    ida = _viajes("1", "s1", "Ida", ["p1", "p2", "p3"], ["05:00", "05:30", "06:00", "21:50"])
    vuelta = _viajes("2", "s1", "Volta", ["p4", "p2", "p1"], ["05:10", "22:00"])
    a105 = _viajes("3", "s2", "Volta", ["p5", "p6"], ["04:33", "23:58", "24:20"])
    extension = _viajes("4", "s2", "Volta", ["p5", "p2", "p6"], ["07:00"])
    _tabla(carpeta, "trips.txt", ida[0] + vuelta[0] + a105[0] + extension[0])
    _tabla(carpeta, "stop_times.txt", ida[1] + vuelta[1] + a105[1] + extension[1])
    _tabla(carpeta, "shapes.txt", [
        {"shape_id": "1", "shape_pt_lat": 10.3955, "shape_pt_lon": -75.4712, "shape_pt_sequence": 1},
        {"shape_id": "1", "shape_pt_lat": 10.4140, "shape_pt_lon": -75.5245, "shape_pt_sequence": 2},
    ])
    return carpeta


def test_el_sentido_sale_del_nombre_o_del_letrero():
    assert sentido_de("Ida - portal - centro") == "ida"
    assert sentido_de("Vuelta - centro - portal") == "vuelta"
    assert sentido_de("Circular bodeguita - zona norte") == "circular"
    assert sentido_de("Extensión", "Volta") == "vuelta"  # así viene escrito en el GTFS
    assert sentido_de("Extensión", "Unico") == "circular"
    assert sentido_de("Extensión", "") is None


def test_lee_igual_el_zip_y_la_carpeta(gtfs, tmp_path):
    archivo = tmp_path / "gtfs.zip"
    with zipfile.ZipFile(archivo, "w") as z:
        for tabla in gtfs.iterdir():
            z.write(tabla, f"GTFS SITM/{tabla.name}")  # dentro de una carpeta, como suelen venir
    assert leer(archivo) == leer(gtfs)
    assert leer(gtfs)["calendar.txt"][0]["service_id"] == "s1"


def test_un_recorrido_por_ruta_y_sentido_y_la_variante_queda_fuera(gtfs):
    elegidos, omitidos = recorridos(leer(gtfs))
    assert [(r.ruta, r.sentido) for r in elegidos] == [("A105", "vuelta"), ("X103", "ida"), ("X103", "vuelta")]
    a105 = elegidos[0]
    assert a105.nombre.startswith("Vuelta") and len(a105.salidas) == 3  # la que tiene más viajes
    assert omitidos == ["A105 «Extensión»: variante de la vuelta, con 1 viajes "
                        "(se usa «Vuelta - simon bolivar - socorro - portal», con 3)"]
    assert [p["stop_id"] for p in elegidos[1].paradas] == ["p1", "p2", "p3"]


def test_reconoce_estaciones_y_modulos():
    assert estacion_y_modulo("Bazurto A2", ESTACIONES) == ("bazurto", "A2")
    assert estacion_y_modulo("Patio Portal B3", ESTACIONES) == ("portal", "B3")
    assert estacion_y_modulo("Transferencia Santa Lucia Desc", ESTACIONES) == ("santa-lucia", None)
    assert estacion_y_modulo("Antiguo telecom- D1", ESTACIONES) is None  # parece un módulo y no lo es
    assert estacion_y_modulo("Portal De Belen", ESTACIONES) is None


def test_todos_los_paraderos_con_su_punto_oficial(gtfs):
    elegidos, _ = recorridos(leer(gtfs))
    ida = [p for p in paraderos(elegidos, ESTACIONES) if p["ruta"] == "X103" and p["sentido"] == "ida"]
    assert [p["_id"] for p in ida] == ["X103-ida-01", "X103-ida-02", "X103-ida-03"]
    assert [(p["estacion"], p["modulo"], p["precision"]) for p in ida] == [
        ("portal", "B3", "estacion"), (None, None, "oficial"), ("bazurto", "A1", "estacion")]
    assert ida[2]["nombre"] == "Bazurto A1"  # sin los espacios de más
    assert ida[1]["ubicacion"] == {"type": "Point", "coordinates": [-75.49, 10.4]}


def test_hacia_donde_va_cada_recorrido(gtfs):
    elegidos, _ = recorridos(leer(gtfs))
    por_clave = {f"{r.ruta}-{r.sentido}": hacia(r, ESTACIONES) for r in elegidos}
    assert por_clave["X103-vuelta"] == "el Portal"  # el último paradero es el Portal, un extremo del nombre
    assert por_clave["X103-ida"] == "Bazurto"  # termina en una estación que no es un extremo del nombre
    # El nombre dice «portal», pero termina en Santa Lucía: manda el último paradero.
    assert por_clave["A105-vuelta"] == "Santa Lucía"


def test_hacia_cuando_el_ultimo_paradero_no_dice_nada():
    def recorrido(sentido, nombre, *paradas):
        return Recorrido(ruta="C018", sentido=sentido, nombre=nombre, paradas=tuple({"stop_name": p} for p in paradas),
                         salidas=(), forma=None)
    # En la ida, hacia el último extremo del nombre.
    assert hacia(recorrido("ida", "Ida bodeguita - torices", "Parque De La Marina", "Institucion Santa Maria"),
                 ESTACIONES) == "Torices"
    # Si el primero es un extremo, hacia el otro.
    assert hacia(recorrido("vuelta", "Vuelta - terminal - centro", "Terminal De Transportes", "Kr 10"),
                 ESTACIONES) == "el Centro"
    # Si no, hacia el último paradero, con las preposiciones en minúscula.
    assert hacia(recorrido("vuelta", "Vuelta - torices - bodeguita", "Institucion Santa Maria", "Parque De La Marina"),
                 ESTACIONES) == "Parque de la Marina"
    assert hacia(recorrido("circular", "Circular bodeguita - zona norte", "Parque De La Marina"), ESTACIONES) is None


def test_horarios_entre_semana_del_gtfs_y_el_fin_de_semana_con_el_archivo_de_2025(gtfs):
    tablas = leer(gtfs)
    elegidos, _ = recorridos(tablas)
    de_2025 = {"X103": {"_id": "X103", "lunes_a_viernes": ["05:00", "21:00"], "sabado": ["05:30", "20:30"],
                        "domingo_y_festivos": None},
               "A105": {"_id": "A105", "lunes_a_viernes": ["04:30", "22:40"], "sabado": ["05:00", "22:00"],
                        "domingo_y_festivos": ["05:30", "21:30"]}}
    por_ruta = {h["_id"]: h for h in horarios(elegidos, tablas["calendar.txt"], de_2025)}
    x103 = por_ruta["X103"]
    assert x103["lunes_a_viernes"] == ["05:00", "22:00"]  # la primera y la última salida, en cualquier sentido
    assert x103["sabado"] == ["05:30", "20:30"]  # opera el sábado; a qué horas, según 2025
    assert x103["domingo_y_festivos"] == ["05:00", "22:00"]  # opera el domingo y 2025 no lo tenía: el GTFS
    assert x103["salidas_por_hora"]["ida"][5] == 2 and x103["salidas_por_hora"]["ida"][21] == 1
    assert sum(x103["salidas_por_hora"]["vuelta"]) == 2
    a105 = por_ruta["A105"]
    assert a105["lunes_a_viernes"] == ["04:33", "23:59"]  # 24:20 es pasada la medianoche
    assert a105["sabado"] is None and a105["domingo_y_festivos"] is None  # el GTFS dice que no opera


def test_suma_las_rutas_que_paran_en_cada_estacion(gtfs):
    elegidos, _ = recorridos(leer(gtfs))
    transcaribe = {"atribucion": "Datos © colaboradores de OpenStreetMap (ODbL)", "rutas": [],
                   "estaciones": list(ESTACIONES.values())}
    nuevo, sumadas = con_rutas_del_gtfs(transcaribe, paraderos(elegidos, ESTACIONES), "Transcaribe S.A., GTFS")
    assert sumadas == {"santa-lucia": ["A105"]}
    assert {e["_id"]: e["rutas"] for e in nuevo["estaciones"]}["bazurto"] == ["X103"]
    assert nuevo["atribucion"].endswith("Rutas que paran en cada estación: también Transcaribe S.A., GTFS")
    # Correrlo otra vez no repite nada.
    otra_vez, _ = con_rutas_del_gtfs(nuevo, paraderos(elegidos, ESTACIONES), "Transcaribe S.A., GTFS")
    assert otra_vez == nuevo


def test_importa_todo_con_los_datos_de_karta(gtfs, tmp_path):
    datos = tmp_path / "data"
    datos.mkdir()
    (datos / "transcaribe.json").write_text(json.dumps(
        {"atribucion": "OSM", "rutas": [], "estaciones": list(ESTACIONES.values())}), encoding="utf-8")
    (datos / "horarios.json").write_text(json.dumps({"horarios": []}), encoding="utf-8")
    r = importar(gtfs, datos)
    assert len(r["paraderos"]) == 8
    assert r["hacia"] == {"A105-vuelta": "Santa Lucía", "X103-ida": "Bazurto", "X103-vuelta": "el Portal"}
    assert r["fuente"] == "Transcaribe S.A., GTFS del SITM (vigente del 01/01/2026 al 31/12/2026)"
    assert {h["_id"] for h in r["horarios"]} == {"A105", "X103"}
