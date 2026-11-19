"""
Dibuja las 19 láminas del álbum de estaciones (docs/plan-juego.md) en assets/album/<id>.svg.

Mismo estilo que las ilustraciones de los reportes: formas planas con contorno oscuro (#10202E) y los colores del
sistema «Bahía». Cada lámina es una escena de 160 × 110 con algo reconocible del sitio y, al pie, el carril de la
troncal. Solo usa lo que flutter_svg dibuja bien: rect, circle, ellipse, path y polygon, sin filtros ni degradados.

Uso (desde frontend/): python3 tool/dibujar_album.py
"""
from pathlib import Path

ANCHO, ALTO = 160, 110
TINTA = "#10202E"
AGUA, TURQUESA, CIELO_NOCHE = "#3DDBB5", "#2EC4B6", "#13283E"
AMARILLO, CORAL, AZUL, AZUL_CLARO = "#FFC247", "#FF7A6B", "#2F5BD3", "#7FA8FF"
CREMA, BLANCO, MURALLA = "#FFF6C7", "#E8F7FF", "#C98A4B"
TRONCAL, PRETRONCAL, ALIMENTADORA = "#0B6E6E", "#A61E5A", "#7A4A1C"
VERDE, VERDE_OSCURO = "#4BE38B", "#0E3B2E"

SALIDA = Path(__file__).resolve().parent.parent / "assets" / "album"


def rect(x, y, w, h, color, rx=0, borde=True, ancho=2):
    contorno = f' stroke="{TINTA}" stroke-width="{ancho}"' if borde else ""
    return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{rx}" fill="{color}"{contorno}/>'


def circulo(cx, cy, r, color, borde=True, ancho=2):
    contorno = f' stroke="{TINTA}" stroke-width="{ancho}"' if borde else ""
    return f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="{color}"{contorno}/>'


def camino(d, color, borde=True, ancho=2):
    contorno = f' stroke="{TINTA}" stroke-width="{ancho}" stroke-linejoin="round"' if borde else ""
    return f'<path d="{d}" fill="{color}"{contorno}/>'


def linea(d, color=TINTA, ancho=2):
    return f'<path d="{d}" fill="none" stroke="{color}" stroke-width="{ancho}" stroke-linecap="round"/>'


def fondo(cielo):
    return f'<rect width="{ANCHO}" height="{ALTO}" fill="{cielo}"/>'


def carril(color_bus=None, x=18):
    """El carril de la troncal al pie, con un bus si se pide."""
    partes = [rect(-2, 94, ANCHO + 4, 18, "#0B1621", borde=False), rect(-2, 98, ANCHO + 4, 4, AGUA, borde=False)]
    if color_bus:
        partes.append(bus(x, 76, color_bus))
    return "".join(partes)


def bus(x, y, color, largo=46):
    return "".join([
        rect(x, y, largo, 18, color, rx=5),
        rect(x + 5, y + 4, 12, 7, BLANCO, rx=2, ancho=1.5),
        rect(x + 20, y + 4, 10, 7, BLANCO, rx=2, ancho=1.5),
        rect(x + 33, y + 4, largo - 38, 7, BLANCO, rx=2, ancho=1.5),
        circulo(x + 10, y + 19, 3.5, TINTA, borde=False),
        circulo(x + largo - 10, y + 19, 3.5, TINTA, borde=False),
    ])


def palma(x, y, alto=34):
    tronco = camino(f"M{x} {y} Q{x + 4} {y - alto / 2} {x + 2} {y - alto} L{x + 6} {y - alto} "
                    f"Q{x + 8} {y - alto / 2} {x + 5} {y} Z", "#8D5A3B", ancho=1.5)
    cx, cy = x + 4, y - alto
    hojas = "".join(camino(d, VERDE, ancho=1.5) for d in [
        f"M{cx} {cy} Q{cx - 14} {cy - 10} {cx - 22} {cy + 2} Q{cx - 10} {cy - 4} {cx} {cy} Z",
        f"M{cx} {cy} Q{cx + 14} {cy - 10} {cx + 22} {cy + 2} Q{cx + 10} {cy - 4} {cx} {cy} Z",
        f"M{cx} {cy} Q{cx - 4} {cy - 16} {cx - 14} {cy - 18} Q{cx - 6} {cy - 8} {cx} {cy} Z",
        f"M{cx} {cy} Q{cx + 4} {cy - 16} {cx + 14} {cy - 18} Q{cx + 6} {cy - 8} {cx} {cy} Z",
    ])
    return tronco + hojas


