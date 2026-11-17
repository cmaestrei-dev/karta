"""
Copia de seguridad diaria propia (plan de calidad, D2): las copias del plan gratuito de Atlas cuestan USD 0,10 al
día y piden tarjeta, así que Karta exporta su base a un bucket privado de S3 que borra todo a los 7 días.

Cada colección va en un archivo «AAAA-MM-DD/<colección>.jsonl.gz», un documento por línea en JSON extendido
(conserva los ObjectId y las fechas). No se copian los datos de referencia, que están en el repositorio, ni lo que
vence en minutos (avistamientos, viajes compartidos, límites de peticiones). Restaurar reemplaza cada documento
por el de la copia según su _id y no borra los que la copia no tenga.
"""
import gzip
from collections.abc import Callable
from datetime import datetime

from bson import json_util
from pymongo import ReplaceOne
from pymongo.database import Database

SIN_RESPALDO = {
    # Datos de referencia: se recargan desde backend/data con cada despliegue.
    "transit_routes", "stations", "places", "route_schedules", "intersections", "address_crossings", "route_stops",
    "route_directions", "reference_data",
    # Lo que vence en minutos.
    "sightings", "live_trips", "rate_limits",
}


def colecciones_a_respaldar(db: Database) -> list[str]:
    return sorted(c for c in db.list_collection_names() if c not in SIN_RESPALDO and not c.startswith("system."))


def respaldar(db: Database, subir: Callable[[str, bytes], None], ahora: datetime) -> dict:
    """Sube una copia de cada colección; devuelve cuántos documentos llevó cada una."""
    dia = ahora.date().isoformat()
    copiados = {}
    for nombre in colecciones_a_respaldar(db):
        lineas = [json_util.dumps(doc, json_options=json_util.CANONICAL_JSON_OPTIONS) for doc in db[nombre].find()]
        subir(f"{dia}/{nombre}.jsonl.gz", gzip.compress("\n".join(lineas).encode()))
        copiados[nombre] = len(lineas)
    return {"respaldo": dia, "colecciones": copiados}


def restaurar(db: Database, leer: Callable[[str], bytes | None], dia: str,
              colecciones: list[str] | None = None) -> dict:
    """Vuelve a poner los documentos de la copia de ese día. Solo las colecciones pedidas, si se dan."""
    restaurados = {}
    for nombre in colecciones or colecciones_a_respaldar(db):
        contenido = leer(f"{dia}/{nombre}.jsonl.gz")
        if contenido is None:
            continue
        texto = gzip.decompress(contenido).decode()
        documentos = [json_util.loads(linea) for linea in texto.split("\n") if linea]
        if documentos:
            db[nombre].bulk_write([ReplaceOne({"_id": d["_id"]}, d, upsert=True) for d in documentos], ordered=False)
        restaurados[nombre] = len(documentos)
    return {"restaurado": dia, "colecciones": restaurados}


def en_s3(bucket: str) -> tuple[Callable[[str, bytes], None], Callable[[str], bytes | None]]:
    """Subir y leer en el bucket de respaldos. boto3 viene con el entorno de Lambda; no hace falta empaquetarlo."""
    import boto3
    from botocore.exceptions import ClientError

    s3 = boto3.client("s3")

    def subir(clave: str, datos: bytes) -> None:
        s3.put_object(Bucket=bucket, Key=clave, Body=datos, ServerSideEncryption="AES256")

    def leer(clave: str) -> bytes | None:
        try:
            return s3.get_object(Bucket=bucket, Key=clave)["Body"].read()
        except ClientError as error:
            if error.response["Error"]["Code"] in ("NoSuchKey", "404"):
                return None
            raise

    return subir, leer
