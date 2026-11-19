"""
Importa el GTFS oficial del SITM Transcaribe: los paraderos de cada ruta, con sus coordenadas, y los horarios.

Fuente: «GTFS SITM.zip», que Transcaribe S.A. entregó el 18 de noviembre de 2026 con el Oficio TC-DO-07.01-01821-26
(respuesta al derecho de petición 3565-10-2026). Va del 1 de enero al 31 de diciembre de 2026 y trae 24 rutas en 45
recorridos, 602 paradas con coordenadas y cada viaje del día con sus horas.

Qué se toma:
- Paraderos: todos, en el orden de su recorrido y en el punto oficial. En las estaciones, el nombre trae el módulo
  («Bazurto A2»): la letra es el vagón y el número el sentido (1 hacia el Centro, 2 hacia el Portal). Los demás quedan
  con precisión `oficial`.
- Horarios: el primer y el último despacho de cada ruta. El GTFS trae un solo horario para todos los días en que opera
  la ruta: no distingue el sábado ni el domingo, y no trae festivos (falta calendar_dates.txt). Así que de lunes a
  viernes vale el GTFS; el sábado y el domingo, el GTFS dice si la ruta opera y el archivo de 2025 a qué horas, hasta
  que Transcaribe lo aclare (se le preguntó el 18 de noviembre). Se guardan también las salidas por hora entre semana.
- Qué rutas paran en cada estación: se suman a las de OpenStreetMap en transcaribe.json (el GTFS pone, por ejemplo,
  las X101, X104, X105 y X106 en La Bodeguita). Si se vuelve a correr importar_osm, hay que volver a correr este.

Qué no se toma:
- Los trazados: coinciden con los de OpenStreetMap, que Karta ya usa (ODbL), a 2 m en promedio. El informe los compara.
- Las variantes: si una ruta tiene dos recorridos en el mismo sentido (la extensión del X106), se usa el de más viajes.

Uso (desde backend/):
    python -m scripts.importar_gtfs RUTA_AL_GTFS [--salida CARPETA] [--informe ARCHIVO.md]
RUTA_AL_GTFS es el .zip o la carpeta descomprimida. --salida: dónde escribir paraderos.json, horarios.json y
transcaribe.json (por defecto, data/). --informe: compara con los datos actuales de data/ y lo escribe en Markdown.
"""
import argparse
import csv
import io
import json
import re
import statistics
import zipfile
from collections import Counter, defaultdict
from dataclasses import dataclass
from datetime import date
from pathlib import Path

from shapely.geometry import LineString, Point

from src.domain.geo import a_metros, distancia_m
from src.domain.texto import normalizar, tokens

DATA = Path(__file__).resolve().parent.parent / "data"
ARCHIVOS = ("routes.txt", "trips.txt", "stops.txt", "stop_times.txt", "calendar.txt", "shapes.txt")
DIAS_GTFS = ("monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday")
# El día del GTFS que representa a cada tipo de día de Karta (src/domain/horarios.py).
DIA_REPRESENTATIVO = {"lunes_a_viernes": "monday", "sabado": "saturday", "domingo_y_festivos": "sunday"}

# Nombres del GTFS que no coinciden con el de la estación en Karta («Desc»: donde se bajan los de la alimentadora).
ALIAS_DE_ESTACION = {"patio portal": "portal", "delicias": "las-delicias", "transferencia santa lucia": "santa-lucia",
                     "transferencia santa lucia desc": "santa-lucia"}
# Cómo leer los extremos del nombre del recorrido («Ida - portal - u. tecnologica») después de «hacia».
LEGIBLE = {"portal": "el Portal", "patio portal": "el Portal", "centro": "el Centro", "u. tecnologica": "UTB",
           "pozon": "el Pozón", "terminal": "la Terminal de Transportes", "terminal de transporte": "la Terminal",
           "simon bolivar": "Simón Bolívar", "santa lucia": "Santa Lucía", "bodeguita": "La Bodeguita",
           "c. luque": "Carlos Luque", "13 junio": "13 de Junio"}
LEGIBLE_DE_ESTACION = {"portal": "el Portal", "santa-lucia": "Santa Lucía", "la-bodeguita": "el Centro",
                       "centro": "el Centro"}
LEJOS_DEL_RECORRIDO_M = 50


