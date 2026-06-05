param(
  [string]$ClusterName = "cloudopshub"
)

$ErrorActionPreference = "Stop"

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$config = Join-Path $root "k8s/kind/cloudopshub-kind.yaml"

function Require-Command($Name) {
  if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
    throw "$Name is not installed or is not on PATH."
  }
}

Require-Command docker
Require-Command kind
Require-Command kubectl

docker info | Out-Null

$clusters = kind get clusters
if ($clusters -notcontains $ClusterName) {
  kind create cluster --name $ClusterName --config $config
}

kubectl config use-context "kind-$ClusterName"

$nodes = kubectl get nodes -o jsonpath="{range .items[*]}{.metadata.name}{'\n'}{end}"
$workerNodes = $nodes | Where-Object { $_ -like "$ClusterName-worker*" }

if ($workerNodes.Count -ge 1) {
  kubectl label node $workerNodes[0] topology.kubernetes.io/zone=local-az-a --overwrite
}

if ($workerNodes.Count -ge 2) {
  kubectl label node $workerNodes[1] topology.kubernetes.io/zone=local-az-b --overwrite
}

kubectl get nodes --show-labels

Write-Host ""
Write-Host "Kind cluster is ready. Deploy the app with:"
Write-Host ".\scripts\deploy-k8s-local.ps1"
