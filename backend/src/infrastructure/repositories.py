"""Adaptadores de MongoDB para los puertos del dominio."""
import math
import re
import secrets
from datetime import datetime, timedelta, timezone

from bson import ObjectId
from pymongo import DESCENDING, ReturnDocument
from pymongo.database import Database
from pymongo.errors import DuplicateKeyError

from src.domain.conocimiento import ComoSePidio, RespuestaDeParada
from src.domain.direcciones import Cruce, Via
from src.domain.mapeo import EstadoDeMarca, Marca, Voto
from src.domain.paraderos import ParaderoOficial
from src.domain.precision import BusMedido, ResultadoDeViaje
from src.domain.models import (
    ALIAS_SIN_CUENTA, REPUTACION_INICIAL, EmailYaRegistrado, Impacto, Estacion, IconoLugar, Incidente, LimiteLugaresGuardados,
    Lugar, LugarGuardado, LugarGuardadoNoEncontrado, RutaTransporte, TipoViajero, Usuario,
)
from src.domain.horarios import HorarioRuta, en_colombia
from src.domain.reportes import GraciasRepetidas, TipoReporte, VotoRepetido, alias_publico
from src.domain.tiempo_real import Observacion, Ocupacion


# Quien borró su cuenta: lo que aportó al mapa común queda a nombre de nadie.
ANONIMO = ObjectId("000000000000000000000000")


class MongoUserRepository:
    def __init__(self, db: Database):
        self._db = db
        self._users = db.users

    def autorizar(self, user_id: str, version: str, en: datetime) -> None:
        # Cada aceptación queda como prueba (Decreto 1074, art. 2.2.2.25.2.5): la versión y cuándo.
        self._users.update_one({"_id": ObjectId(user_id)},
                               {"$push": {"autorizaciones": {"version": version, "en": en}}})

    def erase(self, user_id: str) -> None:
        uid = ObjectId(user_id)
        db = self._db
        # Lo comunitario queda, desligado: los reportes y las marcas de paraderos, con sus votos.
        db.incidents.update_many({"reportado_por": uid}, {"$set": {"reportado_por": ANONIMO}})
        db.stop_marks.update_many({"propuesto_por": uid}, {"$set": {"propuesto_por": ANONIMO}})
        db.stop_marks.update_many({"votos.usuario": uid}, {"$set": {"votos.$[voto].usuario": ANONIMO}},
                                  array_filters=[{"voto.usuario": uid}])
        # Lo que solo sirve para esa persona se borra: sus votos, «Gracias», vistas y límites de peticiones.
        for coleccion in (db.incident_votes, db.incident_thanks, db.incident_views):
            coleccion.delete_many({"usuario": uid})
        db.rate_limits.delete_many({"_id": {"$regex": f"^[^:]+:usuario:{re.escape(user_id)}:"}})
        # Y la cuenta, con sus lugares guardados, su reputación y su impacto.
        self._users.delete_one({"_id": uid})

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

    def sumar_impacto(self, user_id: str, campo: str, cantidad: int = 1) -> None:
        if ObjectId.is_valid(user_id) and campo in Impacto.__dataclass_fields__:
            self._users.update_one({"_id": ObjectId(user_id)}, {"$inc": {f"impacto.{campo}": cantidad}})

    def add_invisible(self, *, huella: str, creado_en: datetime) -> Usuario:
        doc = {
            "secreto": huella,
            "anonimo": True,
            "alias": ALIAS_SIN_CUENTA,
            "reputacion": REPUTACION_INICIAL,
            "creado_en": creado_en,
            "visto_en": creado_en,
        }
        try:
            self._users.insert_one(doc)
        except DuplicateKeyError:  # dos peticiones a la vez con el mismo secreto: gana la primera
            return self.get_by_secret(huella)
        return _to_usuario(doc)

    def get_by_secret(self, huella: str) -> Usuario | None:
        doc = self._users.find_one({"secreto": huella})
        return _to_usuario(doc) if doc else None

    def touch(self, user_id: str, ahora: datetime) -> None:
        if ObjectId.is_valid(user_id):
            self._users.update_one({"_id": ObjectId(user_id), "anonimo": True}, {"$set": {"visto_en": ahora}})

    def upgrade(self, user_id: str, *, email: str, password_hash: str, nombre: str, alias: str,
                tipo_viajero: TipoViajero, terminos_aceptados_en: datetime) -> Usuario:
        try:
            doc = self._users.find_one_and_update(
                {"_id": ObjectId(user_id), "anonimo": True},
                {"$set": {"email": email, "password_hash": password_hash, "nombre": nombre, "alias": alias,
                          "tipo_viajero": tipo_viajero.value, "terminos_aceptados_en": terminos_aceptados_en},
                 "$unset": {"secreto": "", "anonimo": "", "visto_en": ""}},
                return_document=ReturnDocument.AFTER,
            )
        except DuplicateKeyError:
            raise EmailYaRegistrado(email)
        if doc is None:
            raise ValueError("Esa cuenta ya tiene correo.")
        return _to_usuario(doc)


