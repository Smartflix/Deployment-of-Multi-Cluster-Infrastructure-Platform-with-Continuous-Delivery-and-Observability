#!/usr/bin/env bash
set -euo pipefail

AWS_REGION="${AWS_REGION:-us-east-1}"
ROOT_DOMAIN="${ROOT_DOMAIN:-devopslegend.click}"
FRONTEND_HOST="${FRONTEND_HOST:-app.${ROOT_DOMAIN}}"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "$1 is required before running this script."
    exit 1
  fi
}

require_command aws

HOSTED_ZONE_ID="$(aws route53 list-hosted-zones-by-name \
  --dns-name "${ROOT_DOMAIN}." \
  --query "HostedZones[?Name=='${ROOT_DOMAIN}.'] | [0].Id" \
  --output text | sed 's#/hostedzone/##')"

if [[ -z "${HOSTED_ZONE_ID}" || "${HOSTED_ZONE_ID}" == "None" ]]; then
  echo "Could not find Route 53 hosted zone for ${ROOT_DOMAIN}."
  exit 1
fi

EXISTING_CERT_ARN="$(aws acm list-certificates \
  --region "${AWS_REGION}" \
  --certificate-statuses ISSUED PENDING_VALIDATION \
  --query "CertificateSummaryList[?DomainName=='${FRONTEND_HOST}'] | [0].CertificateArn" \
  --output text)"

if [[ -n "${EXISTING_CERT_ARN}" && "${EXISTING_CERT_ARN}" != "None" ]]; then
  CERTIFICATE_ARN="${EXISTING_CERT_ARN}"
  echo "Using existing ACM certificate: ${CERTIFICATE_ARN}"
else
  CERTIFICATE_ARN="$(aws acm request-certificate \
    --region "${AWS_REGION}" \
    --domain-name "${FRONTEND_HOST}" \
    --validation-method DNS \
    --query CertificateArn \
    --output text)"
  echo "Requested ACM certificate: ${CERTIFICATE_ARN}"
fi

echo "Waiting for ACM validation record to appear..."
for _ in {1..30}; do
  RECORD_JSON="$(aws acm describe-certificate \
    --region "${AWS_REGION}" \
    --certificate-arn "${CERTIFICATE_ARN}" \
    --query "Certificate.DomainValidationOptions[0].ResourceRecord" \
    --output json)"

  RECORD_NAME="$(printf '%s' "${RECORD_JSON}" | python3 -c 'import json,sys; data=json.load(sys.stdin); print((data or {}).get("Name", ""))')"
  RECORD_TYPE="$(printf '%s' "${RECORD_JSON}" | python3 -c 'import json,sys; data=json.load(sys.stdin); print((data or {}).get("Type", ""))')"
  RECORD_VALUE="$(printf '%s' "${RECORD_JSON}" | python3 -c 'import json,sys; data=json.load(sys.stdin); print((data or {}).get("Value", ""))')"

  if [[ -n "${RECORD_NAME}" && -n "${RECORD_TYPE}" && -n "${RECORD_VALUE}" ]]; then
    break
  fi

  sleep 5
done

if [[ -z "${RECORD_NAME:-}" || -z "${RECORD_TYPE:-}" || -z "${RECORD_VALUE:-}" ]]; then
  echo "ACM did not return a DNS validation record."
  exit 1
fi

CHANGE_BATCH="$(mktemp)"
cat > "${CHANGE_BATCH}" <<EOF
{
  "Comment": "CloudOpsHub ACM validation for ${FRONTEND_HOST}",
  "Changes": [
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "${RECORD_NAME}",
        "Type": "${RECORD_TYPE}",
        "TTL": 300,
        "ResourceRecords": [
          { "Value": "${RECORD_VALUE}" }
        ]
      }
    }
  ]
}
EOF

aws route53 change-resource-record-sets \
  --hosted-zone-id "${HOSTED_ZONE_ID}" \
  --change-batch "file://${CHANGE_BATCH}" >/dev/null

rm -f "${CHANGE_BATCH}"

echo "Created/updated ACM DNS validation record in Route 53."
echo "Waiting for ACM certificate to be issued..."
aws acm wait certificate-validated \
  --region "${AWS_REGION}" \
  --certificate-arn "${CERTIFICATE_ARN}"

echo ""
echo "ACM certificate is issued."
echo "export FRONTEND_HOST=${FRONTEND_HOST}"
echo "export CERTIFICATE_ARN=${CERTIFICATE_ARN}"
