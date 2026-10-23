from fastapi import APIRouter, Depends
from src.application.incident_service import IncidentService
from src.domain.schemas.route_schema import IncidentRiskDetail, RouteRiskRequest, RouteRiskResponse
from src.infrastructure.dependencies import get_incident_service

router = APIRouter(prefix="/api/v1/routes", tags=["Rutas y Enrutamiento"])

@router.post("/risk", response_model=RouteRiskResponse)
def evaluate_route_risk(request: RouteRiskRequest, service: IncidentService = Depends(get_incident_service)):
    """Escanea la ruta trazada y calcula su nivel de riesgo según los incidentes a menos de 500 m."""
    resultado = service.evaluate_route_risk(request)
    return RouteRiskResponse(
        score=resultado.score,
        nivel=resultado.nivel,
        total_incidentes=len(resultado.incidentes),
        detalle_incidentes=[IncidentRiskDetail.model_validate(i) for i in resultado.incidentes],
    )
