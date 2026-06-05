#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-cloudopshub}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TERRAFORM_DIR="${ROOT}/infra/terraform"

if [[ -z "${TF_VAR_db_password:-}" ]]; then
  echo "Set TF_VAR_db_password before running."
  echo "Example: export TF_VAR_db_password='your-rds-password'"
  exit 1
fi

cd "${TERRAFORM_DIR}"

if terraform output -raw rds_address >/tmp/cloudopshub-rds-address 2>/dev/null; then
  RDS_HOST="$(cat /tmp/cloudopshub-rds-address)"
else
  RDS_ENDPOINT="$(terraform output -raw rds_endpoint)"
  RDS_HOST="${RDS_ENDPOINT%%:*}"
fi

if terraform output -raw rds_port >/tmp/cloudopshub-rds-port 2>/dev/null; then
  RDS_PORT="$(cat /tmp/cloudopshub-rds-port)"
else
  RDS_PORT="5432"
fi

RDS_DB="$(terraform output -raw rds_database_name)"
RDS_USER="$(terraform output -raw rds_username)"

kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -
kubectl create secret generic cloudopshub-rds-secret \
  --from-literal=DB_HOST="${RDS_HOST}" \
  --from-literal=DB_PORT="${RDS_PORT}" \
  --from-literal=DB_NAME="${RDS_DB}" \
  --from-literal=DB_USER="${RDS_USER}" \
  --from-literal=DB_PASSWORD="${TF_VAR_db_password}" \
  -n "${NAMESPACE}" \
  --dry-run=client \
  -o yaml | kubectl apply -f -

kubectl get secret cloudopshub-rds-secret -n "${NAMESPACE}"
