"""Inyección de dependencias de FastAPI: conecta los servicios con sus adaptadores."""
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from pymongo.database import Database

from src.application.auth_service import AuthService
from src.application.incident_service import IncidentService
from src.domain.models import Usuario
from src.infrastructure.database import get_database
from src.infrastructure.repositories import MongoIncidentRepository, MongoUserRepository
from src.infrastructure.security import password_hasher, token_issuer

_bearer = HTTPBearer(auto_error=False)


def get_db() -> Database:
    return get_database()


def get_user_repository(db: Database = Depends(get_db)) -> MongoUserRepository:
    return MongoUserRepository(db)


def get_auth_service(users: MongoUserRepository = Depends(get_user_repository)) -> AuthService:
    return AuthService(users, password_hasher, token_issuer)


def get_incident_service(db: Database = Depends(get_db)) -> IncidentService:
    return IncidentService(MongoIncidentRepository(db))


def get_current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(_bearer),
    users: MongoUserRepository = Depends(get_user_repository),
) -> Usuario:
    """Exige un token Bearer válido de un usuario que todavía exista."""
    no_autorizado = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Sesión inválida o expirada.",
        headers={"WWW-Authenticate": "Bearer"},
    )
    if credentials is None:
        raise no_autorizado
    user_id = token_issuer.read_subject(credentials.credentials)
    usuario = users.get_by_id(user_id) if user_id else None
    if usuario is None:
        raise no_autorizado
    return usuario
