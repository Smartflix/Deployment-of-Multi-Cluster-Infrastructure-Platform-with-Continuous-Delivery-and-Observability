#!/usr/bin/env bash
set -euo pipefail

BACKUP_NAME="${BACKUP_NAME:-cloudopshub-$(date -u +%Y%m%d%H%M%S)}"
NAMESPACE="${NAMESPACE:-cloudopshub}"
EXCLUDED_RESOURCES="${EXCLUDED_RESOURCES:-targetgroupbindings.elbv2.k8s.aws}"

if ! command -v velero >/dev/null 2>&1; then
  echo "velero CLI is required. Install it before running this script."
  exit 1
fi

velero backup create "${BACKUP_NAME}" \
  --include-namespaces "${NAMESPACE}" \
  --exclude-resources "${EXCLUDED_RESOURCES}" \
  --wait

velero backup describe "${BACKUP_NAME}" --details
