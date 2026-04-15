from pydantic import BaseModel, Field
from datetime import datetime

class IncidentCreate(BaseModel):
    """Payload del frontend con coordenadas flotantes."""
    id_usuario: int
    categoria: str = Field(..., max_length=50, description="Ej: Seguridad, Tráfico")
    intensidad: int = Field(..., ge=1, le=5, description="Escala de 1 a 5")
    latitud: float
    longitud: float

class IncidentResponse(BaseModel):
    """Respuesta del API ocultando la complejidad espacial."""
    id_incidente: int
    id_usuario: int
    categoria: str
    intensidad: int
    fecha_reporte: datetime

    class Config:
        from_attributes = True