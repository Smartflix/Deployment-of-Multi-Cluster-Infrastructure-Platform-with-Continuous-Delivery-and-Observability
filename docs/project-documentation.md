# CloudOpsHub Project Documentation

This document explains the CloudOpsHub project in full: what was built, how it works, how it is deployed, how it is monitored, and the main blockers that came up during the build. It is written as a practical project record, so another engineer can understand the journey and operate the platform without needing to replay every terminal session.

## Project Summary

CloudOpsHub is a cloud infrastructure and application delivery platform built around Kubernetes, GitOps, CI/CD, observability, and backup validation.

The final production application is available at:

```text
https://app.devopslegend.click
```

The application is deployed to an Amazon EKS production cluster in `us-east-1`. The cluster runs across two availability zones, uses ArgoCD for GitOps deployment, uses Docker Hub for application images, uses Amazon RDS PostgreSQL Multi-AZ for the database, and exposes the frontend through an AWS Application Load Balancer with HTTPS.

The project also includes monitoring with Prometheus and Grafana, log collection with Loki and Grafana Alloy, alert routing to Slack through Alertmanager, and backup validation with RDS snapshots and Velero.

## Main Goal

The goal was to create a real production-style DevOps platform, not only a demo app. The project had to prove these things:

- The frontend, backend, and database are connected.
- The application can run locally during development.
- The application can be containerized and pushed to Docker Hub.
- Kubernetes can run the workloads locally and in AWS.
- ArgoCD can keep production in sync with Git.
- GitHub Actions can build, scan, push, and update deployment tags.
- Production workloads can run across multiple availability zones.
- The database can be moved from an in-cluster Postgres pod to RDS PostgreSQL Multi-AZ.
- The frontend can be exposed through an ALB with a custom HTTPS domain.
- Metrics, logs, dashboards, and alerts can show the health of the platform.
- Backups can be created and restore validation can be performed.

## Repository Layout

```text
apps/
  backend/                 Backend API and metrics service
  frontend/                Frontend dashboard served by Nginx
  db/                      Local/demo PostgreSQL image assets

infra/terraform/           AWS infrastructure, EKS, networking, and RDS

k8s/apps/                  ArgoCD Application manifests
k8s/helm/                  Helm charts for frontend, backend, and db

monitoring/                Prometheus, Grafana, Loki, alerts, and routing config

scripts/                   Helper scripts for deployment, HTTPS, monitoring, backups, and alerts

.github/workflows/         GitHub Actions CI/CD workflow

docs/                      Architecture, deployment, monitoring, backup, and project documentation
```

## Application Design

The application has three main parts.

The frontend is an Nginx-served dashboard. It displays the platform status and calls backend API endpoints so it is clear that the frontend and backend are linked. Nginx also proxies `/api` traffic to the backend service, which keeps the browser experience simple.

The backend is a Python service. It exposes application endpoints such as:

```text
/api/summary
/api/clusters
/api/pipelines
/api/incidents
/api/database
/metrics
```

The database started as a local and in-cluster PostgreSQL container for development and testing. Production was later switched to Amazon RDS PostgreSQL Multi-AZ, which is the correct production direction because it gives managed backups, failover, and better operational reliability than a single Postgres pod.

## Local Development

For local development, the project uses Docker Compose. The local compose file runs the frontend, backend, and PostgreSQL together.

Important local backend environment values are:

```text
DB_HOST=db
DB_PORT=5432
DB_NAME=cloudopshub
DB_USER=cloudopshub
DB_PASSWORD=change-me
```

The local app can be started with:

```bash
docker compose up --build
```

Frontend:

```text
http://localhost:18090
```

Backend:

```text
http://localhost:18091/api/summary
```

The local environment is useful because it proves the application works before it is pushed into Kubernetes.

## Container Images

The project images are stored in Docker Hub under:

```text
docker.io/fabulousjeff2009
```

Main images:

```text
docker.io/fabulousjeff2009/cloudopshub-frontend
docker.io/fabulousjeff2009/cloudopshub-backend
docker.io/fabulousjeff2009/cloudopshub-db
```

During the project, images were first built manually and pushed to Docker Hub. Later, GitHub Actions took over the repeatable build and push process.

The production deployment eventually used immutable Git SHA image tags. One verified deployed tag was:

```text
759e34ddb88b085b65db1c0d06d571b34198435f
```