class MongoIncidentRepository:
    """Reportes en `incidents` (con TTL sobre `expira_en`) y sus votos en `incident_votes`."""

    # Los votos se guardan un poco más que cualquier reporte, solo para impedir votos repetidos.
    VIDA_DE_LOS_VOTOS = timedelta(days=2)

    def __init__(self, db: Database):
        self._incidents = db.incidents
        self._votes = db.incident_votes
        self._thanks = db.incident_thanks
        self._views = db.incident_views

    def reward_voters(self, incidente_id: str, sigue: bool, excepto: str | None = None) -> list[str]:
        filtro: dict = {"incidente": ObjectId(incidente_id), "sigue": sigue, "premiado": {"$ne": True}}
        if excepto and ObjectId.is_valid(excepto):
            filtro["usuario"] = {"$ne": ObjectId(excepto)}
        votantes = [str(v["usuario"]) for v in self._votes.find(filtro, {"usuario": 1})]
        self._votes.update_many(filtro, {"$set": {"premiado": True}})
        return votantes

    def register_thanks(self, incidente_id: str, usuario_id: str, ahora: datetime) -> Incidente:
        try:
            self._thanks.insert_one({"incidente": ObjectId(incidente_id), "usuario": ObjectId(usuario_id),
                                     "en": ahora, "expira_en": ahora + self.VIDA_DE_LOS_VOTOS})
        except DuplicateKeyError:
            raise GraciasRepetidas()
        doc = self._incidents.find_one_and_update({"_id": ObjectId(incidente_id)}, {"$inc": {"gracias": 1}},
                                                  return_document=ReturnDocument.AFTER)
        return _to_incidente(doc)

    def thanks_of(self, incidente_id: str, usuario_id: str) -> bool:
        if not (ObjectId.is_valid(incidente_id) and ObjectId.is_valid(usuario_id)):
            return False
        return self._thanks.count_documents(
            {"incidente": ObjectId(incidente_id), "usuario": ObjectId(usuario_id)}, limit=1) > 0

    def register_view(self, incidente_id: str, usuario_id: str, ahora: datetime) -> bool:
        try:
            self._views.insert_one({"incidente": ObjectId(incidente_id), "usuario": ObjectId(usuario_id),
                                    "en": ahora, "expira_en": ahora + self.VIDA_DE_LOS_VOTOS})
            return True
        except DuplicateKeyError:
            return False

    def add(self, *, reportado_por: str, tipo: TipoReporte, detalles: dict[str, str], latitud: float,
            longitud: float, lugar: str | None, creado_en: datetime, expira_en: datetime,
            sin_cuenta: bool = False, nivel_autor: int = 1) -> Incidente:
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
            "sin_cuenta": sin_cuenta,
            "nivel_autor": nivel_autor,
            "gracias": 0,
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

    def active_for_route(self, tipo: str, ruta: str, ahora: datetime) -> list[Incidente]:
        cursor = self._incidents.find({"tipo": tipo, "detalles.ruta": ruta, "expira_en": {"$gt": ahora}})
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
        self._crossings = db.address_crossings

    def crossings_on(self, via_clave: str) -> list[Cruce]:
        return [Cruce(nombre=d["nombre"], vias=tuple(Via(*v.split(":", 1)) for v in d["vias"]),
                      longitud=d["ubicacion"]["coordinates"][0], latitud=d["ubicacion"]["coordinates"][1])
                for d in self._crossings.find({"vias": via_clave})]

    def search(self, tokens: list[str], limite: int) -> list[Lugar]:
        # Cada token debe ser el comienzo de alguna palabra del nombre ("boca" → "bocagrande").
        # Los tokens solo tienen letras y números, y el índice sobre `tokens` atiende el prefijo anclado.
        filtro = {"tokens": {"$all": [re.compile("^" + re.escape(t)) for t in tokens]}}
        return [_to_lugar(doc) for doc in self._places.find(filtro).limit(limite)]

    def nearest(self, lon: float, lat: float, radio_m: float, tipo: str | None = None) -> tuple[Lugar, float] | None:
        docs = list(self._places.aggregate(_cercanos(lon, lat, radio_m, 1, {"tipo": tipo} if tipo else None)))
        return (_to_lugar(docs[0]), docs[0]["distancia_m"]) if docs else None


