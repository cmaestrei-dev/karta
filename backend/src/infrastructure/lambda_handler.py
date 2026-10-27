"""
Entrada de AWS Lambda (D7): la misma app de FastAPI, detrás de una Function URL con HTTPS.

Mangum traduce cada petición de la Function URL a ASGI, con `lifespan="off"`: el arranque en frío no prepara nada.
Los índices y los datos de referencia se preparan al desplegar, con el evento {"preparar": true}
(deploy/aws/desplegar.sh). La primera carga de datos tardó 18 s, y Lambda solo da 10 s para arrancar.
Un programador de EventBridge invoca la función cada 5 minutos con {"calentar": true} para que no se apague;
de paso guarda los conteos del piloto que se juntaron en memoria.
"""
from urllib.parse import unquote

from mangum import Mangum

from src.infrastructure.database import ensure_indexes, get_database
from src.infrastructure.dependencies import contadores
from src.infrastructure.main import app
from src.infrastructure.reference_data import cargar_datos_de_referencia

_db = get_database()
_asgi = Mangum(app, lifespan="off")


def handler(event: dict, context) -> dict:
    if event.get("preparar"):
        ensure_indexes(_db)
        cargar_datos_de_referencia(_db)
        return {"preparada": True}
    if event.get("calentar"):
        _db.command("ping")  # además, mantiene activa la base de Atlas, que se pausa tras 30 días sin conexiones
        contadores(_db).vaciar()
        return {"calentada": True}
    # La Function URL manda en requestContext.http.path la ruta sin la barra final («/api/v1/incidents»), y Mangum usa
    # esa: FastAPI redirigía a «/api/v1/incidents/» y la redirección volvía igual, en bucle. rawPath trae la ruta tal cual.
    http = event.get("requestContext", {}).get("http")
    if http is not None and event.get("rawPath"):
        http["path"] = unquote(event["rawPath"])
    return _asgi(event, context)
