from datetime import datetime
from typing import List, Literal

from pydantic import BaseModel, ConfigDict, Field, model_validator
from src.domain.geo import validar_cobertura

class RoutePoint(BaseModel):
    lat: float = Field(..., ge=-90, le=90)
    lon: float = Field(..., ge=-180, le=180)

class RouteRiskRequest(BaseModel):
    """Polilínea trazada en el mapa que la App Móvil quiere evaluar."""
    route: List[RoutePoint] = Field(..., min_length=2, max_length=5000)

class IncidentRiskDetail(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    grupo: str
    tipo: str
    votos_si: int

class RouteRiskResponse(BaseModel):
    """Resultado del escaneo de riesgo sobre la ruta."""
    score: int
    nivel: str
    total_incidentes: int
    detalle_incidentes: List[IncidentRiskDetail]

class Coordenada(BaseModel):
    lat: float = Field(..., ge=-90, le=90)
    lon: float = Field(..., ge=-180, le=180)
    nombre: str | None = Field(None, max_length=80, description='Nombre para mostrar, ej. "Mi ubicación"')

    @model_validator(mode="after")
    def dentro_de_cartagena(self):
        validar_cobertura(self.lat, self.lon)
        return self

class RouteSuggestRequest(BaseModel):
    origen: Coordenada
    destino: Coordenada
    criterio: Literal["rapida", "segura", "sin_transbordo"] = Field(
        "rapida", description="Cómo ordenar: la más rápida, la más segura (el riesgo pesa el triple) o sin transbordo")
    salida: datetime | None = Field(
        None, description="Hora de salida (ISO 8601 con zona); por defecto, ahora. Define qué rutas operan")

class LineaGeoJSON(BaseModel):
    type: Literal["LineString"] = "LineString"
    coordinates: List[List[float]] = Field(..., description="Pares [longitud, latitud]")

class TramoResponse(BaseModel):
    modo: Literal["caminata", "bus"]
    desde: str
    hasta: str
    distancia_m: int
    duracion_min: int
    espera_min: int = 0
    ruta: str | None = Field(None, description='Código de la ruta, ej. "T101"')
    nombre_ruta: str | None = None
    tipo_ruta: str | None = None
    geometria: LineaGeoJSON

class RiesgoResumen(BaseModel):
    score: int
    nivel: str
    total_incidentes: int

class RouteOptionResponse(BaseModel):
    resumen: str
    tiempo_total_min: int
    distancia_caminata_m: int
    transbordos: int = Field(..., description="Cambios de bus: 0 o 1")
    tramos: List[TramoResponse]
    riesgo: RiesgoResumen

class RouteSuggestResponse(BaseModel):
    opciones: List[RouteOptionResponse]
    criterio: Literal["rapida", "segura", "sin_transbordo"]
    salida: datetime = Field(..., description="Hora de salida usada, en hora de Colombia")
    aviso: str | None = Field(None, description="Por qué no hay opciones en bus, si es por el horario")
    nota: str
    fuente: str


class RouteGeometryResponse(BaseModel):
    """Una ruta de Transcaribe con su trazado, para dibujarla en el mapa."""
    codigo: str
    nombre: str
    tipo: str
    geometria: dict = Field(..., description="GeoJSON LineString con coordenadas [lon, lat]")
