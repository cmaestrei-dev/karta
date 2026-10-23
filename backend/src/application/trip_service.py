from dataclasses import replace
from datetime import datetime, timezone

from src.domain.geo import circulo, corredor_de_ruta, distancia_m
from src.domain.models import Estacion, RutaTransporte
from src.domain.ports import IncidentRepository, PlaceRepository, TransitRepository
from src.domain.route_risk import PENALIZACION_RIESGO_MIN, RADIO_BUSQUEDA_M, ResultadoRiesgo, evaluar_riesgo
from src.domain.trip_planning import CAMINATA_MAXIMA_DE_ACCESO_M, OpcionViaje, caminata_entre, planificar


class TripService:
    MAX_OPCIONES = 3
    CANDIDATAS_A_EVALUAR = 5   # el riesgo se calcula solo para las más rápidas
    RADIO_ESTACION_M = 150
    RADIO_REFERENCIA_M = 300

    def __init__(self, transit: TransitRepository, places: PlaceRepository, incidents: IncidentRepository):
        self.transit = transit
        self.places = places
        self.incidents = incidents

    def suggest(self, origen: tuple[float, float], destino: tuple[float, float],
                nombre_origen: str | None = None,
                nombre_destino: str | None = None) -> list[tuple[OpcionViaje, ResultadoRiesgo]]:
        """
        Caso de Uso: Consultar rutas sugeridas.
        1. MongoDB devuelve solo las rutas que pasan cerca del origen y del destino ($geoIntersects).
        2. Se calcula la mejor subida y bajada en cada ruta (y la opción a pie si es cerca).
        3. A las más rápidas se les evalúa el riesgo con los incidentes vigentes de su corredor.
        4. Se ordenan por tiempo + penalización por riesgo.
        """
        areas = [circulo(*origen, CAMINATA_MAXIMA_DE_ACCESO_M), circulo(*destino, CAMINATA_MAXIMA_DE_ACCESO_M)]
        rutas = self.transit.routes_intersecting_all(areas)
        estaciones = self.transit.list_stations()

        opciones = sorted(planificar(rutas, estaciones, origen, destino), key=lambda o: o.tiempo_total_min)
        ahora = datetime.now(timezone.utc)
        evaluadas = []
        for opcion in opciones[:self.CANDIDATAS_A_EVALUAR]:
            corredor = corredor_de_ruta(opcion.coordenadas, RADIO_BUSQUEDA_M)
            evaluadas.append((opcion, evaluar_riesgo(self.incidents.find_active_within(corredor, ahora))))
        evaluadas.sort(key=lambda par: par[0].tiempo_total_min + PENALIZACION_RIESGO_MIN[par[1].nivel])

        return [(self._etiquetar(opcion, estaciones, nombre_origen, nombre_destino), riesgo)
                for opcion, riesgo in evaluadas[:self.MAX_OPCIONES]]

    def nearby_stations(self, lat: float, lon: float, radio_m: float, limite: int) -> list[tuple[Estacion, float]]:
        """Caso de Uso: Ver estaciones de Transcaribe cercanas, de la más cercana a la más lejana."""
        return self.transit.stations_near(lon, lat, radio_m, limite)

    def _etiquetar(self, opcion: OpcionViaje, estaciones: list[Estacion],
                   nombre_origen: str | None, nombre_destino: str | None) -> OpcionViaje:
        """Pone nombres legibles a los puntos de subida y bajada ("Estación Bazurto")."""
        inicio, fin = nombre_origen or "Tu ubicación", nombre_destino or "Tu destino"
        tramos = list(opcion.tramos)
        bus = next((k for k, t in enumerate(tramos) if t.modo == "bus"), None)
        if bus is None:
            tramos[0] = replace(tramos[0], desde=inicio, hasta=fin)
            return OpcionViaje(tramos=tuple(tramos))

        ruta = tramos[bus].ruta
        subida, estacion_subida = self._parada(tramos[bus].coordenadas[0], ruta, estaciones)
        bajada, estacion_bajada = self._parada(tramos[bus].coordenadas[-1], ruta, estaciones)
        # Si se sube o se baja en una estación, la caminata llega a la estación misma: así su distancia
        # coincide con la que muestra /stops/nearby para esa estación.
        if estacion_subida:
            tramos[bus - 1] = caminata_entre(tramos[bus - 1].coordenadas[0], (estacion_subida.longitud, estacion_subida.latitud))
        if estacion_bajada:
            tramos[bus + 1] = caminata_entre((estacion_bajada.longitud, estacion_bajada.latitud), tramos[bus + 1].coordenadas[-1])
        tramos[bus - 1] = replace(tramos[bus - 1], desde=inicio, hasta=subida)
        tramos[bus] = replace(tramos[bus], desde=subida, hasta=bajada)
        tramos[bus + 1] = replace(tramos[bus + 1], desde=bajada, hasta=fin)
        return OpcionViaje(tramos=tuple(tramos))

    def _parada(self, punto: tuple[float, float], ruta: RutaTransporte,
                estaciones: list[Estacion]) -> tuple[str, Estacion | None]:
        """Nombre legible del punto de subida o bajada y, si es una estación de la ruta, la estación."""
        propias = [(distancia_m(punto, (e.longitud, e.latitud)), e) for e in estaciones if ruta.id in e.rutas]
        if propias:
            distancia, estacion = min(propias, key=lambda par: par[0])
            if distancia <= self.RADIO_ESTACION_M:
                return f"Estación {estacion.nombre}", estacion
        cercano = self.places.nearest(punto[0], punto[1], self.RADIO_REFERENCIA_M)
        if cercano:
            return f"Paradero cerca de {cercano[0].nombre}", None
        return "Paradero sobre la vía", None
