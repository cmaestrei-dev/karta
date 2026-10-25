"""
Ubica los paraderos oficiales de Transcaribe sobre el recorrido de cada ruta.

Fuente: «Paraderos del Sistema Integrado de Transporte Masivo Transcaribe S.A.» (2025), Portal de Datos Abiertos
de Cartagena, licencia CC BY (data/fuentes/paradero_transcaribe_2025.xlsx). Trae 948 paraderos en orden por ruta y
sentido, pero sin coordenadas, y casi todos nombrados por una referencia («Iglesia Pozón», «Central de Abastos»).

Solo se publican los que se pueden ubicar bien:
1. `estacion`: es una estación («Madre Bernarda A1»): la estación, con el módulo donde para la ruta en ese sentido
   (el 1 es hacia el Centro y el 2 hacia el Portal; las letras, la mitad de la plataforma).
2. `direccion`: una dirección («Kr 68 entre Cl 16 y 17», «Cl 4 con Kr 80A»): los cruces de calles de OSM, llevados
   al recorrido de la ruta (a más de 250 m de él, no se usa).
Los demás quedan fuera. Se probó ubicarlos por el nombre de un lugar conocido y repartiéndolos entre sus vecinos:
el lugar casi siempre era el barrio entero («Iglesia Pozón» → El Pozón) o uno equivocado, y los repartidos quedaban
a una mediana de 230 m y, uno de cada cinco, a más de 1,4 km. Para esos hace falta la comunidad (D12, D16).

Uso: python -m scripts.importar_paraderos [--validar ruta/al/gtfs]
  --validar: compara con el GTFS comunitario (ColombiaGTFS, 2019, CC BY-SA) emparejando por nombre. Solo mide:
  sus coordenadas no se copian (su licencia no se puede mezclar con la ODbL de OSM).
"""
import json
import re
import statistics
import sys
from collections import defaultdict
from pathlib import Path

import openpyxl
from shapely.geometry import LineString, Point

from src.domain.direcciones import Via, leer_direccion, leer_via, ubicar, Cruce, vias_del_cruce
from src.domain.geo import a_grados, a_metros
from src.domain.texto import normalizar, tokens

DATA = Path(__file__).resolve().parent.parent / "data"
FUENTE = DATA / "fuentes" / "paradero_transcaribe_2025.xlsx"
SALIDA = DATA / "paraderos.json"
LEJOS_DEL_RECORRIDO_M = 250

# Nombres oficiales que no coinciden con el nombre de la estación en los datos.
ALIAS_DE_ESTACION = {"transferencia santa lucia": "santa-lucia", "patio portal": "portal", "delicias": "las-delicias",
                     "santa lucia": "santa-lucia"}
# Cómo leer el destino después de «hacia»: con artículo y sin las abreviaturas ni anotaciones del archivo.
LEGIBLE = {"Centro": "el Centro", "Portal": "el Portal", "Patio Portal": "el Portal", "Pozón": "el Pozón",
           "F. del Campo": "Flor del Campo", "S. Bolívar": "Simón Bolívar",
           "Huellas de Alberto Uribe Vuelta": "Huellas de Alberto Uribe", "Frente a Barcelona de Indias": "Barcelona de Indias"}
# Palabras que no sirven para reconocer un lugar.
VACIAS = {"de", "del", "la", "las", "el", "los", "y", "a", "al", "frente", "entrada", "antes", "despues", "diagonal",
          "calle", "carrera", "kr", "cl", "tv", "dg", "mz", "lote", "casa", "sector", "barrio", "parque", "colegio",
          "iglesia", "tienda", "supertienda", "drogueria", "estacion", "centro", "comercial", "cc", "urbanizacion",
          "conjunto", "edificio", "edif", "via", "avenida", "av", "1", "2", "3"}


def leer_fuente() -> list[dict]:
    hoja = openpyxl.load_workbook(FUENTE, read_only=True).worksheets[0]
    filas = list(hoja.iter_rows(values_only=True))
    i = {c: k for k, c in enumerate(filas[0])}
    paraderos = []
    for f in filas[1:]:
        if not f or not f[i["Codigo_Rutas"]]:
            continue
        codigo = str(f[i["Paraderos"]]).strip()
        paraderos.append({
            "ruta": str(f[i["Codigo_Rutas"]]).strip(),
            "sentido": str(f[i["Sentido"]]).strip().lower(),
            "orden": int(re.sub(r"\D", "", codigo) or 0),
            "codigo": codigo,
            "nombre": re.sub(r"\s+", " ", str(f[i["Ubicacion_del_Paradero"]])).strip(),
            "nombre_ruta": re.sub(r"\s+", " ", str(f[i["Rutas"]])).strip(),
        })
    return paraderos


