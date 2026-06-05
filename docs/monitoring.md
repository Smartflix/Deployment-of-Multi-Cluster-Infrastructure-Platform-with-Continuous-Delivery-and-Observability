# Monitoring

CloudOpsHub uses `kube-prometheus-stack` for the first production monitoring layer:

- Prometheus for Kubernetes and application metrics.
- Grafana for dashboards.
- Alertmanager for alert routing.
- kube-state-metrics and node exporter for cluster visibility.

## Install

```bash
export GRAFANA_ADMIN_PASSWORD='<strong-password>'
chmod +x scripts/install-monitoring.sh
./scripts/install-monitoring.sh
```

Open Grafana locally:

```bash
kubectl port-forward svc/cloudopshub-monitoring-grafana 3000:80 -n monitoring
```

Login:

```text
username: admin
password: value of GRAFANA_ADMIN_PASSWORD
```

## Application Metrics

The backend exposes Prometheus metrics at:

```text
/metrics
```

The backend Helm chart can create a `ServiceMonitor` when `serviceMonitor.enabled=true`. The production ArgoCD backend app enables this so Prometheus can scrape:

```text
cloudopshub_backend_info
cloudopshub_database_reachable
cloudopshub_http_requests_total
```

## Verify

```bash
kubectl get pods,svc -n monitoring
kubectl get servicemonitor -A | grep backend
kubectl port-forward svc/backend 38091:8080 -n cloudopshub
curl http://localhost:38091/metrics
```

Grafana includes the `CloudOpsHub Application` dashboard from `monitoring/cloudopshub-dashboard.yaml`.

For logs and tracing, install Loki and Tempo from Grafana Helm charts after metrics are stable.
