#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-cloudopshub}"
DB_PASSWORD="${DB_PASSWORD:-}"

if [[ -z "${DB_PASSWORD}" ]]; then
  echo "Set DB_PASSWORD before running this script."
  echo "Example: DB_PASSWORD='your-password' ./scripts/create-db-secret.sh"
  exit 1
fi

kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic cloudopshub-db-secret \
  --from-literal=postgres-password="${DB_PASSWORD}" \
  -n "${NAMESPACE}" \
  --dry-run=client \
  -o yaml | kubectl apply -f -

kubectl rollout restart deployment/db -n "${NAMESPACE}" || true
kubectl rollout status deployment/db -n "${NAMESPACE}" --timeout=180s
