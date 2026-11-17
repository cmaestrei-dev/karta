"""
Carga en MongoDB los datos de referencia versionados en backend/data/ (generados con
scripts/importar_osm.py, importar_horarios.py e importar_cruces.py): rutas, estaciones y horarios de
Transcaribe, lugares buscables de Cartagena y cruces de calles para nombrar los paraderos.
"""
import hashlib
import json
from pathlib import Path

from pymongo import ReplaceOne
from pymongo.collection import Collection
from pymongo.database import Database

from src.domain.direcciones import vias_del_cruce
from src.infrastructure.repositories import REFERENCIA

DATA_DIR = Path(__file__).resolve().parents[2] / "data"


# Cada grupo de colecciones con los archivos de los que sale: si un archivo cambia, el grupo se recarga.
GRUPOS = {
    "transcaribe": ("transcaribe.json", "lugares.json"),
    "horarios": ("horarios.json",),
    "cruces": ("cruces.json",),
    "direcciones": ("nomenclatura.json", "cruces.json"),
    "paraderos": ("paraderos.json",),
}


def cargar_datos_de_referencia(db: Database, forzar: bool = False) -> None:
    """
    Idempotente. Carga lo que esté vacío y recarga lo que haya cambiado en backend/data/ desde la última carga
    (por la huella de sus archivos): así una base que ya existía recibe las estaciones o rutas nuevas al
    actualizar el servidor, sin borrar nada a mano.
    """
    def _cargar_transcaribe():
        transcaribe = _leer("transcaribe.json")
        _reemplazar(db.transit_routes, transcaribe["rutas"])
        _reemplazar(db.stations, transcaribe["estaciones"])
        _reemplazar(db.places, _leer("lugares.json")["lugares"])

    def _cargar_paraderos():
        paraderos = _leer("paraderos.json")
        _reemplazar(db.route_stops, paraderos["paraderos"])
        _reemplazar(db.route_directions, [{"_id": k, "hacia": v} for k, v in paraderos["hacia"].items()])

    cargas = {
        "transcaribe": (db.transit_routes, _cargar_transcaribe),
        "horarios": (db.route_schedules, lambda: _reemplazar(db.route_schedules, _leer("horarios.json")["horarios"])),
        "cruces": (db.intersections, lambda: _reemplazar(db.intersections, _leer("cruces.json")["cruces"])),
        "direcciones": (db.address_crossings, lambda: _reemplazar(db.address_crossings, cruces_para_direcciones())),
        "paraderos": (db.route_stops, _cargar_paraderos),
    }

    for grupo, (coleccion, cargar) in cargas.items():
        huella = _huella(GRUPOS[grupo])
        previa = db.reference_data.find_one({"_id": grupo})
        if forzar or coleccion.estimated_document_count() == 0 or not previa or previa.get("huella") != huella:
            cargar()
            db.reference_data.replace_one({"_id": grupo}, {"_id": grupo, "huella": huella}, upsert=True)
    REFERENCIA.limpiar()


def _huella(archivos: tuple[str, ...]) -> str:
    h = hashlib.sha256()
    for nombre in archivos:
        ruta = DATA_DIR / nombre
        h.update(nombre.encode())
        h.update(ruta.read_bytes() if ruta.exists() else b"")
    return h.hexdigest()


def cruces_para_direcciones() -> list[dict]:
    """
    Los cruces con alguna vía numerada, con sus vías como claves («calle:9») para buscar direcciones. Salen de
    nomenclatura.json (toda la ciudad) si existe; si no, de los cruces cercanos a las rutas.
    """
    origen = DATA_DIR / "nomenclatura.json"
    cruces = _leer(origen.name)["cruces"] if origen.exists() else _leer("cruces.json")["cruces"]
    resultado = []
    for c in cruces:
        # nomenclatura.json trae todas las vías del cruce; cruces.json, solo las dos principales en el nombre.
        vias = [v for nombre in c.get("vias", []) if (v := vias_del_cruce(nombre))] or [vias_del_cruce(c["nombre"])]
        claves = sorted({via.clave for grupo in vias for via in grupo})
        if claves:
            resultado.append({"_id": c["_id"], "nombre": c["nombre"], "ubicacion": c["ubicacion"], "vias": claves})
    return resultado


def _leer(nombre: str) -> dict:
    return json.loads((DATA_DIR / nombre).read_text(encoding="utf-8"))


def _reemplazar(coleccion: Collection, documentos: list[dict]) -> None:
    """Deja la colección igual a los datos: actualiza o crea cada documento y borra los que ya no están."""
    coleccion.bulk_write([ReplaceOne({"_id": d["_id"]}, d, upsert=True) for d in documentos])
    coleccion.delete_many({"_id": {"$nin": [d["_id"] for d in documentos]}})
