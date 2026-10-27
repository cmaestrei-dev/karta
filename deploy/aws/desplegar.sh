#!/usr/bin/env bash
# Crea o actualiza la API de Karta en AWS Lambda (D7), con:
#   - una versión publicada en cada despliegue, que se prepara y se prueba ANTES de recibir tráfico;
#   - el alias «live», que apunta a la última versión que pasó la prueba (volver atrás es moverlo);
#   - una Function URL pública con HTTPS sobre «live» (la dirección que usa la app);
#   - un programador de EventBridge que invoca «live» cada 5 minutos para que no se apague;
#   - registros en CloudWatch que se borran a los 7 días.
# Todo cabe en la capa siempre gratuita de AWS. Se corre en AWS CloudShell o en un portátil con la AWS CLI:
#   deploy/aws/desplegar.sh                  la primera vez, o para actualizar el código
#   deploy/aws/desplegar.sh --cambiar-base   para poner otra cadena de conexión de MongoDB Atlas
#   deploy/aws/desplegar.sh --responsable    para poner los datos de contacto y la fecha de vigencia de la política
#   deploy/aws/desplegar.sh --rotar-secreto  un secreto nuevo para los tokens (cada 90 días): todos vuelven a entrar
#   deploy/aws/desplegar.sh --versiones      las últimas versiones y cuál está sirviendo
#   deploy/aws/desplegar.sh --volver N       devuelve «live» a la versión N, sin subir nada
# La primera vez pide la cadena de conexión de Atlas (no se ve al pegarla) y genera el secreto de los tokens.
# Ninguno de los dos se muestra en pantalla ni queda en el repositorio. Ver docs/despliegue-aws.md.
set -euo pipefail

export AWS_REGION="${AWS_REGION:-us-east-1}" AWS_PAGER=""
FUNCION=karta-api
ALIAS=live
ROL=karta-api-lambda
ROL_CALENTADOR=karta-api-calentador
CALENTADOR=karta-api-calentar
raiz="$(cd "$(dirname "$0")/../.." && pwd)"
cuenta="$(aws sts get-caller-identity --query Account --output text)"
arn_funcion="arn:aws:lambda:$AWS_REGION:$cuenta:function:$FUNCION"
obra="$(mktemp -d)"
chmod 700 "$obra"
trap 'rm -rf "$obra"' EXIT

opcion="${1:-}"

# --- Sin subir nada ----------------------------------------------------------------------------------------------

if [[ "$opcion" == "--versiones" ]]; then
  echo "«$ALIAS» sirve la versión $(aws lambda get-alias --function-name "$FUNCION" --name "$ALIAS" \
    --query FunctionVersion --output text). Las últimas:"
  aws lambda list-versions-by-function --function-name "$FUNCION" \
    --query 'Versions[?Version!=`$LATEST`].[Version, LastModified]' --output text | tail -10
  exit 0
fi
if [[ "$opcion" == "--volver" ]]; then
  version="${2:?Di a qué versión volver; las ves con --versiones}"
  aws lambda update-alias --function-name "$FUNCION" --name "$ALIAS" --function-version "$version" >/dev/null
  echo "Listo: «$ALIAS» volvió a la versión $version. Si se cambió la contraseña de Atlas después de esa versión,"
  echo "la vieja ya no se conecta: en ese caso corre otra vez el despliegue con --cambiar-base."
  exit 0
fi

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

# Los datos del responsable que la política publica (Ley 1581; Decreto 1074, art. 2.2.2.25.3.1). Quedan en la
# configuración de la función, no en el repositorio público, y no se muestran al terminar.
pedir_responsable() {
  local correo telefono direccion vigente
  read -rp "Correo para consultas y reclamos sobre datos: " correo
  read -rp "Teléfono de contacto: " telefono
  read -rp "Dirección física (calle y número, barrio): " direccion
  read -rp "Desde cuándo rige la política (por ejemplo, 18 de noviembre de 2026): " vigente
  for valor in "$correo" "$telefono" "$direccion" "$vigente"; do
    [[ -n "$valor" && "$valor" != *"["* ]] || { echo "Falta un dato: no se cambió nada." >&2; exit 1; }
  done
  RESPONSABLE_CORREO="$correo" RESPONSABLE_TELEFONO="$telefono" RESPONSABLE_DIRECCION="$direccion" \
    POLITICA_VIGENTE_DESDE="$vigente" python3 -c 'import json, os, sys
claves = ("RESPONSABLE_CORREO", "RESPONSABLE_TELEFONO", "RESPONSABLE_DIRECCION", "POLITICA_VIGENTE_DESDE")
json.dump({k: os.environ[k] for k in claves}, open(sys.argv[1] + "/responsable.json", "w"))' "$obra"
}

