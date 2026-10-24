"""
Descarga de OpenStreetMap las calles con nombre de Cartagena, calcula sus cruces y guarda en
backend/data/cruces.json los que quedan cerca de las rutas de Transcaribe. Sirven para nombrar los puntos
de subida fuera de la troncal («Paradero Av. Pedro de Heredia con Cra. 28»): el archivo oficial de paraderos
no trae coordenadas.

Uso (desde backend/, después de scripts/importar_osm.py):
    python -m scripts.importar_cruces

Datos © colaboradores de OpenStreetMap, disponibles bajo la licencia ODbL.
"""
import json
import re
from collections import defaultdict
from pathlib import Path
from urllib.parse import urlencode
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

import numpy as np
import shapely
from shapely.geometry import LineString

from src.domain.geo import a_metros

# Servidores públicos de Overpass; si uno está saturado (504) se prueba el siguiente.
SERVIDORES = ["https://overpass-api.de/api/interpreter", "https://overpass.private.coffee/api/interpreter",
              "https://maps.mail.ru/osm/tools/overpass/api/interpreter"]
USER_AGENT = "KartaProyectoUniversitario/1.0 (Universidad de Cartagena)"
DATA_DIR = Path(__file__).resolve().parent.parent / "data"
DISTANCIA_A_LA_RUTA_M = 120   # solo interesan los cruces por donde pasa un bus

# Cuanto más importante la vía, antes va en el nombre: «Av. Pedro de Heredia con Cra. 28».
JERARQUIA = ["trunk", "primary", "secondary", "tertiary", "unclassified", "residential", "living_street",
             "service", "pedestrian"]

CONSULTA = f"""[out:json][timeout:180];
area["name"="Cartagena de Indias"]["admin_level"]->.a;
way["highway"~"^({'|'.join(JERARQUIA)})$"]["name"](area.a);
out body;
>;
out skel qt;"""

ABREVIATURAS = [
    (r"^Avenida\b", "Av."), (r"^Carrera\b", "Cra."), (r"^Transversal\b", "Tv."), (r"^Diagonal\b", "Dg."),
    (r"^Callejón\b", "Cjón."),
]


def abreviar(nombre: str) -> str:
    """«Carrera 28» → «Cra. 28», «Avenida Pedro de Heredia» → «Av. Pedro de Heredia»."""
    nombre = " ".join(nombre.split())
    for patron, corto in ABREVIATURAS:
        nombre = re.sub(patron, corto, nombre)
    return nombre


def cruces(elementos: list[dict]) -> list[dict]:
    """Nodos que comparten dos calles de nombre distinto, con el nombre de las dos más importantes."""
    coordenadas = {e["id"]: (e["lon"], e["lat"]) for e in elementos if e["type"] == "node"}
    rango_por_nombre: dict[str, int] = {}
    nombres_por_nodo: dict[int, set[str]] = defaultdict(set)
    for via in (e for e in elementos if e["type"] == "way"):
        nombre = abreviar(via["tags"]["name"])
        rango = JERARQUIA.index(via["tags"]["highway"])
        rango_por_nombre[nombre] = min(rango, rango_por_nombre.get(nombre, rango))
        for nodo in via["nodes"]:
            nombres_por_nodo[nodo].add(nombre)

    resultado, vistos = [], set()
    for nodo, nombres in nombres_por_nodo.items():
        if len(nombres) < 2 or nodo not in coordenadas:
            continue
        principales = sorted(nombres, key=lambda n: (rango_por_nombre[n], n))[:2]
        nombre = f"{principales[0]} con {principales[1]}"
        lon, lat = coordenadas[nodo]
        # Una avenida de doble calzada cruza la misma calle dos veces a pocos metros: basta un cruce por cuadra.
        clave = (nombre, round(lon, 3), round(lat, 3))
        if clave in vistos:
            continue
        vistos.add(clave)
        resultado.append({"_id": f"n{nodo}", "nombre": nombre,
                          "ubicacion": {"type": "Point", "coordinates": [round(lon, 6), round(lat, 6)]}})
    return resultado


def cerca_de_las_rutas(cruces_: list[dict], rutas: list[dict]) -> list[dict]:
    lineas = shapely.STRtree([a_metros(LineString(r["geometria"]["coordinates"])) for r in rutas])
    puntos = [a_metros(shapely.Point(c["ubicacion"]["coordinates"])) for c in cruces_]
    cercanos, _ = lineas.query(puntos, predicate="dwithin", distance=DISTANCIA_A_LA_RUTA_M)
    return [cruces_[k] for k in sorted(set(np.asarray(cercanos).tolist()))]


def descargar() -> list[dict]:
    errores = []
    for servidor in SERVIDORES:
        peticion = Request(servidor, data=urlencode({"data": CONSULTA}).encode(), headers={"User-Agent": USER_AGENT})
        try:
            with urlopen(peticion, timeout=300) as respuesta:
                return json.load(respuesta)["elements"]
        except (HTTPError, URLError, TimeoutError) as error:
            errores.append(f"{servidor}: {error}")
    raise SystemExit("Ningún servidor de Overpass respondió:\n" + "\n".join(errores))


def main() -> None:
    elementos = descargar()
    rutas = json.loads((DATA_DIR / "transcaribe.json").read_text(encoding="utf-8"))["rutas"]
    todos = cruces(elementos)
    utiles = cerca_de_las_rutas(todos, rutas)
    salida = DATA_DIR / "cruces.json"
    salida.write_text(json.dumps({"atribucion": "Datos © colaboradores de OpenStreetMap (ODbL)",
                                  "cruces": utiles}, ensure_ascii=False, separators=(",", ":")),
                      encoding="utf-8")
    print(f"{len(todos)} cruces en Cartagena; {len(utiles)} cerca de las rutas, en {salida}")


if __name__ == "__main__":
    main()
