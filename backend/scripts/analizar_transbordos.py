"""
Analiza los transbordos que propone el planificador en toda la red: para cada alimentadora, orígenes a lo largo de
su recorrido (lejos de la troncal, donde de verdad hace falta cambiar de bus) y destinos en todas las estaciones
troncales. Compara las reglas de antes (cualquier punto a menos de 300 m, en línea recta) con las de ahora
(integraciones oficiales y el cruce de la avenida para entrar a una estación troncal).

Uso: python -m scripts.analizar_transbordos [--md docs/analisis-transbordos.md]
"""
import json
import statistics
import sys
from collections import Counter
from contextlib import contextmanager
from pathlib import Path

import numpy as np
from shapely.geometry import LineString, Point

from src.domain import trip_planning as tp
from src.domain.geo import a_grados, a_metros
from src.domain.models import Estacion, RutaTransporte

DATA = Path(__file__).resolve().parent.parent / "data"
SEPARACION_M = 1200         # un origen cada tanto sobre el recorrido de la alimentadora
# Destinos: las estaciones troncales a las que más se viaja, del Centro al oriente.
DESTINOS = {"centro", "la-bodeguita", "bazurto", "chambacu", "el-prado", "maria-auxiliadora", "los-ejecutivos"}
LEJOS_DE_LA_TRONCAL_M = 900  # más cerca de una estación troncal, se camina directo a ella


def cargar() -> tuple[list[RutaTransporte], list[Estacion]]:
    datos = json.loads((DATA / "transcaribe.json").read_text(encoding="utf-8"))
    rutas = [RutaTransporte(id=r["_id"], nombre=r["nombre"], tipo=r["tipo"], cortes_en_osm=r["cortes_en_osm"],
                            coordenadas=[tuple(c) for c in r["geometria"]["coordinates"]]) for r in datos["rutas"]]
    estaciones = [Estacion(id=e["_id"], nombre=e["nombre"], longitud=e["ubicacion"]["coordinates"][0],
                           latitud=e["ubicacion"]["coordinates"][1], rutas=e["rutas"]) for e in datos["estaciones"]]
    return rutas, estaciones


@contextmanager
def reglas_de_antes():
    """El planificador como estaba: sin integraciones, sin cruce de la avenida y la misma penalización siempre."""
    guardado = (tp.INTEGRACIONES, tp.CRUCE_A_ESTACION_MIN, tp.PENALIZACION_TRANSBORDO_INTEGRADO_MIN,
                tp.TRANSBORDO_EN_ESTACION_M, tp.SOLO_EN_ESTACIONES)
    tp.INTEGRACIONES, tp.CRUCE_A_ESTACION_MIN, tp.SOLO_EN_ESTACIONES = {}, 0, ("troncal",)
    tp.PENALIZACION_TRANSBORDO_INTEGRADO_MIN, tp.TRANSBORDO_EN_ESTACION_M = tp.PENALIZACION_TRANSBORDO_MIN, 0
    try:
        yield
    finally:
        (tp.INTEGRACIONES, tp.CRUCE_A_ESTACION_MIN, tp.PENALIZACION_TRANSBORDO_INTEGRADO_MIN,
         tp.TRANSBORDO_EN_ESTACION_M, tp.SOLO_EN_ESTACIONES) = guardado


def origenes(alimentadora: RutaTransporte, troncales: list[Estacion]) -> list[tuple[float, float]]:
    linea = a_metros(LineString(alimentadora.coordenadas))
    estaciones = [a_metros(Point(e.longitud, e.latitud)) for e in troncales]
    puntos = []
    for d in np.arange(SEPARACION_M / 2, linea.length, SEPARACION_M):
        p = linea.interpolate(d)
        if min(p.distance(e) for e in estaciones) > LEJOS_DE_LA_TRONCAL_M:
            puntos.append(tuple(a_grados(p).coords[0]))
    return puntos


def nombre_de_estacion(punto, ruta: RutaTransporte, estaciones: list[Estacion], radio_m: float = 80) -> str:
    """La estación de esa ruta donde se baja o se sube (Santa Lucía y Madre Bernarda están a 66 m)."""
    p = a_metros(Point(punto))
    propias = [e for e in estaciones if ruta.id in e.rutas]
    if not propias:
        return "un paradero"
    cerca = min(propias, key=lambda e: a_metros(Point(e.longitud, e.latitud)).distance(p))
    return cerca.nombre if a_metros(Point(cerca.longitud, cerca.latitud)).distance(p) <= radio_m else "un paradero"


def transbordo(opcion: tp.OpcionViaje, estaciones: list[Estacion]) -> dict | None:
    buses = [k for k, t in enumerate(opcion.tramos) if t.modo == "bus"]
    if len(buses) != 2:
        return None
    a, cambio, b = opcion.tramos[buses[0]], opcion.tramos[buses[0] + 1], opcion.tramos[buses[1]]
    return {
        "rutas": f"{a.ruta.id} → {b.ruta.id}",
        "baja": nombre_de_estacion(a.coordenadas[-1], a.ruta, estaciones),
        "sube": nombre_de_estacion(b.coordenadas[0], b.ruta, estaciones),
        "caminata_m": round(cambio.distancia_m),
        "minutos": round(opcion.tiempo_total_min),
        "integrado": cambio.integrado,
    }


def mejor(rutas, estaciones, origen, destino, muestras) -> tp.OpcionViaje | None:
    opciones = [o for o in tp.planificar(rutas, estaciones, origen, destino, muestras=muestras) if o.rutas]
    return min(opciones, key=tp.costo_percibido) if opciones else None


