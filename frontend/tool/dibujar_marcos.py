"""
Dibuja los marcos del avatar (assets/marcos/*.svg): Muralla, Bahía, Castillo y La Popa.

Cada marco tiene dos capas, una detrás del avatar (`fondo`: aura, sol) y otra delante (`frente`: aro y
accesorios), y dos niveles de detalle: `vitrina` para el perfil (88 px o más) y `chico` para el inicio y las
listas (hasta 64 px), sin los detalles que a ese tamaño se vuelven ruido. Todo es SVG plano (trazos, degradados
y opacidad, sin filtros) para que flutter_svg lo dibuje igual en cualquier teléfono.

Geometría común: viewBox de 192 × 192 centrado en el avatar, que mide 120 de diámetro (el lienzo es 1,6 veces
el avatar). El aro va de r = 55 a r = 65. Los ángulos son de reloj: 0° a las 12 y crecen hacia las 3. Entre las
3:30 y las 6:30 (105°–195°) va la insignia del nivel: ahí no se dibuja nada importante.

Uso: python3 tool/dibujar_marcos.py   (escribe en assets/marcos/)
"""
import math
from pathlib import Path

SALIDA = Path(__file__).resolve().parent.parent / "assets" / "marcos"
MEDIO = 96  # medio lienzo
R_IN, R_OUT = 55.0, 65.0  # el aro


# ------------------------------------------------------------------------------------------------ geometría

def polar(r: float, grados: float) -> tuple[float, float]:
    a = math.radians(grados)
    return r * math.sin(a), -r * math.cos(a)


def f(v: float) -> str:
    return f"{v:.2f}".rstrip("0").rstrip(".")


def pt(p: tuple[float, float]) -> str:
    return f"{f(p[0])},{f(p[1])}"


def sector(r1: float, r2: float, a1: float, a2: float) -> str:
    """Un trozo de anillo entre r1 y r2, de a1 a a2 (en sentido del reloj)."""
    grande = 1 if (a2 - a1) % 360 > 180 else 0
    return (f"M{pt(polar(r2, a1))}A{f(r2)},{f(r2)} 0 {grande} 1 {pt(polar(r2, a2))}"
            f"L{pt(polar(r1, a2))}A{f(r1)},{f(r1)} 0 {grande} 0 {pt(polar(r1, a1))}Z")


def anillo(r1: float, r2: float) -> str:
    """Anillo completo (dos círculos con la regla evenodd)."""
    def circulo(r):
        return f"M{f(r)},0A{f(r)},{f(r)} 0 1 1 {f(-r)},0A{f(r)},{f(r)} 0 1 1 {f(r)},0Z"
    return circulo(r2) + circulo(r1)


def curva_polar(puntos: list[tuple[float, float]]) -> str:
    """Una línea suave por puntos (r, grados) con Catmull-Rom → Bézier."""
    xy = [polar(r, a) for r, a in puntos]
    d = f"M{pt(xy[0])}"
    for i in range(len(xy) - 1):
        p0 = xy[i - 1] if i > 0 else xy[i]
        p1, p2 = xy[i], xy[i + 1]
        p3 = xy[i + 2] if i + 2 < len(xy) else p2
        c1 = (p1[0] + (p2[0] - p0[0]) / 6, p1[1] + (p2[1] - p0[1]) / 6)
        c2 = (p2[0] - (p3[0] - p1[0]) / 6, p2[1] - (p3[1] - p1[1]) / 6)
        d += f"C{pt(c1)} {pt(c2)} {pt(p2)}"
    return d


def estrella(cx: float, cy: float, r: float, color: str, filo: str | None = None, ancho: float = 0) -> str:
    """Destello de cuatro puntas."""
    k = r * 0.22
    d = (f"M{f(cx)},{f(cy - r)}Q{f(cx + k)},{f(cy - k)} {f(cx + r)},{f(cy)}Q{f(cx + k)},{f(cy + k)} {f(cx)},{f(cy + r)}"
         f"Q{f(cx - k)},{f(cy + k)} {f(cx - r)},{f(cy)}Q{f(cx - k)},{f(cy - k)} {f(cx)},{f(cy - r)}Z")
    trazo = f' stroke="{filo}" stroke-width="{f(ancho)}" stroke-linejoin="round"' if filo else ""
    return f'<path d="{d}" fill="{color}"{trazo}/>'


