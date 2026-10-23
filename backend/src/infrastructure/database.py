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