def cargar():
    transcaribe = json.loads((DATA / "transcaribe.json").read_text(encoding="utf-8"))
    rutas = {r["_id"]: a_metros(LineString(r["geometria"]["coordinates"])) for r in transcaribe["rutas"]}
    estaciones = {e["_id"]: e for e in transcaribe["estaciones"]}
    nomenclatura = json.loads((DATA / "nomenclatura.json").read_text(encoding="utf-8"))["cruces"]
    cruces = []
    for c in nomenclatura:
        vias = tuple(v for nombre in c.get("vias", []) for v in vias_del_cruce(nombre)) or vias_del_cruce(c["nombre"])
        if vias:
            lon, lat = c["ubicacion"]["coordinates"]
            cruces.append(Cruce(c["nombre"], vias, lon, lat))
    return rutas, estaciones, cruces


# ------------------------------------------------------------------------------------------------ cada método

def por_estacion(nombre: str, estaciones: dict) -> tuple[Point, str, str | None] | None:
    """«Madre Bernarda A1» → (punto de la estación, id, módulo «A1»)."""
    m = re.match(r"^(.*?)\s+([A-D][1-6])$", nombre)
    base, modulo = (m.group(1), m.group(2)) if m else (nombre, None)
    clave = normalizar(base).replace("estacion ", "").strip()
    ident = ALIAS_DE_ESTACION.get(clave)
    if ident is None:
        ident = next((i for i, e in estaciones.items() if normalizar(e["nombre"]) == clave), None)
    if ident is None or (modulo is None and not re.search(r"estaci|transferencia|portal", normalizar(nombre))):
        return None
    lon, lat = estaciones[ident]["ubicacion"]["coordinates"]
    return a_metros(Point(lon, lat)), ident, modulo


def _cruces_de(a: Via, b: Via, cruces: list[Cruce]) -> list[Point]:
    return [a_metros(Point(c.longitud, c.latitud)) for c in cruces if a in c.vias and b in c.vias]


def _via_o_numero(texto: str, como: Via | None) -> Via | None:
    """«Cl 16» → Via(calle, 16); «17» solo hereda el tipo de la vía anterior («entre Cl 16 y 17»)."""
    via = leer_via(texto)
    if via is None and como is not None and re.fullmatch(r"\d{1,3}\s*[a-zA-Z]?(\s*bis)?", texto.strip(), re.I):
        via = Via(como.tipo, re.sub(r"\s+", "", texto.lower()))
    return via


def por_direccion(nombre: str, cruces: list[Cruce], linea) -> Point | None:
    """«Kr 68 entre Cl 16 y 17» (punto medio de los dos cruces), «Cl 4 con Kr 80A», «Calle 14 #65-34», «Kr 10»."""
    texto = re.sub(r"\s*-\s*.*$", "", nombre).strip()  # «Kr 9 - Beach Club» → «Kr 9»
    cerca = lambda puntos: min(puntos, key=linea.distance) if puntos else None
    m = re.match(r"^(.+?)\s+entre\s+(.+?)\s+y\s+(.+)$", texto, re.I)
    if m:
        via = leer_via(m.group(1))
        a = leer_via(m.group(2))
        b = _via_o_numero(m.group(3), a)
        if via and a and b:
            pa, pb = cerca(_cruces_de(via, a, cruces)), cerca(_cruces_de(via, b, cruces))
            if pa and pb:
                return Point((pa.x + pb.x) / 2, (pa.y + pb.y) / 2)
            return pa or pb
        return None
    m = re.match(r"^(.+?)\s+con\s+(.+)$", texto, re.I)
    if m:
        via, otra = leer_via(m.group(1)), leer_via(m.group(2))
        if via and otra is None and re.fullmatch(r"\d{1,3}\s*[a-zA-Z]?", m.group(2).strip()):
            otra = Via("calle" if via.tipo != "calle" else "carrera", re.sub(r"\s+", "", m.group(2).lower()))
        return cerca(_cruces_de(via, otra, cruces)) if via and otra else None
    direccion = leer_direccion(texto)
    if direccion and direccion.cruce:
        puntos = [a_metros(Point(u.longitud, u.latitud))
                  for u in ubicar(direccion, [c for c in cruces if direccion.via in c.vias], limite=6)]
        return cerca(puntos)
    via = leer_via(texto)
    if via:  # solo la vía: el cruce de esa vía más cercano al recorrido
        return cerca([a_metros(Point(c.longitud, c.latitud)) for c in cruces if via in c.vias])
    return None


# ----------------------------------------------------------------------------------------------------- todo

def _limpio(nombre: str) -> str:
    return re.sub(r"^Transferencia\s+", "", re.sub(r"\s+[A-D][1-6]$", "", nombre)).strip()


