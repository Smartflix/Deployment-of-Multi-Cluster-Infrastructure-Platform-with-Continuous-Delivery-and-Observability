# Runbooks

## Deploy (staging)
- Push to `staging` branch or open PR to trigger CI.
- CI builds image and pushes to registry.
- ArgoCD syncs staging manifests to staging cluster.

## Rollback
- Use ArgoCD UI to roll back to previous application revision.
- Restore DB from latest Velero/DB backup if needed.

## Monitoring
- Check Grafana dashboards for system health.
- Check Loki for logs, Tempo for traces.

