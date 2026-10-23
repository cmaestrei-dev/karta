"""Puertos (interfaces) que la capa de aplicación necesita. La infraestructura los implementa."""
from datetime import datetime
from typing import Protocol

from src.domain.models import CategoriaIncidente, Incidente, TipoViajero, Usuario


class UserRepository(Protocol):
    def add(self, *, email: str, password_hash: str, nombre: str, tipo_viajero: TipoViajero,
            creado_en: datetime, terminos_aceptados_en: datetime) -> Usuario: ...

    def get_by_email(self, email: str) -> Usuario | None: ...

    def get_by_id(self, user_id: str) -> Usuario | None: ...


class IncidentRepository(Protocol):
    def add(self, *, reportado_por: str, categoria: CategoriaIncidente, intensidad: int,
            latitud: float, longitud: float, creado_en: datetime, expira_en: datetime) -> Incidente: ...

    def list_active(self, ahora: datetime, limite: int) -> list[Incidente]: ...

    def find_active_within(self, area: dict, ahora: datetime) -> list[Incidente]:
        """Incidentes vigentes dentro de un polígono GeoJSON."""
        ...


class PasswordHasher(Protocol):
    dummy_hash: str

    def hash(self, password: str) -> str: ...

    def verify(self, password: str, password_hash: str) -> bool: ...


class TokenIssuer(Protocol):
    def issue(self, user_id: str) -> str: ...