def lineal(ident: str, paradas: list[tuple[float, str, float]], x1=0.0, y1=0.0, x2=0.0, y2=1.0,
           espacio: str | None = None) -> str:
    unidades = f' gradientUnits="{espacio}"' if espacio else ""
    stops = "".join(f'<stop offset="{f(o)}" stop-color="{c}"' + (f' stop-opacity="{f(a)}"' if a < 1 else "") + "/>"
                    for o, c, a in paradas)
    return f'<linearGradient id="{ident}" x1="{f(x1)}" y1="{f(y1)}" x2="{f(x2)}" y2="{f(y2)}"{unidades}>{stops}</linearGradient>'


def radial(ident: str, paradas: list[tuple[float, str, float]], cx=0.0, cy=0.0, r=1.0, espacio="userSpaceOnUse",
           fx: float | None = None, fy: float | None = None) -> str:
    foco = f' fx="{f(fx)}" fy="{f(fy)}"' if fx is not None else ""
    stops = "".join(f'<stop offset="{f(o)}" stop-color="{c}"' + (f' stop-opacity="{f(a)}"' if a < 1 else "") + "/>"
                    for o, c, a in paradas)
    return (f'<radialGradient id="{ident}" cx="{f(cx)}" cy="{f(cy)}" r="{f(r)}"{foco} gradientUnits="{espacio}">'
            f"{stops}</radialGradient>")


def svg(defs: list[str], cuerpo: list[str]) -> str:
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="192" height="192" viewBox="-{MEDIO} -{MEDIO} 192 192">'
            f'<defs>{"".join(defs)}</defs>{"".join(cuerpo)}</svg>\n')


def rotado(grados: float, r: float, contenido: str, escala: float = 1.0) -> str:
    """Pieza dibujada «hacia arriba» (y negativa = hacia afuera), puesta en el aro a esa hora."""
    x, y = polar(r, grados)
    return f'<g transform="translate({f(x)},{f(y)}) rotate({f(grados)}) scale({f(escala)})">{contenido}</g>'


# ---------------------------------------------------------------------------------------------------- Muralla

