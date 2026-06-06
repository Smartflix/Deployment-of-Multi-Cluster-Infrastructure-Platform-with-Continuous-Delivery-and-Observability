#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-monitoring}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

kubectl apply -f "${ROOT}/monitoring/cloudopshub-test-alert.yaml"

echo "Temporary test alert applied."
echo "Wait 1-2 minutes, then check Alertmanager/Grafana or your Slack channel."
echo ""
echo "Check alert state:"
echo "  kubectl get prometheusrule cloudopshub-test-alert -n ${NAMESPACE}"
echo ""
echo "Remove the test alert after validation:"
echo "  kubectl delete -f ${ROOT}/monitoring/cloudopshub-test-alert.yaml"