def sol(cx=132, cy=22, r=11):
    return circulo(cx, cy, r + 7, AMARILLO, borde=False).replace('fill=', 'fill-opacity="0.18" fill=') + \
        circulo(cx, cy, r, AMARILLO)


def estacion_troncal(x=40, y=50, w=80):
    """Una estación de la troncal: plataforma de vidrio con techo."""
    return "".join([
        camino(f"M{x - 6} {y} L{x + w + 6} {y} L{x + w} {y - 10} L{x} {y - 10} Z", AMARILLO),
        rect(x, y, w, 32, "#BFE3EC"),
        linea(f"M{x + w / 4} {y} L{x + w / 4} {y + 32}"),
        linea(f"M{x + w / 2} {y} L{x + w / 2} {y + 32}"),
        linea(f"M{x + 3 * w / 4} {y} L{x + 3 * w / 4} {y + 32}"),
        rect(x - 4, y + 32, w + 8, 6, "#3A5168"),
    ])


def casa(x, y, w, h, color, techo=CORAL):
    return "".join([
        rect(x, y, w, h, color),
        camino(f"M{x - 3} {y} L{x + w / 2} {y - h * 0.45} L{x + w + 3} {y} Z", techo),
        rect(x + w / 2 - 4, y + h - 13, 8, 13, TINTA, borde=False),
        rect(x + 4, y + 6, 7, 7, BLANCO, ancho=1.5),
    ])


# ---------------------------------------------------------------------------------------------------- las láminas

def portal():
    techo = camino("M8 46 Q80 6 152 46 L152 52 L8 52 Z", "#3A5168")
    columnas = "".join(rect(x, 52, 6, 42, "#5B7288") for x in (14, 77, 140))
    return fondo("#12304A") + sol(28, 20, 8) + techo + columnas + carril() + bus(24, 74, TRONCAL) + \
        bus(88, 74, PRETRONCAL)


def santa_lucia():
    anden = rect(10, 64, 140, 12, "#3A5168")
    techo = camino("M6 40 L154 40 L148 30 L12 30 Z", AMARILLO) + "".join(rect(x, 40, 4, 24, "#5B7288") for x in (20, 78, 136))
    return fondo("#1B2E44") + techo + anden + carril() + bus(14, 76, ALIMENTADORA) + bus(66, 76, ALIMENTADORA) + \
        bus(118, 76, ALIMENTADORA, largo=40)


def madre_bernarda():
    cebra = "".join(rect(x, 82, 8, 14, BLANCO, ancho=1.5) for x in (14, 28, 42, 56))
    return fondo("#16304A") + estacion_troncal(70, 44, 76) + rect(-2, 82, 70, 14, "#2A3D52", borde=False) + cebra + \
        carril(TRONCAL, x=96)


def la_castellana():
    edificio = rect(26, 30, 108, 62, AZUL)
    toldo = camino("M20 30 L140 30 L134 44 L26 44 Z", AMARILLO) + "".join(
        camino(f"M{x} 30 L{x + 8} 30 L{x + 7} 44 L{x - 1} 44 Z", BLANCO, ancho=1.2) for x in (38, 62, 86, 110))
    vitrinas = rect(36, 56, 26, 24, "#BFE3EC") + rect(98, 56, 26, 24, "#BFE3EC") + rect(68, 56, 24, 36, TINTA, borde=False)
    bolsa = rect(44, 64, 12, 14, CORAL, rx=2, ancho=1.5) + linea("M47 64 Q50 58 53 64", ancho=1.5)
    return fondo("#23324A") + edificio + toldo + vitrinas + bolsa + carril()


