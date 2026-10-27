"""
Qué tan exacto es Karta (D17): cuánto estimó y cuánto tardó de verdad cada viaje, y las cifras que salen de ahí.

Cada viaje llega sin cuenta, sin puntos y con la hora redondeada al cuarto de hora. Cada cifra reúne viajes de al
menos MINIMO_POR_CIFRA personas distintas; con menos no se calcula (política, «Estadísticas agregadas y anónimas»).
Contar viajes no basta: quien toma el T103 a la misma hora cada día llenaría solo una celda en dos semanas. Cuántas
personas hay detrás de cada celda lo lleva la infraestructura aparte (aportes.py), sin ligarlo a los viajes.
"""
import math
from collections import defaultdict
from dataclasses import dataclass
from datetime import datetime, timedelta
from statistics import median

from src.domain.horarios import en_colombia, tipo_de_dia

MINIMO_POR_CIFRA = 10  # personas distintas
CERCA_MIN = 5  # «acertó»: a menos de 5 minutos de lo estimado


@dataclass(frozen=True)
class BusMedido:
    ruta: str
    espera_estimada_min: int
    # None si no se pudo medir: el viaje empezó ya a bordo, o el GPS no vio la llegada a la parada.
    espera_real_min: int | None
    a_bordo_estimado_min: int
    a_bordo_real_min: int


@dataclass(frozen=True)
class ResultadoDeViaje:
    estimado_min: int
    real_min: int
    franja: datetime  # cuándo empezó, en Colombia y redondeado hacia abajo al cuarto de hora
    tipo_de_dia: str
    buses: tuple[BusMedido, ...]

    @property
    def error_min(self) -> int:
        """Positivo: tardó más de lo que dijo Karta."""
        return self.real_min - self.estimado_min


def celdas_de(r: ResultadoDeViaje) -> list[str]:
    """Las cifras del informe a las que aporta este viaje: el total, su hora y la espera y el tiempo a bordo de cada ruta."""
    celdas = ["total", f"hora:{r.franja.hour}"]
    for bus in r.buses:
        if bus.espera_real_min is not None:
            celdas.append(f"espera:{bus.ruta}")
        celdas.append(f"a_bordo:{bus.ruta}")
    return list(dict.fromkeys(celdas))


def mes_de(momento: datetime) -> str:
    """«2026-11»: las huellas de quienes aportan se agrupan por mes de Colombia."""
    return en_colombia(momento).strftime("%Y-%m")


def franja_de(momento: datetime) -> datetime:
    local = en_colombia(momento)
    return local.replace(minute=local.minute - local.minute % 15, second=0, microsecond=0)


def resultado(estimado_min: int, real_min: int, buses: list[BusMedido], llego_en: datetime) -> ResultadoDeViaje:
    """El viaje tal como se guarda: la hora de salida se deduce de la llegada y se redondea."""
    inicio = franja_de(llego_en - timedelta(minutes=real_min))
    return ResultadoDeViaje(estimado_min, real_min, inicio, tipo_de_dia(inicio.date()), tuple(buses))


@dataclass(frozen=True)
class Precision:
    viajes: int
    mediana_min: float  # del error con signo: positivo, se tarda más de lo estimado
    p90_min: int  # el 90 % de los viajes se equivoca a lo sumo esto, en valor absoluto
    cerca: float  # fracción a menos de CERCA_MIN minutos


def precision(errores: list[int], personas: int) -> Precision | None:
    """Las cifras de un grupo de errores (real − estimado), o None si vienen de menos de MINIMO_POR_CIFRA personas."""
    if not errores or personas < MINIMO_POR_CIFRA:
        return None
    absolutos = sorted(abs(e) for e in errores)
    p90 = absolutos[math.ceil(0.9 * len(absolutos)) - 1]  # percentil por rango más cercano
    cerca = sum(1 for e in absolutos if e < CERCA_MIN) / len(absolutos)
    return Precision(len(errores), float(median(errores)), p90, cerca)


@dataclass(frozen=True)
class Informe:
    total: Precision | None
    por_hora: dict[int, Precision]  # hora del día en Colombia (6 = de 6:00 a 6:59)
    espera_por_ruta: dict[str, Precision]
    a_bordo_por_ruta: dict[str, Precision]
    viajes: int


def informe(resultados: list[ResultadoDeViaje], personas: dict[str, int]) -> Informe:
    """
    Lo que se puede publicar: solo los grupos con viajes de al menos MINIMO_POR_CIFRA personas. `personas` dice
    cuántas personas distintas aportaron a cada celda (celdas_de); una celda que no está ahí no se publica.
    """
    por_hora: dict[int, list[int]] = defaultdict(list)
    espera: dict[str, list[int]] = defaultdict(list)
    a_bordo: dict[str, list[int]] = defaultdict(list)
    for r in resultados:
        por_hora[r.franja.hour].append(r.error_min)
        for bus in r.buses:
            if bus.espera_real_min is not None:
                espera[bus.ruta].append(bus.espera_real_min - bus.espera_estimada_min)
            a_bordo[bus.ruta].append(bus.a_bordo_real_min - bus.a_bordo_estimado_min)

    def publicables(grupos: dict, prefijo: str) -> dict:
        return {clave: p for clave, errores in sorted(grupos.items())
                if (p := precision(errores, personas.get(f"{prefijo}:{clave}", 0)))}

    return Informe(precision([r.error_min for r in resultados], personas.get("total", 0)),
                   publicables(por_hora, "hora"), publicables(espera, "espera"), publicables(a_bordo, "a_bordo"),
                   len(resultados))