Using SHA tags is better than relying only on `latest`, because it lets ArgoCD and Kubernetes deploy a specific build and makes rollbacks easier to understand.

## Kubernetes And GitOps

The project was first tested with a local kind cluster. That gave a safe place to confirm Kubernetes manifests before moving to EKS.

Production uses Amazon EKS. ArgoCD manages the application deployment from Git. The ArgoCD application manifests live in:

```text
k8s/apps/frontend-app.yaml
k8s/apps/backend-app.yaml
k8s/apps/db-app.yaml
```

The Helm charts live in:

```text
k8s/helm/frontend
k8s/helm/backend
k8s/helm/db
```

For production, the frontend and backend are active. The db chart is kept for local/demo use, but production uses RDS instead of the in-cluster db application.

The production ArgoCD apps track the active branch:

```text
fix-push
```

That means changes pushed to that branch can be reconciled by ArgoCD into the production cluster.

## Production AWS Architecture

The production environment runs in AWS `us-east-1`.

The EKS cluster is:

```text
cloudopshub-prod
```

The production namespace is:

```text
cloudopshub
```

The cluster was verified with four worker nodes across two availability zones:

```text
us-east-1a: 2 nodes
us-east-1b: 2 nodes
```

This gives the app a real multi-AZ foundation. The frontend and backend run with multiple replicas, and Kubernetes can place them across zones.

## Database: RDS PostgreSQL Multi-AZ

The database was switched from a Kubernetes Postgres pod to Amazon RDS PostgreSQL Multi-AZ.

The backend reads RDS connection details from a Kubernetes secret:

```text
cloudopshub-rds-secret
```

The backend `/api/database` endpoint confirmed production database reachability:

```json
{
  "database": {
    "type": "RDS PostgreSQL Multi-AZ",
    "status": "reachable",
    "host": "cloudopshub-prod-postgres.c8ri4iccgqvm.us-east-1.rds.amazonaws.com",
    "port": 5432,
    "database": "cloudopshub",
    "user": "cloudopshub"
  }
}
```

This was an important project milestone because it proved the app was no longer depending on a temporary in-cluster database for production.

## ALB, Domain, And HTTPS

The frontend is exposed through AWS Load Balancer Controller and an AWS Application Load Balancer.

The public production URL is:

```text
https://app.devopslegend.click
```

The domain is hosted in Route 53:

```text
devopslegend.click
```

The HTTPS setup uses:

- AWS ACM certificate in `us-east-1`.
- Route 53 DNS validation.
- Route 53 alias record pointing `app.devopslegend.click` to the ALB.
- ALB Ingress annotations for HTTP, HTTPS, certificate ARN, and SSL redirect.

The final verification showed HTTP redirecting to HTTPS and HTTPS returning a successful response:

```text
HTTP/1.1 301 Moved Permanently
Location: https://app.devopslegend.click:443/

HTTP/2 200
```

## CI/CD With GitHub Actions

GitHub Actions is used for CI/CD.

The workflow lives at:

```text
.github/workflows/ci.yml
```

The workflow does the following:

1. Runs on pushes and manual workflow dispatch.
2. Builds frontend, backend, and db container images.
3. Pushes images to Docker Hub.
4. Runs Trivy image scanning.
5. Updates the ArgoCD image tags in the GitOps manifests to the Git commit SHA.
6. Commits those tag updates back to the repository.
7. ArgoCD detects the new Git state and syncs the cluster.

Required GitHub secrets:

```text
DOCKERHUB_USERNAME
DOCKERHUB_TOKEN
```

GitHub workflow permissions must allow the workflow to write back to the repository, because the workflow updates image tags in Git.

This completed the GitOps loop: code change, image build, Docker Hub push, Git tag update, ArgoCD sync, and Kubernetes rollout.

## Monitoring And Dashboards

Monitoring uses kube-prometheus-stack:

- Prometheus collects metrics.
- Grafana displays dashboards.
- Alertmanager handles alert routing.
- kube-state-metrics and node exporter provide Kubernetes and node visibility.

The backend exposes Prometheus metrics at:

```text
/metrics
```

Important CloudOpsHub metrics:

```text
cloudopshub_backend_info
cloudopshub_database_reachable
cloudopshub_http_requests_total
```

The main dashboard is:

```text
CloudOpsHub Application
```

The dashboard shows backend scrape health, RDS reachability, application request information, and Loki log panels.

## Logs With Loki

