"""Adaptadores de MongoDB para los puertos del dominio."""
import re
from datetime import datetime

from bson import ObjectId
from pymongo import DESCENDING, ReturnDocument
from pymongo.database import Database
from pymongo.errors import DuplicateKeyError

from src.domain.models import (
    REPUTACION_INICIAL, CategoriaIncidente, EmailYaRegistrado, Estacion, IconoLugar, Incidente, LimiteLugaresGuardados,
    Lugar, LugarGuardado, LugarGuardadoNoEncontrado, RutaTransporte, TipoViajero, Usuario,
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


class MongoPlaceRepository:
    def __init__(self, db: Database):
        self._places = db.places

    def search(self, tokens: list[str], limite: int) -> list[Lugar]:
        # Cada token debe ser el comienzo de alguna palabra del nombre ("boca" → "bocagrande").
        # Los tokens solo tienen letras y números, y el índice sobre `tokens` atiende el prefijo anclado.
        filtro = {"tokens": {"$all": [re.compile("^" + re.escape(t)) for t in tokens]}}
        return [_to_lugar(doc) for doc in self._places.find(filtro).limit(limite)]

    def nearest(self, lon: float, lat: float, radio_m: float) -> tuple[Lugar, float] | None:
        docs = list(self._places.aggregate(_cercanos(lon, lat, radio_m, 1)))
        return (_to_lugar(docs[0]), docs[0]["distancia_m"]) if docs else None


class MongoTransitRepository:
    def __init__(self, db: Database):
        self._routes = db.transit_routes
        self._stations = db.stations

    def routes_intersecting_all(self, areas: list[dict]) -> list[RutaTransporte]:
        filtro = {"$and": [{"geometria": {"$geoIntersects": {"$geometry": area}}} for area in areas]}
        return [_to_ruta(doc) for doc in self._routes.find(filtro)]

    def list_stations(self) -> list[Estacion]:
        return [_to_estacion(doc) for doc in self._stations.find()]

    def stations_near(self, lon: float, lat: float, radio_m: float, limite: int) -> list[tuple[Estacion, float]]:
        return [(_to_estacion(doc), doc["distancia_m"])
                for doc in self._stations.aggregate(_cercanos(lon, lat, radio_m, limite))]


class MongoSavedPlaceRepository:
    """Los lugares guardados viven embebidos en el documento del usuario (`lugares_guardados`)."""

    def __init__(self, db: Database):
        self._users = db.users

    def list(self, user_id: str) -> list[LugarGuardado]:
        doc = self._users.find_one({"_id": ObjectId(user_id)}, {"lugares_guardados": 1}) or {}
        return [_to_lugar_guardado(lugar) for lugar in doc.get("lugares_guardados", [])]

    def add(self, user_id: str, *, nombre: str, icono: IconoLugar, latitud: float, longitud: float,
            maximo: int) -> LugarGuardado:
        lugar = {
            "_id": ObjectId(),
            "nombre": nombre,
            "icono": icono.value,
            "ubicacion": {"type": "Point", "coordinates": [longitud, latitud]},
        }
        # La condición y el $push son una sola operación atómica: dos peticiones simultáneas
        # no pueden dejar al usuario con más del máximo.
        resultado = self._users.update_one(
            {"_id": ObjectId(user_id), f"lugares_guardados.{maximo - 1}": {"$exists": False}},
            {"$push": {"lugares_guardados": lugar}},
        )
        if resultado.matched_count == 0:
            raise LimiteLugaresGuardados()
        return _to_lugar_guardado(lugar)

    def update(self, user_id: str, place_id: str, cambios: dict) -> LugarGuardado:
        if not ObjectId.is_valid(place_id):
            raise LugarGuardadoNoEncontrado()
        actualizacion = {}
        if "nombre" in cambios:
            actualizacion["lugares_guardados.$.nombre"] = cambios["nombre"]
        if "icono" in cambios:
            actualizacion["lugares_guardados.$.icono"] = IconoLugar(cambios["icono"]).value
        if "latitud" in cambios:
            actualizacion["lugares_guardados.$.ubicacion"] = {
                "type": "Point", "coordinates": [cambios["longitud"], cambios["latitud"]],
            }
        # El filtro incluye el _id del dueño: un usuario nunca puede modificar lugares de otro.
        doc = self._users.find_one_and_update(
            {"_id": ObjectId(user_id), "lugares_guardados._id": ObjectId(place_id)},
            {"$set": actualizacion},
            projection={"lugares_guardados": 1},
            return_document=ReturnDocument.AFTER,
        )
        if doc is None:
            raise LugarGuardadoNoEncontrado()
        lugar = next(l for l in doc["lugares_guardados"] if l["_id"] == ObjectId(place_id))
        return _to_lugar_guardado(lugar)

    def delete(self, user_id: str, place_id: str) -> None:
        if not ObjectId.is_valid(place_id):
            raise LugarGuardadoNoEncontrado()
        resultado = self._users.update_one(
            {"_id": ObjectId(user_id)},
            {"$pull": {"lugares_guardados": {"_id": ObjectId(place_id)}}},
        )
        if resultado.modified_count == 0:
            raise LugarGuardadoNoEncontrado()


def _cercanos(lon: float, lat: float, radio_m: float, limite: int) -> list[dict]:
    """Etapas de agregación: documentos dentro del radio, del más cercano al más lejano, con su distancia."""
    return [
        {"$geoNear": {
            "near": {"type": "Point", "coordinates": [lon, lat]},
            "distanceField": "distancia_m",
            "maxDistance": radio_m,
            "spherical": True,
        }},
        {"$limit": limite},
    ]


def _to_lugar(doc: dict) -> Lugar:
    longitud, latitud = doc["ubicacion"]["coordinates"]
    return Lugar(id=str(doc["_id"]), nombre=doc["nombre"], tipo=doc["tipo"], latitud=latitud, longitud=longitud)


def _to_lugar_guardado(doc: dict) -> LugarGuardado:
    longitud, latitud = doc["ubicacion"]["coordinates"]
    return LugarGuardado(id=str(doc["_id"]), nombre=doc["nombre"], icono=IconoLugar(doc["icono"]),
                         latitud=latitud, longitud=longitud)


def _to_estacion(doc: dict) -> Estacion:
    longitud, latitud = doc["ubicacion"]["coordinates"]
    return Estacion(id=doc["_id"], nombre=doc["nombre"], latitud=latitud, longitud=longitud, rutas=doc["rutas"])


def _to_ruta(doc: dict) -> RutaTransporte:
    return RutaTransporte(
        id=doc["_id"], nombre=doc["nombre"], tipo=doc["tipo"],
        coordenadas=[tuple(c) for c in doc["geometria"]["coordinates"]],
        cortes_en_osm=doc.get("cortes_en_osm", 0),
    )


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
