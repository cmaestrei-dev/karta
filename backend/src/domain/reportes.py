"""
Catálogo de tipos de reporte y reglas de la validación comunitaria (casos de uso #5 y #9).

Un reporte es un tipo concreto («el bus no pasa») con detalles concretos (qué ruta, hace cuánto),
nunca una escala abstracta. Los demás viajeros lo confirman o lo desmienten: eso decide cuánto vive
y cuánta reputación gana o pierde quien lo reportó. Todo aquí es puro: sin base de datos ni HTTP.
"""
import enum
import re
from dataclasses import dataclass
from datetime import datetime, timedelta


class Grupo(str, enum.Enum):
    SERVICIO = "servicio"
    VIA = "via"
    SEGURIDAD = "seguridad"


NOMBRE_GRUPO = {Grupo.SERVICIO: "El servicio", Grupo.VIA: "La vía", Grupo.SEGURIDAD: "Tu seguridad"}


@dataclass(frozen=True)
class CampoDetalle:
    """Una pregunta concreta del reporte. `opciones` vacías + tipo "ruta" = un código de ruta de Transcaribe."""
    clave: str
    pregunta: str
    tipo: str = "opciones"  # "opciones" | "ruta"
    opciones: tuple[tuple[str, str], ...] = ()  # (valor, etiqueta para mostrar)
    obligatorio: bool = False


@dataclass(frozen=True)
class TipoReporte:
    clave: str
    nombre: str
    grupo: Grupo
    peso: int  # aporte al riesgo de una ruta que pasa cerca
    vigencia: timedelta  # cuánto vive sin confirmaciones; cada confirmación la renueva
    campos: tuple[CampoDetalle, ...] = ()


_RUTA = CampoDetalle("ruta", "¿Qué ruta?", tipo="ruta", obligatorio=True)

CATALOGO: dict[str, TipoReporte] = {t.clave: t for t in [
    TipoReporte("bus_no_pasa", "El bus no pasa", Grupo.SERVICIO, peso=2, vigencia=timedelta(hours=1), campos=(
        CampoDetalle("ruta", "¿Qué ruta esperas?", tipo="ruta", obligatorio=True),
        CampoDetalle("espera", "¿Hace cuánto esperas?",
                     opciones=(("10", "10 min"), ("20", "20 min"), ("30", "30 min o más"))),
    )),
    TipoReporte("bus_lleno", "Bus lleno, no paró", Grupo.SERVICIO, peso=2, vigencia=timedelta(minutes=30),
                campos=(_RUTA,)),
    TipoReporte("estacion_cerrada", "Estación cerrada", Grupo.SERVICIO, peso=6, vigencia=timedelta(hours=4)),
    TipoReporte("trancon", "Trancón", Grupo.VIA, peso=4, vigencia=timedelta(hours=1), campos=(
        CampoDetalle("estado", "¿Cómo está el tráfico?", opciones=(("lento", "Lento"), ("detenido", "Detenido"))),
    )),
    TipoReporte("accidente", "Accidente", Grupo.VIA, peso=10, vigencia=timedelta(hours=2), campos=(
        CampoDetalle("via", "¿Cómo está la vía?", opciones=(("un_carril", "Ocupa un carril"),
                                                            ("bloqueada", "Bloquea la vía"))),
    )),
    TipoReporte("calle_inundada", "Calle inundada", Grupo.VIA, peso=8, vigencia=timedelta(hours=3), campos=(
        CampoDetalle("paso", "¿Se puede pasar?", opciones=(("con_cuidado", "Con cuidado"),
                                                          ("no_se_puede", "No se puede"))),
    )),
    TipoReporte("robo", "Robo", Grupo.SEGURIDAD, peso=25, vigencia=timedelta(hours=6)),
    TipoReporte("calle_sola", "Calle sola u oscura", Grupo.SEGURIDAD, peso=8, vigencia=timedelta(hours=12)),
    TipoReporte("acoso", "Acoso", Grupo.SEGURIDAD, peso=20, vigencia=timedelta(hours=6), campos=(
        CampoDetalle("donde", "¿Dónde pasó?", opciones=(("estacion", "En la estación"), ("bus", "En el bus"),
                                                        ("calle", "En la calle"))),
    )),
]}

