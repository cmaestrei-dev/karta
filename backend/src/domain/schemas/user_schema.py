from typing import Literal
from pydantic import BaseModel, ConfigDict, EmailStr, Field
from src.domain.models import TipoViajero
from src.domain.politica import VERSION_POLITICA

class RegisterRequest(BaseModel):
    """Datos del formulario de registro (Caso de Uso #1)."""
    email: EmailStr
    password: str = Field(..., min_length=8, max_length=128)
    nombre: str = Field(..., min_length=1, max_length=80)
    tipo_viajero: TipoViajero
    acepta_terminos: Literal[True] = Field(
        ..., description="Consentimiento para el tratamiento de datos personales (Ley 1581 de 2012)."
    )

class AutorizacionRequest(BaseModel):
    """Aceptó el aviso de privacidad de esta versión de la política de datos."""
    version: str = Field(..., max_length=20, examples=["1.0"])

class InvisibleRequest(BaseModel):
    """El secreto aleatorio que el teléfono generó la primera vez y guarda en su almacenamiento seguro."""
    secreto: str = Field(..., min_length=32, max_length=128)
    politica: str | None = Field(None, max_length=20, examples=["1.1"],
                                 description="La versión del aviso de privacidad que se aceptó en el teléfono")

class LoginRequest(BaseModel):
    email: EmailStr
    password: str = Field(..., min_length=1, max_length=128)
    politica: str | None = Field(None, max_length=20, examples=["1.1"],
                                 description="La versión del aviso de privacidad que se aceptó en el teléfono")

class ImpactoResponse(BaseModel):
    """«Tu impacto»: lo que el viajero le ha aportado a la comunidad."""
    model_config = ConfigDict(from_attributes=True)

    reportes: int = 0
    confirmaciones: int = Field(0, description="Veces que otros confirmaron sus reportes")
    gracias: int = Field(0, description="«Gracias» recibidos")
    paraderos: int = Field(0, description="Paraderos que marcó y la comunidad confirmó")
    vistas: int = Field(0, description="Personas que abrieron sus reportes")

class InsigniaResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    clave: str
    nombre: str
    descripcion: str

class AvanceResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    insignia: InsigniaResponse
    llevas: int
    meta: int
    unidad: str = Field(..., description="Cómo se lee el avance: «3 de 10 confirmaciones»")

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
    impacto: ImpactoResponse = ImpactoResponse()
    marco: str | None = Field(None, description="Marco del avatar por nivel: Muralla, Bahía, Castillo o La Popa")
    insignias: list[InsigniaResponse] = []
    siguiente_insignia: AvanceResponse | None = Field(None, description="La insignia sin ganar más cercana")
    autorizacion: str | None = Field(None, description="Última versión de la política de datos que aceptó")
    politica_vigente: str = Field(VERSION_POLITICA, description="Si no es la que aceptó, la app vuelve a mostrar el aviso")

class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    usuario: UserResponse
