# CloudOpsHub

Automated Multi-Cluster Infrastructure Platform for CloudOpsHub.

This repository scaffolds Terraform, Ansible, Helm charts, CI, and monitoring for a multi-cluster GitOps platform that supports dev, staging, and prod delivery across Kubernetes clusters.

See `docs/` for architecture and runbooks.

Container image folders and replacement steps are documented in `docs/images.md`.

## Run The Application Locally

Start with the application before CI/CD:

```powershell
docker compose up --build
```

Open the dashboard:

```text
http://localhost:18090
```

Backend API:

```text
http://localhost:18091/api/summary
http://localhost:18091/api/clusters
http://localhost:18091/api/pipelines
http://localhost:18091/api/incidents
```

Postgres is exposed locally on port `15432` with:

```text
database: cloudopshub
user: cloudopshub
password: change-me
```

## Quickstart

Prerequisites:

- `terraform` >= 1.0
- `aws` CLI configured with credentials
- `kubectl`
- `helm`
- `kubectl` configured for the target cluster after provisioning
- GitHub repository with GitHub Actions and Docker Hub secrets configured

## Provision Infrastructure

Bootstrap the Terraform backend and provision an environment:

```bash
cd infra/terraform
chmod +x backend-bootstrap.sh
./backend-bootstrap.sh
terraform init
terraform apply -var-file=env.dev.tfvars
```

Use another variable file for staging or production:

```bash
terraform apply -var-file=env.staging.tfvars
terraform apply -var-file=env.prod.tfvars
```

Configure `kubectl` for the cluster:

```bash
aws eks update-kubeconfig --name $(terraform output -raw cluster_name) --region us-east-1
```

## Install ArgoCD

Install the official ArgoCD manifests on the control cluster.

For local kind testing:

```powershell
.\scripts\install-argocd-local.ps1 -Revision fix-push
```

This installs ArgoCD, creates the `cloudopshub` namespace, creates the demo DB Secret, applies the ArgoCD Applications, and opens the ArgoCD UI at:

```text
http://localhost:18080
```

For production or a Linux/macOS shell:

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

Register remote clusters when using a central control-plane model. See `docs/deployment.md`.

## Configure Image Pulling

If your Docker Hub repositories are private, create a Docker Hub pull secret in each target namespace:

```bash
kubectl create secret docker-registry dockerhub-pull-secret \
  --docker-server=docker.io \
  --docker-username=fabulousjeff2009 \
  --docker-password=<dockerhub-token> \
  --docker-email=<email>

kubectl patch serviceaccount default \
  -p '{"imagePullSecrets":[{"name":"dockerhub-pull-secret"}]}'
```

## Deploy Applications

Push application images via CI or build and push them locally.

For a local Kubernetes smoke test before ArgoCD, use a kind cluster. If Docker Desktop asks for a Kubernetes provisioner, choose `kind`.

Install kind if needed:

```powershell
choco install kind -y
```

Create a local multi-node kind cluster with two worker nodes labeled as separate zones:

```powershell
.\scripts\create-kind-cluster.ps1
```

Deploy with Helm:

```powershell
.\scripts\deploy-k8s-local.ps1
```

To choose the local Kubernetes DB password:

```powershell
.\scripts\deploy-k8s-local.ps1 -DbPassword "your-local-password"
```

If local ports `18090` or `18091` are already in use, choose different port-forward ports:

```powershell
.\scripts\deploy-k8s-local.ps1 -FrontendPort 28090 -BackendPort 28091
```

This installs the application into the `cloudopshub` namespace and port-forwards:

```text
frontend: http://localhost:18090
backend:  http://localhost:18091/api/summary
```

For GitOps deployment, ArgoCD syncs the Helm charts from `k8s/apps`.

Before syncing the db chart, make sure the DB Secret exists:

```bash
DB_PASSWORD='<db-password>' ./scripts/create-db-secret.sh
```

```bash
kubectl apply -f k8s/apps/db-app.yaml
kubectl apply -f k8s/apps/backend-app.yaml
kubectl apply -f k8s/apps/frontend-app.yaml
```

Check status:

```bash
kubectl get applications -n argocd
kubectl get pods
kubectl get svc
```

## Operations

- Secrets: install SealedSecrets or External Secrets before production use.
- Monitoring: install Prometheus, Grafana, Loki, and Tempo as documented in `docs/monitoring.md`.
- Backups: install Velero and configure database backups as documented in `docs/backups.md`.
- Runbooks: see `docs/runbooks.md`.