PATRON_RUTA = re.compile(r"^[ATXC]\d{3}E?$")


class DetallesInvalidos(ValueError):
    pass


def validar_detalles(tipo: TipoReporte, detalles: dict[str, str], rutas_existentes: set[str]) -> dict[str, str]:
    """Devuelve los detalles limpios o lanza DetallesInvalidos con un mensaje para el viajero."""
    campos = {c.clave: c for c in tipo.campos}
    sobrantes = set(detalles) - set(campos)
    if sobrantes:
        raise DetallesInvalidos(f"«{tipo.nombre}» no lleva estos datos: {', '.join(sorted(sobrantes))}.")
    limpios: dict[str, str] = {}
    for campo in tipo.campos:
        valor = (detalles.get(campo.clave) or "").strip()
        if not valor:
            if campo.obligatorio:
                raise DetallesInvalidos(f"Falta responder: {campo.pregunta}")
            continue
        if campo.tipo == "ruta":
            valor = valor.upper()
            if not PATRON_RUTA.match(valor) or valor not in rutas_existentes:
                raise DetallesInvalidos(f"{valor} no es una ruta de Transcaribe.")
        elif valor not in {v for v, _ in campo.opciones}:
            raise DetallesInvalidos(f"Respuesta no válida para: {campo.pregunta}")
        limpios[campo.clave] = valor
    return limpios


# ---------------------------------------------------------------- validación comunitaria

VOTOS_PARA_RETIRAR = 2  # «ya no está» seguidos (sin un «sigue ahí» en medio) que retiran un reporte

REPUTACION_POR_CONFIRMACION = 2  # para quien reportó, cada vez que otro confirma
REPUTACION_POR_RETIRO = -5  # para quien reportó, si la comunidad lo desmiente
REPUTACION_POR_VOTAR = 1  # para quien ayuda a validar

# Cada confirmación hace pesar más el reporte en el riesgo de una ruta, hasta el doble.
AUMENTO_DE_PESO_POR_CONFIRMACION = 0.25
CONFIRMACIONES_QUE_CUENTAN = 4


def expiracion_al_confirmar(tipo: TipoReporte, expira_en: datetime, ahora: datetime) -> datetime:
    """Una confirmación renueva la vigencia completa desde ahora, sin acortarla nunca."""
    return max(expira_en, ahora + tipo.vigencia)


def debe_retirarse(no_seguidos: int) -> bool:
    return no_seguidos >= VOTOS_PARA_RETIRAR


def peso_en_riesgo(tipo: TipoReporte, confirmaciones: int) -> float:
    factor = 1 + AUMENTO_DE_PESO_POR_CONFIRMACION * min(confirmaciones, CONFIRMACIONES_QUE_CUENTAN)
    return tipo.peso * factor


NIVELES = [(450, 5), (300, 4), (200, 3), (150, 2)]


def nivel(reputacion: int) -> int:
    """Nivel visible del viajero según su reputación (todos empiezan en 100, nivel 1)."""
    return next((n for umbral, n in NIVELES if reputacion >= umbral), 1)


def alias_publico(nombre: str) -> str:
    """Nombre corto que ven los demás: el primer nombre y la inicial del siguiente («Ana P.»)."""
    partes = nombre.split()
    if not partes:
        return "Viajero"
    return f"{partes[0]} {partes[1][0].upper()}." if len(partes) > 1 else partes[0]


class IncidenteNoEncontrado(Exception):
    pass


class VotoPropio(Exception):
    pass


class VotoRepetido(Exception):
    pass
