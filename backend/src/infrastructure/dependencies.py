"""Inyección de dependencias de FastAPI: conecta los servicios con sus adaptadores."""
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from pymongo.database import Database

from src.application.auth_service import AuthService
from src.application.incident_service import IncidentService
from src.application.mapping_service import MappingService
from src.application.place_service import PlaceService
from src.application.realtime_service import RealtimeService
from src.application.trip_service import TripService
from src.domain.models import Usuario
from src.infrastructure.database import get_database
from src.infrastructure.repositories import (
    MongoContadores, MongoIncidentRepository, MongoPlaceRepository, MongoRealtimeRepository, MongoSavedPlaceRepository,
    MongoStopMappingRepository, MongoTransitRepository, MongoUserRepository,
)
from src.infrastructure.security import password_hasher, token_issuer

_bearer = HTTPBearer(auto_error=False)


def get_db() -> Database:
    return get_database()


def get_user_repository(db: Database = Depends(get_db)) -> MongoUserRepository:
    return MongoUserRepository(db)


def get_auth_service(users: MongoUserRepository = Depends(get_user_repository)) -> AuthService:
    return AuthService(users, password_hasher, token_issuer)


def get_incident_service(db: Database = Depends(get_db)) -> IncidentService:
    return IncidentService(MongoIncidentRepository(db), MongoUserRepository(db),
                           MongoPlaceRepository(db), MongoTransitRepository(db), MongoContadores(db))


def get_place_service(db: Database = Depends(get_db)) -> PlaceService:
    return PlaceService(MongoPlaceRepository(db), MongoSavedPlaceRepository(db))


def get_trip_service(db: Database = Depends(get_db)) -> TripService:
    return TripService(MongoTransitRepository(db), MongoPlaceRepository(db), MongoIncidentRepository(db),
                       MongoStopMappingRepository(db))


def get_mapping_service(db: Database = Depends(get_db)) -> MappingService:
    return MappingService(MongoStopMappingRepository(db), MongoTransitRepository(db), MongoUserRepository(db))


def get_realtime_service(db: Database = Depends(get_db)) -> RealtimeService:
    return RealtimeService(MongoRealtimeRepository(db), MongoTransitRepository(db), MongoIncidentRepository(db),
                           MongoContadores(db))


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


def get_optional_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(_bearer),
    users: MongoUserRepository = Depends(get_user_repository),
) -> Usuario | None:
    """El usuario de la sesión si hay un token válido; None si no hay sesión (nunca 401)."""
    if credentials is None:
        return None
    user_id = token_issuer.read_subject(credentials.credentials)
    return users.get_by_id(user_id) if user_id else None
