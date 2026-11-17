"""
Direcciones con la nomenclatura colombiana: «Calle 9 # 3-50» es la casa sobre la Calle 9, a 50 m del cruce con la
vía número 3, hacia la 4. OpenStreetMap casi no tiene direcciones con número en Cartagena (unas 500), pero sí las
calles y sus cruces: con eso basta para ubicar una dirección con 20 a 60 m de precisión, gratis y sin servicios
externos. Todo aquí es puro: sin base de datos ni HTTP.
"""
import math
import re
from dataclasses import dataclass

from src.domain.texto import normalizar

# Cómo escribe la gente cada tipo de vía (y cómo viene en los nombres de OpenStreetMap ya abreviados).
TIPOS_DE_VIA = {
    "calle": ("calle", "cll", "cl", "c"),
    "carrera": ("carrera", "cra", "kra", "kr", "cr", "carr", "k"),
    "transversal": ("transversal", "transv", "trans", "tv", "tr"),
    "diagonal": ("diagonal", "diag", "dg"),
}
_TIPO = {alias: tipo for tipo, alias_ in TIPOS_DE_VIA.items() for alias in alias_}
_ALIAS = "|".join(sorted(_TIPO, key=len, reverse=True))
# «10», «10A», «10 a», «21 bis», «45A Bis», «27A bis B». Una «n» o «no» seguida de un número no es letra de la vía
# sino «número»: «C 9 N° 3 50».
_NUMERO = r"\d{1,3}(?:\s*(?!no?\b\.?\s*\d)[a-z](?![a-z]))?(?:\s*bis)?(?:\s*(?!no?\b)[a-z](?![a-z]))?"

_DIRECCION = re.compile(
    rf"^(?P<tipo>{_ALIAS})\.?\s*(?P<numero>{_NUMERO})"
    rf"(?:\s*(?:#|no\.?|n|num(?:ero)?)?\s*(?P<cruce>{_NUMERO})"
    rf"(?:\s*-?\s*(?P<placa>\d{{1,3}}))?)?\s*$"
)
_VIA = re.compile(rf"^(?P<tipo>{_ALIAS})\.?\s*(?P<numero>{_NUMERO})$")

PLACA_MAXIMA_M = 200  # una cuadra en Cartagena rara vez pasa de esto; más es un error de escritura


@dataclass(frozen=True)
class Via:
    tipo: str      # calle, carrera, transversal o diagonal
    numero: str    # «9», «10a», «21bis»

    @property
    def clave(self) -> str:
        return f"{self.tipo}:{self.numero}"


@dataclass(frozen=True)
class Direccion:
    via: Via
    cruce: str | None = None   # número de la vía que cruza: «3», «8a»
    placa: int | None = None   # metros desde el cruce


@dataclass(frozen=True)
class Cruce:
    """Un punto donde se encuentran dos o más vías, con sus nombres tal como vienen de OpenStreetMap."""
    nombre: str
    vias: tuple[Via, ...]
    longitud: float
    latitud: float


@dataclass(frozen=True)
class Ubicacion:
    nombre: str          # «Calle 9 # 3-50»
    referencia: str      # «Cra. 3 con Calle 9»: el cruce desde el que se ubicó
    longitud: float
    latitud: float
    exacta: bool         # False si no se pudo avanzar la placa hacia la siguiente vía


def _limpiar_numero(texto: str) -> str:
    return re.sub(r"\s+", "", texto.lower())


def leer_via(texto: str) -> Via | None:
    """«Cra. 3» → Via(carrera, 3); «Dg. 21 Bis» → Via(diagonal, 21bis). None si no es una vía numerada."""
    m = _VIA.match(normalizar(texto).replace("º", "").strip())
    return Via(_TIPO[m.group("tipo")], _limpiar_numero(m.group("numero"))) if m else None


def leer_direccion(texto: str) -> Direccion | None:
    """«Calle 9 # 3-50», «cl 9 3 50», «Cra. 3 No. 8-129», «Tv 54 #21». None si no parece una dirección."""
    limpio = normalizar(texto).replace("º", "").replace("°", "").strip()
    m = _DIRECCION.match(limpio)
    if not m:
        return None
    via = Via(_TIPO[m.group("tipo")], _limpiar_numero(m.group("numero")))
    cruce = _limpiar_numero(m.group("cruce")) if m.group("cruce") else None
    placa = int(m.group("placa")) if m.group("placa") else None
    return Direccion(via=via, cruce=cruce, placa=placa if placa is None or placa <= PLACA_MAXIMA_M else None)