def muralla(chico: bool) -> tuple[str, str]:
    filo, junta = "#5E4224", "#6E4F2C"
    piedras = ["#E2C796", "#C9A46A", "#D8B987", "#BE9659", "#E8D2A6", "#CDAA70"]
    defs = [
        lineal("luz", [(0, "#FFF6E2", 0.55), (0.5, "#FFF6E2", 0), (1, "#5E4224", 0.18)], espacio=None),
        lineal("cuerpo", [(0, "#A9824F", 1), (0.35, "#E6D1A8", 1), (0.65, "#D4B582", 1), (1, "#8E6A3C", 1)],
               x1=0, y1=0, x2=1, y2=0),
        radial("cupula", [(0, "#F4E6C8", 1), (0.6, "#CFAF78", 1), (1, "#9C7843", 1)], cx=-3, cy=-33, r=12),
        lineal("bronce", [(0, "#2B2B2E", 1), (0.45, "#6E6A64", 1), (1, "#2B2B2E", 1)], x1=0, y1=0, x2=1, y2=0),
    ]
    ancho = 1.6 if chico else 1.1
    cuerpo = [f'<path d="{anillo(R_IN, R_OUT)}" fill-rule="evenodd" fill="{junta}"/>']
    # Dos hiladas de sillares trabadas, como la piedra coralina de la muralla.
    hiladas = [(R_IN + 0.5, 59.9, 0.0, 10 if chico else 12), (60.1, R_OUT - 0.5, 15.0 if not chico else 18.0, 10 if chico else 12)]
    k = 0
    for r1, r2, desfase, n in hiladas:
        paso = 360 / n
        hueco = 2.2 if chico else 1.8
        for i in range(n):
            a1 = desfase + i * paso + hueco / 2
            a2 = desfase + (i + 1) * paso - hueco / 2
            cuerpo.append(f'<path d="{sector(r1, r2, a1, a2)}" fill="{piedras[k % len(piedras)]}"/>')
            k += 3
    # Luz de arriba y sombra de abajo sobre todo el aro.
    cuerpo.append(f'<path d="{anillo(R_IN, R_OUT)}" fill-rule="evenodd" fill="url(#luz)"/>')
    if not chico:
        # Poros de la piedra coralina.
        for i in range(30):
            a = (i * 137.5) % 360
            r = R_IN + 2 + (i * 7 % 9)
            x, y = polar(r, a)
            cuerpo.append(f'<circle cx="{f(x)}" cy="{f(y)}" r="{f(0.55 + (i % 3) * 0.2)}" fill="#8E6A3C" fill-opacity="0.55"/>')
    cuerpo.append(f'<circle r="{f(R_OUT)}" fill="none" stroke="{filo}" stroke-width="{f(ancho + 0.4)}"/>')
    cuerpo.append(f'<circle r="{f(R_IN)}" fill="none" stroke="{filo}" stroke-width="{f(ancho)}"/>')
    # La garita, a las 10:30, mirando hacia afuera.
    garita = [
        f'<path d="M-6,5L6,5L11,-4L-11,-4Z" fill="#C9A46A" stroke="{filo}" stroke-width="{f(ancho)}" stroke-linejoin="round"/>',
        f'<rect x="-12" y="-7.5" width="24" height="4" rx="2" fill="#E6D1A8" stroke="{filo}" stroke-width="{f(ancho)}"/>',
        f'<rect x="-9.5" y="-23" width="19" height="15.5" fill="url(#cuerpo)" stroke="{filo}" stroke-width="{f(ancho)}"/>',
        f'<rect x="-1.6" y="-20" width="3.2" height="9" rx="1.6" fill="#4A321A"/>',
        f'<rect x="-12" y="-26.5" width="24" height="4" rx="2" fill="#E6D1A8" stroke="{filo}" stroke-width="{f(ancho)}"/>',
        f'<path d="M-10.5,-26.5C-10.5,-35 -6,-39.5 0,-39.5C6,-39.5 10.5,-35 10.5,-26.5Z" fill="url(#cupula)" stroke="{filo}" stroke-width="{f(ancho)}" stroke-linejoin="round"/>',
        f'<rect x="-1.2" y="-43" width="2.4" height="4" fill="{filo}"/>',
        f'<circle cy="-44.5" r="2.8" fill="#E6D1A8" stroke="{filo}" stroke-width="{f(ancho)}"/>',
    ]
    if not chico:
        garita.insert(3, '<path d="M-9.5,-17H9.5M-9.5,-12.5H9.5" stroke="#8E6A3C" stroke-width="0.7" stroke-opacity="0.7"/>')
        garita.append('<path d="M-6.5,-29C-5.5,-33.5 -3,-36 0.5,-36.8" fill="none" stroke="#FFF6E2" stroke-width="1.4" stroke-linecap="round" stroke-opacity="0.85"/>')
    # Un cañón asomado en su baluarte, a las 2.
    canon = (
        f'<path d="M-8,4L-8,-3L0,-9L8,-3L8,4Z" fill="#D8B987" stroke="{filo}" stroke-width="{f(ancho)}" stroke-linejoin="round"/>'
        f'<path d="M-2.6,-4L-2,-19H2L2.6,-4Z" fill="url(#bronce)" stroke="{filo}" stroke-width="{f(ancho * 0.9)}" stroke-linejoin="round"/>'
        f'<rect x="-3.2" y="-21.5" width="6.4" height="3" rx="1.5" fill="url(#bronce)" stroke="{filo}" stroke-width="{f(ancho * 0.9)}"/>'
        f'<circle cy="-3.5" r="3.6" fill="url(#bronce)" stroke="{filo}" stroke-width="{f(ancho * 0.9)}"/>'
        + ('' if chico else '<path d="M-0.8,-6V-17" stroke="#C9C1B2" stroke-width="0.9" stroke-linecap="round" stroke-opacity="0.8"/>')
    )
    cuerpo.append(rotado(52, R_OUT - 1, canon, escala=1.0 if not chico else 1.1))
    cuerpo.append(rotado(315, 63, "".join(garita), escala=0.95 if not chico else 1.0))
    return "", svg(defs, cuerpo)


