"""
Cuántas personas distintas hay detrás de cada estadística, sin guardar un historial de nadie (plan de datos, §6).

Por cada estadística posible y cada mes (por ejemplo «2026-11|a_bordo:T103») se guarda el conjunto de huellas de
quienes aportaron. La huella es un HMAC de la cuenta con una clave del servidor, distinta para cada estadística y
cada mes: no se puede volver a la cuenta sin la clave, no une los viajes de una persona entre estadísticas y no dice
cuál de los registros es de quién, porque los registros (`trip_results`) no la llevan. Sirve solo para contar.
"""
import hashlib
import hmac

from src.infrastructure import config

# Las huellas de un mes se guardan 7 meses: los resultados de viaje de los que salen vencen a los 180 días.
MESES_DE_VIGENCIA = 7


def _clave() -> bytes:
    # Una clave propia, para que rotar el secreto de los tokens no cambie las huellas a mitad de mes. Sin ella (en
    # desarrollo y en las pruebas), una derivada del secreto de los tokens.
    if config.CLAVE_DE_APORTES:
        return config.CLAVE_DE_APORTES.encode()
    return hmac.new(config.JWT_SECRET.encode(), b"karta-aportes", hashlib.sha256).digest()


def huella(mes: str, celda: str, usuario_id: str) -> str:
    return hmac.new(_clave(), f"{mes}|{celda}|{usuario_id}".encode(), hashlib.sha256).hexdigest()[:32]