@dataclass(frozen=True)
class Recorrido:
    """Un recorrido del GTFS (una fila de routes.txt): una ruta de Karta en un sentido."""
    ruta: str                  # «X103»
    sentido: str               # ida | vuelta | circular
    nombre: str                # «Ida - portal - centro»
    paradas: tuple[dict, ...]  # filas de stops.txt, en el orden del viaje más común
    salidas: tuple[tuple[str, int], ...]  # (service_id, minutos desde la medianoche) en la primera parada, por viaje
    forma: str | None          # shape_id


# ----------------------------------------------------------------------------------------------------- lectura

def leer(origen: Path) -> dict[str, list[dict]]:
    """Las tablas del GTFS, del .zip o de la carpeta. Las que falten quedan vacías."""
    tablas = {}
    if origen.is_dir():
        for nombre in ARCHIVOS:
            ruta = origen / nombre
            tablas[nombre] = list(csv.DictReader(open(ruta, encoding="utf-8-sig"))) if ruta.exists() else []
        return tablas
    with zipfile.ZipFile(origen) as z:
        por_nombre = {Path(n).name: n for n in z.namelist()}
        for nombre in ARCHIVOS:
            if nombre in por_nombre:
                texto = z.read(por_nombre[nombre]).decode("utf-8-sig")
                tablas[nombre] = list(csv.DictReader(io.StringIO(texto)))
            else:
                tablas[nombre] = []
    return tablas


def sentido_de(nombre: str, letrero: str = "") -> str | None:
    """«Ida - portal - centro» → ida; «Circular bodeguita - zona norte» → circular. Si el nombre no lo dice
    («Extensión»), el letrero del viaje: Ida, Volta (sic) o Unico."""
    for texto in (normalizar(nombre), normalizar(letrero)):
        if texto.startswith("ida"):
            return "ida"
        if texto.startswith(("vuelta", "volta")):
            return "vuelta"
        if texto.startswith(("circular", "unico")):
            return "circular"
    return None


def _minutos(hora: str) -> int:
    h, m, *_ = (int(x) for x in hora.strip().split(":"))
    return h * 60 + m


def recorridos(gtfs: dict[str, list[dict]]) -> tuple[list[Recorrido], list[str]]:
    """Los recorridos de cada ruta y sentido, y los que se dejaron fuera (variantes y los que no se entienden)."""
    paradas = {p["stop_id"]: p for p in gtfs["stops.txt"]}
    horas = defaultdict(list)
    for f in gtfs["stop_times.txt"]:
        horas[f["trip_id"]].append((int(f["stop_sequence"]), f["stop_id"], f["departure_time"] or f["arrival_time"]))
    viajes = defaultdict(list)
    for v in gtfs["trips.txt"]:
        viajes[v["route_id"]].append(v)

    candidatos, omitidos = defaultdict(list), []
    for r in gtfs["routes.txt"]:
        propios = [v for v in viajes[r["route_id"]] if horas[v["trip_id"]]]
        if not propios:
            omitidos.append(f"{r['route_short_name']} «{r['route_long_name']}»: sin viajes")
            continue
        sentido = sentido_de(r["route_long_name"], propios[0]["trip_headsign"])
        if sentido is None:
            omitidos.append(f"{r['route_short_name']} «{r['route_long_name']}»: no se sabe el sentido")
            continue
        secuencias = Counter(tuple(s for _, s, _ in sorted(horas[v["trip_id"]])) for v in propios)
        secuencia = secuencias.most_common(1)[0][0]
        salidas = tuple((v["service_id"], _minutos(min(horas[v["trip_id"]])[2])) for v in propios)
        formas = Counter(v["shape_id"] for v in propios if v["shape_id"])
        candidatos[(r["route_short_name"].strip(), sentido)].append(Recorrido(
            ruta=r["route_short_name"].strip(), sentido=sentido, nombre=r["route_long_name"].strip(),
            paradas=tuple(paradas[s] for s in secuencia), salidas=salidas,
            forma=formas.most_common(1)[0][0] if formas else None))

    elegidos = []
    for (ruta, sentido), opciones in candidatos.items():
        opciones.sort(key=lambda o: len(o.salidas), reverse=True)
        elegidos.append(opciones[0])
        omitidos += [f"{ruta} «{o.nombre}»: variante de la {sentido}, con {len(o.salidas)} viajes "
                     f"(se usa «{opciones[0].nombre}», con {len(opciones[0].salidas)})" for o in opciones[1:]]
    return sorted(elegidos, key=lambda o: (o.ruta, o.sentido)), omitidos


