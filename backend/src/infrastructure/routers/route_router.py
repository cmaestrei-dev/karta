from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from src.infrastructure.database import get_db
from src.application.incident_service import IncidentService
from src.domain.schemas.route_schema import RouteRiskRequest, RouteRiskResponse

router = APIRouter(prefix="/api/v1/routes", tags=["Rutas y Enrutamiento"])

@router.post("/risk", response_model=RouteRiskResponse)
def evaluate_route_risk(request: RouteRiskRequest, db: Session = Depends(get_db)):
    """Escanea la ruta trazada y calcula su nivel de riesgo según los incidentes cercanos."""
    return IncidentService.evaluate_route_risk(db, request)
