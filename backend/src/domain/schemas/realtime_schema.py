from datetime import datetime  # noqa: F401  (documentación de Swagger)
from typing import Literal

from pydantic import BaseModel, Field, model_validator

from src.domain.geo import validar_cobertura

PATRON_RUTA = r"^[ATXC]\d{3}E?$"
OcupacionApi = Literal["con_puestos", "de_pie", "muy_lleno"]


class _EnCartagena(BaseModel):
    latitud: float = Field(..., ge=-90, le=90)
    longitud: float = Field(..., ge=-180, le=180)

    @model_validator(mode="after")
    def dentro_de_cartagena(self):
        validar_cobertura(self.latitud, self.longitud)
        return self


class AvistamientoRequest(_EnCartagena):
    """«Vi pasar el T103» desde una parada, o cómo va de lleno desde adentro."""
    ruta: str = Field(..., pattern=PATRON_RUTA, examples=["T103"])
    ocupacion: OcupacionApi | None = None


class ViajeCompartidoRequest(_EnCartagena):
    ruta: str = Field(..., pattern=PATRON_RUTA, examples=["T103"])


class ViajeCompartidoResponse(BaseModel):
    viaje: str = Field(..., description="Identificador aleatorio del viaje; no está ligado al viajero")
    vence_en_s: int = Field(..., description="Sin una posición nueva en este tiempo, el viaje se borra")


class PosicionRequest(_EnCartagena):
    ocupacion: OcupacionApi | None = None


class VaradoResponse(BaseModel):
    """Un bus de la ruta varado antes de la subida: no cuenta como uno que viene."""
    lugar: str | None = Field(None, description="Dónde se varó («Cerca de Bazurto»)")
    metros_antes: int = Field(..., description="A cuántos metros antes de la subida, sobre la ruta")
    hace_min: int = Field(..., description="Hace cuánto lo reportaron")
    confirmaciones: int = Field(..., description="Cuántos viajeros más lo confirmaron")


class LlegadaResponse(BaseModel):
    """Cuánto le falta al próximo bus, según los viajeros. Sin observaciones, `minutos` es null."""
    minutos: int | None = None
    fuentes: int = Field(0, description="Cuántos viajeros lo respaldan")
    ocupacion: OcupacionApi | None = None
    visto_hace_min: int | None = None
    varado: VaradoResponse | None = None