Logs are collected with Loki and Grafana Alloy.

The setup files are:

```text
monitoring/loki-values.yaml
monitoring/alloy-logs-values.yaml
scripts/install-loki.sh
```

The Grafana Loki datasource points to:

```text
http://loki-gateway.monitoring.svc.cluster.local
```

Useful LogQL query:

```logql
{namespace="cloudopshub"}
```

The user verified Loki by querying logs and seeing ALB health check traffic from the frontend pods.

## Alerting And Slack Routing

CloudOpsHub alert rules are defined in:

```text
monitoring/cloudopshub-alerts.yaml
```

Alert routing is defined in:

```text
monitoring/cloudopshub-alert-routing.yaml
```

The routing script stores the Slack webhook in a Kubernetes secret:

```text
scripts/configure-alert-routing.sh
```

The test alert script creates a temporary alert so Slack routing can be proven:

```text
scripts/test-alert-routing.sh
```

After testing, the temporary test alert should be removed:

```bash
kubectl delete -f monitoring/cloudopshub-test-alert.yaml --ignore-not-found
```

This project tested both the direct Slack webhook and the Alertmanager route. The direct Slack test message arrived, and the Prometheus/Alertmanager test alert appeared as `CloudOpsHubTestAlert`.

## Backups And Restore Validation

The backup design has two layers:

- RDS snapshots for the production PostgreSQL database.
- Velero backups for Kubernetes resources.

RDS snapshot script:

```text
scripts/create-rds-snapshot.sh
```

Velero scripts:

```text
scripts/install-velero-aws.sh
scripts/create-velero-backup.sh
scripts/validate-velero-restore.sh
```

The Velero restore validation restores resources into:

```text
cloudopshub-restore-test
```

The restore test proved that backend and frontend workloads could be restored and rolled out successfully:

```text
deployment/backend  2/2 available
deployment/frontend 2/2 available
```

The restore test intentionally avoids overwriting production.

## Security Notes

Do not commit local credential files.

The project `.gitignore` protects files such as:

```text
credentials-velero
velero-policy.json
.terraform/
__pycache__/
```

Slack webhook URLs should be treated as secrets. If a webhook is pasted into a terminal, chat, or documentation, rotate it in Slack and update the Kubernetes secret.

Docker Hub access should use a token, not a normal account password.

Production database credentials should stay in Kubernetes secrets or a stronger secret management system such as External Secrets, AWS Secrets Manager, or Sealed Secrets.

## Engineering Decision Process And Code Used

This section records the practical decision process used during the project. It does not include private internal reasoning, but it does document the visible engineering rationale: what problem was being solved, why the change was made, what code or command was used, and how the result was verified.

### 1. Make The Frontend Prove It Is Connected To The Backend

The frontend originally looked too plain and did not clearly prove that it was connected to the backend. The decision was to make the frontend call backend API endpoints and show live platform data. That way, the page is not just static HTML; it proves the application chain is working.

The frontend Nginx config was updated so browser calls to `/api` are sent to the backend service:

```nginx
server {
    listen 80;
    server_name _;

    root /usr/share/nginx/html;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }

    location /api/ {
        proxy_pass http://backend:8080/api/;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location = /healthz {
        proxy_pass http://backend:8080/healthz;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
    }
}
```

The result is a clear application path:

```text
Browser -> Frontend Nginx -> Backend API -> Database
```

### 2. Add Local Database Environment Variables

The local Docker Compose setup needed to show the same kind of backend/database connection as production. The backend service was given database environment variables that point to the local `db` service.

The important part of `docker-compose.yml` is:

```yaml
backend:
  build:
    context: ./apps/backend
  image: docker.io/fabulousjeff2009/cloudopshub-backend:local
  environment:
    PORT: "8080"
    DB_HOST: db
    DB_PORT: "5432"
    DB_NAME: cloudopshub
    DB_USER: cloudopshub
    DB_PASSWORD: change-me
  ports:
    - "18091:8080"
  depends_on:
    db:
      condition: service_healthy
```

This was verified locally with:

```bash
docker compose up --build
curl http://localhost:18091/api/database
```

### 3. Add Backend Database Status And Metrics

The backend needed to expose both a human API endpoint and Prometheus metrics. The decision was to add `/api/database` for the application page and `/metrics` for Prometheus.

The backend route includes:

```python
ROUTES = {
    "/": platform_summary,
    "/healthz": platform_summary,
    "/api/summary": platform_summary,
    "/api/clusters": lambda: {"clusters": CLUSTERS, "generatedAt": now_iso()},
    "/api/pipelines": lambda: {"pipelines": PIPELINES, "generatedAt": now_iso()},
    "/api/incidents": lambda: {"incidents": INCIDENTS, "generatedAt": now_iso()},
    "/api/database": lambda: {"database": database_summary(), "generatedAt": now_iso()},
}
```

The Prometheus metric that proves database reachability is:

```python
f'cloudopshub_database_reachable{{type="{database["type"]}"}} {1 if database["status"] == "reachable" else 0}'
```

The result was verified with:

```bash
curl http://localhost:<backend-port>/api/database
curl http://localhost:<backend-port>/metrics
```

### 4. Build And Push Images Manually Before CI

Before GitHub Actions took over, the images were built and pushed manually to prove Docker Hub access worked.

Example backend commands:

```bash
docker login -u fabulousjeff2009
docker build -t docker.io/fabulousjeff2009/cloudopshub-backend:rds-v1 apps/backend
docker push docker.io/fabulousjeff2009/cloudopshub-backend:rds-v1
```

Later, when the backend metrics were added, a newer backend image was pushed:

```bash
docker build -t docker.io/fabulousjeff2009/cloudopshub-backend:rds-v2 apps/backend
docker push docker.io/fabulousjeff2009/cloudopshub-backend:rds-v2
```

The important lesson was that Kubernetes can only roll out a tag that already exists in the registry.

### 5. Use ArgoCD To Deploy Helm Charts

The project uses ArgoCD Application manifests to point to the Helm charts. The backend app enables the database configuration and ServiceMonitor.

Backend ArgoCD application values:

```yaml
helm:
  parameters:
    - name: image.tag
      value: 759e34ddb88b085b65db1c0d06d571b34198435f
    - name: database.enabled
      value: "true"
    - name: serviceMonitor.enabled
      value: "true"
```

Frontend ArgoCD application values:

```yaml
helm:
  parameters:
    - name: image.tag
      value: 759e34ddb88b085b65db1c0d06d571b34198435f
    - name: ingress.enabled
      value: "true"
    - name: ingress.tls.enabled
      value: "true"
    - name: ingress.tls.certificateArn
      value: arn:aws:acm:us-east-1:867041163440:certificate/dbf536a5-99ec-4ef2-89df-a70124e318c3
    - name: ingress.tls.sslRedirect
      value: "true"
```

The result was verified with:

```bash
kubectl get applications -n argocd
kubectl get pods,svc -n cloudopshub
kubectl get deployment frontend -n cloudopshub -o jsonpath='{.spec.template.spec.containers[0].image}'; echo
kubectl get deployment backend -n cloudopshub -o jsonpath='{.spec.template.spec.containers[0].image}'; echo
```

### 6. Switch Production From In-Cluster Postgres To RDS

The production database was moved to Amazon RDS PostgreSQL Multi-AZ because a single in-cluster Postgres pod is not production-grade for this use case.

The backend production secret was created with RDS connection details:

```bash
kubectl create secret generic cloudopshub-rds-secret \
  --from-literal=DB_HOST=<rds-endpoint> \
  --from-literal=DB_PORT=5432 \
  --from-literal=DB_NAME=cloudopshub \
  --from-literal=DB_USER=cloudopshub \
  --from-literal=DB_PASSWORD=<password> \
  -n cloudopshub \
  --dry-run=client -o yaml | kubectl apply -f -
```

The app was verified with:

```bash
curl http://localhost:<backend-port>/api/database
```

Expected result:

```text
type: RDS PostgreSQL Multi-AZ
status: reachable
```

### 7. Add HTTPS To The ALB Ingress

The frontend Helm Ingress template was updated to support both HTTP-only and HTTPS modes. The important template logic is:

```yaml
annotations:
  {{- if .Values.ingress.tls.enabled }}
  alb.ingress.kubernetes.io/certificate-arn: {{ .Values.ingress.tls.certificateArn | quote }}
  alb.ingress.kubernetes.io/listen-ports: '[{"HTTP":80},{"HTTPS":443}]'
  {{- if .Values.ingress.tls.sslRedirect }}
  alb.ingress.kubernetes.io/ssl-redirect: "443"
  {{- end }}
  {{- else }}
  alb.ingress.kubernetes.io/listen-ports: '[{"HTTP":80}]'
  {{- end }}
```