# Escribe el entorno de la función: lo que ya tenía, con la cadena nueva si se pidió y un secreto si no lo había.
escribir_entorno() {
  python3 - "$obra" "$opcion" <<'PY'
import json, os, secrets, sys
obra, opcion = sys.argv[1], sys.argv[2]
actual = json.load(open(f"{obra}/actual.json")) if os.path.exists(f"{obra}/actual.json") else None
variables = actual or {}
if os.path.exists(f"{obra}/cadena"):
    variables["MONGO_URI"] = open(f"{obra}/cadena").read()
if os.path.exists(f"{obra}/responsable.json"):
    variables.update(json.load(open(f"{obra}/responsable.json")))
if opcion == "--rotar-secreto":
    variables["JWT_SECRET"] = secrets.token_hex(32)
variables.setdefault("JWT_SECRET", secrets.token_hex(32))
variables.setdefault("MONGO_DB", "karta")
variables.setdefault("CORS_ORIGINS", "*")
variables.setdefault("CONTADORES_CADA_S", "60")  # los conteos del piloto se juntan en memoria (plan de calidad, E2)
if os.path.exists(f"{obra}/bucket"):  # la copia diaria en S3 (plan de calidad, D2)
    variables["RESPALDOS_BUCKET"] = open(f"{obra}/bucket").read()
with open(f"{obra}/entorno.json", "w") as f:
    json.dump({"Variables": variables}, f)
PY
}

# Invoca una versión publicada con un evento y deja la respuesta en $obra/respuesta.json.
invocar() {
  aws lambda invoke --function-name "$FUNCION" --qualifier "$1" --cli-binary-format raw-in-base64-out \
    --payload "$2" "$obra/respuesta.json" >/dev/null
}

# El bucket de los respaldos lo crea deploy/aws/ajustar-permisos.sh; sin él, no se programa la copia diaria.
bucket="karta-respaldos-$cuenta"
aws s3api head-bucket --bucket "$bucket" 2>/dev/null && printf '%s' "$bucket" > "$obra/bucket"

echo "1/7 · Armando el paquete…"
"$raiz/deploy/aws/empaquetar.sh" "$obra/karta-api.zip"

echo "2/7 · Rol de la función (solo puede escribir sus registros)…"
if ! aws iam get-role --role-name "$ROL" >/dev/null 2>&1; then
  aws iam create-role --role-name "$ROL" --assume-role-policy-document '{"Version": "2012-10-17", "Statement": [{
    "Effect": "Allow", "Principal": {"Service": "lambda.amazonaws.com"}, "Action": "sts:AssumeRole"}]}' >/dev/null
  aws iam attach-role-policy --role-name "$ROL" \
    --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
  sleep 10  # IAM tarda unos segundos en dejar usar un rol nuevo
fi

echo "3/7 · Función $FUNCION…"
configuracion=(--runtime python3.12 --handler src.infrastructure.lambda_handler.handler
               --memory-size 1769 --timeout 60)  # 1769 MB = una vCPU completa; 60 s para la primera carga de datos
# La arquitectura va con el código (create-function y update-function-code), no con la configuración.
if aws lambda get-function --function-name "$FUNCION" >/dev/null 2>&1; then
  aws lambda update-function-code --function-name "$FUNCION" --zip-file "fileb://$obra/karta-api.zip" \
    --architectures x86_64 >/dev/null
  aws lambda wait function-updated-v2 --function-name "$FUNCION"
  [[ "$opcion" == "--cambiar-base" ]] && pedir_cadena
  [[ "$opcion" == "--responsable" ]] && pedir_responsable
  aws lambda get-function-configuration --function-name "$FUNCION" --query Environment.Variables \
    --output json > "$obra/actual.json"
  escribir_entorno
  aws lambda update-function-configuration --function-name "$FUNCION" "${configuracion[@]}" \
    --environment "file://$obra/entorno.json" >/dev/null
