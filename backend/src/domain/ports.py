"""Puertos (interfaces) que la capa de aplicación necesita. La infraestructura los implementa."""
from datetime import datetime
from typing import Protocol

from src.domain.models import (
    CategoriaIncidente, Estacion, IconoLugar, Incidente, Lugar, LugarGuardado, RutaTransporte, TipoViajero, Usuario,
)


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


class PlaceRepository(Protocol):
    def search(self, tokens: list[str], limite: int) -> list[Lugar]:
        """Lugares cuyo nombre tiene palabras que empiezan por cada token."""
        ...

    def nearest(self, lon: float, lat: float, radio_m: float) -> tuple[Lugar, float] | None:
        """Lugar más cercano dentro del radio y su distancia en metros."""
        ...


class TransitRepository(Protocol):
    def routes_intersecting_all(self, areas: list[dict]) -> list[RutaTransporte]:
        """Rutas cuyo recorrido pasa por todas las áreas (polígonos GeoJSON)."""
        ...

    def list_stations(self) -> list[Estacion]: ...

    def stations_near(self, lon: float, lat: float, radio_m: float, limite: int) -> list[tuple[Estacion, float]]: ...


class SavedPlaceRepository(Protocol):
    def list(self, user_id: str) -> list[LugarGuardado]: ...

    def add(self, user_id: str, *, nombre: str, icono: IconoLugar, latitud: float, longitud: float,
            maximo: int) -> LugarGuardado:
        """Lanza LimiteLugaresGuardados si el usuario ya tiene `maximo` lugares."""
        ...

    def update(self, user_id: str, place_id: str, cambios: dict) -> LugarGuardado:
        """Lanza LugarGuardadoNoEncontrado si el lugar no es de ese usuario."""
        ...

    def delete(self, user_id: str, place_id: str) -> None: ...


class PasswordHasher(Protocol):
    dummy_hash: str

    def hash(self, password: str) -> str: ...

    def verify(self, password: str, password_hash: str) -> bool: ...


class TokenIssuer(Protocol):
    def issue(self, user_id: str) -> str: ...
