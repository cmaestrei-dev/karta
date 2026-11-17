"""
Los indicadores del piloto (docs/plan-comunidad.md, §5) como conteos por día y hora de Colombia, sin cuentas ni
puntos: nacen agregados y se conservan (política, «Estadísticas agregadas y anónimas»). Al mostrarlos, una cifra
con menos de MINIMO_POR_CIFRA casos no se da, y una proporción con un denominador así tampoco.
"""
from dataclasses import dataclass
from datetime import datetime, time

from src.domain.horarios import HORA_DE_COLOMBIA, en_colombia
from src.domain.precision import MINIMO_POR_CIFRA

# Horas pico de Transcaribe: de 6:00 a 7:59 a. m. y de 5:00 a 6:59 p. m.
HORAS_PICO = (6, 7, 17, 18)


def dia(momento: datetime) -> str:
    """«2026-11-18»: el día en Colombia, que es la clave de los conteos."""
    return en_colombia(momento).date().isoformat()


def inicio_del_dia(momento: datetime) -> datetime:
    return datetime.combine(en_colombia(momento).date(), time(0), HORA_DE_COLOMBIA)


def consulta_de_llegada(momento: datetime, troncal: bool, con_datos: bool) -> dict[str, int]:
    """Una consulta de «cuándo llega el bus» (la app repite la suya cada 30 s mientras se espera)."""
    hora, grupo = en_colombia(momento).hour, "troncal" if troncal else "otras"
    campos = {f"llegadas.{grupo}.consultas.{hora}": 1}
    if con_datos:
        campos[f"llegadas.{grupo}.con_datos.{hora}"] = 1
    return campos


def _total(dias: list[dict], *ruta: str) -> int:
    def valor(doc: dict) -> int:
        for clave in ruta:
            doc = doc.get(clave, {}) if isinstance(doc, dict) else {}
        return doc if isinstance(doc, int) else 0
    return sum(valor(d) for d in dias)


def publicable(cuantos: int) -> int | None:
    return cuantos if cuantos >= MINIMO_POR_CIFRA else None


def proporcion(parte: int, todo: int) -> float | None:
    return parte / todo if todo >= MINIMO_POR_CIFRA else None


@dataclass(frozen=True)
class Indicadores:
    """None: menos de MINIMO_POR_CIFRA casos, así que no se da la cifra."""
    dias: int
    llegadas_con_datos_en_pico: float | None  # en la troncal
    viajes_compartidos: int | None
    reportes: int | None
    confirmaciones_por_desmentido: float | None
    agradecieron_de_los_que_vieron: float | None  # personas distintas por día, sumadas
    volvieron_la_semana_siguiente: float | None


def indicadores(dias: list[dict], cuentas_nuevas: int, volvieron: int) -> Indicadores:
    """
    `dias` son los conteos de cada día; `cuentas_nuevas` las cuentas creadas en el piloto con al menos 7 días de
    margen, y `volvieron`, cuántas de ellas se usaron 7 días o más después de crearse.
    """
    consultas = sum(_total(dias, "llegadas", "troncal", "consultas", str(h)) for h in HORAS_PICO)
    con_datos = sum(_total(dias, "llegadas", "troncal", "con_datos", str(h)) for h in HORAS_PICO)
    confirmaciones, desmentidos = _total(dias, "reportes", "confirmaciones"), _total(dias, "reportes", "desmentidos")
    return Indicadores(
        dias=len(dias),
        llegadas_con_datos_en_pico=proporcion(con_datos, consultas),
        viajes_compartidos=publicable(_total(dias, "viajes_compartidos")),
        reportes=publicable(_total(dias, "reportes", "creados")),
        # Sin desmentidos, infinito: el informe lo dice con palabras.
        confirmaciones_por_desmentido=((confirmaciones / desmentidos if desmentidos else float("inf"))
                                       if confirmaciones + desmentidos >= MINIMO_POR_CIFRA else None),
        agradecieron_de_los_que_vieron=proporcion(_total(dias, "personas", "agradecieron"),
                                                  _total(dias, "personas", "vieron_reportes")),
        volvieron_la_semana_siguiente=proporcion(volvieron, cuentas_nuevas),
    )
