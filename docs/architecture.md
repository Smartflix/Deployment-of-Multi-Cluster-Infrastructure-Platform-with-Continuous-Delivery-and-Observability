# Architecture Overview

This document describes the multi-cluster GitOps architecture for CloudOpsHub.

Components:
- Terraform: provision AWS VPC, EKS cluster (prod/staging) and networking.
- Local dev cluster: `kind` (recommended).
- Ansible: post-provision configuration and hardening.
- ArgoCD: installed on a single control cluster to manage all target clusters.
- CI: GitHub Actions building images, running tests, scanning with Trivy, publishing to GHCR/Docker.
- Helm charts: package frontend/backend/db components.
- Observability: Prometheus, Grafana, Loki, Tempo centralized.
- Backups: Velero for k8s backups and DB dump strategy.
