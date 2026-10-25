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
    caminata_maxima_m: int | None = Field(
        None, ge=200, le=2000, description="Lo máximo que se quiere caminar hasta la ruta o desde ella, a pie de verdad "
                                           "(por defecto, unos 1.000 m)")

class LineaGeoJSON(BaseModel):
    type: Literal["LineString"] = "LineString"
    coordinates: List[List[float]] = Field(..., description="Pares [longitud, latitud]")

class ParadaDelTramo(BaseModel):
    nombre: str
    latitud: float
    longitud: float


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
    paradas: List[ParadaDelTramo] = Field(
        default_factory=list,
        description="Estaciones por las que pasa el bus en este tramo, en orden (vacía fuera de la troncal)")
    alternativas: List[str] = Field(
        default_factory=list, description="Otras rutas igual de buenas en este tramo: se toma la que pase primero")
    modulo: str | None = Field(None, description="Módulo de la estación donde para el bus en este sentido («A1»)")
    hacia: str | None = Field(None, description="Hacia dónde va el bus («Bocagrande»)")
    indicacion: str | None = Field(
        None, description="En la caminata de un transbordo integrado, cómo hacer el cambio "
                          "(«Sal de Santa Lucía y cruza por la cebra hasta Madre Bernarda…»)")
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


class EstacionDeRuta(BaseModel):
    id: str
    nombre: str
    latitud: float
    longitud: float


class FranjaDeServicio(BaseModel):
    primera: str = Field(..., description='Primer despacho, "HH:MM" en hora de Colombia')
    ultima: str = Field(..., description='Último despacho, "HH:MM"')


class HorarioDeRuta(BaseModel):
    lunes_a_viernes: FranjaDeServicio | None = None
    sabado: FranjaDeServicio | None = None
    domingo_y_festivos: FranjaDeServicio | None = None


class RoutePageResponse(BaseModel):
    """La página de una ruta: recorrido, estaciones en orden y horario."""
    codigo: str
    nombre: str
    tipo: str
    desde: str
    hasta: str
    geometria: dict = Field(..., description="GeoJSON LineString con coordenadas [lon, lat]")
    estaciones: List[EstacionDeRuta]
    horario: HorarioDeRuta | None = Field(None, description="Null si Transcaribe no publica el horario de la ruta")
    hoy: Literal["lunes_a_viernes", "sabado", "domingo_y_festivos"]
    opera_ahora: bool | None = Field(None, description="Null si no hay horario para saberlo")
