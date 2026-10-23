from pydantic import BaseModel, Field
from typing import List

class RoutePoint(BaseModel):
    lat: float = Field(..., ge=-90, le=90)
    lon: float = Field(..., ge=-180, le=180)

class RouteRiskRequest(BaseModel):
    """Polilínea trazada en el mapa que la App Móvil quiere evaluar."""
    route: List[RoutePoint] = Field(..., min_length=2, max_length=5000)

class IncidentRiskDetail(BaseModel):
    id: int
    categoria: str
    intensidad: int

class RouteRiskResponse(BaseModel):
    """Resultado del escaneo de riesgo sobre la ruta."""
    score: int
    nivel: str
    total_incidentes: int
    detalle_incidentes: List[IncidentRiskDetail]
