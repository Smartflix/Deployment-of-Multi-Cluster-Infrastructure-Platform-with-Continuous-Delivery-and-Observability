#!/usr/bin/env bash
set -euo pipefail

BACKUP_NAME="${BACKUP_NAME:-}"
RESTORE_NAME="${RESTORE_NAME:-cloudopshub-restore-$(date -u +%Y%m%d%H%M%S)}"
RESTORE_NAMESPACE="${RESTORE_NAMESPACE:-cloudopshub-restore-test}"
EXCLUDED_RESOURCES="${EXCLUDED_RESOURCES:-targetgroupbindings.elbv2.k8s.aws}"

if [[ -z "${BACKUP_NAME}" ]]; then
  echo "Set BACKUP_NAME before running."
  echo "Example: BACKUP_NAME='cloudopshub-20260605120000' ./scripts/validate-velero-restore.sh"
  exit 1
fi

if ! command -v velero >/dev/null 2>&1; then
  echo "velero CLI is required. Install it before running this script."
  exit 1
fi

velero restore create "${RESTORE_NAME}" \
  --from-backup "${BACKUP_NAME}" \
  --namespace-mappings "cloudopshub:${RESTORE_NAMESPACE}" \
  --exclude-resources "${EXCLUDED_RESOURCES}" \
  --wait

kubectl get pods,svc -n "${RESTORE_NAMESPACE}"

echo ""
echo "Restore details:"
velero restore describe "${RESTORE_NAME}" --details

echo ""
echo "Checking restored CloudOpsHub workloads:"
kubectl rollout status deployment/backend -n "${RESTORE_NAMESPACE}" --timeout=120s
kubectl rollout status deployment/frontend -n "${RESTORE_NAMESPACE}" --timeout=120s
