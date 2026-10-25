"""Adaptadores de MongoDB para los puertos del dominio."""
import math
import re
import secrets
from datetime import datetime, timedelta, timezone

from bson import ObjectId
from pymongo import DESCENDING, ReturnDocument
from pymongo.database import Database
from pymongo.errors import DuplicateKeyError

from src.domain.models import (
    REPUTACION_INICIAL, EmailYaRegistrado, Estacion, IconoLugar, Incidente, LimiteLugaresGuardados,
    Lugar, LugarGuardado, LugarGuardadoNoEncontrado, RutaTransporte, TipoViajero, Usuario,
)
from src.domain.horarios import HorarioRuta
from src.domain.reportes import TipoReporte, VotoRepetido, alias_publico
from src.domain.tiempo_real import Observacion, Ocupacion


class MongoUserRepository:
    def __init__(self, db: Database):
        self._users = db.users

    def add(self, *, email: str, password_hash: str, nombre: str, alias: str, tipo_viajero: TipoViajero,
            creado_en: datetime, terminos_aceptados_en: datetime) -> Usuario:
        doc = {
            "email": email,
            "password_hash": password_hash,
            "nombre": nombre,
            "alias": alias,
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

    def ajustar_reputacion(self, user_id: str, delta: int) -> None:
        if ObjectId.is_valid(user_id):
            self._users.update_one({"_id": ObjectId(user_id)}, {"$inc": {"reputacion": delta}})


class MongoIncidentRepository:
    """Reportes en `incidents` (con TTL sobre `expira_en`) y sus votos en `incident_votes`."""

    # Los votos se guardan un poco más que cualquier reporte, solo para impedir votos repetidos.
    VIDA_DE_LOS_VOTOS = timedelta(days=2)

    def __init__(self, db: Database):
        self._incidents = db.incidents
        self._votes = db.incident_votes

    def add(self, *, reportado_por: str, tipo: TipoReporte, detalles: dict[str, str], latitud: float,
            longitud: float, lugar: str | None, creado_en: datetime, expira_en: datetime) -> Incidente:
        doc = {
            "reportado_por": ObjectId(reportado_por),
            "grupo": tipo.grupo.value,
            "tipo": tipo.clave,
            "detalles": detalles,
            # GeoJSON exige el orden [longitud, latitud].
            "ubicacion": {"type": "Point", "coordinates": [longitud, latitud]},
            "lugar": lugar,
            "votos_si": 0,
            "votos_no": 0,
            "no_seguidos": 0,
            "creado_en": creado_en,
            "expira_en": expira_en,
        }
        self._incidents.insert_one(doc)
        return _to_incidente(doc)

    def get_active(self, incidente_id: str, ahora: datetime) -> Incidente | None:
        if not ObjectId.is_valid(incidente_id):
            return None
        doc = self._incidents.find_one({"_id": ObjectId(incidente_id), "expira_en": {"$gt": ahora}})
        return _to_incidente(doc) if doc else None

    def list_active(self, ahora: datetime, limite: int, caja: tuple[float, float, float, float] | None = None
                    ) -> list[Incidente]:
        # El índice TTL borra con hasta ~60 s de retraso; el filtro garantiza que solo salgan vigentes.
        filtro: dict = {"expira_en": {"$gt": ahora}}
        if caja is not None:
            lon_min, lat_min, lon_max, lat_max = caja
            filtro["ubicacion"] = {"$geoWithin": {"$box": [[lon_min, lat_min], [lon_max, lat_max]]}}
        cursor = self._incidents.find(filtro).sort("creado_en", DESCENDING).limit(limite)
        return [_to_incidente(doc) for doc in cursor]

    def find_active_within(self, area: dict, ahora: datetime) -> list[Incidente]:
        cursor = self._incidents.find({
            "ubicacion": {"$geoWithin": {"$geometry": area}},
            "expira_en": {"$gt": ahora},
        })
        return [_to_incidente(doc) for doc in cursor]

    def register_vote(self, incidente_id: str, usuario_id: str, sigue: bool, ahora: datetime) -> None:
        try:
            self._votes.insert_one({
                "incidente": ObjectId(incidente_id), "usuario": ObjectId(usuario_id), "sigue": sigue,
                "en": ahora, "expira_en": ahora + self.VIDA_DE_LOS_VOTOS,
            })
        except DuplicateKeyError:
            raise VotoRepetido()

    def apply_confirmation(self, incidente_id: str, nueva_expiracion: datetime) -> Incidente:
        doc = self._incidents.find_one_and_update(
            {"_id": ObjectId(incidente_id)},
            {"$inc": {"votos_si": 1}, "$set": {"no_seguidos": 0}, "$max": {"expira_en": nueva_expiracion}},
            return_document=ReturnDocument.AFTER,
        )
        return _to_incidente(doc)

    def apply_denial(self, incidente_id: str) -> tuple[Incidente, int]:
        doc = self._incidents.find_one_and_update(
            {"_id": ObjectId(incidente_id)},
            {"$inc": {"votos_no": 1, "no_seguidos": 1}},
            return_document=ReturnDocument.AFTER,
        )
        return _to_incidente(doc), doc["no_seguidos"]

    def retire(self, incidente_id: str, ahora: datetime) -> None:
        self._incidents.update_one({"_id": ObjectId(incidente_id)}, {"$set": {"expira_en": ahora}})

    def vote_of(self, incidente_id: str, usuario_id: str) -> bool | None:
        if not (ObjectId.is_valid(incidente_id) and ObjectId.is_valid(usuario_id)):
            return None
        voto = self._votes.find_one({"incidente": ObjectId(incidente_id), "usuario": ObjectId(usuario_id)})
        return voto["sigue"] if voto else None


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
        self._schedules = db.route_schedules
        self._intersections = db.intersections

    def routes_intersecting_all(self, areas: list[dict]) -> list[RutaTransporte]:
        filtro = {"$and": [{"geometria": {"$geoIntersects": {"$geometry": area}}} for area in areas]}
        return [_to_ruta(doc) for doc in self._routes.find(filtro)]

    def routes_intersecting_any(self, areas: list[dict]) -> list[RutaTransporte]:
        filtro = {"$or": [{"geometria": {"$geoIntersects": {"$geometry": area}}} for area in areas]}
        return [_to_ruta(doc) for doc in self._routes.find(filtro)]

    def schedules(self) -> dict[str, HorarioRuta]:
        return {doc["_id"]: HorarioRuta.desde_texto(doc["_id"], doc) for doc in self._schedules.find()}

    def intersection_near(self, lon: float, lat: float, radio_m: float) -> str | None:
        doc = self._intersections.find_one({"ubicacion": {"$nearSphere": {
            "$geometry": {"type": "Point", "coordinates": [lon, lat]}, "$maxDistance": radio_m}}})
        return doc["nombre"] if doc else None

    def list_stations(self) -> list[Estacion]:
        return [_to_estacion(doc) for doc in self._stations.find()]

    def stations_near(self, lon: float, lat: float, radio_m: float, limite: int) -> list[tuple[Estacion, float]]:
        return [(_to_estacion(doc), doc["distancia_m"])
                for doc in self._stations.aggregate(_cercanos(lon, lat, radio_m, limite))]

    def list_routes(self, tipo: str | None = None) -> list[RutaTransporte]:
        filtro = {"tipo": tipo} if tipo else {}
        return [_to_ruta(doc) for doc in self._routes.find(filtro).sort("_id")]

    def route_codes(self) -> set[str]:
        return set(self._routes.distinct("_id"))

    def route(self, codigo: str) -> RutaTransporte | None:
        doc = self._routes.find_one({"_id": codigo})
        return _to_ruta(doc) if doc else None


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
        desde=doc.get("desde", ""), hasta=doc.get("hasta", ""),
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
        # Usuarios creados antes de que existiera el alias lo derivan de su nombre.
        alias=doc.get("alias") or alias_publico(doc["nombre"]),
    )


