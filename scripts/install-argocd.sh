#!/usr/bin/env bash
set -euo pipefail

echo "Installing ArgoCD (minimal example). For production use upstream manifests."

kubectl create namespace argocd || true
kubectl apply -n argocd -f k8s/argocd/install-argocd.yaml

echo "ArgoCD installed. Get admin password:"
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 --decode || true
