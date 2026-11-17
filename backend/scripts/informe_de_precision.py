"""
Qué tan exacto es Karta (D17), con los viajes reales que llegaron al destino: el error de la hora de llegada, por hora
del día, y el de la espera y el tiempo a bordo por ruta. Solo imprime grupos con viajes de al menos 10 personas
distintas, así que el informe se puede publicar o entregar (política, «Estadísticas agregadas y anónimas»).

Uso (con MONGO_URI y MONGO_DB de la base que se quiere medir):
    python -m scripts.informe_de_precision [--desde 2026-11-18] [--md docs/precision-del-piloto.md]
"""
import argparse
from datetime import datetime
from pathlib import Path

from src.domain.horarios import HORA_DE_COLOMBIA
from src.domain.precision import CERCA_MIN, MINIMO_POR_CIFRA, Informe, Precision, informe
from src.infrastructure.database import get_database
from src.infrastructure.repositories import MongoRealtimeRepository


def _signo(minutos: float) -> str:
    return f"+{minutos:g}" if minutos > 0 else f"{minutos:g}"


def _fila(nombre: str, p: Precision) -> str:
    return f"| {nombre} | {p.viajes} | {_signo(p.mediana_min)} min | {p.p90_min} min | {p.cerca:.0%} |"


def _tabla(titulo: str, columna: str, grupos: dict) -> list[str]:
    if not grupos:
        return [f"### {titulo}", "", f"Aún no hay ningún grupo con viajes de {MINIMO_POR_CIFRA} personas.", ""]
    return [f"### {titulo}", "", f"| {columna} | Viajes | Mediana | 90 % se equivoca a lo sumo | A menos de {CERCA_MIN} min |",
            "|---|---|---|---|---|", *[_fila(str(k), p) for k, p in grupos.items()], ""]


def en_markdown(hecho: Informe, desde: datetime) -> str:
    lineas = [
        "# Qué tan exacto es Karta", "",
        f"Viajes reales que llegaron al destino desde el {desde:%d/%m/%Y}: **{hecho.viajes}**. "
        f"El error es lo que se tardó de verdad menos lo que estimó Karta al empezar: positivo, se tardó más. "
        f"Solo se muestran grupos con viajes de al menos {MINIMO_POR_CIFRA} personas distintas.", "",
    ]
    if hecho.total is None:
        lineas += [f"Aún no hay viajes de {MINIMO_POR_CIFRA} personas distintas: no hay cifras que mostrar.", ""]
        return "\n".join(lineas)
    lineas += _tabla("Hora de llegada", "Viajes", {"Todos": hecho.total})
    lineas += _tabla("Hora de llegada, por hora de salida", "Hora",
                     {f"{h}:00": p for h, p in hecho.por_hora.items()})
    lineas += _tabla("Espera en la parada, por ruta", "Ruta", hecho.espera_por_ruta)
    lineas += _tabla("Tiempo a bordo, por ruta", "Ruta", hecho.a_bordo_por_ruta)
    return "\n".join(lineas)


def main() -> None:
    argumentos = argparse.ArgumentParser(description=__doc__.splitlines()[1])
    argumentos.add_argument("--desde", default="2026-01-01", help="Fecha de inicio (AAAA-MM-DD, hora de Colombia)")
    argumentos.add_argument("--md", type=Path, help="Además de imprimirlo, guardarlo en este archivo")
    opciones = argumentos.parse_args()
    desde = datetime.fromisoformat(opciones.desde).replace(tzinfo=HORA_DE_COLOMBIA)
    viajes = MongoRealtimeRepository(get_database())
    texto = en_markdown(informe(viajes.trip_results(desde), viajes.contributors(desde)), desde)
    print(texto)
    if opciones.md:
        opciones.md.write_text(texto + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
