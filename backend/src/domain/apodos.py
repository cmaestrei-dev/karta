"""
Los apodos que escriben los viajeros (docs/plan-juego.md): el apodo del día de una estación y el apodo de karteño con
que se muestra una corona. Son textos libres que ve todo el mundo, en una app para todo público, así que antes de
publicarse pasan por aquí. Lo que el filtro no atrape lo ocultan los reportes de la comunidad. Todo aquí es puro.
"""
import re
import unicodedata

LARGO_MAXIMO = 30
LARGO_MINIMO = 3


class ApodoRechazado(ValueError):
    """El motivo, en palabras para el viajero."""


# Groserías, insultos y contenido para adultos, como se escriben en Colombia. Se buscan como palabras enteras sobre
# el texto normalizado (sin tildes, sin letras repetidas y con los números de «leetspeak» vueltos letras). Las
# palabras de uso común con otro sentido («muere de calor», «a la derecha», «la venta de fritos», «la Alcaldía»)
# no están: esas las cuida la comunidad con los reportes.
_GROSERIAS = {
    "hp", "hpta", "hijueputa", "jueputa", "gonorrea", "malparido", "malparida", "marica", "marico", "maricon",
    "puta", "puto", "putas", "putos", "mierda", "verga", "vergas", "chimba", "chimbo", "culo", "culos", "cono",
    "pendejo", "pendeja", "imbecil", "idiota", "estupido", "estupida", "cabron", "perra", "zorra", "mamaguevo",
    "mamahuevo", "careverga", "carechimba", "caremonda", "monda", "hijodeputa", "joda", "jodase", "culiar",
    "culear", "follar", "polla", "pene", "vagina", "teta", "tetas", "sexo", "porno", "xxx", "violar", "violacion",
    "matar", "mueranse", "nazi", "marihuana", "bareta", "cocaina", "basuco",
}
# Propaganda política: Karta no es una valla.
_POLITICA = {
    "vota", "votar", "voten", "votemos", "candidato", "candidata", "elecciones", "senado", "concejo", "concejal",
    "alcalde", "gobernador", "presidente", "petro", "uribe", "pacto", "uribismo", "petrismo", "liberal",
    "conservador", "conservadores",
}
# Ventas y redes sociales: el apodo no es publicidad gratis (Karta no tiene anuncios).
_COMERCIO = {
    "promo", "promocion", "descuento", "descuentos", "oferta", "ofertas", "ventas", "vendo", "compre",
    "domicilio", "domicilios", "whatsapp", "wasap", "instagram", "insta", "tiktok",
    "facebook", "telegram", "sigueme", "siguenos", "link",
}

_LEET = str.maketrans({"0": "o", "1": "i", "3": "e", "4": "a", "5": "s", "7": "t", "@": "a", "$": "s"})
_ENLACE = re.compile(r"(https?:|www\.|\.(com|co|net|org|io|me|ly)\b|wa\.me)", re.I)
_PERMITIDOS = re.compile(r"^[\w\sáéíóúüñÁÉÍÓÚÜÑ.,¡!¿?'\-«»\"()]+$")


def _normalizado(texto: str) -> str:
    sin_tildes = unicodedata.normalize("NFKD", texto.lower()).encode("ascii", "ignore").decode()
    return re.sub(r"(.)\1{2,}", r"\1", sin_tildes.translate(_LEET))  # «putaaa» → «puta»


def _palabras(normalizado: str) -> list[str]:
    return [p for p in re.split(r"[^a-z0-9]+", normalizado) if p]


def revisar_apodo(texto: str) -> str:
    """El apodo limpio (espacios de más quitados) o ApodoRechazado con el motivo."""
    limpio = re.sub(r"\s+", " ", texto or "").strip()
    if len(limpio) < LARGO_MINIMO:
        raise ApodoRechazado(f"Escribe al menos {LARGO_MINIMO} letras.")
    if len(limpio) > LARGO_MAXIMO:
        raise ApodoRechazado(f"Máximo {LARGO_MAXIMO} caracteres.")
    if not re.search(r"[a-zA-ZáéíóúñÁÉÍÓÚÑ]", limpio):
        raise ApodoRechazado("Ponle al menos una palabra.")
    if "@" in limpio or "#" in limpio or _ENLACE.search(limpio):
        raise ApodoRechazado("Sin enlaces, @ ni #: el apodo no es para promocionar nada.")
    if len(re.sub(r"\D", "", limpio)) >= 7:
        raise ApodoRechazado("Sin números de teléfono.")
    if not _PERMITIDOS.match(limpio):
        raise ApodoRechazado("Usa solo letras, números y signos de puntuación (sin emojis).")
    normal = _normalizado(limpio)
    palabras = set(_palabras(normal))
    # Partidas también cuentan: «hijue puta», «malpa rido».
    pegado = re.sub(r"[^a-z]", "", normal)
    if palabras & _GROSERIAS or any(g in pegado for g in _GROSERIAS if len(g) >= 6):
        raise ApodoRechazado("Ese apodo tiene palabras que no van: Karta es para todo público.")
    if palabras & _POLITICA:
        raise ApodoRechazado("Sin política: el apodo es para el paradero, no para campañas.")
    if palabras & _COMERCIO:
        raise ApodoRechazado("Sin ventas ni redes sociales: Karta no tiene anuncios.")
    return limpio