# ------------------------------------------------------------------------------------------------------ Bahía

def bahia(chico: bool) -> tuple[str, str]:
    filo = "#0A2E4A"
    ancho = 1.6 if chico else 1.15
    defs = [
        lineal("mar", [(0, "#0E4C7A", 1), (0.55, "#1F8FC9", 1), (1, "#2EC4B6", 1)], x1=0, y1=1, x2=0, y2=0),
        lineal("ola", [(0, "#0B4470", 1), (0.4, "#1679B5", 1), (0.75, "#2EB7D6", 1), (1, "#8BEBEA", 1)],
               x1=-70, y1=20, x2=10, y2=-92, espacio="userSpaceOnUse"),
        lineal("tubo", [(0, "#062A47", 1), (1, "#0E4C7A", 1)], x1=0, y1=-82, x2=0, y2=-58, espacio="userSpaceOnUse"),
        radial("halo", [(0, "#2EC4B6", 0), (0.62, "#2EC4B6", 0), (0.72, "#2EC4B6", 0.28), (1, "#1F8FC9", 0)], r=88),
    ]
    fondo = svg(defs[3:], ['<circle r="88" fill="url(#halo)"/>']) if not chico else ""
    cuerpo = [f'<path d="{anillo(R_IN, R_OUT)}" fill-rule="evenodd" fill="url(#mar)"/>']
    if not chico:
        # Oleaje fino dentro del aro.
        ondas = [(60 + 1.4 * math.sin(math.radians(a * 9)), a) for a in range(0, 361, 4)]
        cuerpo.append(f'<path d="{curva_polar(ondas)}" fill="none" stroke="#E6FBFF" stroke-width="0.9" stroke-opacity="0.35"/>')
    cuerpo.append(f'<circle r="{f(R_OUT)}" fill="none" stroke="{filo}" stroke-width="{f(ancho + 0.3)}"/>')
    cuerpo.append(f'<circle r="{f(R_IN)}" fill="none" stroke="{filo}" stroke-width="{f(ancho)}"/>')

    # La ola: sube por la izquierda, revienta arriba y el labio cae hacia la 1, con el tubo oscuro debajo.
    inicio, fin_ = polar(R_OUT, 246), polar(58, 333)
    ola = (f"M{pt(inicio)}C-78,4 -82,-36 -66,-63C-52,-86 -24,-96 2,-93C22,-91 34,-80 33,-67"
           f"C32,-60 25,-57 20,-62C23,-71 14,-79 3,-78C-12,-77 -22,-70 {pt(fin_)}"
           f"A58,58 0 0 0 {pt(polar(58, 246))}Z")
    cuerpo.append(f'<path d="{ola}" fill="url(#ola)" stroke="{filo}" stroke-width="{f(ancho)}" stroke-linejoin="round"/>')
    tubo = (f"M20,-62C23,-71 14,-79 3,-78C-12,-77 -22,-70 {pt(fin_)}"
            f"A58,58 0 0 1 {pt(polar(58, 14))}C16,-58 18,-60 20,-62Z")
    cuerpo.append(f'<path d="{tubo}" fill="url(#tubo)" stroke="{filo}" stroke-width="{f(ancho * 0.8)}" stroke-linejoin="round"/>')
    # Corrientes dentro de la ola.
    if not chico:
        for d in ("M-64,8C-72,-18 -70,-44 -56,-64", "M-56,14C-62,-12 -60,-36 -48,-56", "M-44,-74C-30,-84 -12,-88 6,-87"):
            cuerpo.append(f'<path d="{d}" fill="none" stroke="#BFF4F2" stroke-width="1.3" stroke-opacity="0.55" stroke-linecap="round"/>')
    # Espuma en la cresta y en el labio, con garras que caen.
    cuerpo.append(f'<path d="M-58,-74C-42,-90 -20,-95 2,-93C22,-91 34,-80 33,-67" fill="none" stroke="#F2FEFF" '
                  f'stroke-width="{5.5 if chico else 4.6}" stroke-linecap="round"/>')
    garras = [(36, -60, 3.2), (30, -54, 2.4), (39, -69, 2.2)] if not chico else [(36, -60, 3.6)]
    for x, y, r in garras:
        cuerpo.append(f'<circle cx="{x}" cy="{y}" r="{r}" fill="#F2FEFF" stroke="{filo}" stroke-width="{f(ancho * 0.8)}"/>')
    # Rocío sobre la cresta y un destello de sol en el agua.
    for x, y, r in ([(-40, -89, 2.2), (-28, -92.5, 1.5), (14, -91.5, 1.6)] if not chico else [(-36, -90, 2.6)]):
        cuerpo.append(f'<circle cx="{x}" cy="{y}" r="{r}" fill="#F2FEFF" stroke="{filo}" stroke-width="{f(ancho * 0.7)}"/>')
    x, y = polar(82, 50)
    cuerpo.append(estrella(x, y, 9 if not chico else 10, "#FFFFFF", filo, ancho * 0.8))
    if not chico:
        x, y = polar(78, 72)
        cuerpo.append(estrella(x, y, 4.5, "#E6FBFF", filo, 0.8))
    return fondo, svg(defs[:3], cuerpo)