The Route 53 alias script was then used to point the domain to the ALB:

```bash
export ROOT_DOMAIN=devopslegend.click
export FRONTEND_HOST=app.devopslegend.click
./scripts/create-route53-alb-alias.sh
```

The final HTTPS checks were:

```bash
curl -I http://app.devopslegend.click
curl -I https://app.devopslegend.click
```

The expected behavior was HTTP `301` redirecting to HTTPS and HTTPS returning `200`.

### 8. Add GitHub Actions CI/CD

GitHub Actions was added so image builds and GitOps tag updates happen automatically.

The build matrix includes frontend, backend, and db:

```yaml
strategy:
  fail-fast: false
  matrix:
    app:
      - name: frontend
        context: apps/frontend
        image: cloudopshub-frontend
      - name: backend
        context: apps/backend
        image: cloudopshub-backend
      - name: db
        context: apps/db
        image: cloudopshub-db
```

The workflow pushes both `latest` and the Git SHA:

```yaml
tags: |
  ${{ env.REGISTRY }}/${{ env.IMAGE_NAMESPACE }}/${{ matrix.app.image }}:latest
  ${{ env.REGISTRY }}/${{ env.IMAGE_NAMESPACE }}/${{ matrix.app.image }}:${{ github.sha }}
```

The workflow then updates ArgoCD app manifests:

```python
image_tag = os.environ["IMAGE_TAG"]
files = [
    Path("k8s/apps/backend-app.yaml"),
    Path("k8s/apps/frontend-app.yaml"),
]

for path in files:
    lines = path.read_text().splitlines()
    for index, line in enumerate(lines):
        if line.strip() == "- name: image.tag":
            lines[index + 1] = f"          value: {image_tag}"
            break
    else:
        raise SystemExit(f"image.tag parameter not found in {path}")
    path.write_text("\n".join(lines) + "\n")
```

This made GitHub Actions part of the GitOps loop instead of a separate deployment system.

### 9. Add Monitoring, Logs, And Alerts

Prometheus was used for metrics, Grafana for dashboards, Loki for logs, and Alertmanager for routing.

The Slack routing configuration uses an AlertmanagerConfig:

```yaml
apiVersion: monitoring.coreos.com/v1alpha1
kind: AlertmanagerConfig
metadata:
  name: cloudopshub-alert-routing
  namespace: monitoring
spec:
  route:
    groupBy:
      - namespace
      - alertname
      - severity
    groupWait: 30s
    groupInterval: 5m
    repeatInterval: 4h
    receiver: cloudopshub-slack
  receivers:
    - name: cloudopshub-slack
      slackConfigs:
        - apiURL:
            name: cloudopshub-alert-routing
            key: slack-webhook-url
          sendResolved: true
```

The Slack webhook is not committed. It is placed into a Kubernetes secret by:

```bash
export SLACK_WEBHOOK_URL='https://hooks.slack.com/services/...'
./scripts/configure-alert-routing.sh
```

The direct Slack test was:

```bash
curl -sS -X POST -H 'Content-type: application/json' \
  --data '{"text":"CloudOpsHub direct Slack webhook test"}' \
  "$SLACK_WEBHOOK_URL"
```

The temporary Alertmanager test was:

```bash
./scripts/test-alert-routing.sh
```

After validation, the test alert should be deleted:

```bash
kubectl delete -f monitoring/cloudopshub-test-alert.yaml --ignore-not-found
```

### 10. Add Backup And Restore Validation

The database backup path uses RDS snapshots. The script waits for the DB to be available before creating the snapshot:

```bash
aws rds wait db-instance-available \
  --region "${AWS_REGION}" \
  --db-instance-identifier "${DB_INSTANCE_ID}"

aws rds create-db-snapshot \
  --region "${AWS_REGION}" \
  --db-instance-identifier "${DB_INSTANCE_ID}" \
  --db-snapshot-identifier "${SNAPSHOT_ID}"
```

Kubernetes resources are backed up with Velero:

```bash
./scripts/install-velero-aws.sh
./scripts/create-velero-backup.sh
```

Restore validation is done in a separate namespace so production is not overwritten:

```bash
export BACKUP_NAME=<backup-name>
./scripts/validate-velero-restore.sh
kubectl get all -n cloudopshub-restore-test
```

The restore validation proved that frontend and backend deployments could come back in a separate namespace.

