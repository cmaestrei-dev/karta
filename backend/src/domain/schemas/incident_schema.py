from pydantic import BaseModel, Field
from datetime import datetime
from typing import Literal, Optional

CategoriaIncidente = Literal["Tráfico", "Seguridad"]

class IncidentCreate(BaseModel):
    """Payload del frontend con coordenadas flotantes."""
    id_usuario: int
    categoria: CategoriaIncidente
    intensidad: int = Field(..., ge=1, le=5, description="Escala de 1 a 5")
    latitud: float = Field(..., ge=-90, le=90)
    longitud: float = Field(..., ge=-180, le=180)

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
