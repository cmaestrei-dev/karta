from pydantic import BaseModel, Field
from datetime import datetime
from typing import List, Optional

class IncidentCreate(BaseModel):
    """Payload del frontend con coordenadas flotantes."""
    id_usuario: int
    categoria: str = Field(..., max_length=50, description="Ej: Seguridad, Tráfico")
    intensidad: int = Field(..., ge=1, le=5, description="Escala de 1 a 5")
    latitud: float
    longitud: float

class IncidentResponse(BaseModel):
    """Respuesta del API. Agregamos lat/lon para que el Radar las vea."""
    id_incidente: int
    id_usuario: int
    categoria: str
    intensidad: int

    latitud: float 
    longitud: float
    fecha_reporte: Optional[datetime] = None

    class Config:
        from_attributes = True

class RoutePoint(BaseModel):
    lat: float
    lon: float

class RouteEvaluationRequest(BaseModel):
    route: List[RoutePoint]