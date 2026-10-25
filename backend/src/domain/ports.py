"""Puertos (interfaces) que la capa de aplicación necesita. La infraestructura los implementa."""
from datetime import datetime, timedelta
from typing import Protocol

from src.domain.horarios import HorarioRuta
from src.domain.direcciones import Cruce
from src.domain.models import (
    Estacion, IconoLugar, Incidente, Lugar, LugarGuardado, RutaTransporte, TipoViajero, Usuario,
)
from src.domain.reportes import TipoReporte
from src.domain.tiempo_real import Observacion, Ocupacion


class UserRepository(Protocol):
    def add(self, *, email: str, password_hash: str, nombre: str, alias: str, tipo_viajero: TipoViajero,
            creado_en: datetime, terminos_aceptados_en: datetime) -> Usuario: ...

    def get_by_email(self, email: str) -> Usuario | None: ...

    def get_by_id(self, user_id: str) -> Usuario | None: ...

    def ajustar_reputacion(self, user_id: str, delta: int) -> None:
        """Suma (o resta) puntos de reputación de forma atómica."""
        ...

    def sumar_impacto(self, user_id: str, campo: str, cantidad: int = 1) -> None:
        """Suma al contador de impacto del viajero («reportes», «confirmaciones», «gracias», «vistas»)."""
        ...

    def add_invisible(self, *, huella: str, creado_en: datetime) -> Usuario:
        """Crea la cuenta invisible de un teléfono, identificada por la huella de su secreto."""
        ...

    def get_by_secret(self, huella: str) -> Usuario | None: ...

    def touch(self, user_id: str, ahora: datetime) -> None:
        """Marca que la cuenta invisible sigue en uso (las abandonadas se borran solas)."""
        ...

    def upgrade(self, user_id: str, *, email: str, password_hash: str, nombre: str, alias: str,
                tipo_viajero: TipoViajero, terminos_aceptados_en: datetime) -> Usuario:
        """Le pone correo a una cuenta invisible: deja de ser anónima y se desliga del teléfono."""
        ...


class IncidentRepository(Protocol):
    def add(self, *, reportado_por: str, tipo: TipoReporte, detalles: dict[str, str], latitud: float,
            longitud: float, lugar: str | None, creado_en: datetime, expira_en: datetime,
            sin_cuenta: bool = False, nivel_autor: int = 1) -> Incidente: ...

    def get_active(self, incidente_id: str, ahora: datetime) -> Incidente | None: ...

    def list_active(self, ahora: datetime, limite: int, caja: tuple[float, float, float, float] | None = None
                    ) -> list[Incidente]:
        """Vigentes, los más recientes primero; `caja` = (lon_min, lat_min, lon_max, lat_max)."""
        ...

    def active_for_route(self, tipo: str, ruta: str, ahora: datetime) -> list[Incidente]:
        """Reportes vigentes de un tipo sobre una ruta («bus_varado» del T103)."""
        ...

    def find_active_within(self, area: dict, ahora: datetime) -> list[Incidente]:
        """Incidentes vigentes dentro de un polígono GeoJSON."""
        ...

    def register_vote(self, incidente_id: str, usuario_id: str, sigue: bool, ahora: datetime) -> None:
        """Guarda el voto; lanza VotoRepetido si ese usuario ya votó ese reporte."""
        ...

    def apply_confirmation(self, incidente_id: str, nueva_expiracion: datetime) -> Incidente:
        """Suma un «sigue ahí», reinicia la racha de «ya no» y extiende la vigencia (sin acortarla)."""
        ...

    def apply_denial(self, incidente_id: str) -> tuple[Incidente, int]:
        """Suma un «ya no está» y devuelve el incidente con la racha de «ya no» seguidos."""
        ...

    def retire(self, incidente_id: str, ahora: datetime) -> None:
        """Lo da por vencido ya: deja de verse y el índice TTL lo elimina."""
        ...

    def reward_voters(self, incidente_id: str, sigue: bool, excepto: str | None = None) -> list[str]:
        """Quienes votaron [sigue] y aún no recibieron su punto (salvo [excepto]); quedan marcados como premiados."""
        ...

    def register_thanks(self, incidente_id: str, usuario_id: str, ahora: datetime) -> Incidente:
        """Un «Gracias» por viajero y reporte. Lanza GraciasRepetidas si ya lo dio."""
        ...

    def thanks_of(self, incidente_id: str, usuario_id: str) -> bool: ...

    def register_view(self, incidente_id: str, usuario_id: str, ahora: datetime) -> bool:
        """Anota que el viajero abrió el reporte. True si es la primera vez."""
        ...

    def vote_of(self, incidente_id: str, usuario_id: str) -> bool | None:
        """El voto de ese usuario en ese reporte (True = sigue ahí), o None si no ha votado."""
        ...