def main():
    rutas, estaciones = cargar()
    troncales = [e for e in estaciones if any(r.startswith(("T", "X")) for r in e.rutas)]
    destinos = [e for e in troncales if e.id in DESTINOS]
    sin_integraciones = [e for e in estaciones if e.id not in {"santa-lucia", "portal"}]
    confiables = [r for r in rutas if r.cortes_en_osm <= tp.MAX_CORTES_CONFIABLES]
    with reglas_de_antes():
        muestras_antes = [m for r in confiables if (m := tp.muestrear(r, sin_integraciones)) is not None]
    muestras_ahora = [m for r in confiables if (m := tp.muestrear(r, estaciones)) is not None]
    filas = []
    for alimentadora in [r for r in rutas if r.id.startswith("A") and r.cortes_en_osm <= tp.MAX_CORTES_CONFIABLES]:
        for origen in origenes(alimentadora, troncales):
            for destino in destinos:
                if a_metros(Point(origen)).distance(a_metros(Point(destino.longitud, destino.latitud))) < 2500:
                    continue
                with reglas_de_antes():
                    antes = mejor(rutas, sin_integraciones, origen, (destino.longitud, destino.latitud), muestras_antes)
                ahora = mejor(rutas, estaciones, origen, (destino.longitud, destino.latitud), muestras_ahora)
                filas.append((alimentadora.id, destino.nombre, antes, ahora))

    def resumen(opciones):
        cambios = [t for _, _, o in opciones if o and (t := transbordo(o, estaciones))]
        caminatas = [t["caminata_m"] for t in cambios]
        return cambios, caminatas

    cambios_antes, caminatas_antes = resumen([(a, d, x) for a, d, x, _ in filas])
    cambios_ahora, caminatas_ahora = resumen([(a, d, y) for a, d, _, y in filas])
    distintos = [(a, d, transbordo(x, estaciones), transbordo(y, estaciones)) for a, d, x, y in filas
                 if x and y and transbordo(x, estaciones) and transbordo(y, estaciones)
                 and (transbordo(x, estaciones)["baja"], transbordo(x, estaciones)["sube"])
                 != (transbordo(y, estaciones)["baja"], transbordo(y, estaciones)["sube"])]

    lineas = [
        "# Transbordos en toda la red: antes y ahora",
        "",
        "> Generado con `python -m scripts.analizar_transbordos --md ../docs/analisis-transbordos.md` (backend). "
        "**Antes:** cualquier punto a menos de 300 m servía para cambiar de bus, la caminata era la línea recta "
        "con un 30 % de rodeo y las rutas X se podían tomar en cualquier punto de la avenida. **Ahora:** "
        "Santa Lucía ↔ Madre Bernarda (40 m por la cebra) y el Patio Portal son transbordos integrados, entrar "
        "desde la calle a una estación troncal cuesta 2 minutos por cruzar la avenida, y sobre la troncal las X "
        "solo paran en estaciones.",
        "",
        f"Viajes simulados: **{len(filas)}** (cada alimentadora con estado confiable en OSM, un origen cada "
        f"{SEPARACION_M} m de su recorrido a más de {LEJOS_DE_LA_TRONCAL_M} m de la troncal, hacia cada estación "
        "troncal a más de 2,5 km). Salida en día hábil, todas las rutas en servicio.",
        "",
        "| | Antes | Ahora |",
        "|---|---|---|",
        f"| Viajes con transbordo | {len(cambios_antes)} | {len(cambios_ahora)} |",
        f"| Caminata del transbordo, mediana | {statistics.median(caminatas_antes):.0f} m | {statistics.median(caminatas_ahora):.0f} m |",
        f"| Caminata del transbordo, percentil 90 | {np.percentile(caminatas_antes, 90):.0f} m | {np.percentile(caminatas_ahora, 90):.0f} m |",
        f"| Transbordos integrados (misma estación o Santa Lucía ↔ Madre Bernarda) | — | {sum(t['integrado'] for t in cambios_ahora)} |",
        f"| Transbordos de más de 200 m caminando | {sum(c > 200 for c in caminatas_antes)} | {sum(c > 200 for c in caminatas_ahora)} |",
        f"| Tiempo total, mediana (viajes con transbordo) | {statistics.median(t['minutos'] for t in cambios_antes):.0f} min | {statistics.median(t['minutos'] for t in cambios_ahora):.0f} min |",
        f"| Donde el cambio es en otro lugar: minutos de más (mediana) | — | {statistics.median(y['minutos'] - x['minutos'] for _, _, x, y in distintos) if distintos else 0:+.0f} min |",
        "",
        "## Dónde se cambia de bus",
        "",
        "| Bajarse en → subirse en | Antes | Ahora |",
        "|---|---|---|",
    ]
    lugar = lambda t: f"{t['baja']} → {t['sube']}"
    antes_c, ahora_c = Counter(map(lugar, cambios_antes)), Counter(map(lugar, cambios_ahora))
    for clave in sorted(set(antes_c) | set(ahora_c), key=lambda k: -(ahora_c[k] + antes_c[k]))[:15]:
        lineas.append(f"| {clave} | {antes_c[clave]} | {ahora_c[clave]} |")
    lineas += ["", f"## Viajes en los que cambió el lugar del transbordo ({len(distintos)})", "",
               "| Alimentadora → destino | Antes | Ahora |", "|---|---|---|"]
    for a, d, x, y in distintos[:25]:
        lineas.append(f"| {a} → {d} | {x['rutas']}: {lugar(x)}, {x['caminata_m']} m, {x['minutos']} min "
                      f"| {y['rutas']}: {lugar(y)}, {y['caminata_m']} m, {y['minutos']} min |")
    texto = "\n".join(lineas) + "\n"
    if "--md" in sys.argv:
        Path(sys.argv[sys.argv.index("--md") + 1]).write_text(texto, encoding="utf-8")
    print(texto)


if __name__ == "__main__":
    main()