else
  pedir_cadena
  escribir_entorno
  aws lambda create-function --function-name "$FUNCION" "${configuracion[@]}" --architectures x86_64 \
    --role "arn:aws:iam::$cuenta:role/$ROL" --zip-file "fileb://$obra/karta-api.zip" \
    --environment "file://$obra/entorno.json" >/dev/null
fi
aws lambda wait function-updated-v2 --function-name "$FUNCION"
aws logs create-log-group --log-group-name "/aws/lambda/$FUNCION" 2>/dev/null || true
aws logs put-retention-policy --log-group-name "/aws/lambda/$FUNCION" --retention-in-days 7

echo "4/7 · Publicando la versión…"
version="$(aws lambda publish-version --function-name "$FUNCION" --query Version --output text)"
echo "    Versión $version."

echo "5/7 · Preparando la base y probando la versión $version antes de abrirla…"
# Preparar: los índices y los datos de referencia, que antes se hacían en cada arranque en frío.
invocar "$version" '{"preparar": true}'
if ! grep -q '"preparada": true' "$obra/respuesta.json"; then
  echo "La versión $version no pudo preparar la base:" >&2
  cat "$obra/respuesta.json" >&2; echo >&2
  echo "«$ALIAS» sigue en la versión anterior. Los registros: aws logs tail /aws/lambda/$FUNCION --since 15m" >&2
  exit 1
fi
# Probar: GET /api/v1/health como lo manda la Function URL.
python3 - "$obra/salud.json" <<'PY'
import json, sys
json.dump({"version": "2.0", "routeKey": "$default", "rawPath": "/api/v1/health", "rawQueryString": "",
           "headers": {"host": "despliegue.lambda-url.us-east-1.on.aws"},
           "requestContext": {"accountId": "anonymous", "apiId": "despliegue", "requestId": "despliegue",
                              "domainName": "despliegue.lambda-url.us-east-1.on.aws", "domainPrefix": "despliegue",
                              "routeKey": "$default", "stage": "$default", "time": "01/Jan/2026:00:00:00 +0000",
                              "timeEpoch": 1767225600000,
                              "http": {"method": "GET", "path": "/api/v1/health", "protocol": "HTTP/1.1",
                                       "sourceIp": "127.0.0.1", "userAgent": "desplegar.sh"}},
           "body": None, "isBase64Encoded": False}, open(sys.argv[1], "w"))
PY
invocar "$version" "file://$obra/salud.json"
if ! python3 -c 'import json, sys; sys.exit(json.load(open(sys.argv[1])).get("statusCode") != 200)' \
    "$obra/respuesta.json"; then
  echo "La versión $version no pasó la prueba de salud:" >&2
  cat "$obra/respuesta.json" >&2; echo >&2
  echo "«$ALIAS» sigue en la versión anterior." >&2
  exit 1
fi

echo "6/7 · «$ALIAS» pasa a la versión $version, con su dirección pública…"
if aws lambda get-alias --function-name "$FUNCION" --name "$ALIAS" >/dev/null 2>&1; then
  anterior="$(aws lambda get-alias --function-name "$FUNCION" --name "$ALIAS" --query FunctionVersion --output text)"
  aws lambda update-alias --function-name "$FUNCION" --name "$ALIAS" --function-version "$version" >/dev/null
  echo "    Antes servía la $anterior. Si algo falla: deploy/aws/desplegar.sh --volver $anterior"
else
  aws lambda create-alias --function-name "$FUNCION" --name "$ALIAS" --function-version "$version" >/dev/null
fi
if ! aws lambda get-function-url-config --function-name "$FUNCION" --qualifier "$ALIAS" >/dev/null 2>&1; then
  aws lambda create-function-url-config --function-name "$FUNCION" --qualifier "$ALIAS" --auth-type NONE >/dev/null
  # Desde octubre de 2025, una Function URL pública necesita los dos permisos; el segundo, solo por la URL.
  aws lambda add-permission --function-name "$FUNCION" --qualifier "$ALIAS" --statement-id url-publica \
    --action lambda:InvokeFunctionUrl --principal '*' --function-url-auth-type NONE >/dev/null
  aws lambda add-permission --function-name "$FUNCION" --qualifier "$ALIAS" --statement-id url-publica-invocar \
    --action lambda:InvokeFunction --principal '*' --invoked-via-function-url >/dev/null