# --------------------------------------------------------------------------------------------------- paraderos

def estacion_y_modulo(nombre: str, estaciones: dict[str, dict]) -> tuple[str, str | None] | None:
    """«Bazurto A2» → («bazurto», «A2»); «Transferencia Santa Lucia Desc» → («santa-lucia», None). None si no es una
    estación de Karta («Antiguo telecom- D1» parece un módulo y no lo es)."""
    m = re.match(r"^(.*?)\s+([A-D]\d)$", nombre.strip())
    for base, modulo in ([(m.group(1), m.group(2))] if m else []) + [(nombre, None)]:
        clave = normalizar(base)
        ident = ALIAS_DE_ESTACION.get(clave) or next(
            (i for i, e in estaciones.items() if normalizar(e["nombre"]) == clave), None)
        if ident is not None:
            return ident, modulo
    return None


def _nombre(texto: str) -> str:
    return re.sub(r"\s+", " ", texto).strip().rstrip(".").strip()


def _punto(parada: dict) -> tuple[float, float]:
    return round(float(parada["stop_lon"]), 6), round(float(parada["stop_lat"]), 6)


def paraderos(elegidos: list[Recorrido], estaciones: dict[str, dict]) -> list[dict]:
    salida = []
    for r in elegidos:
        for orden, p in enumerate(r.paradas, start=1):
            nombre = _nombre(p["stop_name"])
            estacion, modulo = estacion_y_modulo(nombre, estaciones) or (None, None)
            salida.append({
                "_id": f"{r.ruta}-{r.sentido}-{orden:02d}", "ruta": r.ruta, "sentido": r.sentido, "orden": orden,
                "nombre": nombre, "estacion": estacion, "modulo": modulo,
                "precision": "estacion" if estacion else "oficial",
                "ubicacion": {"type": "Point", "coordinates": list(_punto(p))},
            })
    return salida


def _legible(extremo: str) -> str:
    clave = normalizar(extremo).strip()
    if clave in LEGIBLE:
        return LEGIBLE[clave]
    menores = ("de", "del", "la", "las", "el", "los", "y")  # en minúscula, salvo al principio
    return " ".join(w.lower() if k and w.lower() in menores else w[:1].upper() + w[1:]
                    for k, w in enumerate(extremo.strip().split()))


def hacia(r: Recorrido, estaciones: dict[str, dict]) -> str | None:
    """
    Hacia dónde va el recorrido («hacia el Centro»). El nombre no siempre va en el orden del viaje («Vuelta - portal -
    centro» sale del Centro, y la A105 de vuelta, «simon bolivar - socorro - portal», termina en Santa Lucía). En orden:
    1. si el último paradero es uno de los extremos del nombre, hacia ese;
    2. si es una estación, hacia ella (las de La Bodeguita y el Centro son «el Centro»);
    3. si el primero es uno de los extremos, hacia el otro; en la ida, hacia el último extremo;
    4. si no, hacia el último paradero.
    Los circulares no van «hacia» ningún lado.
    """
    if r.sentido == "circular":
        return None
    nombre = re.sub(r"^\s*(ida|vuelta|circular)\s*-?\s*", "", r.nombre, flags=re.I)
    extremos = [x.strip() for x in nombre.split(" - ") if x.strip()]
    primero, ultimo = set(tokens(r.paradas[0]["stop_name"])), set(tokens(r.paradas[-1]["stop_name"]))
    es = lambda extremo, parada: set(tokens(extremo)) <= parada
    if len(extremos) >= 2:
        for extremo in (extremos[-1], extremos[0]):
            if es(extremo, ultimo):
                return _legible(extremo)
    if (estacion := estacion_y_modulo(_nombre(r.paradas[-1]["stop_name"]), estaciones)) is not None:
        ident = estacion[0]
        return LEGIBLE_DE_ESTACION.get(ident) or estaciones[ident]["nombre"]
    if len(extremos) >= 2:
        if es(extremos[0], primero) or r.sentido == "ida":
            return _legible(extremos[-1])
        if es(extremos[-1], primero):
            return _legible(extremos[0])
    return _legible(_nombre(r.paradas[-1]["stop_name"]))


# ---------------------------------------------------------------------------------------------------- horarios

