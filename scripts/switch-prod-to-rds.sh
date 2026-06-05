#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-cloudopshub}"
REVISION="${REVISION:-fix-push}"
TFVARS="${TFVARS:-env.prod.tfvars}"

if [[ -z "${TF_VAR_db_password:-}" ]]; then
  echo "Set TF_VAR_db_password before running."
  echo "Example: export TF_VAR_db_password='strong-password'"
  exit 1
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TERRAFORM_DIR="${ROOT}/infra/terraform"

cd "${TERRAFORM_DIR}"

RDS_HOST="$(terraform output -raw rds_address)"
RDS_PORT="$(terraform output -raw rds_port)"
RDS_DB="$(terraform output -raw rds_database_name)"
RDS_USER="$(terraform output -raw rds_username)"

cd "${ROOT}"

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

kubectl delete application db -n argocd --ignore-not-found
kubectl delete deployment db -n "${NAMESPACE}" --ignore-not-found
kubectl delete service db -n "${NAMESPACE}" --ignore-not-found

kubectl apply -f k8s/apps/backend-app.yaml
kubectl patch application backend -n argocd --type merge -p "{\"spec\":{\"source\":{\"targetRevision\":\"${REVISION}\"}}}"
kubectl rollout restart deployment/backend -n "${NAMESPACE}" || true
kubectl rollout status deployment/backend -n "${NAMESPACE}" --timeout=180s

kubectl get applications -n argocd
kubectl get pods,svc -n "${NAMESPACE}" -o wide