class MongoTransitRepository:
    def __init__(self, db: Database):
        self._routes = db.transit_routes
        self._stations = db.stations
        self._schedules = db.route_schedules
        self._intersections = db.intersections
        self._official_stops = db.route_stops
        self._directions = db.route_directions
        self._marks = db.stop_marks

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

    def official_stops(self, rutas: list[str] | None = None) -> list[ParaderoOficial]:
        filtro = {"ruta": {"$in": rutas}} if rutas is not None else {}
        return [p for p in _paraderos_con_comunidad(self._official_stops, self._marks, filtro) if p.longitud is not None]

    def directions(self) -> dict[str, str]:
        return {d["_id"]: d["hacia"] for d in self._directions.find()}

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


def _cercanos(lon: float, lat: float, radio_m: float, limite: int, filtro: dict | None = None) -> list[dict]:
    """Etapas de agregación: documentos dentro del radio, del más cercano al más lejano, con su distancia."""
    return [
        {"$geoNear": {
            "near": {"type": "Point", "coordinates": [lon, lat]},
            "distanceField": "distancia_m",
            "maxDistance": radio_m,
            "spherical": True,
            **({"query": filtro} if filtro else {}),
        }},
        {"$limit": limite},
    ]


def _to_lugar(doc: dict) -> Lugar:
    longitud, latitud = doc["ubicacion"]["coordinates"]
    return Lugar(id=str(doc["_id"]), nombre=doc["nombre"], tipo=doc["tipo"], latitud=latitud, longitud=longitud,
                 detalle=f"{doc['tipo']} · {doc['zona']}" if doc.get("zona") else None)


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
        email=doc.get("email"),
        nombre=doc.get("nombre"),
        tipo_viajero=TipoViajero(doc["tipo_viajero"]) if doc.get("tipo_viajero") else None,
        reputacion=doc["reputacion"],
        password_hash=doc.get("password_hash"),
        creado_en=doc["creado_en"],
        # Usuarios creados antes de que existiera el alias lo derivan de su nombre.
        alias=doc.get("alias") or (alias_publico(doc["nombre"]) if doc.get("nombre") else ALIAS_SIN_CUENTA),
        impacto=Impacto(**{k: v for k, v in doc.get("impacto", {}).items() if k in Impacto.__dataclass_fields__}),
        autorizacion=doc["autorizaciones"][-1]["version"] if doc.get("autorizaciones") else None,
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
        por_confirmar=doc.get("sin_cuenta", False) and doc.get("votos_si", 0) == 0,
        nivel_autor=doc.get("nivel_autor", 1),
        gracias=doc.get("gracias", 0),
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


def _a_paradero(d: dict, marca: dict | None = None) -> ParaderoOficial:
    ubicacion = (d.get("ubicacion") or (marca or {}).get("ubicacion") or {}).get("coordinates")
    return ParaderoOficial(ruta=d["ruta"], sentido=d["sentido"], orden=d["orden"], nombre=d["nombre"],
                           estacion=d.get("estacion"), modulo=d.get("modulo"),
                           precision=d.get("precision") or ("comunidad" if marca else None),
                           longitud=ubicacion[0] if ubicacion else None, latitud=ubicacion[1] if ubicacion else None,
                           id=d["_id"])