# --------------------------------------------------------------------------------------------------- Castillo

ORO = [(0, "#FFF2C2", 1), (0.22, "#F2CF6B", 1), (0.48, "#D9A93A", 1), (0.66, "#9C6B17", 1), (0.82, "#E8C35A", 1),
       (1, "#B8862A", 1)]


def castillo(chico: bool) -> tuple[str, str]:
    filo = "#5A3B0A"
    ancho = 1.6 if chico else 1.15
    defs = [
        lineal("oro", ORO, x1=-60, y1=-60, x2=60, y2=60, espacio="userSpaceOnUse"),
        lineal("oroTorre", [(0, "#FFF2C2", 1), (0.35, "#F2CF6B", 1), (0.75, "#D9A93A", 1), (1, "#9C6B17", 1)],
               x1=0, y1=-96, x2=0, y2=-56, espacio="userSpaceOnUse"),
        lineal("esmeralda", [(0, "#E9FFF4", 1), (0.3, "#7DF0B8", 1), (0.65, "#1FBF7A", 1), (1, "#0E8A55", 1)],
               x1=0, y1=0, x2=1, y2=1),
        radial("halo", [(0, "#F2CF6B", 0), (0.6, "#F2CF6B", 0), (0.7, "#F2CF6B", 0.32), (1, "#F2CF6B", 0)], r=90),
    ]
    fondo = svg(defs[3:], ['<circle r="90" fill="url(#halo)"/>'])
    cuerpo = [
        f'<path d="{anillo(R_IN + 1, R_OUT + 1)}" fill-rule="evenodd" fill="url(#oro)"/>',
        f'<circle r="{f(R_OUT + 1)}" fill="none" stroke="{filo}" stroke-width="{f(ancho + 0.4)}"/>',
        f'<circle r="{f(R_IN + 1)}" fill="none" stroke="{filo}" stroke-width="{f(ancho)}"/>',
        # Filete interior: el segundo muro.
        f'<circle r="{f(R_IN - 2.2)}" fill="none" stroke="#D9A93A" stroke-width="{2.2 if chico else 1.8}"/>',
        f'<circle r="{f(R_IN - 2.2)}" fill="none" stroke="{filo}" stroke-width="0.6" stroke-opacity="0.6"/>',
    ]
    if not chico:
        cuerpo.append(f'<circle r="{f(R_OUT - 1.2)}" fill="none" stroke="#FFF2C2" stroke-width="0.9" stroke-opacity="0.7"/>')
        # Remaches, salvo donde va la insignia.
        for a in range(15, 360, 30):
            if 100 <= a <= 200 or a in (345, 15):
                continue
            x, y = polar(61, a)
            cuerpo.append(f'<circle cx="{f(x)}" cy="{f(y)}" r="1.5" fill="#FFF2C2" stroke="{filo}" stroke-width="0.6"/>')
    # Baluartes a las 3 y a las 9: puntas de flecha como las del fuerte.
    baluarte = (f'<path d="M-9,3L-9,-5L0,-16L9,-5L9,3Z" fill="url(#oroTorre)" stroke="{filo}" stroke-width="{f(ancho)}" stroke-linejoin="round"/>'
                + ('' if chico else f'<path d="M0,-15V2" stroke="{filo}" stroke-width="0.7" stroke-opacity="0.6"/>'))
    for a in (90, 270):
        cuerpo.append(rotado(a, R_OUT - 1, baluarte))
    # La fortaleza a las 12: tres cuerpos con muros en talud.
    torre = [
        f'<path d="M-38,-54L-31,-68L31,-68L38,-54Z" fill="url(#oroTorre)" stroke="{filo}" stroke-width="{f(ancho)}" stroke-linejoin="round"/>',
        f'<path d="M-21,-67.5L-17.5,-78L17.5,-78L21,-67.5Z" fill="url(#oroTorre)" stroke="{filo}" stroke-width="{f(ancho)}" stroke-linejoin="round"/>',
        f'<path d="M-9.5,-77.5L-8,-85L8,-85L9.5,-77.5Z" fill="url(#oroTorre)" stroke="{filo}" stroke-width="{f(ancho)}" stroke-linejoin="round"/>',
        f'<path d="M0,-85V-95" stroke="{filo}" stroke-width="{f(ancho)}" stroke-linecap="round"/>',
        f'<path d="M0.5,-95L11,-92.5L0.5,-89.5Z" fill="#D23B2C" stroke="{filo}" stroke-width="{f(ancho * 0.8)}" stroke-linejoin="round"/>',
    ]
    if not chico:
        # Almenas, troneras y la puerta.
        for x in (-24, -16, 16, 24):
            torre.append(f'<rect x="{x - 2}" y="-71" width="4" height="3.5" fill="url(#oroTorre)" stroke="{filo}" stroke-width="0.8"/>')
        for x in (-11, 11):
            torre.append(f'<rect x="{x - 2.4}" y="-74.5" width="4.8" height="2.6" rx="1.3" fill="#5A3B0A"/>')
        for x in (-22, 22):
            torre.append(f'<rect x="{x - 2.4}" y="-63" width="4.8" height="2.6" rx="1.3" fill="#5A3B0A"/>')
        torre.append(f'<path d="M-28,-67.5H28M-17.5,-77.5H17.5" stroke="#FFF2C2" stroke-width="0.8" stroke-opacity="0.8"/>')
    else:
        for x in (-20, 20):
            torre.append(f'<rect x="{x - 3}" y="-63.5" width="6" height="3.4" rx="1.7" fill="#5A3B0A"/>')
    cuerpo += torre
    # La esmeralda, joya de la corona, en la puerta del fuerte.
    gema = (f'<path d="M0,-71L6.5,-64.5L0,-56L-6.5,-64.5Z" fill="url(#esmeralda)" stroke="#075C38" stroke-width="{f(ancho)}" stroke-linejoin="round"/>'
            + ('' if chico else '<path d="M-6.5,-64.5H6.5M-3,-64.5L0,-71L3,-64.5L0,-56Z" fill="none" stroke="#075C38" stroke-width="0.6" stroke-opacity="0.7"/>'
               '<path d="M-2.2,-67L-0.6,-69" stroke="#FFFFFF" stroke-width="1.2" stroke-linecap="round"/>'))
    cuerpo.append(gema)
    return fondo, svg(defs[:3], cuerpo)


