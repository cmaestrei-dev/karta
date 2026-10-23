"""Normalización de texto para búsquedas sin tildes ni mayúsculas."""
import re
import unicodedata


def normalizar(texto: str) -> str:
    sin_tildes = unicodedata.normalize("NFKD", texto).encode("ascii", "ignore").decode()
    return sin_tildes.lower().strip()


def tokens(texto: str) -> list[str]:
    """Palabras normalizadas, sin repetir: "Estación Bazurto" → ["bazurto", "estacion"]."""
    return sorted(set(t for t in re.split(r"[^a-z0-9]+", normalizar(texto)) if t))
