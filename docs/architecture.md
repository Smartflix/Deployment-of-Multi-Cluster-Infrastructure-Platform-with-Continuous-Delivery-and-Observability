# Architecture Overview

This document describes the multi-cluster GitOps architecture for CloudOpsHub.

## Platform Goal

CloudOpsHub modernizes operations with an infrastructure platform that supports automated provisioning, repeatable application delivery, and multi-environment pipelines across Kubernetes clusters in different locations.

The target operating model is:

- `dev`: fast validation and integration testing.
- `staging`: production-like release validation.
- `prod`: highly available user-facing workloads.

## Components

- Terraform: provisions AWS networking, EKS clusters, node groups, and environment-specific infrastructure from `infra/terraform`.
- Environment variable files: `env.dev.tfvars`, `env.staging.tfvars`, and `env.prod.tfvars` define cluster names, sizes, and regions.
- ArgoCD: installed on a control cluster and used to reconcile application manifests into target clusters.
- GitHub Actions: builds frontend, backend, and db images, scans them with Trivy, and publishes versioned images to GHCR.
- Helm charts: package frontend, backend, and db workloads with reusable Kubernetes manifests.
- GHCR pull secret: allows clusters to pull CloudOpsHub images from GitHub Container Registry.
- Observability: Prometheus, Grafana, Loki, and Tempo provide centralized metrics, logs, and traces.
- Backups: Velero and database backup procedures protect Kubernetes and application state.

## Multi-Cluster Delivery

ArgoCD can run in a central control cluster and deploy to one or more registered target clusters. Each target cluster represents an environment or location, such as:

- `cloudopshub-dev`
- `cloudopshub-staging`
- `cloudopshub-prod`

Application definitions live in `k8s/apps`, while the deployable Helm charts live in `k8s/helm`. This keeps runtime state reproducible from Git.

## Availability And Localized Access

For production, the platform uses one regional EKS cluster spread across two availability zones. Terraform creates two public subnets in separate AZs, and `env.prod.tfvars` requests four worker nodes with a minimum of two nodes so workloads can keep running when one AZ is impaired.

The frontend and backend Helm charts run two replicas and include topology spread constraints using `topology.kubernetes.io/zone`, so Kubernetes tries to place replicas across zones.

If the business requires resilience against an entire AWS region outage, deploy separate production clusters in separate regions and use DNS or global traffic management for failover.

The bundled db chart is suitable for demos and integration testing. Production database HA should use a managed multi-AZ database such as Amazon RDS/Aurora or a production-grade Postgres operator with replication, backups, and failover.
