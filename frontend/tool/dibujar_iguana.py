"""
Dibuja la iguana del Centenario (docs/plan-juego.md): la compañera del modo viaje, en assets/iguana/.

- iguana_<animo>.svg: el cuerpo con cada ánimo (tranquila, feliz, dormida).
- <accesorio>.svg: lo que se pone encima, en el mismo lienzo, para apilarlo sobre el cuerpo.

Mismo estilo que las ilustraciones de los reportes: formas planas, contorno #10202E y colores «Bahía». Las iguanas
del Parque del Centenario son verdes con la papada y las patas anaranjadas.

Uso (desde frontend/): python3 tool/dibujar_iguana.py
"""
from pathlib import Path

ANCHO, ALTO = 120, 100
TINTA = "#10202E"
VERDE, VERDE_OSCURO, PANZA = "#4BE38B", "#1E9E5A", "#B6F5CF"
NARANJA, CORAL, AMARILLO, AZUL, BLANCO = "#FF9F43", "#FF7A6B", "#FFC247", "#2F5BD3", "#E8F7FF"
AGUA = "#3DDBB5"

SALIDA = Path(__file__).resolve().parent.parent / "assets" / "iguana"


def forma(d, color, ancho=2.2):
    return f'<path d="{d}" fill="{color}" stroke="{TINTA}" stroke-width="{ancho}" stroke-linejoin="round"/>'


def trazo(d, ancho=2.2, color=TINTA):
    return f'<path d="{d}" fill="none" stroke="{color}" stroke-width="{ancho}" stroke-linecap="round"/>'


def circulo(cx, cy, r, color, borde=True, ancho=1.8):
    contorno = f' stroke="{TINTA}" stroke-width="{ancho}"' if borde else ""
    return f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="{color}"{contorno}/>'


def cuerpo():
    cola = forma("M30 72 C10 74 4 60 12 50 C16 45 22 48 18 54 C14 61 22 66 34 64 Z", VERDE)
    bandas = trazo("M13 57 L18 55 M16 64 L21 61 M24 68 L27 64", 2, VERDE_OSCURO)
    espalda = forma("M28 74 C26 56 40 44 60 44 C74 44 82 52 84 62 C86 74 76 82 58 82 C42 82 30 80 28 74 Z", VERDE)
    panza = forma("M42 80 C44 70 54 66 66 68 C74 70 78 76 74 80 C64 84 50 84 42 80 Z", PANZA, 1.6)
    puas = "".join(forma(f"M{x} {y} L{x + 4} {y - 8} L{x + 8} {y} Z", VERDE_OSCURO, 1.6)
                   for x, y in ((34, 52), (42, 46), (51, 43), (60, 43), (68, 46)))
    patas = forma("M40 80 L36 90 L44 90 L46 82 Z", NARANJA, 1.8) + forma("M66 80 L66 90 L74 90 L72 80 Z", NARANJA, 1.8)
    papada = forma("M80 58 C78 70 86 76 92 70 C94 66 92 60 88 58 Z", NARANJA)
    cabeza = forma("M74 50 C72 34 84 24 98 26 C110 28 116 38 112 48 C108 58 96 62 86 60 C80 58 76 56 74 50 Z", VERDE)
    nariz = circulo(109, 38, 1.4, TINTA, borde=False)
    # La escama redonda bajo el oído (subtimpánica), clara y chica para que no parezca otro ojo.
    escama = circulo(85, 48, 2.4, PANZA, ancho=1.2)
    return cola + bandas + espalda + panza + puas + patas + papada + cabeza + nariz + escama


def ojos(animo):
    if animo == "dormida":
        # Las «z» van como trazos: el texto de un SVG no siempre se dibuja igual en el teléfono.
        return trazo("M92 37 Q96 40 100 37", 2.4) + trazo("M103 14 h7 l-7 8 h7", 2, BLANCO) + \
            trazo("M112 5 h5 l-5 6 h5", 1.6, BLANCO)
    if animo == "feliz":
        return trazo("M91 38 Q96 32 101 38", 2.6)
    return circulo(96, 36, 6, BLANCO, ancho=2) + circulo(98, 36, 3, TINTA, borde=False) + circulo(99, 35, 1, BLANCO, borde=False)


def boca(animo):
    if animo == "feliz":
        return forma("M98 47 Q104 53 110 46 Q104 49 98 47 Z", CORAL, 1.6)
    return trazo("M99 47 Q104 50 109 46", 2)


# ------------------------------------------------------------------------------------------------- accesorios

def gafas():
    return (forma("M86 32 L104 32 L102 41 Q95 44 90 41 Z", "#10202E", 1.6) +
            forma("M104 32 L114 32 L113 38 Q110 41 106 39 Z", "#10202E", 1.6) +
            trazo("M88 34 L94 34", 1.4, AGUA) + trazo("M84 33 L78 31", 2))


def gorra():
    return (forma("M80 30 C80 18 92 12 104 16 C110 18 112 24 110 28 Z", AZUL) +
            forma("M104 26 L120 28 L118 32 L104 30 Z", AZUL) +
            circulo(95, 15, 2.2, AMARILLO, ancho=1.2) +
            trazo("M89 19 L89 27 M95 19 L90 23 L95 27", 2, AMARILLO))


def vueltiao():
    """El sombrero vueltiao, con sus franjas de caña flecha."""
    ala = forma("M70 30 Q96 38 118 28 Q114 22 96 22 Q76 22 70 30 Z", "#F3E3C3")
    copa = forma("M82 24 C82 10 110 10 110 24 Z", "#F3E3C3")
    franjas = "".join(trazo(d, 1.6) for d in (
        "M84 20 L108 20", "M86 15 L106 15", "M76 28 Q96 34 113 27"))
    return ala + copa + franjas


def panoleta():
    return (forma("M74 54 Q86 64 100 56 L96 66 Q86 72 76 64 Z", CORAL) +
            "".join(circulo(x, y, 1.5, BLANCO, borde=False) for x, y in ((82, 62), (90, 64), (86, 58), (94, 60))))


def audifonos():
    return (trazo("M84 34 C82 12 112 10 112 30", 3.4, "#3A5168") +
            forma("M80 32 h8 v12 h-8 Z", CORAL, 1.6) + forma("M108 28 h8 v12 h-8 Z", CORAL, 1.6))


ANIMOS = ("tranquila", "feliz", "dormida")
ACCESORIOS = {"gafas": gafas, "gorra": gorra, "vueltiao": vueltiao, "panoleta": panoleta, "audifonos": audifonos}


def svg(contenido):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{ANCHO}" height="{ALTO}" viewBox="0 0 {ANCHO} {ALTO}">'
            f'{contenido}</svg>')


def main():
    SALIDA.mkdir(parents=True, exist_ok=True)
    for animo in ANIMOS:
        (SALIDA / f"iguana_{animo}.svg").write_text(svg(cuerpo() + ojos(animo) + boca(animo)), encoding="utf-8")
    for nombre, dibujo in ACCESORIOS.items():
        (SALIDA / f"{nombre}.svg").write_text(svg(dibujo()), encoding="utf-8")
    print(f"✅ {len(ANIMOS)} ánimos y {len(ACCESORIOS)} accesorios en {SALIDA}")


if __name__ == "__main__":
    main()