def hacia_donde(paraderos: list[dict]) -> dict[str, str]:
    """
    Hacia dónde va cada ruta en cada sentido («T102-ida» → «Crespo»). Si el sentido empieza en un extremo del nombre
    oficial de la ruta («Portal - Crespo»), va hacia el otro; si no, hacia su último paradero.
    """
    secuencias = defaultdict(list)
    for p in paraderos:
        if p["sentido"] in ("ida", "vuelta"):
            secuencias[(p["ruta"], p["sentido"])].append(p)
    hacia = {}
    for (ruta, sentido), secuencia in secuencias.items():
        secuencia.sort(key=lambda p: p["orden"])
        extremos = [x.strip() for x in secuencia[0]["nombre_ruta"].split(" - ")]
        primero = set(tokens(secuencia[0]["nombre"]))
        destino = _limpio(secuencia[-1]["nombre"])
        if len(extremos) >= 2:
            if set(tokens(extremos[0])) <= primero:
                destino = extremos[-1]
            elif set(tokens(extremos[-1])) <= primero:
                destino = extremos[0]
        destino = destino.replace("Santa Lucia", "Santa Lucía")
        # Para leerse bien después de «hacia»: «hacia el Centro», «hacia el Portal».
        hacia[f"{ruta}-{sentido}"] = LEGIBLE.get(destino, destino)
    return hacia


def ubicar_paraderos() -> tuple[list[dict], dict]:
    rutas, estaciones, cruces = cargar()
    paraderos = leer_fuente()
    resultado, sin_recorrido = [], set()
    for p in paraderos:
        linea = rutas.get(p["ruta"])
        if linea is None:
            sin_recorrido.add(p["ruta"])
            continue
        punto, precision, estacion, modulo = None, None, None, None
        if (e := por_estacion(p["nombre"], estaciones)) is not None:
            punto, estacion, modulo = e
            precision = "estacion"
        elif (d := por_direccion(p["nombre"], cruces, linea)) is not None:
            punto, precision = d, "direccion"
        if punto is not None and linea.distance(punto) > LEJOS_DEL_RECORRIDO_M:
            punto, precision = None, None
        avance = linea.project(punto) if punto is not None else None
        registro = {**p, "estacion": estacion, "modulo": modulo, "precision": precision, "_avance": avance,
                    "_punto": punto if precision == "estacion" else (linea.interpolate(avance) if avance is not None else None)}
        resultado.append(registro)

    salida = []
    for r in resultado:
        if r["_punto"] is None:
            continue
        lon, lat = a_grados(r["_punto"]).coords[0]
        salida.append({
            "_id": f"{r['ruta']}-{r['sentido']}-{r['orden']:02d}",
            "ruta": r["ruta"], "sentido": r["sentido"], "orden": r["orden"], "nombre": r["nombre"],
            "estacion": r["estacion"], "modulo": r["modulo"], "precision": r["precision"],
            "ubicacion": {"type": "Point", "coordinates": [round(lon, 6), round(lat, 6)]},
        })
    conteo = defaultdict(int)
    for r in resultado:
        conteo[r["precision"] if r["_punto"] is not None else "sin ubicar"] += 1
    return salida, {"total": len(paraderos), "sin recorrido en OSM": sorted(sin_recorrido), **conteo}


def validar(salida: list[dict], gtfs: Path) -> None:
    """Distancia a los paraderos del GTFS comunitario con el mismo nombre y la misma ruta."""
    import csv
    paradas = {f["stop_id"]: f for f in csv.DictReader(open(gtfs / "stops.txt", encoding="utf-8-sig"))}
    viajes = {f["trip_id"]: f["route_id"] for f in csv.DictReader(open(gtfs / "trips.txt", encoding="utf-8-sig"))}
    por_ruta = defaultdict(list)
    for f in csv.DictReader(open(gtfs / "stop_times.txt", encoding="utf-8-sig")):
        if f["stop_id"] in paradas:
            por_ruta[viajes.get(f["trip_id"])].append(paradas[f["stop_id"]])
    errores = defaultdict(list)
    for p in salida:
        claves = {t for t in tokens(p["nombre"]) if t not in VACIAS and len(t) >= 4}
        if not claves:
            continue
        for g in por_ruta.get(p["ruta"], []):
            if claves <= set(tokens(g["stop_name"])):
                real = a_metros(Point(float(g["stop_lon"]), float(g["stop_lat"])))
                errores[p["precision"]].append(real.distance(a_metros(Point(*p["ubicacion"]["coordinates"]))))
                break
    for precision, e in errores.items():
        print(f"  {precision:11} n={len(e):3}  mediana {statistics.median(e):5.0f} m  p80 {sorted(e)[int(len(e) * .8)]:5.0f} m")


def main():
    salida, conteo = ubicar_paraderos()
    SALIDA.write_text(json.dumps({
        "hacia": hacia_donde(leer_fuente()),
        "atribucion": "Paraderos: Transcaribe S.A., Portal de Datos Abiertos de Cartagena (CC BY), 2025. Ubicados "
                      "por Karta con calles y estaciones © colaboradores de OpenStreetMap (ODbL).",
        "paraderos": salida}, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    print(f"✅ {len(salida)} paraderos ubicados de {conteo['total']}: "
          + ", ".join(f"{k} {v}" for k, v in conteo.items() if k != "total"))
    if "--validar" in sys.argv:
        validar(salida, Path(sys.argv[sys.argv.index("--validar") + 1]))


if __name__ == "__main__":
    main()