def _paraderos_con_comunidad(paraderos, marcas, filtro: dict) -> list[ParaderoOficial]:
    """Los paraderos oficiales con la ubicación que les dio la comunidad (las marcas viven aparte: recargar el
    archivo oficial no las borra)."""
    ubicadas = {m["paradero"]: m for m in marcas.find({**filtro, "estado": EstadoDeMarca.UBICADA.value})}
    return [_a_paradero(d, None if "ubicacion" in d else ubicadas.get(d["_id"]))
            for d in paraderos.find(filtro).sort([("sentido", 1), ("orden", 1)])]


def _a_marca(d: dict) -> Marca:
    lon, lat = d["ubicacion"]["coordinates"]
    return Marca(id=str(d["_id"]), paradero=d["paradero"], ruta=d["ruta"], longitud=lon, latitud=lat,
                 propuesto_por=str(d["propuesto_por"]), apoyo=d["apoyo"],
                 votos=tuple(Voto(str(v["usuario"]), v["esta_aqui"], v["peso"]) for v in d.get("votos", [])),
                 estado=EstadoDeMarca(d["estado"]), creado_en=d["creado_en"])


class MongoStopMappingRepository:
    """Marcas de paraderos (`stop_marks`) y subidas anónimas a las rutas (`boardings`, vencen a los 180 días)."""
    VIGENCIA_DE_SUBIDA = timedelta(days=180)

    def __init__(self, db: Database):
        self._paraderos = db.route_stops
        self._marcas = db.stop_marks
        self._subidas = db.boardings

    def route_stop_list(self, ruta: str) -> list[ParaderoOficial]:
        return _paraderos_con_comunidad(self._paraderos, self._marcas, {"ruta": ruta})

    def official_stop(self, paradero_id: str) -> ParaderoOficial | None:
        d = self._paraderos.find_one({"_id": paradero_id})
        if d is None:
            return None
        marca = None if "ubicacion" in d else self._marcas.find_one(
            {"paradero": paradero_id, "estado": EstadoDeMarca.UBICADA.value})
        return _a_paradero(d, marca)

    def pending_mark(self, paradero_id: str) -> Marca | None:
        d = self._marcas.find_one({"paradero": paradero_id, "estado": EstadoDeMarca.POR_CONFIRMAR.value})
        return _a_marca(d) if d else None

    def pending_marks(self, ruta: str) -> list[Marca]:
        return [_a_marca(d) for d in self._marcas.find({"ruta": ruta, "estado": EstadoDeMarca.POR_CONFIRMAR.value})]

    def get_mark(self, marca_id: str) -> Marca | None:
        if not ObjectId.is_valid(marca_id):
            return None
        d = self._marcas.find_one({"_id": ObjectId(marca_id)})
        return _a_marca(d) if d else None

    def add_mark(self, *, paradero: str, ruta: str, longitud: float, latitud: float, propuesto_por: str,
                 peso: int, en: datetime) -> Marca:
        doc = {"paradero": paradero, "ruta": ruta, "ubicacion": {"type": "Point", "coordinates": [longitud, latitud]},
               "propuesto_por": ObjectId(propuesto_por), "apoyo": peso, "votos": [],
               "estado": EstadoDeMarca.POR_CONFIRMAR.value, "creado_en": en}
        try:
            self._marcas.insert_one(doc)
        except DuplicateKeyError:  # otra marca por confirmar llegó primero
            from src.domain.mapeo import MarcaPendiente
            raise MarcaPendiente()
        return _a_marca(doc)

    def add_vote(self, marca_id: str, voto: Voto) -> Marca | None:
        usuario = ObjectId(voto.usuario)
        doc = self._marcas.find_one_and_update(
            {"_id": ObjectId(marca_id), "estado": EstadoDeMarca.POR_CONFIRMAR.value,
             "propuesto_por": {"$ne": usuario}, "votos.usuario": {"$ne": usuario}},
            {"$push": {"votos": {"usuario": usuario, "esta_aqui": voto.esta_aqui, "peso": voto.peso}},
             "$inc": {"apoyo": voto.peso if voto.esta_aqui else -voto.peso}},
            return_document=ReturnDocument.AFTER)
        return _a_marca(doc) if doc else None

    def resolve(self, marca_id: str, estado: EstadoDeMarca, en: datetime) -> None:
        self._marcas.update_one({"_id": ObjectId(marca_id)}, {"$set": {"estado": estado.value, "resuelta_en": en}})

    def add_boarding(self, ruta: str, longitud: float, latitud: float, en: datetime,
                     estacion: str | None = None, modulo: str | None = None) -> None:
        documento = {"ruta": ruta, "ubicacion": {"type": "Point", "coordinates": [longitud, latitud]},
                     "en": en, "expira_en": en + self.VIGENCIA_DE_SUBIDA}
        if estacion is not None:
            documento |= {"estacion": estacion, "modulo": modulo}
        self._subidas.insert_one(documento)

    def boardings(self, ruta: str) -> list[tuple[float, float]]:
        return [tuple(d["ubicacion"]["coordinates"])
                for d in self._subidas.find({"ruta": ruta, "estacion": None}).limit(5000)]

    def station_boardings(self) -> dict[tuple[str, str], list[tuple[float, float]]]:
        grupos: dict[tuple[str, str], list[tuple[float, float]]] = {}
        for d in self._subidas.find({"estacion": {"$ne": None}}, {"estacion": 1, "modulo": 1, "ubicacion": 1}).limit(20000):
            grupos.setdefault((d["estacion"], d["modulo"][0]), []).append(tuple(d["ubicacion"]["coordinates"]))
        return grupos


