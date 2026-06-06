#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-monitoring}"
GRAFANA_ADMIN_PASSWORD="${GRAFANA_ADMIN_PASSWORD:-}"

if [[ -z "${GRAFANA_ADMIN_PASSWORD}" ]]; then
  echo "Set GRAFANA_ADMIN_PASSWORD before running."
  echo "Example: export GRAFANA_ADMIN_PASSWORD='strong-password'"
  exit 1
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update prometheus-community

kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

helm upgrade --install cloudopshub-monitoring prometheus-community/kube-prometheus-stack \
  --namespace "${NAMESPACE}" \
  --values "${ROOT}/monitoring/kube-prometheus-values.yaml" \
  --set grafana.adminPassword="${GRAFANA_ADMIN_PASSWORD}"

kubectl apply -f "${ROOT}/monitoring/cloudopshub-dashboard.yaml"
kubectl apply -f "${ROOT}/monitoring/cloudopshub-alerts.yaml"

if kubectl get secret cloudopshub-alert-routing -n "${NAMESPACE}" >/dev/null 2>&1; then
  kubectl apply -f "${ROOT}/monitoring/cloudopshub-alert-routing.yaml"
else
  echo "Skipping alert routing because secret cloudopshub-alert-routing does not exist."
  echo "Run scripts/configure-alert-routing.sh after creating a Slack webhook."
fi

kubectl rollout status deployment/cloudopshub-monitoring-grafana -n "${NAMESPACE}" --timeout=180s
kubectl get pods,svc -n "${NAMESPACE}"

echo ""
echo "Grafana:"
echo "  kubectl port-forward svc/cloudopshub-monitoring-grafana 3000:80 -n ${NAMESPACE}"
echo "  username: admin"
echo "  password: value of GRAFANA_ADMIN_PASSWORD"
