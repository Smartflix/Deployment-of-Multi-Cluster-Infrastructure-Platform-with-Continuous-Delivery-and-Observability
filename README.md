# CloudOpsHub

Automated Multi-Cluster Infrastructure Platform for CloudOpsHub.

This repository scaffolds Terraform, Ansible, Helm charts, CI, and monitoring for a multi-cluster GitOps platform.

See `docs/` for architecture and runbooks.

Container image folders and replacement steps are documented in `docs/images.md`.
 
## Quickstart (end-to-end)

Prerequisites:
- `terraform` >= 1.0
- `aws` CLI configured with credentials
- `kubectl`
- `helm`
- `kind` (optional local dev cluster)
- `kubectl` configured for the target cluster
- GitHub repository with GitHub Actions and a Personal Access Token with `write:packages` (for GHCR) saved as `CR_PAT` in repository secrets

High-level steps:

1) Provision infrastructure (dev example):

```bash
cd infra/terraform
chmod +x backend-bootstrap.sh
./backend-bootstrap.sh
terraform init
terraform apply -var-file=env.dev.tfvars
```

After apply you'll get outputs for the EKS cluster endpoint and CA — configure `kubectl`:

```bash
aws eks update-kubeconfig --name $(terraform output -raw cluster_name) --region us-east-1
```

2) Install ArgoCD on the control cluster (single control-plane):

```bash
kubectl create namespace argocd || true
kubectl apply -n argocd -f k8s/argocd/install-argocd.yaml
```

3) Register remote clusters (example docs are in `docs/deployment.md`).

4) Install SealedSecrets (for GitOps secrets):

```bash
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.21.4/controller.yaml
```

5) Push application images via CI (GitHub Actions will build, scan and push to GHCR). Ensure `CR_PAT` secret is set.

6) Create ArgoCD Application manifests in `k8s/apps/` and commit — ArgoCD will sync to target clusters.

7) Install monitoring (Prometheus/Grafana/Loki/Tempo) using the `monitoring/` Helm charts or upstream charts documented in `docs/monitoring.md`.

8) Backups: Install Velero following `docs/backups.md` and configure S3 bucket for backups.

Runbook and troubleshooting: see `docs/runbooks.md`.

If you want, I can now: (a) enable GHCR push in CI workflow, (b) add ArgoCD install manifests, (c) add samples for ArgoCD Application manifests, or (d) add SealedSecrets examples. Pick one or more.

