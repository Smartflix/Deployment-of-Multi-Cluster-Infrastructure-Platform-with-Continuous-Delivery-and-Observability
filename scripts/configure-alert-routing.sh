#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-monitoring}"
SLACK_WEBHOOK_URL="${SLACK_WEBHOOK_URL:-}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if [[ -z "${SLACK_WEBHOOK_URL}" ]]; then
  echo "Set SLACK_WEBHOOK_URL before running."
  echo "Example: export SLACK_WEBHOOK_URL='https://hooks.slack.com/services/...'"
  exit 1
fi

kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic cloudopshub-alert-routing \
  --namespace "${NAMESPACE}" \
  --from-literal=slack-webhook-url="${SLACK_WEBHOOK_URL}" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -f "${ROOT}/monitoring/cloudopshub-alert-routing.yaml"

kubectl get secret cloudopshub-alert-routing -n "${NAMESPACE}"
kubectl get alertmanagerconfig cloudopshub-alert-routing -n "${NAMESPACE}"

echo ""
echo "Alert routing is configured."
echo "Run scripts/test-alert-routing.sh to fire a temporary test alert."
