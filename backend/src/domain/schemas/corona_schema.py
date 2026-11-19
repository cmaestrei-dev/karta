"""Las coronas de las estaciones (docs/plan-juego.md). Nunca llevan el id ni el nombre de nadie."""
from datetime import date, datetime

from pydantic import BaseModel, Field


class ReyResponse(BaseModel):
    nombre: str = Field(..., description="«un karteño», o el apodo de karteño de quien reina si pidió mostrarlo")
    desde: date


class ApodoDelDiaResponse(BaseModel):
    texto: str
    hasta: datetime


class TuCoronaResponse(BaseModel):
    participas: bool | None = Field(..., description="None: todavía no ha respondido si quiere participar")
    llevas: int = Field(..., description="Días con aportes en esta estación en los últimos 30, contando hoy")
    faltan: int | None = Field(..., description="Días que le faltan para la corona; 0: mañana puede ser suya")
    puedes_poner_apodo: bool
    otro_apodo_desde: datetime | None = None
    reportaste_el_apodo: bool = False


class CoronaResponse(BaseModel):
    estacion: str
    rey: ReyResponse | None
    eres_rey: bool
    apodo_del_dia: ApodoDelDiaResponse | None
    tu: TuCoronaResponse | None = Field(None, description="Solo con sesión")


class ApodoRequest(BaseModel):
    texto: str = Field(..., min_length=1, max_length=60)


class ReporteDeApodoResponse(BaseModel):
    oculto: bool


class AjustesDeCoronaRequest(BaseModel):
    participa: bool | None = None
    visible: bool | None = None
    apodo: str | None = Field(None, max_length=60, description="Vacío lo quita")


class AjustesDeCoronaResponse(BaseModel):
    participa: bool | None
    visible: bool
    apodo: str | None
