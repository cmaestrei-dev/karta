"""
Reconocimiento sin dinero: marcos del avatar por nivel e insignias por lo que el viajero le ha aportado a la
comunidad (docs/plan-comunidad.md). Se calculan con la reputación y el impacto: nada se guarda aparte, así que
no se pueden «comprar» ni quedar desactualizados. Todo aquí es puro.
"""
from dataclasses import dataclass

from src.domain.models import Impacto

# Los marcos llevan nombres de Cartagena; el nivel 1 aún no tiene marco.
MARCOS = {2: "Muralla", 3: "Bahía", 4: "Castillo", 5: "La Popa"}


@dataclass(frozen=True)
class Insignia:
    clave: str
    nombre: str
    descripcion: str


@dataclass(frozen=True)
class _Regla:
    insignia: Insignia
    dato: str     # campo de Impacto que cuenta
    meta: int
    unidad: str   # cómo se lee el avance: «3 de 10 confirmaciones»


# Solo cuentan aportes que otros validaron: reportar mucho sin que nadie confirme no da insignias.
_REGLAS = (
    _Regla(Insignia("primer_aviso", "Primer aviso", "Alguien confirmó uno de tus reportes"),
           "confirmaciones", 1, "confirmaciones"),
    _Regla(Insignia("ojo_de_halcon", "Ojo de halcón", "Otros viajeros confirmaron 10 de tus reportes"),
           "confirmaciones", 10, "confirmaciones"),
    _Regla(Insignia("gracias_a_ti", "Gracias a ti", "10 viajeros te dieron las gracias"), "gracias", 10, "gracias"),
    _Regla(Insignia("kartografo", "Kartógrafo", "Ubicaste un paradero que no estaba en el mapa"),
           "paraderos", 1, "paraderos ubicados"),
    _Regla(Insignia("gran_kartografo", "Gran Kartógrafo", "Ubicaste 10 paraderos que no estaban en el mapa"),
           "paraderos", 10, "paraderos ubicados"),
    _Regla(Insignia("faro_de_la_bahia", "Faro de la bahía", "100 personas se guiaron con tus reportes"),
           "vistas", 100, "personas que vieron tus reportes"),
)


@dataclass(frozen=True)
class Avance:
    """La insignia que el viajero tiene más cerca, para mostrarle qué le falta."""
    insignia: Insignia
    llevas: int
    meta: int
    unidad: str


def marco(nivel: int) -> str | None:
    return MARCOS.get(min(nivel, 5))


def insignias(impacto: Impacto) -> list[Insignia]:
    """Las insignias ganadas, de la primera a la más difícil."""
    return [r.insignia for r in _REGLAS if getattr(impacto, r.dato) >= r.meta]


def siguiente_insignia(impacto: Impacto) -> Avance | None:
    """La insignia sin ganar con más avance (en empate, la primera del catálogo); None si ya las tiene todas."""
    pendientes = [r for r in _REGLAS if getattr(impacto, r.dato) < r.meta]
    if not pendientes:
        return None
    r = max(pendientes, key=lambda r: getattr(impacto, r.dato) / r.meta)
    if all(getattr(impacto, p.dato) == 0 for p in pendientes):
        r = pendientes[0]
    return Avance(r.insignia, getattr(impacto, r.dato), r.meta, r.unidad)
