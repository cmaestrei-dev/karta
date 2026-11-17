from typing import Literal
from pydantic import BaseModel, ConfigDict, EmailStr, Field
from src.domain.models import TipoViajero

class RegisterRequest(BaseModel):
    """Datos del formulario de registro (Caso de Uso #1)."""
    email: EmailStr
    password: str = Field(..., min_length=8, max_length=128)
    nombre: str = Field(..., min_length=1, max_length=80)
    tipo_viajero: TipoViajero
    acepta_terminos: Literal[True] = Field(
        ..., description="Consentimiento para el tratamiento de datos personales (Ley 1581 de 2012)."
    )

class InvisibleRequest(BaseModel):
    """El secreto aleatorio que el teléfono generó la primera vez y guarda en su almacenamiento seguro."""
    secreto: str = Field(..., min_length=32, max_length=128)

class LoginRequest(BaseModel):
    email: EmailStr
    password: str = Field(..., min_length=1, max_length=128)

class UserResponse(BaseModel):
    """Perfil público del viajero. Nunca incluye el hash de la contraseña."""
    model_config = ConfigDict(from_attributes=True)

    id: str
    email: str | None = Field(None, description="null en la cuenta invisible")
    nombre: str | None = None
    alias: str = Field(..., description="Nombre corto que ven los demás viajeros")
    tipo_viajero: TipoViajero | None = None
    reputacion: int
    nivel: int = Field(..., description="Nivel según la reputación (1 a 5)")
    sin_cuenta: bool = Field(..., description="true: cuenta invisible del teléfono, sin correo")

class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    usuario: UserResponse
