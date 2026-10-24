"""Límite de peticiones como dependencia de FastAPI: por IP antes de la sesión y por viajero después."""
from datetime import timedelta

from fastapi import Depends, HTTPException, Request, status
from pymongo.database import Database

from src.domain.models import Usuario
from src.infrastructure import config
from src.infrastructure.dependencies import get_current_user, get_db
from src.infrastructure.repositories import MongoRateLimiter


def _exceder(segundos: int) -> HTTPException:
    minutos = max(1, round(segundos / 60))
    return HTTPException(
        status_code=status.HTTP_429_TOO_MANY_REQUESTS,
        detail=f"Demasiados intentos seguidos. Vuelve a intentarlo en {minutos} min.",
        headers={"Retry-After": str(segundos)},
    )


def por_ip(accion: str, nombre_limite: str):
    """Limita una acción anónima (registro, inicio de sesión) por dirección IP."""
    def dependencia(request: Request, db: Database = Depends(get_db)) -> None:
        maximo, ventana = getattr(config, nombre_limite)
        ip = request.client.host if request.client else "desconocida"
        espera = MongoRateLimiter(db).hit(f"{accion}:ip:{ip}", maximo, timedelta(seconds=ventana))
        if espera is not None:
            raise _exceder(espera)
    return dependencia


def por_viajero(accion: str, nombre_limite: str):
    """Limita una acción con sesión (reportar, votar) por viajero; devuelve el usuario de la sesión."""
    def dependencia(usuario: Usuario = Depends(get_current_user), db: Database = Depends(get_db)) -> Usuario:
        maximo, ventana = getattr(config, nombre_limite)
        espera = MongoRateLimiter(db).hit(f"{accion}:usuario:{usuario.id}", maximo, timedelta(seconds=ventana))
        if espera is not None:
            raise _exceder(espera)
        return usuario
    return dependencia
