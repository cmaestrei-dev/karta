from pymongo import ASCENDING, GEOSPHERE, MongoClient
from pymongo.database import Database
from src.infrastructure import config

# El cliente mantiene un pool de conexiones y es seguro entre hilos: uno por proceso.
client = MongoClient(config.MONGO_URI, tz_aware=True, serverSelectionTimeoutMS=5000)


def get_database() -> Database:
    return client[config.MONGO_DB]


def ensure_indexes(db: Database) -> None:
    """Crea los índices de las colecciones. Es idempotente: se ejecuta en cada arranque."""
    db.users.create_index([("email", ASCENDING)], unique=True)
    db.incidents.create_index([("ubicacion", GEOSPHERE)])
    # TTL: MongoDB elimina cada incidente cuando pasa su fecha `expira_en`.
    db.incidents.create_index([("expira_en", ASCENDING)], expireAfterSeconds=0)
    db.places.create_index([("ubicacion", GEOSPHERE)])
    db.places.create_index([("tokens", ASCENDING)])  # búsqueda por prefijo de palabra
    db.stations.create_index([("ubicacion", GEOSPHERE)])
    db.transit_routes.create_index([("geometria", GEOSPHERE)])
    # Un voto por viajero y reporte; los votos y las ventanas de límite de peticiones vencen solos.
    db.incident_votes.create_index([("incidente", ASCENDING), ("usuario", ASCENDING)], unique=True)
    db.incident_votes.create_index([("expira_en", ASCENDING)], expireAfterSeconds=0)
    db.rate_limits.create_index([("expira_en", ASCENDING)], expireAfterSeconds=0)
    migrar(db)


def migrar(db: Database) -> None:
    """Ajustes de datos entre versiones. Idempotente."""
    # v2: los reportes con categoría + intensidad (antes de los tipos del catálogo) vencían en horas;
    # se borran en vez de traducirlos, porque no hay forma honesta de saber qué tipo eran.
    db.incidents.delete_many({"tipo": {"$exists": False}})
