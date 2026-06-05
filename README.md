# CloudOpsHub

Automated Multi-Cluster Infrastructure Platform for CloudOpsHub.

This repository scaffolds Terraform, Ansible, Helm charts, CI, and monitoring for a multi-cluster GitOps platform that supports dev, staging, and prod delivery across Kubernetes clusters.

See `docs/` for architecture and runbooks.

Container image folders and replacement steps are documented in `docs/images.md`.

## Quickstart

Prerequisites:

- `terraform` >= 1.0
- `aws` CLI configured with credentials
- `kubectl`
- `helm`
- `kubectl` configured for the target cluster after provisioning
- GitHub repository with GitHub Actions and package publishing enabled for GHCR

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

Install the official ArgoCD manifests on the control cluster:

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

Register remote clusters when using a central control-plane model. See `docs/deployment.md`.

## Configure Image Pulling

Create a GHCR pull secret in each target namespace that pulls CloudOpsHub images:

```bash
kubectl create secret docker-registry ghcr-pull-secret \
  --docker-server=ghcr.io \
  --docker-username=<github-username> \
  --docker-password=<github-token> \
  --docker-email=<email>

kubectl patch serviceaccount default \
  -p '{"imagePullSecrets":[{"name":"ghcr-pull-secret"}]}'
```

## Deploy Applications

Push application images via CI or build and push them locally. ArgoCD syncs the Helm charts from `k8s/apps`.

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
