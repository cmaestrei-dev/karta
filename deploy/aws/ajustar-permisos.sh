#!/usr/bin/env bash
# Una sola vez, en AWS CloudShell con la cuenta principal (no con camilo-dev, que no puede darse permisos a sí mismo).
# Aplica lo que pidió el P0 del plan de calidad (docs/plan-calidad.md). Se puede correr otra vez sin problema:
#   1. La política karta-despliegue de camilo-dev pasa a la de deploy/aws/politica-karta.json: el alias «live» para
#      volver atrás, las alarmas, el aviso por correo, el presupuesto y ver los respaldos. Nada de borrar.
#   2. El calentador puede invocar el alias «live», además de la función.
#   3. El bucket privado de los respaldos diarios, que borra cada copia a los 7 días, y el permiso de la función
#      para escribir y leer allí (y en ningún otro lado).
# En CloudShell: git clone https://github.com/cmaestrei-dev/karta && cd karta && git checkout claude/fase-4
#                deploy/aws/ajustar-permisos.sh
set -euo pipefail

export AWS_PAGER=""
quien="$(aws sts get-caller-identity --query Arn --output text)"
if [[ "$quien" == *":user/camilo-dev" ]]; then
  echo "Esto lo corre la cuenta principal, no camilo-dev, que no puede darse permisos a sí mismo." >&2
  echo "Abre la consola de AWS, región N. Virginia, el ícono >_ (CloudShell), y pega el comando allí." >&2
  exit 1
fi
cuenta="$(aws sts get-caller-identity --query Account --output text)"
politica="arn:aws:iam::$cuenta:policy/karta-despliegue"
funcion="arn:aws:lambda:us-east-1:$cuenta:function:karta-api"
bucket="karta-respaldos-$cuenta"
obra="$(mktemp -d)"
trap 'rm -rf "$obra"' EXIT

echo "1/3 · Política karta-despliegue…"
sed "s/CUENTA/$cuenta/g" "$(dirname "$0")/politica-karta.json" > "$obra/politica.json"
versiones="$(aws iam list-policy-versions --policy-arn "$politica" --query 'length(Versions)' --output text)"
if [[ "$versiones" -ge 5 ]]; then
  echo "La política ya tiene 5 versiones, el máximo. En la consola: IAM › Políticas › karta-despliegue › Versiones," >&2
  echo "borra la más vieja que no sea la predeterminada y vuelve a correr este script." >&2
  exit 1
fi
aws iam create-policy-version --policy-arn "$politica" --policy-document "file://$obra/politica.json" \
  --set-as-default >/dev/null

echo "2/3 · El calentador puede invocar «live»…"
aws iam put-role-policy --role-name karta-api-calentador --policy-name invocar-karta-api --policy-document \
  '{"Version": "2012-10-17", "Statement": [{"Effect": "Allow", "Action": "lambda:InvokeFunction",
    "Resource": ["'"$funcion"'", "'"$funcion"':*"]}]}'

echo "3/3 · Bucket de respaldos $bucket…"
if ! aws s3api head-bucket --bucket "$bucket" 2>/dev/null; then
  aws s3api create-bucket --bucket "$bucket" --region us-east-1 >/dev/null
fi
aws s3api put-public-access-block --bucket "$bucket" --public-access-block-configuration \
  BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
aws s3api put-bucket-encryption --bucket "$bucket" --server-side-encryption-configuration \
  '{"Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]}'
aws s3api put-bucket-lifecycle-configuration --bucket "$bucket" --lifecycle-configuration \
  '{"Rules": [{"ID": "borrar-a-los-7-dias", "Status": "Enabled", "Filter": {}, "Expiration": {"Days": 7}}]}'
aws iam put-role-policy --role-name karta-api-lambda --policy-name respaldos --policy-document \
  '{"Version": "2012-10-17", "Statement": [
    {"Effect": "Allow", "Action": ["s3:PutObject", "s3:GetObject"], "Resource": "arn:aws:s3:::'"$bucket"'/*"},
    {"Effect": "Allow", "Action": "s3:ListBucket", "Resource": "arn:aws:s3:::'"$bucket"'"}]}'

echo
echo "Listo. Desde el portátil ya se puede desplegar: el despliegue programa la copia diaria."
