from pydantic import BaseModel, ConfigDict, Field, model_validator
from datetime import datetime
from src.domain.geo import validar_cobertura
from src.domain.models import CategoriaIncidente

class IncidentCreate(BaseModel):
    """Payload del frontend. El autor se toma del token de sesión, nunca del cuerpo."""
    categoria: CategoriaIncidente
    intensidad: int = Field(..., ge=1, le=5, description="Escala de 1 a 5")
    latitud: float = Field(..., ge=-90, le=90)
    longitud: float = Field(..., ge=-180, le=180)

    @model_validator(mode="after")
    def dentro_de_cartagena(self):
        validar_cobertura(self.latitud, self.longitud)
        return self

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
