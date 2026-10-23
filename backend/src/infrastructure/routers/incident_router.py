from fastapi import APIRouter, Depends, status
from src.application.incident_service import IncidentService
from src.domain.models import Usuario
from src.domain.schemas.incident_schema import IncidentCreate, IncidentResponse
from src.infrastructure.dependencies import get_current_user, get_incident_service
from typing import List

router = APIRouter(prefix="/api/v1/incidents", tags=["Incidentes"])

@router.post("/", response_model=IncidentResponse, status_code=status.HTTP_201_CREATED)
def report_incident(
    incident: IncidentCreate,
    usuario: Usuario = Depends(get_current_user),
    service: IncidentService = Depends(get_incident_service),
):
    """
    Registra un evento de la comunidad en el Mapa de Eficiencia. Requiere sesión.
    """
    return service.report(usuario, incident)

@router.get("/", response_model=List[IncidentResponse])
def get_incidents_endpoint(service: IncidentService = Depends(get_incident_service)):
    """
    Retorna los incidentes vigentes con sus coordenadas para el Radar Táctico de Karta.
    """
    return service.list_active()
