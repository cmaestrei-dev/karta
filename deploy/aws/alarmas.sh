#!/usr/bin/env bash
# Alarmas de la API de Karta y un presupuesto mensual, con aviso por correo (plan de calidad, D1). Todo gratis: las
# primeras 10 alarmas de CloudWatch, los primeros 1.000 correos de SNS y los presupuestos sin acciones no se cobran.
# Se corre con camilo-dev después de deploy/aws/ajustar-permisos.sh, y otra vez si cambian los umbrales:
#   deploy/aws/alarmas.sh
set -euo pipefail

export AWS_REGION="${AWS_REGION:-us-east-1}" AWS_PAGER=""
FUNCION=karta-api
cuenta="$(aws sts get-caller-identity --query Account --output text)"
obra="$(mktemp -d)"
trap 'rm -rf "$obra"' EXIT

read -rp "Correo que recibe las alarmas (no se publica; puede ser el tuyo): " correo
[[ "$correo" == *@*.* ]] || { echo "Eso no parece un correo." >&2; exit 1; }

echo "1/3 · Aviso por correo…"
tema="$(aws sns create-topic --name karta-alertas --query TopicArn --output text)"
if ! aws sns list-subscriptions-by-topic --topic-arn "$tema" --query 'Subscriptions[].Endpoint' --output text \
    | tr '\t' '\n' | grep -qxF "$correo"; then
  aws sns subscribe --topic-arn "$tema" --protocol email --notification-endpoint "$correo" >/dev/null
  echo "    Llega un correo «AWS Notification - Subscription Confirmation»: hay que confirmarlo para recibir avisos."
fi

echo "2/3 · Alarmas…"
# alarma NOMBRE DESCRIPCIÓN MÉTRICA ESTADÍSTICA UMBRAL PERIODOS_DE_5_MIN
alarma() {
  local estadistica=(--statistic "$4")
  [[ "$4" == p* ]] && estadistica=(--extended-statistic "$4")
  aws cloudwatch put-metric-alarm --alarm-name "$1" --alarm-description "$2" \
    --namespace AWS/Lambda --metric-name "$3" --dimensions "Name=FunctionName,Value=$FUNCION" \
    "${estadistica[@]}" --period 300 --evaluation-periods "$6" --threshold "$5" \
    --comparison-operator GreaterThanOrEqualToThreshold --treat-missing-data notBreaching \
    --alarm-actions "$tema" --ok-actions "$tema"
}
alarma karta-errores-5xx "La API respondió 3 o más errores 5xx en 5 minutos." Url5xxCount Sum 3 1
alarma karta-errores-funcion "La función falló (excepción o tiempo agotado)." Errors Sum 1 1
alarma karta-rechazos "Lambda rechazó invocaciones: se llegó al límite de ejecuciones simultáneas." Throttles Sum 1 1
alarma karta-lenta "El p95 de la función pasó de 3 s durante 15 minutos." Duration p95 3000 3
alarma karta-concurrencia "8 o más ejecuciones a la vez: el límite de la cuenta es 10." ConcurrentExecutions Maximum 8 1

echo "3/3 · Presupuesto de USD 5 al mes…"
if ! aws budgets describe-budget --account-id "$cuenta" --budget-name karta-mensual >/dev/null 2>&1; then
  python3 - "$obra" "$correo" <<'PY'
import json, sys
obra, correo = sys.argv[1], sys.argv[2]
# Sin restar los créditos: avisa si Karta empieza a gastar, aunque los créditos lo cubran.
json.dump({"BudgetName": "karta-mensual", "BudgetLimit": {"Amount": "5", "Unit": "USD"}, "TimeUnit": "MONTHLY",
           "BudgetType": "COST", "CostTypes": {"IncludeCredit": False, "IncludeRefund": False}},
          open(f"{obra}/presupuesto.json", "w"))
avisos = [("ACTUAL", 80), ("FORECASTED", 100)]
json.dump([{"Notification": {"NotificationType": tipo, "ComparisonOperator": "GREATER_THAN", "Threshold": umbral,
                             "ThresholdType": "PERCENTAGE"},
            "Subscribers": [{"SubscriptionType": "EMAIL", "Address": correo}]} for tipo, umbral in avisos],
          open(f"{obra}/avisos.json", "w"))
PY
  aws budgets create-budget --account-id "$cuenta" --budget "file://$obra/presupuesto.json" \
    --notifications-with-subscribers "file://$obra/avisos.json"
fi

echo
echo "Listo: 5 alarmas y el presupuesto «karta-mensual». Se ven en CloudWatch › Alarmas y en Billing › Budgets."
