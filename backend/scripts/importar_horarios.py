"""
Descarga del Portal de Datos Abiertos de Cartagena el archivo oficial de rutas de Transcaribe y guarda
en backend/data/horarios.json el primer y el último servicio de cada ruta por tipo de día.

Uso (desde backend/, con las dependencias de desarrollo):
    python -m scripts.importar_horarios

Fuente: «Rutas_Transcaribe 2025.xlsx», Transcaribe S.A., Portal de Datos Abiertos de Cartagena (CC-BY 4.0).
"""
import io
import json
import re
from pathlib import Path
from urllib.request import Request, urlopen

import openpyxl

URL = ("https://datosabiertos.cartagena.gov.co/dataset/0425a937-3f15-4ff0-aff8-806e4075fd4d/resource/"
       "ab94769a-5f6b-41ad-a5ca-3a4ed8812edf/download/rutas_transcaribe-2025.xlsx")
USER_AGENT = "KartaProyectoUniversitario/1.0 (Universidad de Cartagena)"
DATA_DIR = Path(__file__).resolve().parent.parent / "data"
ATRIBUCION = ("Horarios: «Rutas_Transcaribe 2025», Transcaribe S.A., Portal de Datos Abiertos de Cartagena "
              "(CC-BY 4.0)")

# Columnas del archivo oficial: primera y última salida por tipo de día.
COLUMNAS = {
    "lunes_a_viernes": ("Horario_Lunes-Viernes_salida1", "Horario_Lunes-Viernes_salida2"),
    "sabado": ("Horario_sabado_Salida1", "Horario_sabado_Salida2"),
    "domingo_y_festivos": ("Horario_Domingo-Festivos_Salida1", "Horario_Domingo-Festivos_Salida2"),
}


def hora_24(texto) -> str | None:
    """«4:30 a.m.» → «04:30», «10:40 p.m.» → «22:40», «No Opera» → None."""
    if texto is None:
        return None
    t = str(texto).strip().lower()
    m = re.match(r"^(\d{1,2}):(\d{2})\s*([ap])\.?\s*m\.?$", t)
    if not m:
        return None
    hora, minuto, meridiano = int(m[1]), int(m[2]), m[3]
    if meridiano == "p" and hora != 12:
        hora += 12
    if meridiano == "a" and hora == 12:
        hora = 0
    return f"{hora:02d}:{minuto:02d}"


def leer_horarios(contenido: bytes) -> list[dict]:
    hoja = openpyxl.load_workbook(io.BytesIO(contenido), data_only=True).worksheets[0]
    filas = hoja.iter_rows(values_only=True)
    encabezado = [str(c).strip() if c else "" for c in next(filas)]
    columna = {nombre: k for k, nombre in enumerate(encabezado)}
    horarios: dict[str, dict] = {}
    for fila in filas:
        codigo = (fila[columna["Codigo_Rutas"]] or "").strip()
        if not codigo:
            continue
        documento = horarios.setdefault(codigo, {"_id": codigo, **{dia: None for dia in COLUMNAS}})
        for dia, (primera, ultima) in COLUMNAS.items():
            inicio, fin = hora_24(fila[columna[primera]]), hora_24(fila[columna[ultima]])
            if not (inicio and fin):
                continue
            # Un código puede repetirse en variantes (la X106 y su extensión de la mañana):
            # la ruta opera mientras opere cualquiera de ellas.
            actual = documento[dia]
            documento[dia] = [min(actual[0], inicio), max(actual[1], fin)] if actual else [inicio, fin]
    return sorted(horarios.values(), key=lambda h: h["_id"])


def main() -> None:
    with urlopen(Request(URL, headers={"User-Agent": USER_AGENT}), timeout=60) as respuesta:
        horarios = leer_horarios(respuesta.read())
    salida = DATA_DIR / "horarios.json"
    salida.write_text(json.dumps({"atribucion": ATRIBUCION, "horarios": horarios}, ensure_ascii=False, indent=1),
                      encoding="utf-8")
    print(f"{len(horarios)} rutas con horario en {salida}")


if __name__ == "__main__":
    main()
