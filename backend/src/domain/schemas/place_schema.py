from pydantic import BaseModel, ConfigDict, Field, model_validator
from typing import List
from src.domain.geo import validar_cobertura
from src.domain.models import IconoLugar

class PlaceResponse(BaseModel):
    """Lugar encontrado por el buscador o al elegir un punto en el mapa."""
    model_config = ConfigDict(from_attributes=True)

    id: str | None = None
    nombre: str
    tipo: str
    latitud: float
    longitud: float
    detalle: str | None = Field(None, description="Para distinguir resultados: «Dirección aproximada · Bocagrande»")

class SavedPlaceCreate(BaseModel):
    nombre: str = Field(..., min_length=1, max_length=40, description='Ej: "Casa", "Trabajo"')
    icono: IconoLugar = IconoLugar.FAVORITO
    latitud: float = Field(..., ge=-90, le=90)
    longitud: float = Field(..., ge=-180, le=180)

    @model_validator(mode="after")
    def dentro_de_cartagena(self):
        validar_cobertura(self.latitud, self.longitud)
        return self

class SavedPlaceUpdate(BaseModel):
    """Actualización parcial: solo se cambian los campos enviados."""
    nombre: str | None = Field(None, min_length=1, max_length=40)
    icono: IconoLugar | None = None
    latitud: float | None = Field(None, ge=-90, le=90)
    longitud: float | None = Field(None, ge=-180, le=180)

    @model_validator(mode="after")
    def cambios_validos(self):
        if not self.model_fields_set:
            raise ValueError("Indica al menos un campo para actualizar.")
        if (self.latitud is None) != (self.longitud is None):
            raise ValueError("La latitud y la longitud se actualizan juntas.")
        if self.latitud is not None:
            validar_cobertura(self.latitud, self.longitud)
        return self

class SavedPlaceResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    nombre: str
    icono: IconoLugar
    latitud: float
    longitud: float

class StopResponse(BaseModel):
    """Estación de Transcaribe cercana."""
    id: str
    nombre: str
    latitud: float
    longitud: float
    rutas: List[str]
    distancia_m: int = Field(..., description="Distancia en línea recta")
    caminata_m: int = Field(..., description="Distancia estimada a pie (la misma regla del planificador de viajes)")
    caminata_min: int = Field(..., description="Minutos estimados a pie")