def _to_incidente(doc: dict) -> Incidente:
    longitud, latitud = doc["ubicacion"]["coordinates"]
    return Incidente(
        id=str(doc["_id"]),
        reportado_por=str(doc["reportado_por"]),
        grupo=doc["grupo"],
        tipo=doc["tipo"],
        detalles=doc.get("detalles", {}),
        latitud=latitud,
        longitud=longitud,
        lugar=doc.get("lugar"),
        votos_si=doc.get("votos_si", 0),
        votos_no=doc.get("votos_no", 0),
        creado_en=doc["creado_en"],
        expira_en=doc["expira_en"],
    )


ZONA_UTC = timezone.utc


class MongoRateLimiter:
    """Límite de peticiones por ventana fija en `rate_limits`; cada ventana vence sola con un índice TTL."""

    def __init__(self, db: Database):
        self._limites = db.rate_limits

    def hit(self, clave: str, limite: int, ventana: timedelta) -> int | None:
        ahora = datetime.now(tz=ZONA_UTC)
        segundos = int(ventana.total_seconds())
        inicio = int(ahora.timestamp()) // segundos * segundos
        doc = self._limites.find_one_and_update(
            {"_id": f"{clave}:{inicio}"},
            {"$inc": {"conteo": 1}, "$setOnInsert": {"expira_en": datetime.fromtimestamp(inicio + segundos, ZONA_UTC)}},
            upsert=True, return_document=ReturnDocument.AFTER,
        )
        if doc["conteo"] <= limite:
            return None
        return max(1, math.ceil(inicio + segundos - ahora.timestamp()))


