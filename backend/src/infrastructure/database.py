from pymongo import ASCENDING, GEOSPHERE, MongoClient
from pymongo.database import Database
from src.infrastructure import config

# El cliente mantiene un pool de conexiones y es seguro entre hilos: uno por proceso.
client = MongoClient(config.MONGO_URI, tz_aware=True, serverSelectionTimeoutMS=5000)


def get_database() -> Database:
    return client[config.MONGO_DB]


def ensure_indexes(db: Database) -> None:
    """Crea los índices de las colecciones. Es idempotente: se ejecuta en cada arranque."""
    # El correo es único entre quienes lo tienen; las cuentas invisibles no tienen. Antes el índice no era parcial.
    previo = db.users.index_information().get("email_1")
    if previo and "partialFilterExpression" not in previo:
        db.users.drop_index("email_1")
    db.users.create_index([("email", ASCENDING)], unique=True, partialFilterExpression={"email": {"$type": "string"}})
    # La cuenta invisible de cada teléfono, por la huella de su secreto; si no se usa en 180 días, se borra.
    db.users.create_index([("secreto", ASCENDING)], unique=True,
                          partialFilterExpression={"secreto": {"$type": "string"}})
    db.users.create_index([("visto_en", ASCENDING)], expireAfterSeconds=180 * 24 * 3600,
                          partialFilterExpression={"anonimo": True})
    db.incidents.create_index([("ubicacion", GEOSPHERE)])
    # TTL: MongoDB elimina cada incidente cuando pasa su fecha `expira_en`.
    db.incidents.create_index([("expira_en", ASCENDING)], expireAfterSeconds=0)
    db.places.create_index([("ubicacion", GEOSPHERE)])
    db.places.create_index([("tokens", ASCENDING)])  # búsqueda por prefijo de palabra
    db.stations.create_index([("ubicacion", GEOSPHERE)])
    db.transit_routes.create_index([("geometria", GEOSPHERE)])
    db.intersections.create_index([("ubicacion", GEOSPHERE)])
    db.address_crossings.create_index([("vias", ASCENDING)])
    db.route_stops.create_index([("ruta", ASCENDING), ("sentido", ASCENDING), ("orden", ASCENDING)])
    db.route_stops.create_index([("ubicacion", GEOSPHERE)])
    # «Marca este paradero»: una sola marca por confirmar por paradero; las subidas anónimas vencen solas.
    db.stop_marks.create_index([("paradero", ASCENDING)], unique=True,
                               partialFilterExpression={"estado": "por_confirmar"})
    db.stop_marks.create_index([("ruta", ASCENDING), ("estado", ASCENDING)])
    db.boardings.create_index([("ruta", ASCENDING)])
    db.boardings.create_index([("estacion", ASCENDING)], sparse=True)  # las subidas en estaciones, por vagón
    db.boardings.create_index([("expira_en", ASCENDING)], expireAfterSeconds=0)  # «calle:9»: los cruces de una vía numerada
    # Un voto por viajero y reporte; los votos y las ventanas de límite de peticiones vencen solos.
    db.incident_votes.create_index([("incidente", ASCENDING), ("usuario", ASCENDING)], unique=True)
    db.incident_votes.create_index([("expira_en", ASCENDING)], expireAfterSeconds=0)
    # Un «Gracias» y una vista por viajero y reporte (para «Tu impacto»); vencen solos como los votos.
    for coleccion in (db.incident_thanks, db.incident_views):
        coleccion.create_index([("incidente", ASCENDING), ("usuario", ASCENDING)], unique=True)
        coleccion.create_index([("usuario", ASCENDING), ("en", ASCENDING)])  # personas distintas por día
        coleccion.create_index([("expira_en", ASCENDING)], expireAfterSeconds=0)
    db.rate_limits.create_index([("expira_en", ASCENDING)], expireAfterSeconds=0)
    # Tiempo real de los viajeros: vence solo (30 min los avistamientos, 5 min sin moverse los viajes compartidos).
    db.sightings.create_index([("ruta", ASCENDING), ("en", ASCENDING)])
    db.sightings.create_index([("expira_en", ASCENDING)], expireAfterSeconds=0)
    db.live_trips.create_index([("ruta", ASCENDING), ("en", ASCENDING)])
    db.live_trips.create_index([("expira_en", ASCENDING)], expireAfterSeconds=0)
    # «¿Cómo pediste la parada?» (D12): anónimo, por ruta y punto; vence al año.
    db.stop_answers.create_index([("ubicacion", GEOSPHERE), ("ruta", ASCENDING)])
    db.stop_answers.create_index([("expira_en", ASCENDING)], expireAfterSeconds=0)
    # Cuánto estimó Karta y cuánto tardó cada viaje (D17): sin cuenta ni puntos; vence a los 180 días.
    db.trip_results.create_index([("franja", ASCENDING)])
    db.trip_results.create_index([("expira_en", ASCENDING)], expireAfterSeconds=0)
    migrar(db)


def migrar(db: Database) -> None:
    """Ajustes de datos entre versiones. Idempotente."""
    # v2: los reportes con categoría + intensidad (antes de los tipos del catálogo) vencían en horas;
    # se borran en vez de traducirlos, porque no hay forma honesta de saber qué tipo eran.
    db.incidents.delete_many({"tipo": {"$exists": False}})
