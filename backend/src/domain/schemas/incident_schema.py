from datetime import datetime
from typing import List

from pydantic import BaseModel, ConfigDict, Field, model_validator

from src.domain.geo import validar_cobertura


class IncidentCreate(BaseModel):
    """Payload del frontend. El autor se toma del token de sesión, nunca del cuerpo."""
    tipo: str = Field(..., max_length=40, description='Clave del catálogo, ej. "bus_no_pasa"')
    detalles: dict[str, str] = Field(default_factory=dict, max_length=6,
                                     description='Respuestas a las preguntas del tipo, ej. {"ruta": "T103"}')
    latitud: float = Field(..., ge=-90, le=90)
    longitud: float = Field(..., ge=-180, le=180)

    @model_validator(mode="after")
    def dentro_de_cartagena(self):
        validar_cobertura(self.latitud, self.longitud)
        if any(len(k) > 20 or len(v) > 20 for k, v in self.detalles.items()):
            raise ValueError("Los detalles son respuestas cortas.")
        return self


class IncidentResponse(BaseModel):
    """Reporte visible en el mapa. No expone quién lo reportó."""
    model_config = ConfigDict(from_attributes=True)

    id: str
    grupo: str
    tipo: str
    detalles: dict[str, str]
    latitud: float
    longitud: float
    lugar: str | None
    votos_si: int
    votos_no: int
    creado_en: datetime
    expira_en: datetime
    por_confirmar: bool = Field(False, description="De alguien sin cuenta y sin confirmar: no pesa en el riesgo")
    gracias: int = Field(0, description="«Gracias» de quienes usaron el reporte")


class IncidentDetailResponse(IncidentResponse):
    """Al tocar un reporte: quién lo hizo (su alias público) y si el viajero de la sesión ya lo validó."""
    reportado_por_alias: str
    es_mio: bool
    mi_voto: bool | None = Field(None, description="true = «sigue ahí», false = «ya no está», null = no ha votado")
    mis_gracias: bool = Field(False, description="Si el viajero de la sesión ya le dio las gracias")


class VoteRequest(BaseModel):
    sigue: bool = Field(..., description="true = «sigue ahí», false = «ya no está»")


class VoteResponse(BaseModel):
    incidente: IncidentResponse
    retirado: bool = Field(..., description="true si este voto hizo que el reporte deje de mostrarse")


class OpcionResponse(BaseModel):
    valor: str
    etiqueta: str


class CampoResponse(BaseModel):
    clave: str
    pregunta: str
    tipo: str
    obligatorio: bool
    opciones: List[OpcionResponse]


class TipoReporteResponse(BaseModel):
    clave: str
    nombre: str
    vigencia_min: int
    campos: List[CampoResponse]


class GrupoReporteResponse(BaseModel):
    clave: str
    nombre: str
    tipos: List[TipoReporteResponse]
