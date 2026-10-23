from pydantic import BaseModel, ConfigDict, Field, model_validator
from typing import List, Literal
from src.domain.geo import validar_cobertura
from src.domain.models import CategoriaIncidente

class RoutePoint(BaseModel):
    lat: float = Field(..., ge=-90, le=90)
    lon: float = Field(..., ge=-180, le=180)

class RouteRiskRequest(BaseModel):
    """Polilínea trazada en el mapa que la App Móvil quiere evaluar."""
    route: List[RoutePoint] = Field(..., min_length=2, max_length=5000)

class IncidentRiskDetail(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    categoria: CategoriaIncidente
    intensidad: int

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
    tramos: List[TramoResponse]
    riesgo: RiesgoResumen

class RouteSuggestResponse(BaseModel):
    opciones: List[RouteOptionResponse]
    nota: str
    fuente: str
