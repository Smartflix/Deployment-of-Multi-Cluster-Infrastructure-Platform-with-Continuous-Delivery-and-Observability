# CloudOpsHub

Automated Multi-Cluster Infrastructure Platform for CloudOpsHub.

This repository scaffolds Terraform, Ansible, Helm charts, CI, and monitoring for a multi-cluster GitOps platform that supports dev, staging, and prod delivery across Kubernetes clusters.

See `docs/` for architecture and runbooks.

For the full human-readable project report, including blockers and resolutions, see `docs/project-documentation.md`.

Container image folders and replacement steps are documented in `docs/images.md`.

## Application Tree

```text
.
|-- .github/
|   `-- workflows/
|       |-- ci.yml                 # CI validation and image build checks
|       `-- cd.yml                 # Docker Hub push, Trivy scan, GitOps tag updates
|-- ansible/
|   `-- playbooks/
|       `-- site.yml               # Configuration automation entrypoint
|-- apps/
|   |-- backend/
|   |   |-- app.py                 # Python HTTP API and metrics endpoint
|   |   `-- Dockerfile
|   |-- frontend/
|   |   |-- index.html             # CloudOpsHub dashboard UI
|   |   |-- nginx.conf             # Static hosting and API proxy config
|   |   `-- Dockerfile
|   `-- db/
|       |-- init.sql               # Demo PostgreSQL seed data
|       `-- Dockerfile
|-- docs/                          # Architecture, deployment, monitoring, backup docs
|-- infra/
|   `-- terraform/
|       |-- main.tf                # AWS/EKS infrastructure
|       |-- rds.tf                 # Production RDS database
|       |-- eks_resources.tf       # EKS supporting resources
|       |-- env.dev.tfvars
|       |-- env.staging.tfvars
|       `-- env.prod.tfvars
|-- k8s/
|   |-- apps/                      # ArgoCD Application manifests
|   |-- helm/                      # Helm charts for frontend, backend, and db
|   `-- kind/                      # Local kind cluster config
|-- monitoring/                    # Prometheus, Grafana, Loki, and alert configs
|-- scripts/                       # Provisioning, deployment, backup, and ops scripts
|-- docker-compose.yml             # Local app stack
`-- README.md
```

## Project Architecture

CloudOpsHub is a GitOps-based multi-cluster infrastructure platform. Terraform provisions AWS infrastructure, GitHub Actions validates and packages the application, Docker Hub stores versioned container images, and ArgoCD reconciles Kubernetes workloads from Git into the target cluster.

```text
Developer
   |
   | git push / pull request
   v
GitHub Repository
   |
   | CI: app checks, Terraform validate, Helm validate, Docker build check
   v
GitHub Actions CI
   |
   | successful push triggers CD
   v
GitHub Actions CD
   |
   | build and push images
   
Docker Hub
   |
   | commit updated image tags
   v
GitOps Manifests in k8s/apps
   |
   | ArgoCD watches Git
   v
ArgoCD Control Plane
   |
   | sync Helm charts from k8s/helm
   v
Kubernetes / EKS Clusters
   |
   | run frontend, backend, database integration, monitoring, logging
   v
CloudOpsHub Application
```

Core components:

- **Application:** a static nginx frontend, a Python backend API, and a demo PostgreSQL container for local or non-production testing.
- **Infrastructure:** Terraform creates environment-specific AWS resources, including EKS clusters and production RDS PostgreSQL.
- **Delivery:** CI validates code and manifests; CD publishes Docker images and updates ArgoCD image tags.
- **GitOps:** ArgoCD Applications in `k8s/apps` point to Helm charts in `k8s/helm`, keeping cluster state reproducible from Git.
- **Operations:** monitoring, logging, alerting, backups, and restore workflows are supported through `monitoring/`, `scripts/`, and `docs/`.

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

For the production multi-AZ deployment, Terraform creates:

```text
EKS cluster across two availability zones
Managed node group with 4 desired nodes
Multi-AZ RDS PostgreSQL database
```

Production uses RDS for the database. The in-cluster `db` Helm chart is only for local/demo testing.

Use the helper script to plan first:

```powershell
$env:TF_VAR_db_password = "strong-db-password"
.\scripts\deploy-eks-prod.ps1
```

Create the AWS resources only when you are ready:

```powershell
$env:TF_VAR_db_password = "strong-db-password"
.\scripts\deploy-eks-prod.ps1 -Apply
```

To switch an already-running prod cluster from the demo db pod to RDS:

```bash
export TF_VAR_db_password='strong-db-password'
./scripts/switch-prod-to-rds.sh
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

## GitHub Actions CI/CD Pipeline

The CI workflow runs backend Python syntax and API smoke tests, frontend nginx config validation, Terraform formatting and validation, Helm chart lint/render checks, and Docker image build checks.

After CI passes on a push, the CD workflow builds the frontend, backend, and demo db images, pushes them to Docker Hub, scans pushed images with Trivy, then updates the frontend/backend ArgoCD image tags to the Git SHA.

Add these GitHub repository secrets:

```text
DOCKERHUB_USERNAME
DOCKERHUB_TOKEN
```

Enable workflow write access:

```text
Repository Settings -> Actions -> General -> Workflow permissions -> Read and write permissions
```

For a local Kubernetes smoke test before ArgoCD, use a kind cluster. If Docker Desktop asks for a Kubernetes provisioner, choose `kind`.

Install kind ;

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

## Expose Frontend With ALB

For production EKS, expose the frontend through AWS Load Balancer Controller and an ALB-backed Ingress:

```bash
export AWS_REGION=us-east-1
export CLUSTER_NAME=cloudopshub-prod
chmod +x scripts/install-aws-load-balancer-controller.sh
./scripts/install-aws-load-balancer-controller.sh
```

Commit and push the frontend Ingress changes so ArgoCD can sync them:

```bash
git add .
git commit -m "Expose frontend with AWS ALB ingress"
git push origin fix-push
```

Refresh the frontend app and wait for an ALB address:

```bash
kubectl apply -f k8s/apps/frontend-app.yaml
kubectl annotate application frontend -n argocd argocd.argoproj.io/refresh=hard --overwrite
kubectl get ingress -n cloudopshub -w
```

## Operations

- Secrets: install SealedSecrets or External Secrets before production use.
- Monitoring: install Prometheus and Grafana with `scripts/install-monitoring.sh`; see `docs/monitoring.md`.
- Logs: install Loki and Alloy with `scripts/install-loki.sh`; see `docs/monitoring.md`.
- Backups: validate RDS snapshots and Velero restores as documented in `docs/backups.md`.
- Runbooks: see `docs/runbooks.md`.
