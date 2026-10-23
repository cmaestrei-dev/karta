from fastapi import APIRouter, Depends, status
from src.application.incident_service import IncidentService
from src.domain.models import Usuario
from src.domain.schemas.incident_schema import IncidentCreate, IncidentResponse
from src.infrastructure.dependencies import get_current_user, get_incident_service
from src.infrastructure.routers.respuestas import FUERA_DE_COBERTURA, SIN_SESION
from typing import List

router = APIRouter(prefix="/api/v1/incidents", tags=["Incidentes"])

@router.post("/", summary="Reportar un incidente", response_model=IncidentResponse, status_code=status.HTTP_201_CREATED,
             responses={**SIN_SESION, **FUERA_DE_COBERTURA})
def report_incident(
    incident: IncidentCreate,
    usuario: Usuario = Depends(get_current_user),
    service: IncidentService = Depends(get_incident_service),
):
    """
    Reporta un incidente de tráfico o seguridad. Requiere sesión: el autor sale del token, nunca del cuerpo.
    El incidente deja de mostrarse solo (Tráfico 3 h, Seguridad 12 h) gracias a un índice TTL de MongoDB.
    """
    return service.report(usuario, incident)

@router.get("/", summary="Incidentes vigentes", response_model=List[IncidentResponse])
def get_incidents_endpoint(service: IncidentService = Depends(get_incident_service)):
    """
    Incidentes vigentes (no vencidos) con sus coordenadas, para pintarlos en el mapa.
    """
    return service.list_active()
