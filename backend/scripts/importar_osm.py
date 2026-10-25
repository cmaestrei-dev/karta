"""
Descarga de OpenStreetMap las rutas y estaciones de Transcaribe y los lugares buscables de
Cartagena, y los guarda procesados en backend/data/ para cargarlos en MongoDB con el seed.

Uso (desde backend/):
    python -m scripts.importar_osm

Datos © colaboradores de OpenStreetMap, disponibles bajo la licencia ODbL.
"""
import json
import sys
import time
from pathlib import Path
from urllib.parse import urlencode
from urllib.request import Request, urlopen

from shapely.geometry import LineString

from src.domain.geo import a_grados, a_metros, distancia_m
from src.domain.texto import normalizar, tokens

OVERPASS_URL = "https://overpass-api.de/api/interpreter"
USER_AGENT = "KartaProyectoUniversitario/1.0 (Universidad de Cartagena)"
DATA_DIR = Path(__file__).resolve().parent.parent / "data"

AREA = 'area["name"="Cartagena de Indias"]["admin_level"]->.a;'

CONSULTA_RUTAS = f"""[out:json][timeout:180];{AREA}
relation["type"="route"]["route"="bus"]["operator"~"caribe",i](area.a)->.r;
.r out geom;"""

CONSULTA_ANDENES = f"""[out:json][timeout:180];{AREA}
relation["type"="route"]["route"="bus"]["operator"~"caribe",i](area.a)->.r;
way(r.r)["public_transport"="platform"]; out tags center;
rel(r.r)["public_transport"="platform"]; out tags center;"""

CONSULTA_LUGARES = f"""[out:json][timeout:180];{AREA}
(
  nwr["place"~"^(suburb|neighbourhood|quarter|square)$"]["name"](area.a);
  nwr["tourism"~"^(attraction|museum|viewpoint)$"]["name"](area.a);
  nwr["amenity"~"^(university|college|hospital|bus_station|marketplace|townhall|library)$"]["name"](area.a);
  nwr["shop"="mall"]["name"](area.a);
  nwr["aeroway"="aerodrome"]["name"](area.a);
  nwr["leisure"~"^(park|stadium)$"]["name"](area.a);
  nwr["historic"~"^(castle|fort|monument|city_gate)$"]["name"](area.a);
);
out tags center;"""

TIPO_RUTA = {"T": "troncal", "X": "pretroncal", "A": "alimentadora", "C": "complementaria"}

TIPO_LUGAR = [
    ("aeroway", "aerodrome", "Aeropuerto"),
    ("amenity", "bus_station", "Terminal / estación"),
    ("amenity", "university", "Universidad"),
    ("amenity", "college", "Institución educativa"),
    ("amenity", "hospital", "Hospital"),
    ("amenity", "marketplace", "Mercado"),
    ("amenity", "townhall", "Entidad pública"),
    ("amenity", "library", "Biblioteca"),
    ("shop", "mall", "Centro comercial"),
    ("tourism", "museum", "Museo"),
    ("tourism", "attraction", "Sitio turístico"),
    ("tourism", "viewpoint", "Mirador"),
    ("historic", None, "Sitio histórico"),
    ("leisure", "stadium", "Estadio"),
    ("leisure", "park", "Parque"),
    ("place", "square", "Plaza"),
    ("place", None, "Barrio"),
]

def consultar_overpass(consulta: str) -> list[dict]:
    """Ejecuta la consulta con reintentos: el servidor público suele estar saturado."""
    espera = 10
    for _ in range(6):
        peticion = Request(OVERPASS_URL, data=urlencode({"data": consulta}).encode(),
                           headers={"User-Agent": USER_AGENT})
        try:
            with urlopen(peticion, timeout=240) as respuesta:
                return json.load(respuesta)["elements"]
        except Exception as error:  # 429/504 o cuerpo no JSON
            print(f"Overpass no respondió ({error}); reintento en {espera} s")
            time.sleep(espera)
            espera *= 2
    raise RuntimeError("Overpass no está disponible; intenta más tarde.")


