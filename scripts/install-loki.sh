#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-monitoring}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

helm repo add grafana https://grafana.github.io/helm-charts
helm repo update grafana

kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

if kubectl get pvc storage-loki-0 -n "${NAMESPACE}" >/dev/null 2>&1; then
  PVC_PHASE="$(kubectl get pvc storage-loki-0 -n "${NAMESPACE}" -o jsonpath='{.status.phase}')"
  if [[ "${PVC_PHASE}" == "Pending" ]]; then
    echo "Found pending Loki PVC storage-loki-0. Recreating Loki without persistent storage."
    helm uninstall loki --namespace "${NAMESPACE}" || true
    kubectl delete pvc storage-loki-0 -n "${NAMESPACE}" --ignore-not-found
  fi
fi

helm upgrade --install loki grafana/loki \
  --namespace "${NAMESPACE}" \
  --values "${ROOT}/monitoring/loki-values.yaml"

kubectl rollout status statefulset/loki -n "${NAMESPACE}" --timeout=300s || {
  echo ""
  echo "Loki did not become ready. Diagnostics:"
  kubectl get pods -n "${NAMESPACE}" -l app.kubernetes.io/instance=loki -o wide
  kubectl get pvc -n "${NAMESPACE}" -l app.kubernetes.io/instance=loki
  kubectl describe pvc -n "${NAMESPACE}" -l app.kubernetes.io/instance=loki
  kubectl describe statefulset/loki -n "${NAMESPACE}"
  kubectl logs -n "${NAMESPACE}" statefulset/loki --tail=100 || true
  exit 1
}

kubectl rollout status deployment/loki-gateway -n "${NAMESPACE}" --timeout=180s || {
  echo ""
  echo "Loki gateway did not become ready. Diagnostics:"
  kubectl get pods -n "${NAMESPACE}" -l app.kubernetes.io/component=gateway -o wide
  kubectl describe deployment/loki-gateway -n "${NAMESPACE}"
  exit 1
}

kubectl run loki-healthcheck \
  --namespace "${NAMESPACE}" \
  --image=curlimages/curl:8.11.1 \
  --restart=Never \
  --rm \
  -i \
  --command -- sh -c "curl -fsS http://loki-gateway.${NAMESPACE}.svc.cluster.local/ && curl -fsS http://loki.${NAMESPACE}.svc.cluster.local:3100/ready"

helm upgrade --install alloy-logs grafana/alloy \
  --namespace "${NAMESPACE}" \
  --values "${ROOT}/monitoring/alloy-logs-values.yaml"

kubectl rollout status daemonset/alloy-logs -n "${NAMESPACE}" --timeout=300s || {
  echo ""
  echo "Alloy did not become ready. Diagnostics:"
  kubectl get pods -n "${NAMESPACE}" -l app.kubernetes.io/instance=alloy-logs -o wide
  kubectl describe daemonset/alloy-logs -n "${NAMESPACE}"
  kubectl logs -n "${NAMESPACE}" -l app.kubernetes.io/instance=alloy-logs -c alloy --tail=80 || true
  exit 1
}

kubectl get pods,svc -n "${NAMESPACE}"

echo ""
echo "In Grafana, add Loki datasource if it is not auto-discovered:"
echo "  URL: http://loki-gateway.monitoring.svc.cluster.local"
echo "Then query logs with:"
echo '  {namespace="cloudopshub"}'
