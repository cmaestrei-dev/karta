#!/usr/bin/env bash
# Arma el paquete de la API de Karta para AWS Lambda (Python 3.12, x86_64): dependencias, código y datos en un zip.
# Uso, desde cualquier carpeta:  deploy/aws/empaquetar.sh [salida.zip]
# PYTHON elige el intérprete que corre pip (por defecto, python3); el paquete es para 3.12 sin importar cuál sea.
set -euo pipefail

raiz="$(cd "$(dirname "$0")/../.." && pwd)"
salida="$(realpath -m "${1:-karta-api.zip}")"
obra="$(mktemp -d)"
trap 'rm -rf "$obra"' EXIT

# Las dependencias de la API, sin el servidor uvicorn (en Lambda lo reemplaza Mangum).
grep -v '^uvicorn' "$raiz/backend/requirements.txt" > "$obra/requisitos.txt"
cat "$raiz/backend/requirements-lambda.txt" >> "$obra/requisitos.txt"
"${PYTHON:-python3}" -m pip install --quiet --disable-pip-version-check --target "$obra/paquete" \
  --requirement "$obra/requisitos.txt" --only-binary=:all: --implementation cp --python-version 3.12 \
  --platform manylinux_2_28_x86_64 --platform manylinux_2_17_x86_64 --platform manylinux2014_x86_64

cp -r "$raiz/backend/src" "$raiz/backend/data" "$obra/paquete/"
# Lo que Lambda no usa: las cachés de Python y las pruebas que traen numpy, shapely y compañía.
find "$obra/paquete" -type d \( -name "__pycache__" -o -name "tests" \) -prune -exec rm -rf {} +

rm -f "$salida"
(cd "$obra/paquete" && zip -q -r -9 "$salida" .)
echo "Paquete: $salida ($(du -h "$salida" | cut -f1))"
