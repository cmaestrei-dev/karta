"""
Rey o reina de la estación (docs/plan-juego.md, fase B), como las alcaldías de Foursquare.

- La corona es de quien más días aportó en esa estación en los últimos 30 días. Cuenta un aporte por día, y el
  empate lo gana quien ya la tiene.
- Aporta quien hizo allí un reporte que otro confirmó, o votó y la comunidad le dio la razón. Estar ahí no suma.
- Se calcula una vez al día con los días anteriores: la corona no dice quién está en la estación ahora.
- Quien reina pone un apodo del día que dura 24 horas: al ganarla y una vez por semana mientras la conserve. Se ve
  debajo del nombre oficial, nunca en su lugar.
- Si los reportes ocultan su apodo, pierde la corona y no puede reinar en 30 días.
- Solo participa quien lo aceptó. Por defecto se muestra «un karteño», y su apodo de karteño solo si lo pidió.

Todo aquí es puro: sin base de datos ni HTTP.
"""
from dataclasses import dataclass, replace
from datetime import date, datetime, timedelta

from src.domain.horarios import en_colombia

VENTANA_DIAS = 30
MINIMO_DIAS = 2          # con un solo día no se reina: así una corona dice algo
RADIO_DE_ESTACION_M = 80  # un reporte a esta distancia de la estación es de la estación
VIGENCIA_DEL_APODO = timedelta(hours=24)
DIAS_ENTRE_APODOS = 7
CASTIGO = timedelta(days=30)
REPORTES_DE_CONFIANZA_QUE_OCULTAN = 2  # de viajeros de nivel 3 o más
REPORTES_QUE_OCULTAN = 4               # de cualquiera
NIVEL_DE_CONFIANZA = 3
VIGENCIA_DEL_APORTE = timedelta(days=VENTANA_DIAS + 1)
NOMBRE_ANONIMO = "un karteño"


def dia_de(momento: datetime) -> date:
    """El día en Cartagena."""
    return en_colombia(momento).date()


@dataclass(frozen=True)
class ApodoDelDia:
    texto: str
    puesto_por: str
    puesto_en: datetime
    hasta: datetime
    reportes: tuple[tuple[str, int], ...] = ()  # (quién, su nivel)
    oculto: bool = False


@dataclass(frozen=True)
class Corona:
    estacion: str
    rey: str | None = None         # id de quien reina
    desde: date | None = None      # desde qué día reina
    calculada_para: date | None = None
    apodo: ApodoDelDia | None = None
    ultimo_apodo: datetime | None = None  # cuándo puso su último apodo quien reina


@dataclass(frozen=True)
class AportesDe:
    """Lo que alguien aportó en una estación en la ventana: días distintos y el primero de ellos."""
    dias: int
    primero: date


def quien_reina(aportes: dict[str, AportesDe], actual: str | None, vetados: set[str]) -> str | None:
    """Quien más días aportó (al menos [MINIMO_DIAS]). En el empate, quien ya reina; si no está entre los empatados,
    quien empezó antes."""
    candidatos = {u: a for u, a in aportes.items() if u not in vetados and a.dias >= MINIMO_DIAS}
    if not candidatos:
        return None
    mas = max(a.dias for a in candidatos.values())
    empatados = [u for u, a in candidatos.items() if a.dias == mas]
    if actual in empatados:
        return actual
    return min(empatados, key=lambda u: (candidatos[u].primero, u))


def recalcular(corona: Corona, aportes: dict[str, AportesDe], vetados: set[str], hoy: date) -> Corona:
    """La corona de hoy. Si cambia de dueño, el apodo del anterior se va con él."""
    rey = quien_reina(aportes, corona.rey, vetados)
    if rey == corona.rey:
        return replace(corona, calculada_para=hoy)
    return Corona(estacion=corona.estacion, rey=rey, desde=hoy if rey else None, calculada_para=hoy)


def faltan(llevas: int, dias_del_rey: int | None, eres_rey: bool) -> int | None:
    """
    Cuántos días más de aportes le faltan para la corona; None si ya la tiene. [llevas] cuenta hoy y la corona se
    calcula mañana con hoy incluido: 0 quiere decir que mañana puede ser suya. El empate es de quien reina.
    """
    if eres_rey:
        return None
    meta = MINIMO_DIAS if dias_del_rey is None else dias_del_rey + 1
    return max(meta - llevas, 0)


def apodo_vigente(corona: Corona, ahora: datetime) -> ApodoDelDia | None:
    a = corona.apodo
    return a if a is not None and not a.oculto and a.hasta > ahora else None


def puede_poner_apodo(corona: Corona, usuario_id: str, ahora: datetime) -> bool:
    """Al ganar la corona y, mientras la conserve, una vez por semana."""
    if corona.rey != usuario_id or corona.desde is None:
        return False
    ultimo = corona.ultimo_apodo
    if ultimo is None or dia_de(ultimo) < corona.desde:
        return True
    return ahora - ultimo >= timedelta(days=DIAS_ENTRE_APODOS)


def cuando_puede_otra_vez(corona: Corona) -> datetime | None:
    return corona.ultimo_apodo + timedelta(days=DIAS_ENTRE_APODOS) if corona.ultimo_apodo else None


def poner(corona: Corona, texto: str, usuario_id: str, ahora: datetime) -> Corona:
    return replace(corona, apodo=ApodoDelDia(texto=texto, puesto_por=usuario_id, puesto_en=ahora,
                                             hasta=ahora + VIGENCIA_DEL_APODO), ultimo_apodo=ahora)


def reportar(apodo: ApodoDelDia, usuario_id: str, nivel: int) -> ApodoDelDia:
    """Un reporte más (uno por viajero). Se oculta con dos de confianza o cuatro de cualquiera."""
    if any(quien == usuario_id for quien, _ in apodo.reportes):
        return apodo
    reportes = (*apodo.reportes, (usuario_id, nivel))
    de_confianza = sum(1 for _, n in reportes if n >= NIVEL_DE_CONFIANZA)
    oculto = de_confianza >= REPORTES_DE_CONFIANZA_QUE_OCULTAN or len(reportes) >= REPORTES_QUE_OCULTAN
    return replace(apodo, reportes=reportes, oculto=oculto)


@dataclass(frozen=True)
class EstadoDeCorona:
    """Lo que ve un viajero de la corona de una estación."""
    estacion: str
    rey: str | None               # «un karteño», su apodo de karteño, o None si nadie reina
    desde: date | None
    eres_rey: bool
    apodo: ApodoDelDia | None     # solo si está vigente
    participas: bool | None       # None: aún no ha respondido si quiere participar
    llevas: int                   # días con aportes en los últimos 30, contando hoy
    faltan: int | None
    puedes_poner_apodo: bool
    otro_apodo_desde: datetime | None
    reportaste_el_apodo: bool
