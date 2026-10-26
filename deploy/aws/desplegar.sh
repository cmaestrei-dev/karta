#!/usr/bin/env bash
# Crea o actualiza la API de Karta en AWS Lambda (D7), con:
#   - una Function URL pública con HTTPS (la dirección que usa la app);
#   - un programador de EventBridge que la invoca cada 5 minutos para que no se apague;
#   - registros en CloudWatch que se borran a los 7 días.
# Todo cabe en la capa siempre gratuita de AWS. Se corre en AWS CloudShell, dentro del repositorio clonado:
#   deploy/aws/desplegar.sh                  la primera vez, o para actualizar el código
#   deploy/aws/desplegar.sh --cambiar-base   para poner otra cadena de conexión de MongoDB Atlas
# La primera vez pide la cadena de conexión de Atlas (no se ve al pegarla) y genera el secreto de los tokens.
# Ninguno de los dos se muestra en pantalla ni queda en el repositorio. Ver docs/despliegue-aws.md.
set -euo pipefail

export AWS_REGION="${AWS_REGION:-us-east-1}" AWS_PAGER=""
FUNCION=karta-api
ROL=karta-api-lambda
ROL_CALENTADOR=karta-api-calentador
CALENTADOR=karta-api-calentar
raiz="$(cd "$(dirname "$0")/../.." && pwd)"
cuenta="$(aws sts get-caller-identity --query Account --output text)"
arn_funcion="arn:aws:lambda:$AWS_REGION:$cuenta:function:$FUNCION"
obra="$(mktemp -d)"
chmod 700 "$obra"
trap 'rm -rf "$obra"' EXIT

pedir_cadena() {
  local cadena
  read -rsp "Pega la cadena de conexión de MongoDB Atlas (mongodb+srv://…) y presiona Enter: " cadena
  echo
  [[ "$cadena" == mongodb* ]] || { echo "Eso no parece una cadena de MongoDB." >&2; exit 1; }
  # Atlas muestra «<db_password>»: hay que reemplazarlo entero, signos < > incluidos.
  if [[ "${cadena%%@*}" == *[\<\>]* ]]; then
    echo "La contraseña quedó entre < >: quita esos dos signos y vuelve a correr el script." >&2
    exit 1
  fi
  printf '%s' "$cadena" > "$obra/cadena"
}

# Escribe el entorno de la función: lo que ya tenía, con la cadena nueva si se pidió y un secreto si no lo había.
escribir_entorno() {
  python3 - "$obra" <<'PY'
import json, os, secrets, sys
obra = sys.argv[1]
actual = json.load(open(f"{obra}/actual.json")) if os.path.exists(f"{obra}/actual.json") else None
variables = actual or {}
if os.path.exists(f"{obra}/cadena"):
    variables["MONGO_URI"] = open(f"{obra}/cadena").read()
variables.setdefault("JWT_SECRET", secrets.token_hex(32))
variables.setdefault("MONGO_DB", "karta")
variables.setdefault("CORS_ORIGINS", "*")
with open(f"{obra}/entorno.json", "w") as f:
    json.dump({"Variables": variables}, f)
PY
}

echo "1/5 · Armando el paquete…"
"$raiz/deploy/aws/empaquetar.sh" "$obra/karta-api.zip"

echo "2/5 · Rol de la función (solo puede escribir sus registros)…"
if ! aws iam get-role --role-name "$ROL" >/dev/null 2>&1; then
  aws iam create-role --role-name "$ROL" --assume-role-policy-document '{"Version": "2012-10-17", "Statement": [{
    "Effect": "Allow", "Principal": {"Service": "lambda.amazonaws.com"}, "Action": "sts:AssumeRole"}]}' >/dev/null
  aws iam attach-role-policy --role-name "$ROL" \
    --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
  sleep 10  # IAM tarda unos segundos en dejar usar un rol nuevo
fi

