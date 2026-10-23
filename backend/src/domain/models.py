"""Entidades y reglas del dominio de Karta. No dependen de FastAPI ni de MongoDB."""
import enum
from dataclasses import dataclass
from datetime import datetime, timedelta


class TipoViajero(str, enum.Enum):
    RESIDENTE = "Residente"
    TURISTA = "Turista"


class CategoriaIncidente(str, enum.Enum):
    TRAFICO = "Tráfico"
    SEGURIDAD = "Seguridad"


# Tiempo que un reporte sigue activo; luego MongoDB lo elimina con un índice TTL.
VIGENCIA_POR_CATEGORIA = {
    CategoriaIncidente.TRAFICO: timedelta(hours=3),
    CategoriaIncidente.SEGURIDAD: timedelta(hours=12),
}

REPUTACION_INICIAL = 100  # Validará la veracidad de reportes


@dataclass(frozen=True)
class Usuario:
    id: str
    email: str
    nombre: str
    tipo_viajero: TipoViajero
    reputacion: int
    password_hash: str
    creado_en: datetime


@dataclass(frozen=True)
class Incidente:
    id: str
    reportado_por: str
    categoria: CategoriaIncidente
    intensidad: int
    latitud: float
    longitud: float
    creado_en: datetime
    expira_en: datetime


class IconoLugar(str, enum.Enum):
    CASA = "casa"
    TRABAJO = "trabajo"
    ESTUDIO = "estudio"
    FAVORITO = "favorito"


MAX_LUGARES_GUARDADOS = 10


@dataclass(frozen=True)
class Lugar:
    """Punto buscable de la ciudad (barrio, sitio turístico, estación...)."""
    id: str | None
    nombre: str
    tipo: str
    latitud: float
    longitud: float


@dataclass(frozen=True)
class LugarGuardado:
    """Lugar frecuente de un viajero ("Casa", "Trabajo"). Vive embebido en su documento."""
    id: str
    nombre: str
    icono: IconoLugar
    latitud: float
    longitud: float


@dataclass(frozen=True)
class Estacion:
    id: str
    nombre: str
    latitud: float
    longitud: float
    rutas: list[str]


@dataclass(frozen=True)
class RutaTransporte:
    """Ruta de Transcaribe con su recorrido ordenado en el sentido de circulación."""
    id: str
    nombre: str
    tipo: str  # troncal | pretroncal | alimentadora | complementaria
    coordenadas: list[tuple[float, float]]  # (lon, lat)
    cortes_en_osm: int


class EmailYaRegistrado(Exception):
    pass


class CredencialesInvalidas(Exception):
    pass


class LimiteLugaresGuardados(Exception):
    pass


class LugarGuardadoNoEncontrado(Exception):
    pass