def los_angeles():
    nubes = "".join(camino(f"M{x} {y} q6 -10 16 -4 q8 -8 16 2 q8 0 6 8 l-38 0 Z", BLANCO, ancho=1.5)
                    for x, y in ((20, 30), (96, 22)))
    casas = casa(18, 58, 30, 34, CORAL, AMARILLO) + casa(58, 54, 34, 38, AMARILLO, AZUL) + casa(102, 60, 32, 32, AZUL_CLARO, CORAL)
    return fondo("#1C3A5C") + nubes + casas + carril()


def los_ejecutivos():
    torres = rect(22, 34, 30, 62, "#3A5168") + rect(60, 12, 36, 84, AZUL) + rect(104, 40, 30, 56, AZUL_CLARO)
    ventanas = "".join(rect(x, y, 6, 6, AMARILLO if (x + y) % 3 else BLANCO, ancho=1)
                       for x in (66, 76, 86) for y in (20, 32, 44, 56, 68))
    ventanas += "".join(rect(x, y, 5, 5, BLANCO, ancho=1) for x in (28, 40) for y in (42, 54, 66))
    return fondo("#102A3C") + torres + ventanas + carril()


def villa_olimpica():
    graderia = camino("M10 70 Q80 20 150 70 L150 80 L10 80 Z", "#3A5168")
    pista = camino("M24 80 Q80 50 136 80 Z", CORAL, ancho=1.5) + linea("M36 80 Q80 58 124 80", BLANCO, 1.5) + \
        linea("M48 80 Q80 66 112 80", BLANCO, 1.5)
    reflectores = "".join(rect(x, 24, 4, 46, "#5B7288", ancho=1.5) + rect(x - 5, 18, 14, 8, AMARILLO, ancho=1.5)
                          for x in (16, 140))
    return fondo("#14294A") + reflectores + graderia + pista + carril()


def cuatro_vientos():
    viento = "".join(linea(d, BLANCO, 2.2) for d in ("M14 26 Q40 18 60 28", "M24 40 Q54 32 76 42", "M90 22 Q114 14 138 24"))
    molinete = "".join(camino(d, color, ancho=1.5) for d, color in (
        ("M80 56 L80 36 L92 48 Z", CORAL), ("M80 56 L100 56 L88 68 Z", AMARILLO),
        ("M80 56 L80 76 L68 64 Z", AZUL_CLARO), ("M80 56 L60 56 L72 44 Z", AGUA)))
    return fondo("#173452") + viento + rect(78, 56, 4, 38, "#8D5A3B", ancho=1.5) + molinete + \
        circulo(80, 56, 3, TINTA, borde=False) + palma(20, 94, 40) + palma(130, 94, 36) + carril()


def republica_del_libano():
    cedro = "".join(camino(f"M{80 - w} {y} L{80 + w} {y} L{80 + w * 0.6} {y - 12} L{80 - w * 0.6} {y - 12} Z", VERDE, ancho=1.8)
                    for w, y in ((38, 76), (30, 62), (22, 48), (14, 34)))
    return fondo("#1A3350") + sol(30, 24, 9) + rect(76, 76, 8, 18, "#8D5A3B", ancho=1.8) + cedro + carril()


def espana():
    fachada = rect(14, 26, 132, 68, CREMA)
    balcones = "".join(
        rect(x, 40, 22, 20, AZUL, ancho=1.5) + rect(x - 3, 58, 28, 6, "#8D5A3B", ancho=1.5) +
        "".join(linea(f"M{x + k} 60 L{x + k} 64", TINTA, 1.2) for k in (3, 9, 15, 21))
        for x in (26, 70, 114))
    flores = "".join(circulo(x, 56, 3, CORAL, ancho=1) for x in (30, 40, 74, 84, 118, 128))
    return fondo("#24365A") + fachada + rect(14, 20, 132, 8, CORAL) + balcones + flores + carril()


