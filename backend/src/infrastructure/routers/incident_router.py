from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session
from src.infrastructure.database import get_db
from src.application.incident_service import IncidentService
from src.domain.schemas.incident_schema import IncidentCreate, IncidentResponse, RouteEvaluationRequest
from typing import List

router = APIRouter(prefix="/api/v1/incidents", tags=["Incidentes"])

@router.post("/", response_model=IncidentResponse, status_code=status.HTTP_201_CREATED)
def report_incident(incident: IncidentCreate, db: Session = Depends(get_db)):
    """
    Registra un evento de la comunidad en el Mapa de Eficiencia.
    Dispara notificaciones en tiempo real a los subsistemas.
    """
    return IncidentService.create_incident(db, incident)

@router.get("/", response_model=List[IncidentResponse]) # Sugerencia: agregué el response_model aquí también
def get_incidents_endpoint(db: Session = Depends(get_db)):
    """
    Retorna la lista de incidentes activos con sus coordenadas para el Radar Táctico de Karta.
    """
    return IncidentService.get_active_incidents(db)

@router.post("/evaluate")
def evaluate_route(request: RouteEvaluationRequest, db: Session = Depends(get_db)):
    """Endpoint para que la App Móvil solicite análisis de riesgo de una ruta."""
    return IncidentService.evaluate_route_risk(db, request)