class MongoRealtimeRepository:
    """
    Avistamientos (`sightings`, vencen a los 30 min) y viajes compartidos (`live_trips`, un documento por viaje que
    se sobrescribe y vence 5 min después de la última posición). Ningún documento guarda al viajero: no hay
    historial de ubicaciones de nadie (Ley 1581).
    """
    VIGENCIA_AVISTAMIENTO = timedelta(minutes=30)
    VIGENCIA_VIAJE = timedelta(minutes=5)

    def __init__(self, db: Database):
        self._sightings = db.sightings
        self._trips = db.live_trips

    def add_sighting(self, ruta: str, longitud: float, latitud: float, ocupacion: Ocupacion | None,
                     en: datetime) -> None:
        self._sightings.insert_one({
            "ruta": ruta, "ubicacion": {"type": "Point", "coordinates": [longitud, latitud]},
            "ocupacion": ocupacion.value if ocupacion else None,
            "en": en, "expira_en": en + self.VIGENCIA_AVISTAMIENTO,
        })

    def start_trip(self, ruta: str, longitud: float, latitud: float, en: datetime) -> str:
        viaje = secrets.token_urlsafe(16)
        self._trips.insert_one({
            "_id": viaje, "ruta": ruta, "ubicacion": {"type": "Point", "coordinates": [longitud, latitud]},
            "ocupacion": None, "en": en, "expira_en": en + self.VIGENCIA_VIAJE,
        })
        return viaje

    def update_trip(self, viaje: str, longitud: float, latitud: float, ocupacion: Ocupacion | None,
                    en: datetime) -> bool:
        cambios = {"ubicacion": {"type": "Point", "coordinates": [longitud, latitud]}, "en": en,
                   "expira_en": en + self.VIGENCIA_VIAJE}
        if ocupacion:
            cambios["ocupacion"] = ocupacion.value
        # El TTL de MongoDB barre cada minuto: un viaje vencido puede seguir ahí unos segundos.
        resultado = self._trips.update_one({"_id": viaje, "expira_en": {"$gt": en}}, {"$set": cambios})
        return resultado.matched_count == 1

    def end_trip(self, viaje: str) -> None:
        self._trips.delete_one({"_id": viaje})

    def observations(self, ruta: str, desde: datetime) -> list[Observacion]:
        def observacion(doc: dict, en_vivo: bool) -> Observacion:
            lon, lat = doc["ubicacion"]["coordinates"]
            return Observacion(longitud=lon, latitud=lat, en=doc["en"], en_vivo=en_vivo,
                               ocupacion=Ocupacion(doc["ocupacion"]) if doc.get("ocupacion") else None)
        filtro = {"ruta": ruta, "en": {"$gte": desde}}
        return ([observacion(d, True) for d in self._trips.find({**filtro, "expira_en": {"$gt": desde}})]
                + [observacion(d, False) for d in self._sightings.find(filtro)])
