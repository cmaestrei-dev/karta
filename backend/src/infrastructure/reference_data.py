"""
Carga en MongoDB los datos de referencia versionados en backend/data/ (generados con
scripts/importar_osm.py): rutas y estaciones de Transcaribe y lugares buscables de Cartagena.
"""
import json
from pathlib import Path

from pymongo import ReplaceOne
from pymongo.collection import Collection
from pymongo.database import Database

DATA_DIR = Path(__file__).resolve().parents[2] / "data"


def cargar_datos_de_referencia(db: Database, forzar: bool = False) -> None:
    """Idempotente. Sin `forzar`, solo carga si las colecciones están vacías."""
    if not forzar and db.transit_routes.estimated_document_count() > 0:
        return
    transcaribe = _leer("transcaribe.json")
    _reemplazar(db.transit_routes, transcaribe["rutas"])
    _reemplazar(db.stations, transcaribe["estaciones"])
    _reemplazar(db.places, _leer("lugares.json")["lugares"])


def _leer(nombre: str) -> dict:
    return json.loads((DATA_DIR / nombre).read_text(encoding="utf-8"))


def _reemplazar(coleccion: Collection, documentos: list[dict]) -> None:
    coleccion.bulk_write([ReplaceOne({"_id": d["_id"]}, d, upsert=True) for d in documentos])
