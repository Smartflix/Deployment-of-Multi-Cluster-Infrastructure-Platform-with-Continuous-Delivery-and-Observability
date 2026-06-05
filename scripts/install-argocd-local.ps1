param(
  [string]$Namespace = "cloudopshub",
  [string]$DbPassword = "change-me-local",
  [string]$Revision = "HEAD",
  [switch]$SkipPortForward
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($Namespace)) {
  $Namespace = "cloudopshub"
}

$root = Resolve-Path (Join-Path $PSScriptRoot "..")

function Require-Command($Name) {
  if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
    throw "$Name is not installed or is not on PATH."
  }
}

Require-Command kubectl

$context = kubectl config current-context 2>$null
if (-not $context) {
  throw "kubectl has no current context. Create or select a Kubernetes cluster first."
}

Write-Host "Using Kubernetes context: $context"

kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

kubectl rollout status deployment/argocd-server -n argocd --timeout=300s
kubectl rollout status deployment/argocd-repo-server -n argocd --timeout=300s
kubectl rollout status statefulset/argocd-application-controller -n argocd --timeout=300s

kubectl create namespace $Namespace --dry-run=client -o yaml | kubectl apply -f -
kubectl create secret generic cloudopshub-db-secret `
  --from-literal=postgres-password=$DbPassword `
  --namespace $Namespace `
  --dry-run=client `
  -o yaml | kubectl apply -f -

kubectl apply -f (Join-Path $root "k8s/apps/db-app.yaml")
kubectl apply -f (Join-Path $root "k8s/apps/backend-app.yaml")
kubectl apply -f (Join-Path $root "k8s/apps/frontend-app.yaml")

if ($Revision -ne "HEAD") {
  foreach ($app in @("db", "backend", "frontend")) {
    kubectl patch application $app -n argocd --type merge -p "{`"spec`":{`"source`":{`"targetRevision`":`"$Revision`"}}}"
  }
}

kubectl get applications -n argocd

if (-not $SkipPortForward) {
  Write-Host ""
  Write-Host "Starting ArgoCD UI port-forward in a separate PowerShell window:"
  Write-Host "  http://localhost:18080"
  Start-Process powershell -ArgumentList "-NoExit", "-Command", "kubectl port-forward svc/argocd-server 18080:80 -n argocd"

  Write-Host ""
  Write-Host "Get the initial ArgoCD admin password with:"
  Write-Host "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | %{ [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String(`$_)) }"
}
