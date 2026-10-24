"""
Carga en MongoDB los datos de referencia versionados en backend/data/ (generados con
scripts/importar_osm.py, importar_horarios.py e importar_cruces.py): rutas, estaciones y horarios de
Transcaribe, lugares buscables de Cartagena y cruces de calles para nombrar los paraderos.
"""
import json
from pathlib import Path

from pymongo import ReplaceOne
from pymongo.collection import Collection
from pymongo.database import Database

DATA_DIR = Path(__file__).resolve().parents[2] / "data"


def cargar_datos_de_referencia(db: Database, forzar: bool = False) -> None:
    """Idempotente. Sin `forzar`, solo carga lo que esté vacío (una base que ya existía recibe los datos nuevos)."""
    if forzar or db.transit_routes.estimated_document_count() == 0:
        transcaribe = _leer("transcaribe.json")
        _reemplazar(db.transit_routes, transcaribe["rutas"])
        _reemplazar(db.stations, transcaribe["estaciones"])
        _reemplazar(db.places, _leer("lugares.json")["lugares"])
    if forzar or db.route_schedules.estimated_document_count() == 0:
        _reemplazar(db.route_schedules, _leer("horarios.json")["horarios"])
    if forzar or db.intersections.estimated_document_count() == 0:
        _reemplazar(db.intersections, _leer("cruces.json")["cruces"])


def _leer(nombre: str) -> dict:
    return json.loads((DATA_DIR / nombre).read_text(encoding="utf-8"))


def _reemplazar(coleccion: Collection, documentos: list[dict]) -> None:
    """Deja la colección igual a los datos: actualiza o crea cada documento y borra los que ya no están."""
    coleccion.bulk_write([ReplaceOne({"_id": d["_id"]}, d, upsert=True) for d in documentos])
    coleccion.delete_many({"_id": {"$nin": [d["_id"] for d in documentos]}})
