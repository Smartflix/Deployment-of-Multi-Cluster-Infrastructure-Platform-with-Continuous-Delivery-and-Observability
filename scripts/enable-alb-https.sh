#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-argocd}"
APP_NAME="${APP_NAME:-frontend}"
CERTIFICATE_ARN="${CERTIFICATE_ARN:-}"
FRONTEND_HOST="${FRONTEND_HOST:-}"

if [[ -z "${CERTIFICATE_ARN}" ]]; then
  echo "Set CERTIFICATE_ARN before running."
  echo "Example: export CERTIFICATE_ARN='arn:aws:acm:us-east-1:123456789012:certificate/abc...'"
  exit 1
fi

APP_JSON="$(kubectl get application "${APP_NAME}" -n "${NAMESPACE}" -o json)"

printf '%s' "${APP_JSON}" | CERTIFICATE_ARN="${CERTIFICATE_ARN}" FRONTEND_HOST="${FRONTEND_HOST}" python3 -c '
import json
import os
import sys

app = json.load(sys.stdin)
certificate_arn = os.environ["CERTIFICATE_ARN"]
frontend_host = os.environ.get("FRONTEND_HOST", "")

helm = app.setdefault("spec", {}).setdefault("source", {}).setdefault("helm", {})
parameters = helm.setdefault("parameters", [])

def set_param(name, value):
    for param in parameters:
        if param.get("name") == name:
            param["value"] = value
            return
    parameters.append({"name": name, "value": value})

set_param("ingress.enabled", "true")
set_param("ingress.tls.enabled", "true")
set_param("ingress.tls.certificateArn", certificate_arn)
set_param("ingress.tls.sslRedirect", "true")

if frontend_host:
    set_param("ingress.hosts[0].host", frontend_host)

for field in ["status", "metadata"]:
    if field == "metadata":
        app[field] = {
            "name": app["metadata"]["name"],
            "namespace": app["metadata"].get("namespace", "argocd"),
            "annotations": app["metadata"].get("annotations", {}),
        }
    else:
        app.pop(field, None)

json.dump(app, sys.stdout)
' | kubectl apply -f -

kubectl get application "${APP_NAME}" -n "${NAMESPACE}" -o yaml | sed -n '/parameters:/,/destination:/p'

echo ""
echo "ArgoCD will sync the frontend Ingress with HTTPS."
echo "Check the ALB with:"
echo "  kubectl get ingress frontend -n cloudopshub"