def _hora(minutos: int) -> str:
    """Las horas del GTFS pueden pasar de las 24:00 (un viaje que sigue después de la medianoche)."""
    minutos = min(minutos, 23 * 60 + 59)
    return f"{minutos // 60:02d}:{minutos % 60:02d}"


def horarios(elegidos: list[Recorrido], calendario: list[dict], horarios_2025: dict[str, dict]) -> list[dict]:
    opera = {c["service_id"]: {d for d in DIAS_GTFS if c.get(d) == "1"} for c in calendario}
    por_ruta = defaultdict(list)
    for r in elegidos:
        por_ruta[r.ruta].append(r)
    salida = []
    for ruta, suyos in sorted(por_ruta.items()):
        documento = {"_id": ruta}
        for tipo, dia in DIA_REPRESENTATIVO.items():
            minutos = [m for r in suyos for servicio, m in r.salidas if dia in opera.get(servicio, set())]
            if not minutos:
                documento[tipo] = None
            elif tipo != "lunes_a_viernes" and (horarios_2025.get(ruta) or {}).get(tipo):
                documento[tipo] = horarios_2025[ruta][tipo]  # opera ese día; a qué horas lo dice el archivo de 2025
            else:
                documento[tipo] = [_hora(min(minutos)), _hora(max(minutos))]
        por_hora = {}
        for r in suyos:
            cuenta = [0] * 24
            for servicio, m in r.salidas:
                if "monday" in opera.get(servicio, set()):
                    cuenta[min(m // 60, 23)] += 1
            por_hora[r.sentido] = cuenta
        documento["salidas_por_hora"] = por_hora
        salida.append(documento)
    return salida


def vigencia(calendario: list[dict]) -> tuple[date, date] | None:
    fechas = [(c["start_date"], c["end_date"]) for c in calendario if c.get("start_date") and c.get("end_date")]
    if not fechas:
        return None
    leer_fecha = lambda t: date(int(t[:4]), int(t[4:6]), int(t[6:8]))
    return leer_fecha(min(f[0] for f in fechas)), leer_fecha(max(f[1] for f in fechas))


def con_rutas_del_gtfs(transcaribe: dict, nuevos: list[dict], fuente: str) -> tuple[dict, dict[str, list[str]]]:
    """transcaribe.json con las rutas que, según el GTFS, paran en cada estación y OSM no tenía (recorridos y lo demás,
    igual). Devuelve también las que se sumaron, por estación."""
    paran = defaultdict(set)
    for p in nuevos:
        if p["estacion"]:
            paran[p["estacion"]].add(p["ruta"])
    sumadas, estaciones = {}, []
    for e in transcaribe["estaciones"]:
        nuevas = sorted(paran[e["_id"]] - set(e["rutas"]))
        if nuevas:
            sumadas[e["_id"]] = nuevas
        estaciones.append({**e, "rutas": e["rutas"] + nuevas})
    atribucion = transcaribe["atribucion"].split(". Rutas que paran en cada estación:")[0]
    return {**transcaribe, "atribucion": f"{atribucion}. Rutas que paran en cada estación: también {fuente}",
            "estaciones": estaciones}, sumadas


# ----------------------------------------------------------------------------------------------------- informe

def _lista(rutas) -> str:
    return ", ".join(sorted(rutas)) or "ninguna"


def _cifras(errores: list[float]) -> str:
    errores = sorted(errores)
    return (f"{len(errores)} | {statistics.median(errores):.0f} m | {errores[int(len(errores) * .8)]:.0f} m | "
            f"{errores[-1]:.0f} m")


def informe(elegidos: list[Recorrido], omitidos: list[str], nuevos: list[dict], hacia_nuevo: dict[str, str],
            nuevos_horarios: list[dict], gtfs: dict[str, list[dict]], datos: Path) -> str:
    """Compara lo importado con los datos actuales de Karta, en Markdown."""
    transcaribe = json.loads((datos / "transcaribe.json").read_text(encoding="utf-8"))
    viejos = json.loads((datos / "paraderos.json").read_text(encoding="utf-8"))
    horarios_viejos = {h["_id"]: h
                       for h in json.loads((datos / "horarios.json").read_text(encoding="utf-8"))["horarios"]}
    lineas_osm = {r["_id"]: a_metros(LineString(r["geometria"]["coordinates"])) for r in transcaribe["rutas"]}
    estaciones = {e["_id"]: e for e in transcaribe["estaciones"]}
    l = ["# Importación del GTFS de Transcaribe", ""]

    # Resumen
    rutas_gtfs = {r.ruta for r in elegidos}
    ubicados_antes = sum("ubicacion" in p for p in viejos["paraderos"])
    l += ["## Resumen", "",
          f"- **Recorridos:** {len(elegidos)} de {len(rutas_gtfs)} rutas.",
          f"- **Paraderos:** {len(nuevos)}, todos con coordenadas oficiales "
          f"({sum(p['precision'] == 'estacion' for p in nuevos)} en estaciones). Antes, {ubicados_antes} ubicados "
          f"de {len(viejos['paraderos'])}.",
          f"- **Rutas de Karta que no están en el GTFS:** {_lista(set(lineas_osm) - rutas_gtfs)}.",
          f"- **Rutas del GTFS que no están en Karta:** {_lista(rutas_gtfs - set(lineas_osm))}."]
    if omitidos:
        l += ["- **Fuera de la importación:**"] + [f"  - {o}" for o in omitidos]
    l.append("")

    # Paraderos por sentido
    contar = lambda lista: Counter((p["ruta"], p["sentido"]) for p in lista)
    antes, ahora = contar(viejos["paraderos"]), contar(nuevos)
    l += ["## Paraderos por ruta y sentido", "", "| Ruta | Sentido | Archivo 2025 | GTFS | Hacia (antes → ahora) |",
          "|---|---|---|---|---|"]
    for clave in sorted(set(antes) | set(ahora)):
        k = f"{clave[0]}-{clave[1]}"
        h_antes, h_ahora = viejos["hacia"].get(k), hacia_nuevo.get(k)
        cambio = h_ahora if h_antes == h_ahora else f"{h_antes or '—'} → {h_ahora or '—'}"
        l.append(f"| {clave[0]} | {clave[1]} | {antes.get(clave, 0)} | {ahora.get(clave, 0)} | {cambio or '—'} |")
    l.append("")

    # Precisión de lo que Karta ya ubicaba
    por_nombre = {(p["ruta"], p["sentido"], normalizar(p["nombre"])): p for p in nuevos}
    errores, lejanos = defaultdict(list), []
    for p in viejos["paraderos"]:
        n = por_nombre.get((p["ruta"], p["sentido"], normalizar(p["nombre"])))
        if n is None or "ubicacion" not in p:
            continue
        d = distancia_m(p["ubicacion"]["coordinates"], n["ubicacion"]["coordinates"])
        errores[p["precision"]].append(d)
        if d > 150:
            lejanos.append((d, p))
    l += ["## Qué tan lejos estaban los paraderos que Karta ya ubicaba", "",
          "Emparejados por ruta, sentido y nombre.", "", "| Cómo se ubicó | Paraderos | Mediana | P80 | Máximo |",
          "|---|---|---|---|---|"]
    l += [f"| {precision} | {_cifras(e)} |" for precision, e in sorted(errores.items())]
    if lejanos:
        l += ["", "A más de 150 m:", ""]
        l += [f"- {p['_id']} «{p['nombre']}» ({p['precision']}): {d:.0f} m"
              for d, p in sorted(lejanos, key=lambda x: -x[0])]
    l.append("")

    # Paraderos lejos del recorrido de OSM
    lejos = []
    for p in nuevos:
        linea = lineas_osm.get(p["ruta"])
        if linea is not None:
            d = linea.distance(a_metros(Point(p["ubicacion"]["coordinates"])))
            if d > LEJOS_DEL_RECORRIDO_M:
                lejos.append((d, p))
    l += [f"## Paraderos a más de {LEJOS_DEL_RECORRIDO_M} m del recorrido de OpenStreetMap", ""]
    l += [f"- {p['_id']} «{p['nombre']}»: {d:.0f} m" for d, p in sorted(lejos, key=lambda x: -x[0])] or ["Ninguno."]
    l.append("")

    # Estaciones: qué rutas paran y dónde quedan los módulos
    paran, modulos = defaultdict(set), defaultdict(dict)
    for p in nuevos:
        if p["estacion"]:
            paran[p["estacion"]].add(p["ruta"])
            if p["modulo"]:
                modulos[p["estacion"]][p["modulo"]] = tuple(p["ubicacion"]["coordinates"])
    l += ["## Estaciones", "",
          "| Estación | Rutas en Karta que no paran según el GTFS | Rutas que paran y Karta no tiene | "
          "Punto de Karta al centro de los módulos |", "|---|---|---|---|"]
    for ident, e in sorted(estaciones.items()):
        sobran = sorted(set(e["rutas"]) - paran[ident])
        faltan = sorted(paran[ident] - set(e["rutas"]))
        puntos = list(modulos[ident].values())
        centro = (sum(x for x, _ in puntos) / len(puntos), sum(y for _, y in puntos) / len(puntos)) if puntos else None
        lejania = f"{distancia_m(e['ubicacion']['coordinates'], centro):.0f} m" if centro else "—"
        l.append(f"| {e['nombre']} | {', '.join(sobran) or '—'} | {', '.join(faltan) or '—'} | {lejania} |")
    l.append("")

    # Vagones: cuál queda hacia el Centro (D18)
    l += ["## Vagones de las estaciones dobles", "",
          "El vagón más cerca de la estación siguiente en la ida (hacia el Centro) es el extremo hacia el Centro; si la "
          "estación es la última de la ida, el más cerca de la anterior es el extremo hacia el Portal.", ""]
    for ident, mods in sorted(modulos.items()):
        letras = {m[0] for m in mods}
        if not {"A", "B"} <= letras or ident == "portal":
            continue
        centro_de = lambda letra: [sum(c) / len(c) for c in zip(*(v for m, v in mods.items() if m[0] == letra))]
        a, b = centro_de("A"), centro_de("B")
        votos = Counter()
        for r in elegidos:
            if r.sentido != "ida":
                continue
            en_ruta = [p for p in nuevos if p["ruta"] == r.ruta and p["sentido"] == "ida" and p["estacion"]]
            for i, p in enumerate(en_ruta):
                if p["estacion"] != ident:
                    continue
                siguiente = next((q for q in en_ruta[i + 1:] if q["estacion"] != ident), None)
                anterior = next((q for q in reversed(en_ruta[:i]) if q["estacion"] != ident), None)
                if siguiente:
                    s = siguiente["ubicacion"]["coordinates"]
                    votos["A" if distancia_m(a, s) < distancia_m(b, s) else "B"] += 1
                elif anterior:
                    s = anterior["ubicacion"]["coordinates"]
                    votos["B" if distancia_m(a, s) < distancia_m(b, s) else "A"] += 1
        if votos:
            letra, n = votos.most_common(1)[0]
            l.append(f"- **{estaciones[ident]['nombre']}:** el vagón {letra} queda hacia el Centro "
                     f"({n} de {sum(votos.values())} recorridos de ida; vagones a {distancia_m(a, b):.0f} m).")
    l.append("")

    # Horarios
    l += ["## Horarios", "", "De lunes a viernes, el GTFS. Sábado y domingo: si opera, según el GTFS; a qué horas, "
          "según el archivo de 2025.", "", "| Ruta | L-V 2025 | L-V GTFS | Sábado 2025 → ahora | Domingo 2025 → ahora |",
          "|---|---|---|---|---|"]
    texto = lambda f: "–".join(f) if f else "no opera"
    for h in nuevos_horarios:
        v = horarios_viejos.get(h["_id"], {})
        dia = lambda tipo: texto(v.get(tipo)) if v.get(tipo) == h[tipo] else f"{texto(v.get(tipo))} → {texto(h[tipo])}"
        l.append(f"| {h['_id']} | {texto(v.get('lunes_a_viernes')) if v else 'sin datos'} | "
                 f"{texto(h['lunes_a_viernes'])} | {dia('sabado')} | {dia('domingo_y_festivos')} |")
    l.append("")

    # Trazados: por qué no se importan
    puntos_de_forma = defaultdict(list)
    for f in gtfs["shapes.txt"]:
        puntos_de_forma[f["shape_id"]].append((int(f["shape_pt_sequence"]), float(f["shape_pt_lon"]),
                                               float(f["shape_pt_lat"])))
    l += ["## Trazados del GTFS frente a los de OpenStreetMap", "",
          "Distancia de un punto cada 50 m del trazado del GTFS a la línea de OSM de la misma ruta.", "",
          "| Ruta | Sentido | Largo | Distancia media | A más de 60 m |", "|---|---|---|---|---|"]
    for r in elegidos:
        if not r.forma or r.forma not in puntos_de_forma or r.ruta not in lineas_osm:
            continue
        forma = a_metros(LineString([(x, y) for _, x, y in sorted(puntos_de_forma[r.forma])]))
        distancias = [lineas_osm[r.ruta].distance(forma.interpolate(d)) for d in range(0, int(forma.length), 50)]
        if distancias:
            l.append(f"| {r.ruta} | {r.sentido} | {forma.length / 1000:.1f} km | "
                     f"{statistics.mean(distancias):.0f} m | {sum(d > 60 for d in distancias) / len(distancias):.0%} |")
    return "\n".join(l) + "\n"


# --------------------------------------------------------------------------------------------------------- todo

def importar(origen: Path, datos: Path = DATA) -> dict:
    """Lee el GTFS y arma los archivos de Karta (y lo necesario para el informe)."""
    gtfs = leer(origen)
    elegidos, omitidos = recorridos(gtfs)
    transcaribe = json.loads((datos / "transcaribe.json").read_text(encoding="utf-8"))
    estaciones = {e["_id"]: e for e in transcaribe["estaciones"]}
    horarios_2025 = {h["_id"]: h for h in json.loads((datos / "horarios.json").read_text(encoding="utf-8"))["horarios"]}
    nuevos = paraderos(elegidos, estaciones)
    hacia_nuevo = {f"{r.ruta}-{r.sentido}": h for r in elegidos if (h := hacia(r, estaciones))}
    nuevos_horarios = horarios(elegidos, gtfs["calendar.txt"], horarios_2025)
    periodo = vigencia(gtfs["calendar.txt"])
    fuente = "Transcaribe S.A., GTFS del SITM" + (
        f" (vigente del {periodo[0]:%d/%m/%Y} al {periodo[1]:%d/%m/%Y})" if periodo else "")
    transcaribe, sumadas = con_rutas_del_gtfs(transcaribe, nuevos, fuente)
    return {"gtfs": gtfs, "elegidos": elegidos, "omitidos": omitidos, "paraderos": nuevos, "hacia": hacia_nuevo,
            "horarios": nuevos_horarios, "fuente": fuente, "transcaribe": transcaribe, "sumadas": sumadas}


def main():
    argumentos = argparse.ArgumentParser(description=__doc__.split("\n\n")[0].strip())
    argumentos.add_argument("gtfs", type=Path, help="el .zip del GTFS o la carpeta descomprimida")
    argumentos.add_argument("--salida", type=Path, default=DATA,
                            help="dónde escribir paraderos.json, horarios.json y transcaribe.json")
    argumentos.add_argument("--informe", type=Path, help="escribe aquí la comparación con los datos actuales (Markdown)")
    a = argumentos.parse_args()

    r = importar(a.gtfs)
    a.salida.mkdir(parents=True, exist_ok=True)
    if a.informe:  # antes de escribir, por si --salida es data/: se compara con lo que había
        a.informe.write_text(informe(r["elegidos"], r["omitidos"], r["paraderos"], r["hacia"], r["horarios"],
                                     r["gtfs"], DATA), encoding="utf-8")
    (a.salida / "paraderos.json").write_text(json.dumps({
        "hacia": r["hacia"], "atribucion": f"Paraderos: {r['fuente']}.", "paraderos": r["paraderos"]},
        ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    (a.salida / "horarios.json").write_text(json.dumps({
        "atribucion": f"Horarios: {r['fuente']}. Los de sábados, domingos y festivos: «Rutas_Transcaribe 2025», "
                      "Transcaribe S.A., Portal de Datos Abiertos de Cartagena (CC-BY 4.0).",
        "horarios": r["horarios"]}, ensure_ascii=False, indent=1), encoding="utf-8")
    (a.salida / "transcaribe.json").write_text(json.dumps(r["transcaribe"], ensure_ascii=False, separators=(",", ":")),
                                               encoding="utf-8")
    print(f"✅ {len(r['elegidos'])} recorridos, {len(r['paraderos'])} paraderos y {len(r['horarios'])} horarios "
          f"en {a.salida}" + (f"; informe en {a.informe}" if a.informe else ""))
    for estacion, rutas in r["sumadas"].items():
        print(f"   en {estacion} también paran: {', '.join(rutas)}")
    for o in r["omitidos"]:
        print(f"   fuera: {o}")


if __name__ == "__main__":
    main()
