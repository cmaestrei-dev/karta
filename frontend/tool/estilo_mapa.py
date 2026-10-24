"""Genera el estilo de mapa «Bahía» (claro y oscuro) para las teselas vectoriales de OpenFreeMap.

Uso (desde frontend/): python3 tool/estilo_mapa.py
Escribe assets/mapa/bahia_oscuro.json y assets/mapa/bahia_claro.json (MapLibre Style Spec v8,
esquema OpenMapTiles). La idea del estilo: agua profunda, solo las vías que orientan y pocas etiquetas;
la troncal de Transcaribe y los reportes los dibuja la app encima, porque son lo importante.
"""
import json
from pathlib import Path

DESTINO = Path(__file__).resolve().parent.parent / "assets" / "mapa"

PALETAS = {
    "oscuro": {
        "tierra": "#101C28", "agua": "#0A2436", "parque": "#10231F", "edificio": "#15283A",
        "calle": "#172A3C", "via": "#1F3346", "principal": "#2A4560", "borde": None,
        "etiqueta": "#7F96AA", "barrio": "#9DB2C4", "etiqueta_agua": "#4F7C99", "halo": "#0B1621",
    },
    "claro": {
        "tierra": "#EDF1F3", "agua": "#BBD7E5", "parque": "#DCEBE1", "edificio": "#E2E8EC",
        "calle": "#FFFFFF", "via": "#FFFFFF", "principal": "#FFFFFF", "borde": "#CBD6DD",
        "etiqueta": "#6A7C8B", "barrio": "#4B5F70", "etiqueta_agua": "#4E7F9C", "halo": "#EDF1F3",
    },
}

FUENTE = "openmaptiles"
SIN_TUNELES = ["!", ["match", ["get", "brunnel"], ["tunnel"], True, False]]


def ancho(*paradas):
    """Ancho que crece con el zoom: ancho(12, 1, 18, 10) → 1 px en z12, 10 px en z18."""
    return ["interpolate", ["exponential", 1.5], ["zoom"], *paradas]


def clases(*nombres):
    return ["match", ["get", "class"], list(nombres), True, False]


def estilo(nombre, p):
    capas = [
        {"id": "fondo", "type": "background", "paint": {"background-color": p["tierra"]}},
        {"id": "parques", "type": "fill", "source": FUENTE, "source-layer": "park",
         "paint": {"fill-color": p["parque"], "fill-opacity": 0.8}},
        {"id": "verde", "type": "fill", "source": FUENTE, "source-layer": "landcover",
         "filter": clases("grass", "wood"), "paint": {"fill-color": p["parque"], "fill-opacity": 0.6}},
        {"id": "agua", "type": "fill", "source": FUENTE, "source-layer": "water",
         "filter": SIN_TUNELES, "paint": {"fill-color": p["agua"]}},
        {"id": "canales", "type": "line", "source": FUENTE, "source-layer": "waterway",
         "paint": {"line-color": p["agua"], "line-width": ancho(12, 0.5, 18, 4)}},
        {"id": "edificios", "type": "fill", "source": FUENTE, "source-layer": "building", "minzoom": 15,
         "paint": {"fill-color": p["edificio"], "fill-opacity": 0.7}},
    ]

    # (capa, filtro, color, ancho en el zoom mínimo, ancho en z18, zoom mínimo)
    vias = [
        ("calles", clases("minor", "service", "track"), p["calle"], 0.5, 7, 13),
        ("vias", clases("secondary", "tertiary"), p["via"], 0.8, 11, 11),
        ("principales", clases("primary", "trunk", "motorway"), p["principal"], 1, 14, 9),
    ]
    if p["borde"]:
        # En el tema claro las vías blancas necesitan un borde para separarse del suelo: 1 px por lado.
        for clave, filtro, _, desde, hasta, minzoom in vias:
            capas.append({"id": f"{clave}-borde", "type": "line", "source": FUENTE, "source-layer": "transportation",
                          "minzoom": minzoom, "filter": ["all", filtro, SIN_TUNELES],
                          "layout": {"line-cap": "round", "line-join": "round"},
                          "paint": {"line-color": p["borde"], "line-width": ancho(minzoom, desde + 1, 18, hasta + 2)}})
    for clave, filtro, color, desde, hasta, minzoom in vias:
        grosor = ancho(minzoom, desde, 18, hasta)
        capas.append({"id": clave, "type": "line", "source": FUENTE, "source-layer": "transportation",
                      "minzoom": minzoom, "filter": ["all", filtro, SIN_TUNELES],
                      "layout": {"line-cap": "round", "line-join": "round"},
                      "paint": {"line-color": color, "line-width": grosor}})

    etiqueta = {"text-color": p["etiqueta"], "text-halo-color": p["halo"], "text-halo-width": 1.5}
    capas += [
        {"id": "nombres-de-vias", "type": "symbol", "source": FUENTE, "source-layer": "transportation_name",
         "minzoom": 14, "filter": clases("primary", "secondary", "tertiary", "trunk"),
         "layout": {"symbol-placement": "line", "text-field": ["get", "name"], "text-font": ["Noto Sans Regular"],
                    "text-size": ["interpolate", ["linear"], ["zoom"], 14, 10, 18, 13]},
         "paint": etiqueta},
        {"id": "nombres-de-agua", "type": "symbol", "source": FUENTE, "source-layer": "water_name",
         "layout": {"text-field": ["get", "name"], "text-font": ["Noto Sans Italic"], "text-size": 12},
         "paint": {**etiqueta, "text-color": p["etiqueta_agua"]}},
        {"id": "barrios", "type": "symbol", "source": FUENTE, "source-layer": "place", "minzoom": 12,
         "filter": clases("suburb", "neighbourhood", "quarter"),
         "layout": {"text-field": ["get", "name"], "text-font": ["Noto Sans Bold"],
                    "text-size": ["interpolate", ["linear"], ["zoom"], 12, 10, 16, 13], "text-max-width": 8},
         "paint": {**etiqueta, "text-color": p["barrio"]}},
    ]

    return {
        "version": 8,
        "name": f"Karta Bahía ({nombre})",
        "sources": {FUENTE: {"type": "vector", "url": "https://tiles.openfreemap.org/planet",
                             "attribution": "© OpenFreeMap © colaboradores de OpenStreetMap"}},
        "glyphs": "https://tiles.openfreemap.org/fonts/{fontstack}/{range}.pbf",
        "layers": capas,
    }


if __name__ == "__main__":
    DESTINO.mkdir(parents=True, exist_ok=True)
    for nombre, paleta in PALETAS.items():
        ruta = DESTINO / f"bahia_{nombre}.json"
        ruta.write_text(json.dumps(estilo(nombre, paleta), ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
        print(f"escrito {ruta.relative_to(DESTINO.parent.parent)}")