echo "3/5 · Función $FUNCION…"
configuracion=(--runtime python3.12 --architectures x86_64 --handler src.infrastructure.lambda_handler.handler
               --memory-size 1769 --timeout 60)  # 1769 MB = una vCPU completa; 60 s para la primera carga de datos
if aws lambda get-function --function-name "$FUNCION" >/dev/null 2>&1; then
  aws lambda update-function-code --function-name "$FUNCION" --zip-file "fileb://$obra/karta-api.zip" >/dev/null
  aws lambda wait function-updated-v2 --function-name "$FUNCION"
  [[ "${1:-}" == "--cambiar-base" ]] && pedir_cadena
  aws lambda get-function-configuration --function-name "$FUNCION" --query Environment.Variables \
    --output json > "$obra/actual.json"
  escribir_entorno
  aws lambda update-function-configuration --function-name "$FUNCION" "${configuracion[@]}" \
    --environment "file://$obra/entorno.json" >/dev/null
else
  pedir_cadena
  escribir_entorno
  aws lambda create-function --function-name "$FUNCION" "${configuracion[@]}" \
    --role "arn:aws:iam::$cuenta:role/$ROL" --zip-file "fileb://$obra/karta-api.zip" \
    --environment "file://$obra/entorno.json" >/dev/null
fi
aws lambda wait function-updated-v2 --function-name "$FUNCION"
aws logs create-log-group --log-group-name "/aws/lambda/$FUNCION" 2>/dev/null || true
aws logs put-retention-policy --log-group-name "/aws/lambda/$FUNCION" --retention-in-days 7

echo "4/5 · Dirección pública con HTTPS…"
if ! aws lambda get-function-url-config --function-name "$FUNCION" >/dev/null 2>&1; then
  aws lambda create-function-url-config --function-name "$FUNCION" --auth-type NONE >/dev/null
  # Desde octubre de 2025, una Function URL pública necesita los dos permisos; el segundo, solo por la URL.
  aws lambda add-permission --function-name "$FUNCION" --statement-id url-publica \
    --action lambda:InvokeFunctionUrl --principal '*' --function-url-auth-type NONE >/dev/null
  aws lambda add-permission --function-name "$FUNCION" --statement-id url-publica-invocar \
    --action lambda:InvokeFunction --principal '*' --invoked-via-function-url >/dev/null
fi
url="$(aws lambda get-function-url-config --function-name "$FUNCION" --query FunctionUrl --output text)"

echo "5/5 · Calentador cada 5 minutos…"
if ! aws iam get-role --role-name "$ROL_CALENTADOR" >/dev/null 2>&1; then
  aws iam create-role --role-name "$ROL_CALENTADOR" --assume-role-policy-document '{"Version": "2012-10-17",
    "Statement": [{"Effect": "Allow", "Principal": {"Service": "scheduler.amazonaws.com"}, "Action": "sts:AssumeRole",
    "Condition": {"StringEquals": {"aws:SourceAccount": "'"$cuenta"'"}}}]}' >/dev/null
  aws iam put-role-policy --role-name "$ROL_CALENTADOR" --policy-name invocar-karta-api --policy-document \
    '{"Version": "2012-10-17", "Statement": [{"Effect": "Allow", "Action": "lambda:InvokeFunction",
      "Resource": "'"$arn_funcion"'"}]}'
  sleep 10
fi
if ! aws scheduler get-schedule --name "$CALENTADOR" >/dev/null 2>&1; then
  aws scheduler create-schedule --name "$CALENTADOR" --schedule-expression "rate(5 minutes)" \
    --flexible-time-window Mode=OFF --target '{"Arn": "'"$arn_funcion"'",
      "RoleArn": "arn:aws:iam::'"$cuenta"':role/'"$ROL_CALENTADOR"'", "Input": "{\"calentar\": true}"}' >/dev/null
fi

echo
echo "Probando ${url}api/v1/health"
curl -fsS --max-time 30 "${url}api/v1/health" && echo
echo
echo "Listo. La API de Karta quedó en: ${url}api/v1"
echo "Compila la app con: --dart-define=API_BASE_URL=${url}api/v1"