class PlaceRepository(Protocol):
    def search(self, tokens: list[str], limite: int) -> list[Lugar]:
        """Lugares cuyo nombre tiene palabras que empiezan por cada token."""
        ...

    def nearest(self, lon: float, lat: float, radio_m: float, tipo: str | None = None) -> tuple[Lugar, float] | None:
        """Lugar más cercano dentro del radio (opcionalmente, de un tipo) y su distancia en metros."""
        ...

    def crossings_on(self, via_clave: str) -> list[Cruce]:
        """Los cruces de una vía numerada («calle:9»), para ubicar direcciones."""
        ...


class TransitRepository(Protocol):
    def routes_intersecting_all(self, areas: list[dict]) -> list[RutaTransporte]:
        """Rutas cuyo recorrido pasa por todas las áreas (polígonos GeoJSON)."""
        ...

    def routes_intersecting_any(self, areas: list[dict]) -> list[RutaTransporte]:
        """Rutas cuyo recorrido pasa por al menos una de las áreas (polígonos GeoJSON)."""
        ...

    def schedules(self) -> dict[str, HorarioRuta]:
        """Horario de servicio de cada ruta que lo tiene publicado, por código."""
        ...

    def intersection_near(self, lon: float, lat: float, radio_m: float) -> str | None:
        """Nombre del cruce de calles más cercano («Av. Pedro de Heredia con Cra. 28»), si hay uno en el radio."""
        ...

    def list_stations(self) -> list[Estacion]: ...

    def stations_near(self, lon: float, lat: float, radio_m: float, limite: int) -> list[tuple[Estacion, float]]: ...

    def list_routes(self, tipo: str | None = None) -> list[RutaTransporte]: ...

    def route_codes(self) -> set[str]: ...

    def route(self, codigo: str) -> RutaTransporte | None: ...


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


class RateLimiter(Protocol):
    def hit(self, clave: str, limite: int, ventana: timedelta) -> int | None:
        """Cuenta una petición; si la ventana ya llegó al límite devuelve los segundos que faltan."""
        ...


class RealtimeRepository(Protocol):
    """Lo que los viajeros ven de los buses. Nada guarda quién lo envió y todo vence solo (TTL)."""

    def add_sighting(self, ruta: str, longitud: float, latitud: float, ocupacion: Ocupacion | None,
                     en: datetime) -> None: ...

    def start_trip(self, ruta: str, longitud: float, latitud: float, en: datetime) -> str:
        """Crea un viaje compartido anónimo y devuelve su identificador aleatorio."""
        ...

    def update_trip(self, viaje: str, longitud: float, latitud: float, ocupacion: Ocupacion | None,
                    en: datetime) -> bool:
        """Mueve el viaje; False si ya no existe (terminó o venció)."""
        ...

    def end_trip(self, viaje: str) -> None: ...

    def observations(self, ruta: str, desde: datetime) -> list[Observacion]:
        """Avistamientos y viajes compartidos de la ruta desde ese momento."""
        ...