def maria_auxiliadora():
    capilla = rect(46, 40, 68, 54, CREMA) + camino("M40 40 L80 14 L120 40 Z", CORAL)
    torre = rect(72, 6, 16, 14, CREMA, ancho=1.8) + camino("M70 6 L80 -2 L90 6 Z", CORAL, ancho=1.8)
    puerta = camino("M70 94 L70 70 Q80 58 90 70 L90 94 Z", "#8D5A3B") + circulo(80, 30, 5, AZUL_CLARO, ancho=1.5)
    return fondo("#1F3352") + torre + capilla + puerta + palma(18, 94, 34) + palma(136, 94, 30) + carril()


def el_prado():
    pasto = camino("M-2 70 Q40 58 80 66 Q120 74 162 62 L162 96 L-2 96 Z", "#1E6B4A", borde=False)
    arboles = "".join(rect(x - 2, 56, 4, 16, "#8D5A3B", ancho=1.5) + circulo(x, 48, 13, VERDE, ancho=1.8) for x in (30, 124))
    banca = rect(62, 70, 36, 5, "#8D5A3B", ancho=1.5) + rect(64, 75, 3, 8, TINTA, borde=False) + rect(93, 75, 3, 8, TINTA, borde=False) \
        + rect(62, 62, 36, 4, "#8D5A3B", ancho=1.5)
    return fondo("#173A5A") + sol(80, 24, 9) + pasto + arboles + banca + carril()


def bazurto():
    toldos = camino("M6 44 L28 18 L50 44 Z", CORAL) + camino("M50 44 L80 14 L110 44 Z", AMARILLO) + \
        camino("M110 44 L132 18 L154 44 Z", AGUA)
    mesa = rect(8, 64, 144, 22, "#8D5A3B") + rect(6, 44, 148, 6, "#5C3A21")
    frutas = "".join(circulo(x, 60, 7, color, ancho=1.5) for x, color in (
        (22, "#FF9F43"), (40, VERDE), (58, AMARILLO), (76, CORAL), (94, VERDE), (112, "#FF9F43"), (130, AMARILLO)))
    return fondo("#2A1F12") + toldos + mesa + frutas + carril()


def las_delicias():
    caldero = camino("M30 66 Q80 100 130 66 Z", "#3A5168") + rect(26, 62, 108, 6, "#5B7288", rx=3)
    arepas = "".join(camino(f"M{x - 13} 64 Q{x} 48 {x + 13} 64 Z", AMARILLO, ancho=1.8) for x in (54, 80, 106))
    vapor = "".join(linea(f"M{x} 40 q-6 -8 0 -16 q6 -8 0 -16", BLANCO, 2) for x in (60, 80, 100))
    llama = camino("M66 92 Q72 82 76 92 Q80 80 86 92 Q90 84 94 92 Z", CORAL, ancho=1.5)
    return fondo("#2E2236") + vapor + caldero + arepas + llama + carril()


def la_popa():
    cerro = camino("M-2 96 L-2 72 Q40 40 80 34 Q120 40 162 72 L162 96 Z", VERDE_OSCURO, borde=False)
    ladera = camino("M20 96 Q60 60 80 54 Q100 60 140 96 Z", "#165A44", borde=False)
    convento = rect(62, 18, 36, 18, BLANCO) + rect(74, 6, 12, 14, BLANCO, ancho=1.8) + \
        camino("M72 6 L80 -2 L88 6 Z", MURALLA, ancho=1.8) + "".join(rect(x, 24, 5, 8, CIELO_NOCHE, rx=2, ancho=1)
                                                                    for x in (67, 77, 87))
    return fondo(CIELO_NOCHE) + sol(132, 24, 10) + cerro + ladera + convento + carril(TRONCAL, x=94)