### 11. Commands Used Most Often During Troubleshooting

These commands were used repeatedly to understand what was happening:

```bash
kubectl get pods,svc -n cloudopshub
kubectl describe pod <pod-name> -n cloudopshub
kubectl logs deploy/backend -n cloudopshub
kubectl rollout status deployment/backend -n cloudopshub
kubectl rollout restart deployment/backend -n cloudopshub
kubectl rollout undo deployment/backend -n cloudopshub
kubectl get applications -n argocd
kubectl describe application frontend -n argocd
kubectl get ingress -n cloudopshub
kubectl describe ingress frontend -n cloudopshub
kubectl get nodes -L topology.kubernetes.io/zone
```

For AWS:

```bash
aws eks list-clusters --region us-east-1
aws eks update-kubeconfig --name cloudopshub-prod --region us-east-1
aws rds describe-db-instances --region us-east-1 --db-instance-identifier cloudopshub-prod-postgres
aws acm describe-certificate --region us-east-1 --certificate-arn <certificate-arn>
aws route53 list-hosted-zones-by-name --dns-name devopslegend.click
```

For validation:

```bash
curl -I https://app.devopslegend.click
curl http://localhost:<backend-port>/api/database
curl http://localhost:<backend-port>/metrics
dig app.devopslegend.click A
```

## Blockers And How They Were Resolved

### Docker Compose command failed

The first local blocker happened when `docker compose up --build` returned:

```text
unknown flag: --build
```

This meant the local Docker Compose setup was not using the modern Compose v2 plugin. Trying the older Python-based `docker-compose` also caused a runtime error:

```text
KeyError: 'id'
```

The fix was to move to Docker Compose v2 and use the modern command:

```bash
docker compose up --build
```

After this, the local frontend, backend, and database could run together.

### Docker Hub push was denied

Docker image builds worked, but pushing to Docker Hub initially returned:

```text
denied: requested access to the resource is denied
```

The issue was Docker Hub authentication. The fix was to log in with the correct Docker Hub username and a valid password or token:

```bash
docker login -u fabulousjeff2009
```

After login succeeded, images could be pushed.

### Kubernetes namespace was missing

During local Kubernetes deployment, the script failed because the namespace did not exist:

```text
namespaces "cloudopshub" not found
```

The fix was to create the namespace before applying workloads:

```bash
kubectl create namespace cloudopshub --dry-run=client -o yaml | kubectl apply -f -
```

The deploy script was adjusted so the namespace creation step is part of the normal flow.

### Kind cluster and Docker Desktop Kubernetes confusion

Docker Desktop Kubernetes was disabled, so a local Kubernetes target was needed. The project used kind instead of relying on Docker Desktop Kubernetes.

The kind cluster became the local test cluster, and the EKS cluster became the production target.

### Database secret missing

The db pod initially failed because Kubernetes could not find the expected secret:

```text
secret "cloudopshub-db-secret" not found
```

The fix was to create the secret in the `cloudopshub` namespace before syncing or starting the db workload.

Later, production was changed to use RDS and the backend used `cloudopshub-rds-secret` instead.

### ArgoCD UI looked stale

At one point, the terminal showed that the `db` ArgoCD Application no longer existed, but the ArgoCD UI still appeared to show it.

The likely reason was stale UI state or cached application data. The practical fix was to trust the terminal output, refresh the ArgoCD application view, log out and back in, or restart the ArgoCD server if needed.

The project moved forward once the actual Kubernetes and ArgoCD API state was confirmed from the terminal.

### ArgoCD login password problems

ArgoCD login failed several times because the password being used was not the current admin password. Hashes from Kubernetes secrets were also confused with the plain password.

The important lesson is that ArgoCD stores password hashes in Kubernetes, and those hashes are not the login password. If login is lost, reset the admin password through the supported ArgoCD secret flow, then restart the ArgoCD server.

The project continued after ArgoCD CLI and Kubernetes state could still be managed.

### Backend still showed old API behavior

The backend returned:

```json
{
  "error": "not_found",
  "path": "/api/database"
}
```

The route existed in the source code, but the cluster was still running an old backend image. The fix was to rebuild and push the backend image, then update Kubernetes or ArgoCD to use the new tag.

Once the correct image was deployed, `/api/database` returned the RDS status successfully.

### Backend rollout failed because the image tag did not exist

When the backend was updated to:

