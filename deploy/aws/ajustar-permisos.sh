#!/usr/bin/env bash
# Una sola vez, en AWS CloudShell con la cuenta principal (no con camilo-dev, que no puede darse permisos a sí mismo).
# Aplica lo que pidió el P0 del plan de calidad (docs/plan-calidad.md):
#   1. La política karta-despliegue de camilo-dev pasa a la de deploy/aws/politica-karta.json: el alias «live» para
#      volver atrás, las alarmas, el aviso por correo y el presupuesto. Nada de borrar.
#   2. El calentador puede invocar el alias «live», además de la función.
# En CloudShell: git clone https://github.com/cmaestrei-dev/karta && cd karta && git checkout claude/fase-4
#                deploy/aws/ajustar-permisos.sh
set -euo pipefail

export AWS_PAGER=""
cuenta="$(aws sts get-caller-identity --query Account --output text)"
politica="arn:aws:iam::$cuenta:policy/karta-despliegue"
funcion="arn:aws:lambda:us-east-1:$cuenta:function:karta-api"
obra="$(mktemp -d)"
trap 'rm -rf "$obra"' EXIT

echo "1/2 · Política karta-despliegue…"
sed "s/CUENTA/$cuenta/g" "$(dirname "$0")/politica-karta.json" > "$obra/politica.json"
if [[ "$(aws iam list-policy-versions --policy-arn "$politica" --query 'length(Versions)')" -ge 5 ]]; then
  echo "La política ya tiene 5 versiones, el máximo. En la consola: IAM › Políticas › karta-despliegue › Versiones," >&2
  echo "borra la más vieja que no sea la predeterminada y vuelve a correr este script." >&2
  exit 1
fi
aws iam create-policy-version --policy-arn "$politica" --policy-document "file://$obra/politica.json" \
  --set-as-default >/dev/null

echo "2/2 · El calentador puede invocar «live»…"
aws iam put-role-policy --role-name karta-api-calentador --policy-name invocar-karta-api --policy-document \
  '{"Version": "2012-10-17", "Statement": [{"Effect": "Allow", "Action": "lambda:InvokeFunction",
    "Resource": ["'"$funcion"'", "'"$funcion"':*"]}]}'

echo
echo "Listo. Desde el portátil ya se puede desplegar con el alias y crear las alarmas (deploy/aws/alarmas.sh)."
