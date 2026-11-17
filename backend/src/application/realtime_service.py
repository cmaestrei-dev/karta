from datetime import datetime, timedelta, timezone

from src.domain.conocimiento import CERCA_DEL_PARADERO_M, ComoSePidio, LoQueSeSabe, como_se_pide
from src.domain.geo import validar_cobertura
from src.domain.indicadores import consulta_de_llegada, dia
from src.domain.ports import Contadores, IncidentRepository, RealtimeRepository, TransitRepository
from src.domain.precision import BusMedido, resultado
from src.domain.tiempo_real import BusVarado, Estimacion, Ocupacion, estimar_llegada, varado_antes_de_la_parada


class RutaDesconocida(Exception):
    pass


class ViajeTerminado(Exception):
    pass


class RealtimeService:
    """Caso de Uso: el tiempo real de Transcaribe hecho por sus pasajeros."""
    VENTANA = timedelta(minutes=30)

    def __init__(self, realtime: RealtimeRepository, transit: TransitRepository, incidents: IncidentRepository,
                 contadores: Contadores | None = None):
        self.realtime = realtime
        self.transit = transit
        self.incidents = incidents
        self.contadores = contadores

    def _contar(self, ahora: datetime, campos: dict[str, int]) -> None:
        """Los indicadores del piloto (docs/plan-comunidad.md, §5), sin quién."""
        if self.contadores:
            self.contadores.sumar(dia(ahora), campos)

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
        ahora = ahora or datetime.now(timezone.utc)
        viaje = self.realtime.start_trip(ruta, longitud, latitud, ahora)
        self._contar(ahora, {"viajes_compartidos": 1})
        return viaje

    def share_position(self, viaje: str, latitud: float, longitud: float, ocupacion: Ocupacion | None,
                       ahora: datetime | None = None) -> None:
        validar_cobertura(latitud, longitud)
        if not self.realtime.update_trip(viaje, longitud, latitud, ocupacion, ahora or datetime.now(timezone.utc)):
            raise ViajeTerminado(viaje)

    def end_trip(self, viaje: str) -> None:
        self.realtime.end_trip(viaje)

    def answer_stop_request(self, ruta: str, latitud: float, longitud: float, como: ComoSePidio,
                            ahora: datetime | None = None) -> None:
        """«¿Cómo pediste la parada?», respondido al bajarse en un paradero (D12)."""
        self._ruta_valida(ruta)
        validar_cobertura(latitud, longitud)
        self.realtime.add_stop_answer(ruta, longitud, latitud, como, ahora or datetime.now(timezone.utc))

    def report_trip_result(self, estimado_min: int, real_min: int, buses: list[BusMedido], aportante: str,
                           ahora: datetime | None = None) -> None:
        """Al llegar: cuánto estimó Karta y cuánto tardó el viaje, en total y en cada bus (D17)."""
        for bus in buses:
            self._ruta_valida(bus.ruta)
        ahora = ahora or datetime.now(timezone.utc)
        self.realtime.add_trip_result(resultado(estimado_min, real_min, buses, ahora), ahora, aportante)

    def stop_request(self, ruta: str, latitud: float, longitud: float) -> LoQueSeSabe | None:
        """Cómo se pide la parada en ese punto según los viajeros, si hay suficientes respuestas que coinciden."""
        self._ruta_valida(ruta)
        respuestas = self.realtime.stop_answers(ruta, longitud, latitud, CERCA_DEL_PARADERO_M)
        return como_se_pide(respuestas, longitud, latitud)

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
        estimacion = estimar_llegada(ruta_, subida, bajada, self.realtime.observations(ruta, ahora - self.VENTANA, ahora),
                                     ahora, varados)
        self._contar(ahora, consulta_de_llegada(ahora, ruta_.tipo == "troncal", estimacion is not None))
        return estimacion, varado_antes_de_la_parada(ruta_, subida, bajada, varados)
