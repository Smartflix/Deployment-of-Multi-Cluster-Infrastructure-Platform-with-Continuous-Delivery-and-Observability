# Monitoring

Recommended stack:
- Prometheus for metrics (kube-prometheus-stack Helm chart)
- Grafana for dashboards
- Loki for logs
- Tempo for tracing

Install example (Helm):

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
helm install kube-prom stack prometheus-community/kube-prometheus-stack --namespace monitoring --create-namespace
```

For logs and tracing, install Loki and Tempo from Grafana Helm charts and configure datasource in Grafana.
