# Deployment and GitOps

This document shows how to deploy applications using GitOps with ArgoCD.

## Environments

Terraform variable files define the target environment:

```bash
terraform apply -var-file=env.dev.tfvars
terraform apply -var-file=env.staging.tfvars
terraform apply -var-file=env.prod.tfvars
```

Each environment should use a unique `cluster_name`. Production should use larger node groups and, when required, a region that is closest to users.

## GitOps Flow

1. Provision or select the target Kubernetes cluster.
2. Install ArgoCD on the control cluster.
3. Register remote target clusters with ArgoCD when using a central control-plane model.
4. Create or update ArgoCD `Application` manifests in `k8s/apps/`.
5. Commit and push changes.
6. ArgoCD detects the Git revision and syncs the Helm charts from `k8s/helm`.

## Register Remote Clusters

On the target cluster, create a service account and cluster role binding for ArgoCD to access the cluster. Then use the `argocd` CLI to add the cluster to the control ArgoCD instance.

```bash
argocd login <ARGOCD_SERVER>
argocd cluster add <context-name-for-remote-cluster>
```

See the ArgoCD docs for full multi-cluster setup.

## Fresh Cluster Checklist

After rebuilding a cluster, recreate required runtime dependencies before syncing workloads:

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

Create the GHCR pull secret in each target namespace that pulls private or restricted images:

```bash
kubectl create secret docker-registry ghcr-pull-secret \
  --docker-server=ghcr.io \
  --docker-username=<github-username> \
  --docker-password=<github-token> \
  --docker-email=<email>

kubectl patch serviceaccount default \
  -p '{"imagePullSecrets":[{"name":"ghcr-pull-secret"}]}'
```

Apply the application manifests:

```bash
kubectl apply -f k8s/apps/db-app.yaml
kubectl apply -f k8s/apps/backend-app.yaml
kubectl apply -f k8s/apps/frontend-app.yaml
```