# ---------------------------------------------------------------------------------------------------- La Popa

def la_popa(chico: bool) -> tuple[str, str]:
    filo = "#3D1E5C"
    ancho = 1.6 if chico else 1.15
    sol = polar(76, 46)
    defs_fondo = [
        radial("aura", [(0, "#FF9A3C", 0), (0.58, "#FF9A3C", 0), (0.64, "#FF9A3C", 0.6), (0.82, "#FF5E7E", 0.25),
                        (1, "#FF5E7E", 0)], r=95),
        radial("sol", [(0, "#FFF8DC", 1), (0.45, "#FFE08A", 1), (1, "#FF9A3C", 1)], cx=sol[0] - 2, cy=sol[1] - 3, r=14),
    ]
    rayos = []
    for i in range(10):
        a = i * 36 + 8
        p1, p2 = polar(16, a), polar(25 if i % 2 == 0 else 21, a)
        rayos.append(f'<path d="M{f(sol[0] + p1[0])},{f(sol[1] + p1[1])}L{f(sol[0] + p2[0])},{f(sol[1] + p2[1])}" '
                     f'stroke="#FFD27A" stroke-width="{3 if chico else 2.2}" stroke-linecap="round" stroke-opacity="0.85"/>')
    fondo = svg(defs_fondo, ['<circle r="95" fill="url(#aura)"/>', *rayos,
                             f'<circle cx="{f(sol[0])}" cy="{f(sol[1])}" r="13" fill="url(#sol)" stroke="#C2410C" stroke-opacity="0.5" stroke-width="1"/>'])
    defs = [
        lineal("atardecer", [(0, "#FFC15E", 1), (0.35, "#FF7A59", 1), (0.68, "#E0457B", 1), (1, "#7B4BD6", 1)],
               x1=50, y1=-50, x2=-40, y2=60, espacio="userSpaceOnUse"),
        lineal("cerro", [(0, "#7A3E8F", 1), (0.55, "#5B2A6E", 1), (1, "#3D1E5C", 1)], x1=0, y1=-82, x2=0, y2=-40,
               espacio="userSpaceOnUse"),
        lineal("muro", [(0, "#FFFFFF", 1), (1, "#F3E3D3", 1)], x1=0, y1=0, x2=0, y2=1),
    ]
    cuerpo = [
        f'<path d="{anillo(R_IN, R_OUT)}" fill-rule="evenodd" fill="url(#atardecer)"/>',
        f'<circle r="{f(R_OUT)}" fill="none" stroke="{filo}" stroke-width="{f(ancho + 0.4)}"/>',
        f'<circle r="{f(R_IN)}" fill="none" stroke="{filo}" stroke-width="{f(ancho)}"/>',
    ]
    if not chico:
        cuerpo.append(f'<circle r="{f(R_OUT - 1.3)}" fill="none" stroke="#FFE7B0" stroke-width="0.9" stroke-opacity="0.65"/>')
    # El cerro: sube suave desde el oeste y cae de golpe al este, como la popa de una galera.
    cerro = (f"M{pt(polar(R_IN + 1, 298))}C-56,-44 -48,-58 -36,-65C-24,-71 -12,-74 -2,-75.5C6,-76.5 13,-77 18,-76"
             f"C24,-73 26,-67 30,-60C33,-55 36,-50 {pt(polar(R_IN + 1, 38))}"
             f"A{f(R_IN + 1)},{f(R_IN + 1)} 0 0 0 {pt(polar(R_IN + 1, 298))}Z")
    cuerpo.append(f'<path d="{cerro}" fill="url(#cerro)" stroke="{filo}" stroke-width="{f(ancho)}" stroke-linejoin="round"/>')
    # Cara este del cerro, iluminada por el sol de la tarde.
    cuerpo.append(f'<path d="M18,-76C24,-73 26,-67 30,-60C33,-55 36,-50 {pt(polar(R_IN + 1, 38))}L26,-50C22,-58 19,-67 14,-75Z" '
                  f'fill="#C2477A" fill-opacity="0.55"/>')
    # Filo de luz sobre la cresta (se lee también en el tema oscuro).
    cuerpo.append(f'<path d="M-36,-65C-24,-71 -12,-74 -2,-75.5C6,-76.5 13,-77 18,-76C24,-73 26,-67 30,-60" fill="none" '
                  f'stroke="#FFB347" stroke-width="{2.4 if chico else 1.7}" stroke-linecap="round"/>')
    if not chico:
        # Laderas con monte: trazos suaves, no manchas.
        for d in ("M-44,-54C-36,-59 -28,-63 -20,-65", "M-30,-58C-22,-62 -12,-65 -4,-66", "M-14,-63C-6,-66 2,-67 10,-67"):
            cuerpo.append(f'<path d="{d}" fill="none" stroke="#2E5A3A" stroke-width="1.6" stroke-opacity="0.6" stroke-linecap="round"/>')
    # El convento en la cima, con la espadaña y una ventana encendida.
    cx, cy = 5, -76
    convento = [
        f'<path d="M-11,0V-6.5H9V0Z" fill="url(#muro)" stroke="{filo}" stroke-width="{f(ancho * 0.85)}" stroke-linejoin="round"/>',
        f'<path d="M-12.2,-6.5L-9,-9.6H7.8L10.2,-6.5Z" fill="#C8553D" stroke="{filo}" stroke-width="{f(ancho * 0.85)}" stroke-linejoin="round"/>',
        f'<path d="M-11,-6.5V-14.5L-8,-17.5L-5,-14.5V-6.5Z" fill="url(#muro)" stroke="{filo}" stroke-width="{f(ancho * 0.85)}" stroke-linejoin="round"/>',
        f'<rect x="-2.2" y="-4.6" width="3" height="3" rx="0.8" fill="#FFB347"/>',
    ]
    if not chico:
        convento += [
            '<path d="M-9.4,-9.5V-12A1.4,1.4 0 0 1 -6.6,-12V-9.5Z" fill="#3D1E5C"/>',
            '<rect x="3.2" y="-4.6" width="2.4" height="3" rx="0.8" fill="#FFB347" fill-opacity="0.8"/>',
            '<path d="M-11,-3H9" stroke="#E2C9B2" stroke-width="0.6"/>',
        ]
    cuerpo.append(f'<g transform="translate({f(cx)},{f(cy)}) scale({1.25 if chico else 1.15})">{"".join(convento)}</g>')
    # Destellos de la tarde.
    for r, a, tam in ([(80, 240, 7.5), (84, 284, 5.5), (79, 74, 6)] if not chico else [(81, 248, 8.5), (80, 76, 7.5)]):
        x, y = polar(r, a)
        cuerpo.append(estrella(x, y, tam, "#FFF6D8", filo, ancho * 0.7))
    if not chico:
        # Dos tijeretas sobre la bahía.
        for (x, y, s) in [(-60, -74, 1.0), (-48, -84, 0.75)]:
            cuerpo.append(f'<path d="M{f(x - 5 * s)},{f(y)}Q{f(x - 2.5 * s)},{f(y - 3 * s)} {f(x)},{f(y)}Q{f(x + 2.5 * s)},{f(y - 3 * s)} {f(x + 5 * s)},{f(y)}" '
                          f'fill="none" stroke="{filo}" stroke-width="1.2" stroke-linecap="round" stroke-linejoin="round"/>')
    return fondo, svg(defs, cuerpo)


MARCOS = {"muralla": muralla, "bahia": bahia, "castillo": castillo, "la_popa": la_popa}


def main() -> None:
    SALIDA.mkdir(parents=True, exist_ok=True)
    for nombre, dibujar in MARCOS.items():
        for detalle in ("vitrina", "chico"):
            fondo, frente = dibujar(detalle == "chico")
            (SALIDA / f"{nombre}_frente_{detalle}.svg").write_text(frente)
            destino = SALIDA / f"{nombre}_fondo_{detalle}.svg"
            if fondo:
                destino.write_text(fondo)
            elif destino.exists():
                destino.unlink()
    print("\n".join(sorted(p.name for p in SALIDA.glob("*.svg"))))


if __name__ == "__main__":
    main()
