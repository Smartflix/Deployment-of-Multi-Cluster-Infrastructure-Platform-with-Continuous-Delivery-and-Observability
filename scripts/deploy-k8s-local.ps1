param(
  [string]$Namespace = "cloudopshub",
  [string]$DbPassword = "change-me-local",
  [int]$FrontendPort = 18090,
  [int]$BackendPort = 18091,
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
Require-Command helm

$context = kubectl config current-context 2>$null
if (-not $context) {
  throw "kubectl has no current context. Enable Docker Desktop Kubernetes or configure an EKS/kind/minikube context first."
}

Write-Host "Using Kubernetes context: $context"

kubectl create namespace $Namespace --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic cloudopshub-db-secret `
  --from-literal=postgres-password=$DbPassword `
  --namespace $Namespace `
  --dry-run=client `
  -o yaml | kubectl apply -f -

helm upgrade --install db (Join-Path $root "k8s/helm/db") --namespace $Namespace
helm upgrade --install backend (Join-Path $root "k8s/helm/backend") --namespace $Namespace
helm upgrade --install frontend (Join-Path $root "k8s/helm/frontend") --namespace $Namespace

kubectl rollout status deployment/db -n $Namespace --timeout=180s
kubectl rollout status deployment/backend -n $Namespace --timeout=180s
kubectl rollout status deployment/frontend -n $Namespace --timeout=180s

kubectl get pods,svc -n $Namespace

if (-not $SkipPortForward) {
  Write-Host ""
  Write-Host "Starting port-forwards in separate PowerShell windows:"
  Write-Host "  Frontend: http://localhost:$FrontendPort"
  Write-Host "  Backend:  http://localhost:$BackendPort/api/summary"

  Start-Process powershell -ArgumentList "-NoExit", "-Command", "kubectl port-forward svc/frontend ${FrontendPort}:80 -n $Namespace"
  Start-Process powershell -ArgumentList "-NoExit", "-Command", "kubectl port-forward svc/backend ${BackendPort}:8080 -n $Namespace"
}
