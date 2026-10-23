"""Adaptadores de MongoDB para los puertos del dominio."""
from datetime import datetime

from bson import ObjectId
from pymongo import DESCENDING
from pymongo.database import Database
from pymongo.errors import DuplicateKeyError

from src.domain.models import (
    REPUTACION_INICIAL, CategoriaIncidente, EmailYaRegistrado, Incidente, TipoViajero, Usuario,
)


class MongoUserRepository:
    def __init__(self, db: Database):
        self._users = db.users

    def add(self, *, email: str, password_hash: str, nombre: str, tipo_viajero: TipoViajero,
            creado_en: datetime, terminos_aceptados_en: datetime) -> Usuario:
        doc = {
            "email": email,
            "password_hash": password_hash,
            "nombre": nombre,
            "tipo_viajero": tipo_viajero.value,
            "reputacion": REPUTACION_INICIAL,
            "terminos_aceptados_en": terminos_aceptados_en,
            "creado_en": creado_en,
        }
        try:
            self._users.insert_one(doc)  # agrega `_id` al documento
        except DuplicateKeyError:
            raise EmailYaRegistrado(email)
        return _to_usuario(doc)

    def get_by_email(self, email: str) -> Usuario | None:
        doc = self._users.find_one({"email": email})
        return _to_usuario(doc) if doc else None

    def get_by_id(self, user_id: str) -> Usuario | None:
        if not ObjectId.is_valid(user_id):
            return None
        doc = self._users.find_one({"_id": ObjectId(user_id)})
        return _to_usuario(doc) if doc else None


class MongoIncidentRepository:
    def __init__(self, db: Database):
        self._incidents = db.incidents

    def add(self, *, reportado_por: str, categoria: CategoriaIncidente, intensidad: int,
            latitud: float, longitud: float, creado_en: datetime, expira_en: datetime) -> Incidente:
        doc = {
            "reportado_por": ObjectId(reportado_por),
            "categoria": categoria.value,
            "intensidad": intensidad,
            # GeoJSON exige el orden [longitud, latitud].
            "ubicacion": {"type": "Point", "coordinates": [longitud, latitud]},
            "creado_en": creado_en,
            "expira_en": expira_en,
        }
        self._incidents.insert_one(doc)
        return _to_incidente(doc)

    def list_active(self, ahora: datetime, limite: int) -> list[Incidente]:
        # El índice TTL borra con hasta ~60 s de retraso; el filtro garantiza que solo salgan vigentes.
        cursor = (self._incidents.find({"expira_en": {"$gt": ahora}})
                  .sort("creado_en", DESCENDING).limit(limite))
        return [_to_incidente(doc) for doc in cursor]

    def find_active_within(self, area: dict, ahora: datetime) -> list[Incidente]:
        cursor = self._incidents.find({
            "ubicacion": {"$geoWithin": {"$geometry": area}},
            "expira_en": {"$gt": ahora},
        })
        return [_to_incidente(doc) for doc in cursor]


def _to_usuario(doc: dict) -> Usuario:
    return Usuario(
        id=str(doc["_id"]),
        email=doc["email"],
        nombre=doc["nombre"],
        tipo_viajero=TipoViajero(doc["tipo_viajero"]),
        reputacion=doc["reputacion"],
        password_hash=doc["password_hash"],
        creado_en=doc["creado_en"],
    )


def _to_incidente(doc: dict) -> Incidente:
    longitud, latitud = doc["ubicacion"]["coordinates"]
    return Incidente(
        id=str(doc["_id"]),
        reportado_por=str(doc["reportado_por"]),
        categoria=CategoriaIncidente(doc["categoria"]),
        intensidad=doc["intensidad"],
        latitud=latitud,
        longitud=longitud,
        creado_en=doc["creado_en"],
        expira_en=doc["expira_en"],
    )