fi
url="$(aws lambda get-function-url-config --function-name "$FUNCION" --qualifier "$ALIAS" \
  --query FunctionUrl --output text)"

echo "7/7 · Calentador cada 5 minutos…"
if ! aws iam get-role --role-name "$ROL_CALENTADOR" >/dev/null 2>&1; then
  aws iam create-role --role-name "$ROL_CALENTADOR" --assume-role-policy-document '{"Version": "2012-10-17",
    "Statement": [{"Effect": "Allow", "Principal": {"Service": "scheduler.amazonaws.com"}, "Action": "sts:AssumeRole",
    "Condition": {"StringEquals": {"aws:SourceAccount": "'"$cuenta"'"}}}]}' >/dev/null
  aws iam put-role-policy --role-name "$ROL_CALENTADOR" --policy-name invocar-karta-api --policy-document \
    '{"Version": "2012-10-17", "Statement": [{"Effect": "Allow", "Action": "lambda:InvokeFunction",
      "Resource": ["'"$arn_funcion"'", "'"$arn_funcion"':*"]}]}'
  sleep 10
fi
# Calienta «live» si su rol ya puede invocarlo; si no, sigue con la función sin alias, como antes.
calentar="$arn_funcion:$ALIAS"
if ! aws iam get-role-policy --role-name "$ROL_CALENTADOR" --policy-name invocar-karta-api \
    --query PolicyDocument --output json | grep -q "$FUNCION:\*"; then
  calentar="$arn_funcion"
  echo "    Ojo: el rol del calentador todavía no puede invocar «$ALIAS». Corre una vez deploy/aws/ajustar-permisos.sh"
  echo "    en CloudShell con la cuenta principal (docs/despliegue-aws.md)."
fi
objetivo='{"Arn": "'"$calentar"'", "RoleArn": "arn:aws:iam::'"$cuenta"':role/'"$ROL_CALENTADOR"'",
  "Input": "{\"calentar\": true}"}'
if aws scheduler get-schedule --name "$CALENTADOR" >/dev/null 2>&1; then
  aws scheduler update-schedule --name "$CALENTADOR" --schedule-expression "rate(5 minutes)" \
    --flexible-time-window Mode=OFF --target "$objetivo" >/dev/null
else
  aws scheduler create-schedule --name "$CALENTADOR" --schedule-expression "rate(5 minutes)" \
    --flexible-time-window Mode=OFF --target "$objetivo" >/dev/null
fi

if [[ -f "$obra/bucket" ]]; then
  # La copia diaria, a las 3 a. m. de Colombia (8:00 UTC), con el mismo rol que el calentador.
  respaldo='{"Arn": "'"$calentar"'", "RoleArn": "arn:aws:iam::'"$cuenta"':role/'"$ROL_CALENTADOR"'",
    "Input": "{\"respaldar\": true}"}'
  if aws scheduler get-schedule --name karta-api-respaldar >/dev/null 2>&1; then
    aws scheduler update-schedule --name karta-api-respaldar --schedule-expression "cron(0 8 * * ? *)" \
      --flexible-time-window Mode=OFF --target "$respaldo" >/dev/null
  else
    aws scheduler create-schedule --name karta-api-respaldar --schedule-expression "cron(0 8 * * ? *)" \
      --flexible-time-window Mode=OFF --target "$respaldo" >/dev/null
  fi
  echo "    Y la copia diaria en s3://$bucket, a las 3 a. m. de Colombia."
else
  echo "    Sin bucket de respaldos: corre deploy/aws/ajustar-permisos.sh en CloudShell para tener la copia diaria."
fi

echo
echo "Probando ${url}api/v1/health"
curl -fsS --max-time 30 "${url}api/v1/health" && echo
echo
echo "Listo. La API de Karta (versión $version) quedó en: ${url}api/v1"
echo "Compila la app con: --dart-define=API_BASE_URL=${url}api/v1"