```text
docker.io/fabulousjeff2009/cloudopshub-backend:rds-v2
```

Kubernetes failed with:

```text
docker.io/fabulousjeff2009/cloudopshub-backend:rds-v2: not found
```

The problem was simple but important: the deployment referenced a tag that had not been pushed yet. The fix was to push the image tag to Docker Hub, then restart or resync the deployment.

After the image existed in Docker Hub, the rollout completed.

### Terraform output for RDS was missing

The project tried to read:

```text
rds_address
```

Terraform returned:

```text
Output "rds_address" not found
```

The output had been added to the Terraform code but not yet applied to the Terraform state. The fix was to run `terraform apply` after adding the output, so the state file included the new output values.

### RDS snapshot failed because DB was not available

The first RDS snapshot attempt failed with:

```text
InvalidDBInstanceState
```

The RDS instance was still in a state where snapshots could not be created. The fix was to wait until the instance status was:

```text
available
```

The snapshot script was improved to wait for the database to become available before creating a snapshot.

### AWS Load Balancer Controller failed to start

The AWS Load Balancer Controller initially crashed with:

```text
failed to get VPC ID from instance metadata
```

The controller could not discover the VPC automatically from instance metadata. The fix was to install or upgrade the controller with explicit `region` and `vpcId` values.

After this, the controller could create and manage the frontend ALB.

### ALB HTTPS initially failed

The first HTTPS test returned:

```text
curl: (35) SSL routines::unexpected eof while reading
```

This happened while the ALB/Ingress was not fully configured for HTTPS. The fix was to add the ACM certificate ARN and HTTPS listener annotations through the frontend Helm chart and ArgoCD application values.

### ACM validation script crashed

The ACM validation helper script crashed with:

```text
AttributeError: 'NoneType' object has no attribute 'get'
```

The ACM certificate validation record was not immediately available when the script tried to read it. The fix was to make the script wait and handle missing validation record data until ACM returned it.

### Ingress patch failed after trying to set the host

ArgoCD failed to patch the frontend Ingress with:

```text
Ingress.networking.k8s.io "frontend" is invalid: spec.rules[0].http.paths: Required value
```

The issue was caused by using a Helm parameter like:

```text
ingress.hosts[0].host
```

That overwrote part of the list item and removed the required path structure. The fix was to stop overriding the host in that way and let the chart render the full paths correctly. The Route 53 alias and ACM certificate still made `app.devopslegend.click` work.

### DNS did not resolve after HTTPS setup

After HTTPS was configured, DNS initially returned no answer for:

```text
app.devopslegend.click
```

The fix was to create the Route 53 alias record pointing the hostname to the ALB:

```bash
./scripts/create-route53-alb-alias.sh
```

After the Route 53 change propagated, HTTP redirected to HTTPS and HTTPS returned `HTTP/2 200`.

### Grafana looked empty even though monitoring was installed

Grafana was running, but the application dashboard did not show the expected CloudOpsHub metrics.

The cause was that the backend image did not yet expose the final `/metrics` output in production. The fix was to rebuild and deploy the backend image with Prometheus metrics, then confirm:

```text
cloudopshub_database_reachable
```

Once Prometheus scraped the new metrics, Grafana showed backend scrape health and RDS reachability.

### Port-forward conflicts

Several port-forward commands failed with messages like:

```text
address already in use
```

This happened because an old port-forward process was still using the local port. The fix was to either stop the old process or use a different local port.

Examples used during the project included `18091`, `28091`, `38091`, and `48091`.

### Loki install timed out

The first Loki/Alloy setup timed out while waiting for pods.

There were two causes. First, Loki persistence expected storage that was not available or ready. Second, Loki later failed with:

```text
mkdir /var/loki: read-only file system
```

The fix was to run Loki with temporary storage for this project stage and mount a writable `emptyDir` at `/var/loki`. After that, Loki started and Grafana could query logs.

For a stricter production setup, the next step would be persistent Loki storage using the EBS CSI driver or an object-storage-backed Loki configuration.

### Velero was missing

The backup script reported:

```text
velero is required before running this script
```

The fix was to install Velero and configure it for AWS/S3 backups using:

```bash
./scripts/install-velero-aws.sh
```

The generated `credentials-velero` file was intentionally kept out of Git.

### Velero restore was partially failed

The restore validation completed as `PartiallyFailed` because the AWS Load Balancer Controller rejected a restored TargetGroupBinding:

