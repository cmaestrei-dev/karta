from typing import List, Literal

from pydantic import BaseModel, Field

from src.domain.mapeo import PARADAS_POR_VIAJE
from src.domain.schemas.realtime_schema import PATRON_RUTA, _EnCartagena

EstadoDeParadero = Literal["estacion", "direccion", "estimado", "comunidad", "por_confirmar", "sin_ubicar"]


class MarcaResponse(BaseModel):
    id: str
    paradero: str
    latitud: float
    longitud: float
    apoyo: int = Field(..., description="Marca y confirmaciones menos los «no está aquí»; con 3 queda en el mapa")
    estado: Literal["por_confirmar", "ubicada", "descartada"]
    mia: bool = Field(False, description="La marcó quien pregunta")
    mi_voto: bool | None = Field(None, description="true: confirmó; false: dijo que no está; null: no ha votado")


class ParaderoResponse(BaseModel):
    id: str
    orden: int
    nombre: str
    estado: EstadoDeParadero
    modulo: str | None = None
    latitud: float | None = None
    longitud: float | None = None
    marca: MarcaResponse | None = Field(None, description="La marca por confirmar, si hay una")


class SentidoResponse(BaseModel):
    sentido: Literal["ida", "vuelta", "circular"]
    hacia: str | None = None
    paraderos: List[ParaderoResponse]


class PistaResponse(BaseModel):
    """Varias subidas a la ruta en el mismo lugar: casi seguro hay un paradero."""
    latitud: float
    longitud: float
    subidas: int


class ParaderosDeRutaResponse(BaseModel):
    ruta: str
    ubicados: int
    total: int
    sentidos: List[SentidoResponse]
    pistas: List[PistaResponse]


class MarcarRequest(_EnCartagena):
    """Dónde está el paradero: se lleva a la calle por donde pasa la ruta."""


class VotoDeMarcaRequest(_EnCartagena):
    """Desde dónde se responde: hay que estar a menos de 300 m de la marca."""
    esta_aqui: bool


class ParadaDelViajeRequest(_EnCartagena):
    """«El bus paró aquí», en ese paradero de la lista oficial."""
    paradero: str = Field(..., max_length=40, examples=["A107-ida-03"])


class ViajeDeMapeoRequest(BaseModel):
    sentido: Literal["ida", "vuelta", "circular"]
    paradas: List[ParadaDelViajeRequest] = Field(..., min_length=1, max_length=PARADAS_POR_VIAJE)


class ResultadoDeParadaResponse(BaseModel):
    paradero: str
    resultado: Literal["marcado", "confirmado", "contradicho", "ya_ubicado", "ya_respondido", "dudoso",
                       "lejos_del_recorrido", "otra_ruta"]


class ViajeDeMapeoResponse(BaseModel):
    marcados: int = Field(..., description="Paraderos que no tenían marca y ahora la tienen")
    confirmados: int = Field(..., description="Marcas que había y coincidieron con donde paró el bus")
    contradichos: int = Field(..., description="Marcas que había, lejos de donde paró el bus")
    paradas: List[ResultadoDeParadaResponse]


class SubidaRequest(_EnCartagena):
    ruta: str = Field(..., pattern=PATRON_RUTA, examples=["A107"])
