"""
Descarga de OpenStreetMap las rutas y estaciones de Transcaribe y los lugares buscables de
Cartagena, y los guarda procesados en backend/data/ para cargarlos en MongoDB con el seed.

Uso (desde backend/):
    python -m scripts.importar_osm                  # rutas, estaciones y lugares
    python -m scripts.importar_osm --solo-lugares   # solo los lugares buscables
    python -m scripts.importar_osm --solo-recorridos   # solo el trazado de las rutas que ya están

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
  nwr["place"~"^(suburb|neighbourhood|quarter|square|village|hamlet|locality|island)$"]["name"](area.a);
  nwr["tourism"~"^(attraction|museum|viewpoint|hotel|hostel|guest_house)$"]["name"](area.a);
  nwr["amenity"~"^(university|college|hospital|bus_station|marketplace|townhall|library|place_of_worship|school|clinic|fuel|police)$"]["name"](area.a);
  nwr["shop"~"^(mall|supermarket)$"]["name"](area.a);
  nwr["landuse"="retail"]["name"](area.a);
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
    ("amenity", "clinic", "Clínica"),
    ("amenity", "school", "Colegio"),
    ("amenity", "place_of_worship", "Iglesia"),
    ("amenity", "police", "Policía"),
    ("amenity", "fuel", "Estación de servicio"),
    ("shop", "mall", "Centro comercial"),
    ("shop", "supermarket", "Supermercado"),
    ("landuse", "retail", "Zona comercial"),   # el Mercado de Bazurto y Caribe Plaza están mapeados así
    ("tourism", "museum", "Museo"),
    ("tourism", "attraction", "Sitio turístico"),
    ("tourism", "viewpoint", "Mirador"),
    ("tourism", "hotel", "Hotel"),
    ("tourism", "hostel", "Hotel"),
    ("tourism", "guest_house", "Hotel"),
    ("historic", None, "Sitio histórico"),
    ("leisure", "stadium", "Estadio"),
    ("leisure", "park", "Parque"),
    ("place", "square", "Plaza"),
    ("place", "village", "Corregimiento"),     # La Boquilla, Bocachica, Pasacaballos
    ("place", "hamlet", "Caserío"),
    ("place", "locality", "Sector"),
    ("place", "island", "Isla"),
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


HUECO_TOLERABLE_M = 150   # un hueco menor se cruza en línea recta; uno mayor es un corte de la relación


def encadenar_vias(vias: list[list[tuple[float, float]]]) -> tuple[list[tuple[float, float]], int]:
    """
    Une las vías de una relación en una sola línea orientada. Devuelve (línea, cortes).

    Cada vía se toma por el extremo más cercano a donde va la línea: en OSM a veces dos vías seguidas no comparten
    el nodo (quedan a 8 m), y una ruta de ida y vuelta repite las vías en sentido contrario. Las glorietas (vías
    cerradas) se recorren en su sentido, desde el nodo más cercano a la llegada hasta el más cercano a la vía que
    sigue. Si la línea llega a la mitad de una vía (un cruce en T), se toma la mitad que lleva a la vía siguiente.
    Una vía repetida dos veces seguidas se salta cuando la siguiente arranca donde ya está la línea (un error de
    OSM; un retorno de verdad, como al final de una calle ciega, sigue desde el otro extremo). Solo un hueco de más
    de 150 m cuenta como corte.
    """
    linea = list(vias[0])
    if len(vias) > 1:
        siguiente = vias[1]
        lejos = lambda p: min(distancia_m(p, siguiente[0]), distancia_m(p, siguiente[-1]))
        if lejos(linea[0]) < lejos(linea[-1]):
            linea.reverse()  # la primera vía venía en sentido contrario
    cortes = 0
    for i, via in enumerate(vias[1:], start=1):
        fin = linea[-1]
        sigue = vias[i + 1] if i + 1 < len(vias) else None
        if sigue is not None and set(via) == set(vias[i - 1]) and fin in (sigue[0], sigue[-1]):
            continue  # la misma vía dos veces seguidas y la siguiente arranca aquí: está repetida por error en OSM
        if via[0] == via[-1] and len(via) > 3:
            ciclo = via[:-1]
            entra = min(range(len(ciclo)), key=lambda k: distancia_m(fin, ciclo[k]))
            sale = entra if sigue is None else min(
                range(len(ciclo)), key=lambda k: min(distancia_m(ciclo[k], sigue[0]), distancia_m(ciclo[k], sigue[-1])))
            tramo, k = [ciclo[entra]], entra
            while k != sale:
                k = (k + 1) % len(ciclo)
                tramo.append(ciclo[k])
        elif fin in via[1:-1]:
            # Se entra a la vía por la mitad (un cruce en T): sigue la mitad que lleva hacia la vía siguiente.
            k = via.index(fin)
            mitades = [via[k:], via[k::-1]]
            tramo = max(mitades, key=len) if sigue is None else min(
                mitades, key=lambda t: min(distancia_m(t[-1], sigue[0]), distancia_m(t[-1], sigue[-1])))
        else:
            tramo = via if distancia_m(fin, via[0]) <= distancia_m(fin, via[-1]) else via[::-1]
        if distancia_m(fin, tramo[0]) > HUECO_TOLERABLE_M:
            cortes += 1  # relación incompleta en OSM: se salta el hueco
        linea.extend(tramo[1:] if tramo[0] == fin else tramo)
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
DISTANCIA_MISMO_SITIO_M = 300   # mismo nombre con dos etiquetas («Mall Plaza» centro comercial y zona comercial)


def procesar_lugares(elementos: list[dict], estaciones: list[dict]) -> list[dict]:
    lugares, vistos, por_nombre = [], {}, {}
    orden = {tipo: k for k, (_, _, tipo) in enumerate(TIPO_LUGAR)}
    # Primero los tipos más específicos: si un sitio tiene dos etiquetas, queda la que mejor lo describe.
    for e in sorted(elementos, key=lambda e: orden.get(tipo_de_lugar(e["tags"]), len(orden))):
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
        mismo_nombre = por_nombre.setdefault(normalizar(nombre), [])
        if any(distancia_m(punto, previo) < DISTANCIA_MISMO_SITIO_M for previo in mismo_nombre):
            continue
        previos.append(punto)
        mismo_nombre.append(punto)
        lugares.append({
            "_id": f"osm-{e['type'][0]}{e['id']}",
            "nombre": nombre,
            "tipo": tipo,
            "ubicacion": {"type": "Point", "coordinates": [round(centro["lon"], 6), round(centro["lat"], 6)]},
            "tokens": tokens(nombre),
        })
    poner_zonas(lugares)
    for estacion in estaciones:
        lugares.append({
            "_id": f"estacion-{estacion['_id']}",
            "nombre": f"Estación {estacion['nombre']}",
            "tipo": "Estación Transcaribe",
            "ubicacion": estacion["ubicacion"],
            "tokens": tokens(f"Estación {estacion['nombre']} Transcaribe"),
        })
    return sorted(lugares, key=lambda l: l["nombre"])


ZONAS = ("Barrio", "Corregimiento", "Sector", "Caserío")
RADIO_DE_ZONA_M = 1500


def poner_zonas(lugares: list[dict]) -> None:
    """A cada sitio, el barrio más cercano: así se distinguen las diez «Terpel» o los hoteles con el mismo nombre."""
    zonas = [l for l in lugares if l["tipo"] in ZONAS]
    for lugar in lugares:
        if lugar["tipo"] in ZONAS or lugar["tipo"] == "Isla":
            continue
        punto = tuple(lugar["ubicacion"]["coordinates"])
        cerca = min(((distancia_m(punto, tuple(z["ubicacion"]["coordinates"])), z["nombre"]) for z in zonas),
                    default=None)
        if cerca and cerca[0] <= RADIO_DE_ZONA_M:
            lugar["zona"] = cerca[1]


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


def solo_lugares():
    """Vuelve a descargar los lugares buscables sin tocar las rutas ni las estaciones."""
    transcaribe = json.loads((DATA_DIR / "transcaribe.json").read_text(encoding="utf-8"))
    lugares = procesar_lugares(consultar_overpass(CONSULTA_LUGARES), transcaribe["estaciones"])
    agregar_estaciones_de_integracion(transcaribe, lugares)
    atribucion = "Datos © colaboradores de OpenStreetMap (ODbL), descargados el " + time.strftime("%Y-%m-%d")
    with open(DATA_DIR / "lugares.json", "w", encoding="utf-8") as archivo:
        json.dump({"atribucion": atribucion, "lugares": lugares}, archivo, ensure_ascii=False, separators=(",", ":"))
    print(f"✅ {len(lugares)} lugares.")


def solo_recorridos():
    """Vuelve a encadenar el trazado de las rutas que ya están, sin tocar las estaciones ni los lugares."""
    transcaribe = json.loads((DATA_DIR / "transcaribe.json").read_text(encoding="utf-8"))
    nuevas = {r["_id"]: r for r in procesar_rutas(consultar_overpass(CONSULTA_RUTAS), [])["rutas"]}
    for ruta in transcaribe["rutas"]:
        nueva = nuevas.get(ruta["_id"])
        if nueva is None:
            print(f"   ⚠️ {ruta['_id']}: ya no está en OSM; queda como estaba")
            continue
        antes = (ruta["cortes_en_osm"], len(ruta["geometria"]["coordinates"]))
        ruta["geometria"], ruta["cortes_en_osm"] = nueva["geometria"], nueva["cortes_en_osm"]
        if antes != (ruta["cortes_en_osm"], len(ruta["geometria"]["coordinates"])):
            print(f"   {ruta['_id']}: cortes {antes[0]} → {ruta['cortes_en_osm']}, "
                  f"vértices {antes[1]} → {len(ruta['geometria']['coordinates'])}")
    for ref in sorted(set(nuevas) - {r["_id"] for r in transcaribe["rutas"]}):
        print(f"   ℹ️ {ref}: está en OSM y no en Karta; no se agrega sola")
    transcaribe["atribucion"] = "Datos © colaboradores de OpenStreetMap (ODbL), descargados el " + time.strftime("%Y-%m-%d")
    with open(DATA_DIR / "transcaribe.json", "w", encoding="utf-8") as archivo:
        json.dump(transcaribe, archivo, ensure_ascii=False, separators=(",", ":"))


def main():
    if "--solo-integraciones" in sys.argv:
        return solo_estaciones_de_integracion()
    if "--solo-recorridos" in sys.argv:
        return solo_recorridos()
    if "--solo-lugares" in sys.argv:
        return solo_lugares()
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
