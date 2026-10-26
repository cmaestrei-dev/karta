"""
Entrada de AWS Lambda (D7): la misma app de FastAPI, detrás de una Function URL con HTTPS.

Mangum traduce cada petición de la Function URL a ASGI. El arranque (índices y datos de referencia) se hace una
sola vez, cuando Lambda carga la función, y no en cada petición: por eso Mangum va con `lifespan="off"`.
Un programador de EventBridge invoca la función cada 5 minutos con {"calentar": true} para que no se apague
(el primer viaje tras un arranque en frío tarda unos segundos más).
"""
from mangum import Mangum

from src.infrastructure.database import ensure_indexes, get_database
from src.infrastructure.main import app
from src.infrastructure.reference_data import cargar_datos_de_referencia

_db = get_database()
ensure_indexes(_db)
cargar_datos_de_referencia(_db)

_asgi = Mangum(app, lifespan="off")


def handler(event: dict, context) -> dict:
    if event.get("calentar"):
        _db.command("ping")  # además, mantiene activa la base de Atlas, que se pausa tras 30 días sin conexiones
        return {"calentada": True}
    return _asgi(event, context)
