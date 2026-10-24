"""
Horarios de servicio de Transcaribe: primer y último despacho de cada ruta por tipo de día
(datos abiertos de Cartagena). Sirven para no sugerir una ruta que a esa hora no opera.
"""
from dataclasses import dataclass
from datetime import date, datetime, time, timedelta, timezone

# Colombia no tiene horario de verano: siempre UTC−5.
HORA_DE_COLOMBIA = timezone(timedelta(hours=-5), "COT")

# El último bus sale de la cabecera a la hora de cierre y sigue recogiendo pasajeros por el camino.
MARGEN_DEL_ULTIMO_BUS = timedelta(minutes=30)

DIAS = ("lunes_a_viernes", "sabado", "domingo_y_festivos")


@dataclass(frozen=True)
class HorarioRuta:
    codigo: str
    # Por tipo de día, (primer despacho, último despacho); None si ese día no opera.
    por_dia: dict[str, tuple[time, time] | None]

    @classmethod
    def desde_texto(cls, codigo: str, por_dia: dict[str, list[str] | None]) -> "HorarioRuta":
        return cls(codigo=codigo, por_dia={
            dia: (time.fromisoformat(v[0]), time.fromisoformat(v[1])) if v else None
            for dia, v in ((d, por_dia.get(d)) for d in DIAS)
        })


def domingo_de_pascua(anio: int) -> date:
    """Algoritmo anónimo gregoriano (Meeus/Jones/Butcher)."""
    a, b, c = anio % 19, anio // 100, anio % 100
    d, e = b // 4, b % 4
    f = (b + 8) // 25
    g = (b - f + 1) // 3
    h = (19 * a + b - d - g + 15) % 30
    i, k = c // 4, c % 4
    l = (32 + 2 * e + 2 * i - h - k) % 7
    m = (a + 11 * h + 22 * l) // 451
    mes = (h + l - 7 * m + 114) // 31
    dia = (h + l - 7 * m + 114) % 31 + 1
    return date(anio, mes, dia)


def _al_lunes(dia: date) -> date:
    """Ley Emiliani (Ley 51 de 1983): el festivo se corre al lunes siguiente si no cae en lunes."""
    return dia + timedelta(days=(7 - dia.weekday()) % 7)


def festivos_de_colombia(anio: int) -> set[date]:
    pascua = domingo_de_pascua(anio)
    fijos = [date(anio, 1, 1), date(anio, 5, 1), date(anio, 7, 20), date(anio, 8, 7),
             date(anio, 12, 8), date(anio, 12, 25),
             pascua - timedelta(days=3), pascua - timedelta(days=2)]  # Jueves y Viernes Santo
    trasladables = [date(anio, 1, 6), date(anio, 3, 19), date(anio, 6, 29), date(anio, 8, 15),
                    date(anio, 10, 12), date(anio, 11, 1), date(anio, 11, 11),
                    pascua + timedelta(days=39),   # Ascensión
                    pascua + timedelta(days=60),   # Corpus Christi
                    pascua + timedelta(days=68)]   # Sagrado Corazón
    return set(fijos) | {_al_lunes(d) for d in trasladables}


def tipo_de_dia(dia: date) -> str:
    if dia.weekday() == 6 or dia in festivos_de_colombia(dia.year):
        return "domingo_y_festivos"
    return "sabado" if dia.weekday() == 5 else "lunes_a_viernes"


def en_colombia(momento: datetime) -> datetime:
    """Hora local de Cartagena; un momento sin zona se toma como UTC."""
    if momento.tzinfo is None:
        momento = momento.replace(tzinfo=timezone.utc)
    return momento.astimezone(HORA_DE_COLOMBIA)


def opera(horario: HorarioRuta | None, momento: datetime) -> bool:
    """¿Se puede tomar la ruta a esa hora? Una ruta sin horario publicado se da por disponible."""
    if horario is None:
        return True
    local = en_colombia(momento)
    franja = horario.por_dia[tipo_de_dia(local.date())]
    if franja is None:
        return False
    inicio = datetime.combine(local.date(), franja[0], HORA_DE_COLOMBIA)
    fin = datetime.combine(local.date(), franja[1], HORA_DE_COLOMBIA) + MARGEN_DEL_ULTIMO_BUS
    return inicio <= local <= fin


def proximo_servicio(horarios: list[HorarioRuta], momento: datetime) -> datetime | None:
    """El primer despacho de cualquiera de las rutas después de `momento` (en los próximos 7 días)."""
    local = en_colombia(momento)
    for dias in range(8):
        dia = local.date() + timedelta(days=dias)
        tipo = tipo_de_dia(dia)
        salidas = sorted(datetime.combine(dia, h.por_dia[tipo][0], HORA_DE_COLOMBIA)
                         for h in horarios if h.por_dia[tipo])
        siguiente = next((s for s in salidas if s > local), None)
        if siguiente:
            return siguiente
    return None


DIAS_DE_LA_SEMANA = ("lunes", "martes", "miércoles", "jueves", "viernes", "sábado", "domingo")


def hora_legible(momento: datetime) -> str:
    """«5:30 a. m.», «12:15 p. m.» (formato de Colombia)."""
    local = en_colombia(momento)
    hora = local.hour % 12 or 12
    return f"{hora}:{local.minute:02d} {'a. m.' if local.hour < 12 else 'p. m.'}"


def cuando(momento: datetime, desde: datetime) -> str:
    """«a las 5:30 a. m.» si es el mismo día, «mañana a las …» o «el lunes a las …»."""
    dias = (en_colombia(momento).date() - en_colombia(desde).date()).days
    legible = hora_legible(momento)
    hora = f"a la {legible}" if legible.startswith("1:") else f"a las {legible}"
    if dias == 0:
        return hora
    if dias == 1:
        return f"mañana {hora}"
    return f"el {DIAS_DE_LA_SEMANA[en_colombia(momento).weekday()]} {hora}"
