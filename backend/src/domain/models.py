"""Entidades y reglas del dominio de Karta. No dependen de FastAPI ni de MongoDB."""
import enum
from dataclasses import dataclass
from datetime import datetime

from src.domain.reportes import nivel as nivel_por_reputacion


class TipoViajero(str, enum.Enum):
    RESIDENTE = "Residente"
    TURISTA = "Turista"


REPUTACION_INICIAL = 100  # Sube o baja según la comunidad confirme o desmienta sus reportes


@dataclass(frozen=True)
class Usuario:
    id: str
    email: str
    nombre: str
    tipo_viajero: TipoViajero
    reputacion: int
    password_hash: str
    creado_en: datetime
    alias: str  # nombre corto que ven los demás viajeros

    @property
    def nivel(self) -> int:
        return nivel_por_reputacion(self.reputacion)


@dataclass(frozen=True)
class Incidente:
    """Reporte de la comunidad: un tipo del catálogo (src/domain/reportes.py) con sus detalles."""
    id: str
    reportado_por: str
    grupo: str
    tipo: str
    detalles: dict[str, str]
    latitud: float
    longitud: float
    lugar: str | None  # nombre legible del sitio, calculado al reportar
    votos_si: int
    votos_no: int
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