def encadenar_vias(vias: list[list[tuple[float, float]]]) -> tuple[list[tuple[float, float]], int]:
    """Une las vías de una relación en una sola línea orientada. Devuelve (línea, cortes)."""
    linea = list(vias[0])
    cortes = 0
    for i, via in enumerate(vias[1:], start=1):
        if i == 1 and linea[0] in (via[0], via[-1]) and linea[-1] not in (via[0], via[-1]):
            linea.reverse()  # la primera vía venía en sentido contrario
        if via[0] == linea[-1]:
            linea.extend(via[1:])
        elif via[-1] == linea[-1]:
            linea.extend(reversed(via[:-1]))
        else:
            cortes += 1  # relación incompleta en OSM: se salta el hueco
            linea.extend(via)
    return linea, cortes


def simplificar(coordenadas: list[tuple[float, float]], tolerancia_m: float = 5) -> list[list[float]]:
    simple = a_grados(a_metros(LineString(coordenadas)).simplify(tolerancia_m))
    puntos: list[list[float]] = []
    for lon, lat in simple.coords:
        punto = [round(lon, 6), round(lat, 6)]
        if not puntos or punto != puntos[-1]:  # MongoDB rechaza vértices consecutivos repetidos
            puntos.append(punto)
    return puntos


def procesar_rutas(relaciones: list[dict], andenes: list[dict]) -> dict:
    andenes_por_id = {(a["type"], a["id"]): a for a in andenes if a["tags"].get("name")}
    rutas, estaciones = [], {}
    for rel in relaciones:
        etiquetas = rel["tags"]
        ref = etiquetas.get("ref", "").strip()
        vias = [[(p["lon"], p["lat"]) for p in m["geometry"]]
                for m in rel["members"] if m["type"] == "way" and m["role"] == "" and m.get("geometry")]
        if not ref or not vias:
            continue
        coordenadas, cortes = encadenar_vias(vias)
        rutas.append({
            "_id": ref,
            "nombre": etiquetas.get("name", ref),
            "tipo": TIPO_RUTA.get(ref[0], "otra"),
            "desde": etiquetas.get("from"),
            "hasta": etiquetas.get("to"),
            "geometria": {"type": "LineString", "coordinates": simplificar(coordenadas)},
            "cortes_en_osm": cortes,
            "osm_id": rel["id"],
        })
        for m in rel["members"]:
            anden = andenes_por_id.get((m["type"], m["ref"]))
            if anden and m["role"].startswith("platform"):
                nombre = anden["tags"]["name"]
                estacion = estaciones.setdefault(nombre, {
                    "_id": normalizar(nombre).replace(" ", "-"),
                    "nombre": nombre,
                    "ubicacion": {"type": "Point",
                                  "coordinates": [round(anden["center"]["lon"], 6), round(anden["center"]["lat"], 6)]},
                    "rutas": [],
                })
                if ref not in estacion["rutas"]:
                    estacion["rutas"].append(ref)
    return {"rutas": sorted(rutas, key=lambda r: r["_id"]), "estaciones": sorted(estaciones.values(), key=lambda e: e["nombre"])}


def tipo_de_lugar(etiquetas: dict) -> str | None:
    for clave, valor, tipo in TIPO_LUGAR:
        if clave in etiquetas and (valor is None or etiquetas[clave] == valor):
            return tipo
    return None


DISTANCIA_DUPLICADO_M = 1500


def procesar_lugares(elementos: list[dict], estaciones: list[dict]) -> list[dict]:
    lugares, vistos = [], {}
    for e in elementos:
        etiquetas = e["tags"]
        tipo = tipo_de_lugar(etiquetas)
        centro = e.get("center") or {"lat": e.get("lat"), "lon": e.get("lon")}
        if not tipo or centro["lat"] is None:
            continue
        nombre = etiquetas["name"].strip()
        # El mismo lugar suele estar mapeado como punto y como área: mismo nombre y tipo, muy cerca.
        punto = (centro["lon"], centro["lat"])
        previos = vistos.setdefault((normalizar(nombre), tipo), [])
        if any(distancia_m(punto, previo) < DISTANCIA_DUPLICADO_M for previo in previos):
            continue
        previos.append(punto)
        lugares.append({
            "_id": f"osm-{e['type'][0]}{e['id']}",
            "nombre": nombre,
            "tipo": tipo,
            "ubicacion": {"type": "Point", "coordinates": [round(centro["lon"], 6), round(centro["lat"], 6)]},
            "tokens": tokens(nombre),
        })
    for estacion in estaciones:
        lugares.append({
            "_id": f"estacion-{estacion['_id']}",
            "nombre": f"Estación {estacion['nombre']}",
            "tipo": "Estación Transcaribe",
            "ubicacion": estacion["ubicacion"],
            "tokens": tokens(f"Estación {estacion['nombre']} Transcaribe"),
        })
    return sorted(lugares, key=lambda l: l["nombre"])