class MongoRealtimeRepository:
    """
    Avistamientos (`sightings`, vencen a los 30 min) y viajes compartidos (`live_trips`, un documento por viaje que
    se sobrescribe y vence 5 min después de la última posición). Ningún documento guarda al viajero: no hay
    historial de ubicaciones de nadie (Ley 1581).
    """
    VIGENCIA_AVISTAMIENTO = timedelta(minutes=30)
    VIGENCIA_VIAJE = timedelta(minutes=5)
    # Cómo se pide la parada cambia poco, pero cambia (un paradero nuevo, otra regla): un año basta.
    VIGENCIA_RESPUESTA_DE_PARADA = timedelta(days=365)
    # Los resultados de los viajes (`trip_results`): las estadísticas se calculan antes de que venzan.
    VIGENCIA_RESULTADO = timedelta(days=180)

    def __init__(self, db: Database):
        self._sightings = db.sightings
        self._trips = db.live_trips
        self._stop_answers = db.stop_answers
        self._resultados = db.trip_results

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

    def add_stop_answer(self, ruta: str, longitud: float, latitud: float, como: ComoSePidio, en: datetime) -> None:
        self._stop_answers.insert_one({
            "ruta": ruta, "ubicacion": {"type": "Point", "coordinates": [longitud, latitud]}, "como": como.value,
            "en": en, "expira_en": en + self.VIGENCIA_RESPUESTA_DE_PARADA,
        })

    def stop_answers(self, ruta: str, longitud: float, latitud: float, radio_m: float) -> list[RespuestaDeParada]:
        cerca = {"$near": {"$geometry": {"type": "Point", "coordinates": [longitud, latitud]}, "$maxDistance": radio_m}}
        return [RespuestaDeParada(ComoSePidio(d["como"]), *d["ubicacion"]["coordinates"], d["en"])
                for d in self._stop_answers.find({"ruta": ruta, "ubicacion": cerca}).limit(500)]

    def add_trip_result(self, resultado: ResultadoDeViaje, en: datetime) -> None:
        # Sin la hora exacta de llegada: `en` solo sirve para el vencimiento.
        self._resultados.insert_one({
            "estimado_min": resultado.estimado_min, "real_min": resultado.real_min, "franja": resultado.franja,
            "tipo_de_dia": resultado.tipo_de_dia,
            "buses": [{"ruta": b.ruta, "espera_estimada_min": b.espera_estimada_min,
                       "espera_real_min": b.espera_real_min, "a_bordo_estimado_min": b.a_bordo_estimado_min,
                       "a_bordo_real_min": b.a_bordo_real_min} for b in resultado.buses],
            "expira_en": en + self.VIGENCIA_RESULTADO,
        })

    def trip_results(self, desde: datetime) -> list[ResultadoDeViaje]:
        return [ResultadoDeViaje(d["estimado_min"], d["real_min"], en_colombia(d["franja"]), d["tipo_de_dia"],
                                 tuple(BusMedido(**b) for b in d["buses"]))
                for d in self._resultados.find({"franja": {"$gte": desde}}).limit(100000)]
