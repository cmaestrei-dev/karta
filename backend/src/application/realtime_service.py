from datetime import datetime, timedelta, timezone

from src.domain.geo import validar_cobertura
from src.domain.ports import IncidentRepository, RealtimeRepository, TransitRepository
from src.domain.tiempo_real import BusVarado, Estimacion, Ocupacion, estimar_llegada, varado_antes_de_la_parada


class RutaDesconocida(Exception):
    pass


class ViajeTerminado(Exception):
    pass


class RealtimeService:
    """Caso de Uso: el tiempo real de Transcaribe hecho por sus pasajeros."""
    VENTANA = timedelta(minutes=30)

    def __init__(self, realtime: RealtimeRepository, transit: TransitRepository, incidents: IncidentRepository):
        self.realtime = realtime
        self.transit = transit
        self.incidents = incidents

    def _ruta_valida(self, ruta: str) -> None:
        if ruta not in self.transit.route_codes():
            raise RutaDesconocida(ruta)

    def report_sighting(self, ruta: str, latitud: float, longitud: float, ocupacion: Ocupacion | None,
                        ahora: datetime | None = None) -> None:
        """«Vi pasar el T103» (desde una parada) o «va de pie» (desde adentro)."""
        self._ruta_valida(ruta)
        validar_cobertura(latitud, longitud)
        self.realtime.add_sighting(ruta, longitud, latitud, ocupacion, ahora or datetime.now(timezone.utc))

    def start_trip(self, ruta: str, latitud: float, longitud: float, ahora: datetime | None = None) -> str:
        self._ruta_valida(ruta)
        validar_cobertura(latitud, longitud)
        return self.realtime.start_trip(ruta, longitud, latitud, ahora or datetime.now(timezone.utc))

    def share_position(self, viaje: str, latitud: float, longitud: float, ocupacion: Ocupacion | None,
                       ahora: datetime | None = None) -> None:
        validar_cobertura(latitud, longitud)
        if not self.realtime.update_trip(viaje, longitud, latitud, ocupacion, ahora or datetime.now(timezone.utc)):
            raise ViajeTerminado(viaje)

    def end_trip(self, viaje: str) -> None:
        self.realtime.end_trip(viaje)

    def arrival(self, ruta: str, subida: tuple[float, float], bajada: tuple[float, float],
                ahora: datetime | None = None) -> tuple[Estimacion | None, tuple[BusVarado, float] | None]:
        """
        Cuánto le falta al próximo bus de la ruta para llegar a la subida, yendo hacia la bajada, y si hay un bus
        varado antes de la subida (que ya no cuenta como uno que viene).
        """
        ruta_ = self.transit.route(ruta)
        if ruta_ is None:
            raise RutaDesconocida(ruta)
        ahora = ahora or datetime.now(timezone.utc)
        varados = [BusVarado(i.longitud, i.latitud, i.creado_en, i.votos_si, i.lugar)
                   for i in self.incidents.active_for_route("bus_varado", ruta, ahora)]
        estimacion = estimar_llegada(ruta_, subida, bajada, self.realtime.observations(ruta, ahora - self.VENTANA),
                                     ahora, varados)
        return estimacion, varado_antes_de_la_parada(ruta_, subida, bajada, varados)