# Estaciones cuyos andenes no tienen nombre en OSM: sin ellas, las alimentadoras no tienen dónde integrarse con la
# troncal. Rutas según Transcaribe, «Rutas y recorridos» (julio de 2024); coordenadas de OSM (ODbL).
ESTACIONES_DE_INTEGRACION = [
    {"_id": "santa-lucia", "nombre": "Santa Lucía", "osm": "way 185608086",
     "ubicacion": {"type": "Point", "coordinates": [-75.478005, 10.395206]},
     "rutas": ["A103", "A104", "A105", "A107", "A108", "A111"]},
    {"_id": "portal", "nombre": "Patio Portal", "osm": "relation 13764314",
     "ubicacion": {"type": "Point", "coordinates": [-75.472655, 10.395616]},
     "rutas": ["A101", "A102", "A114", "A117", "C016", "T100E", "T101", "T102", "T103", "X102", "X103"]},
]


def agregar_estaciones_de_integracion(transcaribe: dict, lugares: list[dict]) -> None:
    """Agrega (o reemplaza) las estaciones de integración y sus lugares buscables."""
    ids = {e["_id"] for e in ESTACIONES_DE_INTEGRACION}
    transcaribe["estaciones"] = sorted(
        [e for e in transcaribe["estaciones"] if e["_id"] not in ids]
        + [{k: v for k, v in e.items() if k != "osm"} for e in ESTACIONES_DE_INTEGRACION],
        key=lambda e: e["nombre"])
    lugares[:] = [l for l in lugares if l["_id"] not in {f"estacion-{i}" for i in ids}]
    for e in ESTACIONES_DE_INTEGRACION:
        lugares.append({"_id": f"estacion-{e['_id']}", "nombre": f"Estación {e['nombre']}", "tipo": "Estación Transcaribe",
                        "ubicacion": e["ubicacion"], "tokens": tokens(f"Estación {e['nombre']} Transcaribe")})
    lugares.sort(key=lambda l: l["nombre"])


def solo_estaciones_de_integracion():
    """Aplica ESTACIONES_DE_INTEGRACION a los archivos ya descargados, sin consultar OSM."""
    datos = {n: json.loads((DATA_DIR / n).read_text(encoding="utf-8")) for n in ("transcaribe.json", "lugares.json")}
    agregar_estaciones_de_integracion(datos["transcaribe.json"], datos["lugares.json"]["lugares"])
    for nombre, contenido in datos.items():
        with open(DATA_DIR / nombre, "w", encoding="utf-8") as archivo:
            json.dump(contenido, archivo, ensure_ascii=False, separators=(",", ":"))
    print(f"✅ {len(datos['transcaribe.json']['estaciones'])} estaciones.")


def main():
    if "--solo-integraciones" in sys.argv:
        return solo_estaciones_de_integracion()
    DATA_DIR.mkdir(exist_ok=True)
    print("Descargando rutas de Transcaribe…")
    relaciones = consultar_overpass(CONSULTA_RUTAS)
    andenes = consultar_overpass(CONSULTA_ANDENES)
    transcaribe = procesar_rutas(relaciones, andenes)

    print("Descargando lugares de Cartagena…")
    lugares = procesar_lugares(consultar_overpass(CONSULTA_LUGARES), transcaribe["estaciones"])
    agregar_estaciones_de_integracion(transcaribe, lugares)

    atribucion = "Datos © colaboradores de OpenStreetMap (ODbL), descargados el " + time.strftime("%Y-%m-%d")
    for nombre, contenido in (("transcaribe.json", transcaribe), ("lugares.json", {"lugares": lugares})):
        with open(DATA_DIR / nombre, "w", encoding="utf-8") as archivo:
            json.dump({"atribucion": atribucion, **contenido}, archivo, ensure_ascii=False, separators=(",", ":"))

    print(f"✅ {len(transcaribe['rutas'])} rutas, {len(transcaribe['estaciones'])} estaciones, {len(lugares)} lugares.")
    for ruta in transcaribe["rutas"]:
        if ruta["cortes_en_osm"]:
            print(f"   ⚠️ {ruta['_id']}: {ruta['cortes_en_osm']} cortes en la relación de OSM")


if __name__ == "__main__":
    main()
