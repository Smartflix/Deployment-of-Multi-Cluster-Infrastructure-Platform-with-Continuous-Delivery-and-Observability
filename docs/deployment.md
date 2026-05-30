# Deployment and GitOps

This document shows how to deploy applications using GitOps with ArgoCD.

1. Ensure ArgoCD is installed on the control cluster (see README quickstart).
2. Create an ArgoCD `Application` manifest in `k8s/apps/` pointing at the Helm chart or kustomize path in this repo.
3. Commit and push — ArgoCD will detect and sync the app to the target cluster.

Registering remote clusters with ArgoCD (control cluster approach):

- On the target cluster (remote), create a service account and clusterrolebinding for ArgoCD to access the cluster. Then use `argocd` CLI to add the cluster to the control ArgoCD instance. Example steps:

```bash
# on control cluster (argocd server pod must be reachable)
# install argocd CLI: https://argo-cd.readthedocs.io/en/stable/cli_installation/
argocd login <ARGOCD_SERVER>
argocd cluster add <context-name-for-remote-cluster>
```

See ArgoCD docs for full multi-cluster setup.
