param(
  [switch]$Apply,
  [string]$Tfvars = "env.prod.tfvars",
  [string]$Namespace = "cloudopshub",
  [string]$Revision = "fix-push",
  [switch]$InstallArgoCD
)

$ErrorActionPreference = "Stop"

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$terraformDir = Join-Path $root "infra/terraform"

function Require-Command($Name) {
  if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
    throw "$Name is not installed or is not on PATH."
  }
}

Require-Command aws
Require-Command terraform
Require-Command kubectl

if ([string]::IsNullOrWhiteSpace($env:TF_VAR_db_password)) {
  throw "Set TF_VAR_db_password before running. Example: `$env:TF_VAR_db_password='strong-password'"
}

Push-Location $terraformDir
try {
  terraform init
  terraform plan -var-file=$Tfvars

  if ($Apply) {
    terraform apply -var-file=$Tfvars

    $clusterName = terraform output -raw cluster_name
    $region = (Get-Content $Tfvars | Where-Object { $_ -match '^aws_region\s*=' }) -replace '.*=\s*"?([^"]+)"?', '$1'
    if ([string]::IsNullOrWhiteSpace($region)) {
      $region = "us-east-1"
    }

    aws eks update-kubeconfig --name $clusterName --region $region

    kubectl create namespace $Namespace --dry-run=client -o yaml | kubectl apply -f -

    $rdsHost = terraform output -raw rds_address
    $rdsPort = terraform output -raw rds_port
    $rdsDb = terraform output -raw rds_database_name
    $rdsUser = terraform output -raw rds_username

    kubectl create secret generic cloudopshub-rds-secret `
      --from-literal=DB_HOST=$rdsHost `
      --from-literal=DB_PORT=$rdsPort `
      --from-literal=DB_NAME=$rdsDb `
      --from-literal=DB_USER=$rdsUser `
      --from-literal=DB_PASSWORD=$env:TF_VAR_db_password `
      --namespace $Namespace `
      --dry-run=client `
      -o yaml | kubectl apply -f -

    if ($InstallArgoCD) {
      & (Join-Path $root "scripts/install-argocd-local.ps1") -Namespace $Namespace -DbPassword $env:TF_VAR_db_password -Revision $Revision
    }
  }
}
finally {
  Pop-Location
}
