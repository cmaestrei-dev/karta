"""Entidades y reglas del dominio de Karta. No dependen de FastAPI ni de MongoDB."""
import enum
from dataclasses import dataclass
from datetime import datetime

from src.domain.reportes import nivel as nivel_por_reputacion


class TipoViajero(str, enum.Enum):
    RESIDENTE = "Residente"
    TURISTA = "Turista"


REPUTACION_INICIAL = 100  # Sube o baja según la comunidad confirme o desmienta sus reportes
ALIAS_SIN_CUENTA = "Viajero sin cuenta"


@dataclass(frozen=True)
class Impacto:
    """Lo que el viajero le ha aportado a la comunidad: se muestra en su perfil («Tu impacto»)."""
    reportes: int = 0          # reportes hechos
    confirmaciones: int = 0    # veces que otros confirmaron sus reportes
    gracias: int = 0           # «Gracias» recibidos
    vistas: int = 0            # personas que abrieron sus reportes
    paraderos: int = 0         # paraderos que marcó y la comunidad confirmó (Kartógrafo)


@dataclass(frozen=True)
class Usuario:
    """
    Un viajero. Sin correo es la cuenta invisible del teléfono: se crea sola al abrir Karta, sin nombre ni
    correo, y registrarse le pone correo a esa misma cuenta (conserva la reputación y los lugares).
    """
    id: str
    email: str | None
    nombre: str | None
    tipo_viajero: TipoViajero | None
    reputacion: int
    password_hash: str | None
    creado_en: datetime
    alias: str  # nombre corto que ven los demás viajeros
    impacto: Impacto = Impacto()

    @property
    def nivel(self) -> int:
        return nivel_por_reputacion(self.reputacion)

    @property
    def sin_cuenta(self) -> bool:
        return self.email is None

    @property
    def marco(self) -> str | None:
        from src.domain.reconocimiento import marco
        return marco(self.nivel)

    @property
    def insignias(self) -> list:
        from src.domain.reconocimiento import insignias
        return insignias(self.impacto)

    @property
    def siguiente_insignia(self):
        from src.domain.reconocimiento import siguiente_insignia
        return siguiente_insignia(self.impacto)


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
    # Lo reportó alguien sin cuenta y nadie lo ha confirmado: se ve en el mapa, pero no pesa en el riesgo.
    por_confirmar: bool = False
    nivel_autor: int = 1   # el nivel de quien reportó, al reportar: pesa en el riesgo
    gracias: int = 0       # «Gracias» de quienes usaron el reporte


class IconoLugar(str, enum.Enum):
    CASA = "casa"
    TRABAJO = "trabajo"
    ESTUDIO = "estudio"
    FAVORITO = "favorito"


MAX_LUGARES_GUARDADOS = 10


@dataclass(frozen=True)
class Lugar:
    """Punto buscable de la ciudad (barrio, sitio turístico, estación, dirección...)."""
    id: str | None
    nombre: str
    tipo: str
    latitud: float
    longitud: float
    detalle: str | None = None  # para distinguir resultados con el mismo nombre: «Dirección aproximada · Bocagrande»


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
    desde: str = ""   # cabeceras, como las nombra OSM («Ciudad Jardín», «Patio Portal»)
    hasta: str = ""


class EmailYaRegistrado(Exception):
    pass


class CredencialesInvalidas(Exception):
    pass


class LimiteLugaresGuardados(Exception):
    pass


class LugarGuardadoNoEncontrado(Exception):
    pass
