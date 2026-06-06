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
kubectl get prometheusrule -n monitoring | grep cloudopshub
kubectl port-forward svc/backend 38091:8080 -n cloudopshub
curl http://localhost:38091/metrics
```

Grafana includes the `CloudOpsHub Application` dashboard from `monitoring/cloudopshub-dashboard.yaml`.

## Alerts

CloudOpsHub alert rules are installed from `monitoring/cloudopshub-alerts.yaml`:

- `CloudOpsHubBackendDown`
- `CloudOpsHubRDSUnreachable`
- `CloudOpsHubPodCrashLooping`
- `CloudOpsHubDeploymentReplicasUnavailable`

Check alert rules:

```bash
kubectl get prometheusrule cloudopshub-alerts -n monitoring -o yaml
```

## Alert Routing

Alertmanager routing is configured with `monitoring/cloudopshub-alert-routing.yaml`. The Slack webhook URL is stored in a Kubernetes Secret and is not committed to Git.

Create a Slack incoming webhook, then configure routing:

```bash
export SLACK_WEBHOOK_URL='https://hooks.slack.com/services/...'
chmod +x scripts/configure-alert-routing.sh
./scripts/configure-alert-routing.sh
```

Fire a temporary test alert:

```bash
chmod +x scripts/test-alert-routing.sh
./scripts/test-alert-routing.sh
```

After the Slack notification arrives, remove the test alert:

```bash
kubectl delete -f monitoring/cloudopshub-test-alert.yaml
```

## Logs With Loki

Install Loki and Grafana Alloy for Kubernetes pod logs:

```bash
chmod +x scripts/install-loki.sh
./scripts/install-loki.sh
```

Grafana is configured with a Loki datasource from `monitoring/kube-prometheus-values.yaml`:

```text
URL: http://loki-gateway.monitoring.svc.cluster.local
```

Query CloudOpsHub logs:

```logql
{namespace="cloudopshub"}
```

For tracing, install Tempo after metrics and logs are stable.
