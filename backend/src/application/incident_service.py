from datetime import datetime, timezone

from src.domain.models import VIGENCIA_POR_CATEGORIA, Incidente, Usuario
from src.domain.ports import IncidentRepository
from src.domain.route_risk import ResultadoRiesgo, corredor_de_ruta, evaluar_riesgo
from src.domain.schemas.incident_schema import IncidentCreate
from src.domain.schemas.route_schema import RouteRiskRequest


class IncidentService:
    MAX_INCIDENTES_EN_MAPA = 500

    def __init__(self, incidents: IncidentRepository):
        self.incidents = incidents

    def report(self, usuario: Usuario, datos: IncidentCreate) -> Incidente:
        """Caso de Uso: Reportar incidente. El autor es el usuario de la sesión."""
        ahora = datetime.now(timezone.utc)
        return self.incidents.add(
            reportado_por=usuario.id,
            categoria=datos.categoria,
            intensidad=datos.intensidad,
            latitud=datos.latitud,
            longitud=datos.longitud,
            creado_en=ahora,
            expira_en=ahora + VIGENCIA_POR_CATEGORIA[datos.categoria],
        )

    def list_active(self) -> list[Incidente]:
        """Caso de Uso: Consultar incidentes vigentes para el Radar Táctico."""
        return self.incidents.list_active(datetime.now(timezone.utc), self.MAX_INCIDENTES_EN_MAPA)

    def evaluate_route_risk(self, request: RouteRiskRequest) -> ResultadoRiesgo:
        """
        Caso de Uso: Escanear el riesgo de una ruta.
        Construye un corredor de 500 m alrededor de la ruta y lo consulta en una sola
        búsqueda geoespacial, en lugar de una consulta por cada punto.
        """
        area = corredor_de_ruta([(p.lon, p.lat) for p in request.route])
        cercanos = self.incidents.find_active_within(area, datetime.now(timezone.utc))
        return evaluar_riesgo(cercanos)
