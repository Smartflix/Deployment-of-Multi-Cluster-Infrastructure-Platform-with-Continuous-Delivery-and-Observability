#!/usr/bin/env bash
set -euo pipefail

AWS_REGION="${AWS_REGION:-us-east-1}"
ROOT_DOMAIN="${ROOT_DOMAIN:-devopslegend.click}"
FRONTEND_HOST="${FRONTEND_HOST:-app.${ROOT_DOMAIN}}"
INGRESS_NAMESPACE="${INGRESS_NAMESPACE:-cloudopshub}"
INGRESS_NAME="${INGRESS_NAME:-frontend}"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "$1 is required before running this script."
    exit 1
  fi
}

require_command aws
require_command kubectl

HOSTED_ZONE_ID="$(aws route53 list-hosted-zones-by-name \
  --dns-name "${ROOT_DOMAIN}." \
  --query "HostedZones[?Name=='${ROOT_DOMAIN}.'] | [0].Id" \
  --output text | sed 's#/hostedzone/##')"

if [[ -z "${HOSTED_ZONE_ID}" || "${HOSTED_ZONE_ID}" == "None" ]]; then
  echo "Could not find Route 53 hosted zone for ${ROOT_DOMAIN}."
  exit 1
fi

ALB_DNS_NAME="$(kubectl get ingress "${INGRESS_NAME}" -n "${INGRESS_NAMESPACE}" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"

if [[ -z "${ALB_DNS_NAME}" ]]; then
  echo "Ingress ${INGRESS_NAMESPACE}/${INGRESS_NAME} does not have an ALB hostname yet."
  exit 1
fi

ALB_HOSTED_ZONE_ID="$(aws elbv2 describe-load-balancers \
  --region "${AWS_REGION}" \
  --query "LoadBalancers[?DNSName=='${ALB_DNS_NAME}'] | [0].CanonicalHostedZoneId" \
  --output text)"

if [[ -z "${ALB_HOSTED_ZONE_ID}" || "${ALB_HOSTED_ZONE_ID}" == "None" ]]; then
  echo "Could not find ALB hosted zone ID for ${ALB_DNS_NAME}."
  exit 1
fi

CHANGE_BATCH="$(mktemp)"
cat > "${CHANGE_BATCH}" <<EOF
{
  "Comment": "CloudOpsHub frontend ALB alias",
  "Changes": [
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "${FRONTEND_HOST}.",
        "Type": "A",
        "AliasTarget": {
          "HostedZoneId": "${ALB_HOSTED_ZONE_ID}",
          "DNSName": "${ALB_DNS_NAME}",
          "EvaluateTargetHealth": true
        }
      }
    }
  ]
}
EOF

aws route53 change-resource-record-sets \
  --hosted-zone-id "${HOSTED_ZONE_ID}" \
  --change-batch "file://${CHANGE_BATCH}"

rm -f "${CHANGE_BATCH}"

echo ""
echo "Created/updated Route 53 alias:"
echo "  https://${FRONTEND_HOST}"
echo "  -> ${ALB_DNS_NAME}"
