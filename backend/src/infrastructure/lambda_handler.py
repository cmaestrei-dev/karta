"""
Entrada de AWS Lambda (D7): la misma app de FastAPI, detrás de una Function URL con HTTPS.

Mangum traduce cada petición de la Function URL a ASGI, con `lifespan="off"`: el arranque en frío no prepara nada.
Los índices y los datos de referencia se preparan al desplegar, con el evento {"preparar": true}
(deploy/aws/desplegar.sh). La primera carga de datos tardó 18 s, y Lambda solo da 10 s para arrancar.
Un programador de EventBridge invoca la función cada 5 minutos con {"calentar": true} para que no se apague;
de paso guarda los conteos del piloto que se juntaron en memoria. Otro, cada día a las 3 a. m. de Colombia, con
{"respaldar": true}: la copia de seguridad en S3 (respaldo.py). {"restaurar": "AAAA-MM-DD"} la vuelve a poner
(deploy/aws/respaldos.sh).
"""
from datetime import datetime, timezone
from urllib.parse import unquote

from mangum import Mangum

from src.infrastructure import config
from src.infrastructure.database import ensure_indexes, get_database
from src.infrastructure.dependencies import contadores
from src.infrastructure.main import app
from src.infrastructure.reference_data import cargar_datos_de_referencia
from src.infrastructure.respaldo import en_s3, respaldar, restaurar

_db = get_database()
_asgi = Mangum(app, lifespan="off")


def handler(event: dict, context) -> dict:
    if event.get("preparar"):
        ensure_indexes(_db)
        cargar_datos_de_referencia(_db)
        return {"preparada": True}
    if event.get("respaldar") or event.get("restaurar"):
        if not config.RESPALDOS_BUCKET:
            raise RuntimeError("Falta RESPALDOS_BUCKET: el despliegue lo pone cuando existe el bucket de respaldos.")
        subir, leer = en_s3(config.RESPALDOS_BUCKET)
        if event.get("respaldar"):
            return respaldar(_db, subir, datetime.now(timezone.utc))
        return restaurar(_db, leer, event["restaurar"], event.get("colecciones"))
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