def vias_del_cruce(nombre: str) -> tuple[Via, ...]:
    """«Cra. 3 con Calle 9» → (carrera 3, calle 9); las vías con nombre propio no cuentan."""
    return tuple(v for parte in nombre.split(" con ") if (v := leer_via(parte)))


def distancia_m(a: tuple[float, float], b: tuple[float, float]) -> float:
    lat = math.radians((a[1] + b[1]) / 2)
    return math.hypot((b[0] - a[0]) * 111_320 * math.cos(lat), (b[1] - a[1]) * 110_540)


def _cruces_de(via: Via, numero: str, cruces: list[Cruce]) -> list[Cruce]:
    """Cruces de [via] con otra vía de número [numero] (de otro tipo: una calle se cruza con carreras)."""
    return [c for c in cruces if via in c.vias and any(v.numero == numero and v.tipo != via.tipo for v in c.vias)]


def ubicar(direccion: Direccion, cruces: list[Cruce], limite: int = 3) -> list[Ubicacion]:
    """
    Dónde queda la dirección. La numeración se repite en sectores distintos de la ciudad (hay una Calle 9 en
    Bocagrande y otra cerca de la Cra. 82): el número del cruce las distingue, y si aun así hay varias, salen todas.
    Sin número de cruce, la vía misma (su cruce central).
    """
    via = direccion.via
    nombre_via = f"{via.tipo.capitalize()} {via.numero.upper().replace('BIS', ' Bis')}"
    if direccion.cruce is None:
        de_la_via = sorted((c for c in cruces if via in c.vias), key=lambda c: (c.longitud, c.latitud))
        if not de_la_via:
            return []
        centro = de_la_via[len(de_la_via) // 2]
        return [Ubicacion(nombre_via, centro.nombre, centro.longitud, centro.latitud, exacta=False)]

    nombre = f"{nombre_via} # {direccion.cruce.upper().replace('BIS', ' Bis')}"
    if direccion.placa is not None:
        nombre += f"-{direccion.placa}"
    resultados: list[Ubicacion] = []
    for cruce in _cruces_de(via, direccion.cruce, cruces)[:limite]:
        origen = (cruce.longitud, cruce.latitud)
        punto, exacta = origen, direccion.placa in (None, 0)
        if direccion.placa:
            # La placa crece desde el cruce hacia la vía siguiente (la 4 si el cruce es con la 3).
            base = int(re.match(r"\d+", direccion.cruce).group())
            hacia = _mas_cercano(origen, _cruces_de(via, str(base + 1), cruces))
            desde = _mas_cercano(origen, _cruces_de(via, str(base - 1), cruces)) if base > 0 else None
            if hacia:
                punto, exacta = _avanzar(origen, (hacia.longitud, hacia.latitud), direccion.placa), True
            elif desde:
                punto, exacta = _avanzar(origen, (desde.longitud, desde.latitud), -direccion.placa), True
        resultados.append(Ubicacion(nombre, cruce.nombre, round(punto[0], 6), round(punto[1], 6), exacta))
    return resultados


def _mas_cercano(origen: tuple[float, float], candidatos: list[Cruce], maximo_m: float = 400) -> Cruce | None:
    """El cruce más cercano a [origen] entre [candidatos], si está a una cuadra razonable."""
    if not candidatos:
        return None
    mejor = min(candidatos, key=lambda c: distancia_m(origen, (c.longitud, c.latitud)))
    return mejor if distancia_m(origen, (mejor.longitud, mejor.latitud)) <= maximo_m else None


def _avanzar(origen: tuple[float, float], hacia: tuple[float, float], metros: float) -> tuple[float, float]:
    """[metros] desde [origen] en dirección a [hacia] (negativo: en sentido contrario), sin pasarse de la cuadra."""
    largo = distancia_m(origen, hacia)
    if largo == 0:
        return origen
    t = max(-1.0, min(1.0, metros / largo))
    return origen[0] + (hacia[0] - origen[0]) * t, origen[1] + (hacia[1] - origen[1]) * t
