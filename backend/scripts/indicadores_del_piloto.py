"""
Los indicadores del piloto (docs/plan-comunidad.md, §5) frente a sus metas, con los conteos diarios de la base. Una
cifra con menos de 10 casos no se da, así que el informe se puede publicar. La precisión de la hora de llegada está
aparte: python -m scripts.informe_de_precision.

Uso (con MONGO_URI y MONGO_DB de la base que se quiere medir):
    python -m scripts.indicadores_del_piloto --desde 2026-11-18 --hasta 2026-11-23 [--md docs/indicadores-del-piloto.md]
"""
import argparse
from datetime import date, datetime, time, timedelta
from pathlib import Path

from src.domain.horarios import HORA_DE_COLOMBIA
from src.domain.indicadores import HORAS_PICO, Indicadores, indicadores
from src.domain.precision import MINIMO_POR_CIFRA
from src.infrastructure.database import get_database
from src.infrastructure.repositories import MongoContadores

SEMANA = timedelta(days=7)


def _porcentaje(valor: float | None) -> str:
    return f"{valor:.0%}" if valor is not None else f"menos de {MINIMO_POR_CIFRA} casos"


def _cuantos(valor: int | None) -> str:
    return str(valor) if valor is not None else f"menos de {MINIMO_POR_CIFRA}"


def _razon(valor: float | None) -> str:
    if valor is None:
        return f"menos de {MINIMO_POR_CIFRA} votos"
    return "sin desmentidos" if valor == float("inf") else f"{valor:.1f} a 1".replace(".", ",")


def en_markdown(hecho: Indicadores, desde: date, hasta: date) -> str:
    pico = " y ".join(f"{h}:00" for h in HORAS_PICO)
    filas = [
        ("Llegadas con datos de viajeros, en hora pico, en la troncal", "≥ 1 de cada 3 consultas (33 %)",
         _porcentaje(hecho.llegadas_con_datos_en_pico)),
        ("Reportes confirmados frente a desmentidos", "≥ 3 a 1", _razon(hecho.confirmaciones_por_desmentido)),
        ("Viajeros que vuelven la semana siguiente", "≥ 50 %", _porcentaje(hecho.volvieron_la_semana_siguiente)),
        ("Personas que usaron un «Gracias», de las que vieron reportes", "≥ 30 %",
         _porcentaje(hecho.agradecieron_de_los_que_vieron)),
        ("Viajes con la posición del bus compartida", "≥ 60 % de los viajes activos",
         f"{_cuantos(hecho.viajes_compartidos)} viajes compartidos; el porcentaje sale de la encuesta"),
        ("Reportes hechos", "—", _cuantos(hecho.reportes)),
    ]
    return "\n".join([
        "# Indicadores del piloto", "",
        f"Del {desde:%d/%m/%Y} al {hasta:%d/%m/%Y} ({hecho.dias} días con actividad). Metas de "
        f"[plan-comunidad.md](plan-comunidad.md), §5. Ninguna cifra reúne menos de {MINIMO_POR_CIFRA} casos.", "",
        "| Indicador | Meta | Resultado |", "|---|---|---|",
        *[f"| {nombre} | {meta} | {resultado} |" for nombre, meta, resultado in filas], "",
        "- **Cómo se cuenta:**",
        f"  - Las consultas de llegada son las de la app, que repite la suya cada 30 s mientras se espera; hora pico: "
        f"las horas que empiezan a las {pico}.",
        "  - «Confirmados frente a desmentidos» compara los votos «Sigue ahí» con los «Ya no está».",
        "  - Las personas que vieron reportes o dieron «Gracias» se cuentan una vez por día y se suman.",
        "  - «Vuelven» son las cuentas creadas en el piloto que se usaron otra vez 7 días o más después de crearse.",
        "  - El servidor no sabe cuántos viajes se hicieron sin compartir, porque esos no envían nada. Por eso el "
        "porcentaje de viajes compartidos sale de la encuesta.",
        "",
    ])


def main() -> None:
    argumentos = argparse.ArgumentParser(description=__doc__.splitlines()[1])
    argumentos.add_argument("--desde", required=True, help="Primer día del piloto (AAAA-MM-DD)")
    argumentos.add_argument("--hasta", required=True, help="Último día del piloto (AAAA-MM-DD)")
    argumentos.add_argument("--md", type=Path, help="Además de imprimirlo, guardarlo en este archivo")
    opciones = argumentos.parse_args()
    desde, hasta = date.fromisoformat(opciones.desde), date.fromisoformat(opciones.hasta)

    db = get_database()
    dias = MongoContadores(db).dias(desde.isoformat(), hasta.isoformat())
    # Las cuentas creadas en el piloto que ya tuvieron una semana para volver.
    inicio = datetime.combine(desde, time(0), HORA_DE_COLOMBIA)
    fin = min(datetime.combine(hasta + timedelta(days=1), time(0), HORA_DE_COLOMBIA),
              datetime.now(HORA_DE_COLOMBIA) - SEMANA)
    nuevas = {"creado_en": {"$gte": inicio, "$lt": fin}, "anonimo": True}
    volvieron = {**nuevas, "$expr": {"$gte": ["$visto_en", {"$add": ["$creado_en", SEMANA.total_seconds() * 1000]}]}}
    texto = en_markdown(indicadores(dias, db.users.count_documents(nuevas), db.users.count_documents(volvieron)),
                        desde, hasta)
    print(texto)
    if opciones.md:
        opciones.md.write_text(texto + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
