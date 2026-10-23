from pydantic import BaseModel, ConfigDict, Field
from datetime import datetime
from src.domain.models import CategoriaIncidente

class IncidentCreate(BaseModel):
    """Payload del frontend. El autor se toma del token de sesión, nunca del cuerpo."""
    categoria: CategoriaIncidente
    intensidad: int = Field(..., ge=1, le=5, description="Escala de 1 a 5")
    latitud: float = Field(..., ge=-90, le=90)
    longitud: float = Field(..., ge=-180, le=180)

class IncidentResponse(BaseModel):
    """Incidente visible en el mapa. No expone quién lo reportó."""
    model_config = ConfigDict(from_attributes=True)

    id: str
    categoria: CategoriaIncidente
    intensidad: int
    latitud: float
    longitud: float
    creado_en: datetime
    expira_en: datetime
