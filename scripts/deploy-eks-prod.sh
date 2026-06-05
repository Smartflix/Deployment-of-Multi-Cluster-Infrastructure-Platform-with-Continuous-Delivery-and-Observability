#!/usr/bin/env bash
set -euo pipefail

TFVARS="${TFVARS:-env.prod.tfvars}"
NAMESPACE="${NAMESPACE:-cloudopshub}"
REVISION="${REVISION:-fix-push}"
APPLY="${APPLY:-false}"
INSTALL_ARGOCD="${INSTALL_ARGOCD:-false}"

if [[ -z "${TF_VAR_db_password:-}" ]]; then
  echo "Set TF_VAR_db_password before running."
  echo "Example: export TF_VAR_db_password='strong-password'"
  exit 1
fi

cd "$(dirname "$0")/../infra/terraform"

terraform init
terraform plan -var-file="${TFVARS}"

if [[ "${APPLY}" != "true" ]]; then
  echo "Plan complete. Set APPLY=true to create AWS resources."
  exit 0
fi

terraform apply -var-file="${TFVARS}"

CLUSTER_NAME="$(terraform output -raw cluster_name)"
REGION="$(awk -F= '/^aws_region/ { gsub(/[ "]/, "", $2); print $2 }' "${TFVARS}")"
REGION="${REGION:-us-east-1}"

aws eks update-kubeconfig --name "${CLUSTER_NAME}" --region "${REGION}"

kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

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

kubectl create secret generic cloudopshub-rds-secret \
  --from-literal=DB_HOST="${RDS_HOST}" \
  --from-literal=DB_PORT="${RDS_PORT}" \
  --from-literal=DB_NAME="${RDS_DB}" \
  --from-literal=DB_USER="${RDS_USER}" \
  --from-literal=DB_PASSWORD="${TF_VAR_db_password}" \
  -n "${NAMESPACE}" \
  --dry-run=client \
  -o yaml | kubectl apply -f -

if [[ "${INSTALL_ARGOCD}" == "true" ]]; then
  cd ../..
  kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
  kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
  kubectl rollout status deployment/argocd-server -n argocd --timeout=300s
  kubectl rollout status deployment/argocd-repo-server -n argocd --timeout=300s
  kubectl rollout status statefulset/argocd-application-controller -n argocd --timeout=300s
  kubectl apply -f k8s/apps/backend-app.yaml
  kubectl apply -f k8s/apps/frontend-app.yaml
  kubectl patch application backend -n argocd --type merge -p "{\"spec\":{\"source\":{\"targetRevision\":\"${REVISION}\"}}}"
  kubectl patch application frontend -n argocd --type merge -p "{\"spec\":{\"source\":{\"targetRevision\":\"${REVISION}\"}}}"
fi
