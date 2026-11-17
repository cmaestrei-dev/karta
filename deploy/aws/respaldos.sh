#!/usr/bin/env bash
# Las copias de seguridad diarias de la base (plan de calidad, D2), en el bucket privado karta-respaldos-<cuenta>:
#   deploy/aws/respaldos.sh                                  las copias que hay (cada una se borra a los 7 días)
#   deploy/aws/respaldos.sh --ahora                          hace una copia ya, la misma de las 3 a. m.
#   deploy/aws/respaldos.sh --restaurar AAAA-MM-DD [colección…]
#                                                            vuelve a poner los documentos de esa copia
# Restaurar reemplaza cada documento por el de la copia según su _id y no borra los que la copia no tenga.
# Lo hace la propia función (alias «live»): nadie tiene que manejar la contraseña de Atlas.
set -euo pipefail

export AWS_REGION="${AWS_REGION:-us-east-1}" AWS_PAGER=""
cuenta="$(aws sts get-caller-identity --query Account --output text)"
bucket="karta-respaldos-$cuenta"
obra="$(mktemp -d)"
trap 'rm -rf "$obra"' EXIT

invocar() {
  aws lambda invoke --function-name karta-api --qualifier live --cli-binary-format raw-in-base64-out \
    --cli-read-timeout 120 --payload "$1" "$obra/respuesta.json" >/dev/null
  cat "$obra/respuesta.json"; echo
}

case "${1:-}" in
  "")
    aws s3 ls "s3://$bucket/" ;;
  --ahora)
    invocar '{"respaldar": true}' ;;
  --restaurar)
    dia="${2:?Di qué copia: AAAA-MM-DD (las ves sin argumentos)}"
    shift 2
    colecciones="$(python3 -c 'import json, sys; print(json.dumps(sys.argv[1:] or None))' "$@")"
    read -rp "Esto reescribe en la base de producción los documentos de la copia del $dia. Escribe «restaurar»: " si
    [[ "$si" == "restaurar" ]] || { echo "No se hizo nada."; exit 1; }
    invocar '{"restaurar": "'"$dia"'", "colecciones": '"$colecciones"'}' ;;
  *)
    echo "Uso: deploy/aws/respaldos.sh [--ahora | --restaurar AAAA-MM-DD [colección…]]" >&2; exit 1 ;;
esac
