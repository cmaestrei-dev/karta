from pydantic import BaseModel, ConfigDict, Field
from typing import List
from src.domain.models import CategoriaIncidente

class RoutePoint(BaseModel):
    lat: float = Field(..., ge=-90, le=90)
    lon: float = Field(..., ge=-180, le=180)

class RouteRiskRequest(BaseModel):
    """Polilínea trazada en el mapa que la App Móvil quiere evaluar."""
    route: List[RoutePoint] = Field(..., min_length=2, max_length=5000)

class IncidentRiskDetail(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    categoria: CategoriaIncidente
    intensidad: int

class RouteRiskResponse(BaseModel):
    """Resultado del escaneo de riesgo sobre la ruta."""
    score: int
    nivel: str
    total_incidentes: int
    detalle_incidentes: List[IncidentRiskDetail]