def lo_amador():
    agua = rect(-2, 66, 164, 30, "#1F6F8B", borde=False) + linea("M10 76 q8 -4 16 0 q8 4 16 0", "#7FD4FF", 1.6) + \
        linea("M90 84 q8 -4 16 0 q8 4 16 0", "#7FD4FF", 1.6)
    manglar = "".join(circulo(x, 56, 14, "#1E6B4A", ancho=1.8) + linea(f"M{x - 8} 66 L{x - 4} 58 M{x} 66 L{x} 58 M{x + 8} 66 L{x + 4} 58", TINTA, 1.5)
                      for x in (22, 138))
    canoa = camino("M56 70 L108 70 L100 80 L64 80 Z", CORAL) + rect(80, 58, 3, 12, "#8D5A3B", ancho=1)
    return fondo("#173A5A") + sol(80, 24, 9) + manglar + agua + canoa + carril()


def chambacu():
    torres = rect(36, 14, 34, 82, "#3A5168") + rect(90, 22, 34, 74, "#5B7288")
    ventanas = "".join(rect(x, y, 6, 5, AMARILLO if (x * y) % 7 < 3 else BLANCO, ancho=1)
                       for x, xs in ((42, 0), (52, 0), (62 - 2, 0), (96, 0), (106, 0), (116 - 2, 0)) for y in range(22 + xs, 86, 11))
    return fondo("#1A2B48") + torres + ventanas + palma(14, 94, 34) + carril()


def centro():
    muralla = rect(-2, 64, 164, 32, MURALLA) + "".join(rect(x, 56, 12, 10, MURALLA) for x in (2, 22, 116, 136))
    torre = rect(58, 24, 44, 72, "#E3B178") + camino("M54 24 L80 4 L106 24 Z", ALIMENTADORA)
    reloj = circulo(80, 38, 9, BLANCO) + linea("M80 32 L80 38 L84 41", TINTA, 1.6)
    arco = camino("M68 96 L68 72 Q80 58 92 72 L92 96 Z", "#2B2233")
    return fondo("#2B2233") + muralla + torre + reloj + arco + carril()


def la_bodeguita():
    mar = rect(-2, 58, 164, 38, "#1F6F8B", borde=False) + linea("M8 70 q8 -4 16 0 q8 4 16 0", "#7FD4FF", 1.6) + \
        linea("M104 80 q8 -4 16 0 q8 4 16 0", "#7FD4FF", 1.6)
    muelle = rect(-2, 50, 60, 8, "#8D5A3B") + "".join(rect(x, 58, 4, 14, "#5C3A21", ancho=1.5) for x in (8, 28, 48))
    lancha = camino("M76 64 L142 64 L132 78 L84 78 Z", BLANCO) + rect(96, 54, 26, 10, AZUL_CLARO, rx=2) + \
        linea("M84 70 L132 70", CORAL, 3)
    return fondo("#15324E") + sol(132, 22, 9) + mar + muelle + lancha + carril()


LAMINAS = {
    "portal": portal, "santa-lucia": santa_lucia, "madre-bernarda": madre_bernarda, "la-castellana": la_castellana,
    "los-angeles": los_angeles, "los-ejecutivos": los_ejecutivos, "villa-olimpica": villa_olimpica,
    "cuatro-vientos": cuatro_vientos, "republica-del-libano": republica_del_libano, "espana": espana,
    "maria-auxiliadora": maria_auxiliadora, "el-prado": el_prado, "bazurto": bazurto, "las-delicias": las_delicias,
    "la-popa": la_popa, "lo-amador": lo_amador, "chambacu": chambacu, "centro": centro, "la-bodeguita": la_bodeguita,
}


def main():
    SALIDA.mkdir(parents=True, exist_ok=True)
    for ident, dibujo in LAMINAS.items():
        svg = (f'<svg xmlns="http://www.w3.org/2000/svg" width="{ANCHO}" height="{ALTO}" viewBox="0 0 {ANCHO} {ALTO}">'
               f'{dibujo()}</svg>')
        (SALIDA / f"{ident}.svg").write_text(svg, encoding="utf-8")
    print(f"✅ {len(LAMINAS)} láminas en {SALIDA}")


if __name__ == "__main__":
    main()
