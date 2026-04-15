from pydantic import BaseModel
from src.infrastructure.models import TipoViajero

class UserCreate(BaseModel):
    """Esquema de entrada: Lo que el Frontend (Karta App) nos envía."""
    tipo_viajero: TipoViajero

class UserResponse(BaseModel):
    """Esquema de salida: Lo que el Backend le responde al Frontend."""
    id_usuario: int
    tipo_viajero: TipoViajero
    reputacion_puntos: int

    class Config:
        from_attributes = True