```text
TargetGroup ... is already bound
```

This happened because the restore test namespace tried to restore an ALB target group binding already owned by the production namespace.

The fix was to exclude:

```text
targetgroupbindings.elbv2.k8s.aws
```

from Velero backup and restore validation. After that, backend and frontend resources restored cleanly into the test namespace.

### GitHub Actions failed because Trivy action version did not exist

The workflow failed with:

```text
Unable to resolve action aquasecurity/trivy-action@0.24.0
```

The action version was not valid. The fix was to update the workflow to a valid version:

```text
aquasecurity/trivy-action@v0.35.0
```

After that, the CI workflow completed and pushed images.

### Slack alert did not arrive

Alert routing was configured, but Slack did not receive the alert. A direct webhook test returned:

```text
no_service
```

That meant the Slack webhook was invalid, deleted, or from the wrong app/workspace. The fix was to create or regenerate a working Slack incoming webhook and update the Kubernetes secret.

After testing the new webhook directly, Slack received:

```text
CloudOpsHub direct Slack webhook test
```

Then Alertmanager routing could be tested again.

### Slack webhook was exposed

At one point, a Slack webhook URL was pasted into the terminal/chat. That should always be treated as a leaked secret.

The correct resolution is to revoke or rotate that webhook in Slack, create a new one, and update:

```text
cloudopshub-alert-routing
```

in the `monitoring` namespace.

## Validation Checklist

The project was considered working when these checks passed:

```bash
kubectl get nodes -L topology.kubernetes.io/zone
kubectl get applications -n argocd
kubectl get pods,svc -n cloudopshub
kubectl get ingress -n cloudopshub
curl -I https://app.devopslegend.click
curl https://app.devopslegend.click
curl http://localhost:<backend-port>/api/database
curl http://localhost:<backend-port>/metrics
kubectl get pods,svc -n monitoring
kubectl get prometheusrule -n monitoring
kubectl get alertmanagerconfig -n monitoring
velero backup get
velero restore get
```

Important verified outcomes:

- EKS production nodes were spread across `us-east-1a` and `us-east-1b`.
- Frontend and backend pods were running with two replicas.
- Backend reported RDS PostgreSQL Multi-AZ as reachable.
- ArgoCD showed frontend and backend healthy and synced.
- GitHub Actions built and pushed SHA-tagged images.
- ALB served the app through HTTPS.
- Grafana showed backend scrape health and RDS reachability.
- Loki returned CloudOpsHub namespace logs.
- Slack direct webhook worked.
- Velero restored frontend and backend into `cloudopshub-restore-test`.

## Current Production State

At the end of this stage, the platform has:

- A production EKS cluster in AWS.
- Multi-AZ worker nodes.
- Frontend and backend deployed through ArgoCD.
- RDS PostgreSQL Multi-AZ connected to the backend.
- Docker Hub images managed by CI/CD.
- HTTPS frontend access on `app.devopslegend.click`.
- Prometheus and Grafana monitoring.
- Loki logs visible in Grafana.
- Alertmanager routing prepared for Slack.
- RDS snapshot and Velero backup scripts.
- Restore validation completed for Kubernetes workloads.

## Recommended Next Improvements

The project is already strong, but these improvements would make it more production-ready:

- Rotate the Slack webhook that was exposed and update the Kubernetes secret.
- Add External Secrets or AWS Secrets Manager integration.
- Add persistent Loki storage using EBS CSI or object storage.
- Add Route 53 and ACM management into Terraform instead of only helper scripts.
- Add automated RDS restore validation into a controlled runbook.
- Add GitHub Actions environments and approvals for production.
- Add Terraform remote state locking and clear state backend documentation.
- Add cost-control documentation for EKS, ALB, RDS, CloudWatch, and S3.
- Add a final architecture diagram for presentations or portfolio use.

## Closing Notes

This project was built like a real platform: the work moved from local application testing, to containers, to Kubernetes, to GitOps, to AWS production, and then into monitoring, logging, alerting, HTTPS, and backup validation.

The blockers were normal production engineering blockers: missing secrets, stale UI state, image tag mismatches, DNS propagation, ALB controller configuration, storage assumptions, webhook errors, and restore conflicts. Each one improved the final platform because it forced the project to become more repeatable and better documented.

The final result is a working CloudOpsHub platform with a clear deployment path, observable production workloads, validated recovery steps, and a public HTTPS endpoint.
