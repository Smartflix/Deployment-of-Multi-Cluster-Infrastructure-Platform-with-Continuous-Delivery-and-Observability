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

Create the Docker Hub pull secret in each target namespace if the image repositories are private:

```bash
kubectl create secret docker-registry dockerhub-pull-secret \
  --docker-server=docker.io \
  --docker-username=fabulousjeff2009 \
  --docker-password=<dockerhub-token> \
  --docker-email=<email>

kubectl patch serviceaccount default \
  -p '{"imagePullSecrets":[{"name":"dockerhub-pull-secret"}]}'
```

Create the demo database password Secret before syncing the db chart:

```bash
kubectl create namespace cloudopshub
kubectl create secret generic cloudopshub-db-secret \
  --from-literal=postgres-password=<db-password> \
  -n cloudopshub
```

From WSL/Linux, you can use the helper script:

```bash
DB_PASSWORD='<db-password>' ./scripts/create-db-secret.sh
```

Apply the application manifests:

```bash
kubectl apply -f k8s/apps/backend-app.yaml
kubectl apply -f k8s/apps/frontend-app.yaml
```

For production, use RDS and do not sync `k8s/apps/db-app.yaml`. The db chart is retained for local/demo testing.

## HTTPS For The Frontend ALB

The frontend Ingress supports HTTPS through AWS Load Balancer Controller annotations.

Requirements:

- A domain name you control, such as `app.example.com`.
- An ACM certificate in the same AWS region as the ALB, currently `us-east-1`.
- DNS validation completed for the ACM certificate.

Request a certificate:

```bash
export AWS_REGION=us-east-1
export FRONTEND_HOST=app.example.com

aws acm request-certificate \
  --region "$AWS_REGION" \
  --domain-name "$FRONTEND_HOST" \
  --validation-method DNS \
  --query CertificateArn \
  --output text
```

If the domain is hosted in Route 53, use the helper script to request the certificate and create the DNS validation record:

```bash
export AWS_REGION=us-east-1
export ROOT_DOMAIN=devopslegend.click
export FRONTEND_HOST=app.devopslegend.click
chmod +x scripts/request-acm-cert-route53.sh
./scripts/request-acm-cert-route53.sh
```

Create the DNS validation record shown by:

```bash
aws acm describe-certificate \
  --region "$AWS_REGION" \
  --certificate-arn "$CERTIFICATE_ARN" \
  --query "Certificate.DomainValidationOptions[0].ResourceRecord"
```

After the certificate status is `ISSUED`, enable HTTPS:

```bash
export CERTIFICATE_ARN=<acm-certificate-arn>
export FRONTEND_HOST=app.example.com
chmod +x scripts/enable-alb-https.sh
./scripts/enable-alb-https.sh
```

Verify:

```bash
kubectl get ingress frontend -n cloudopshub
curl -I "https://${FRONTEND_HOST}"
```

The chart uses:

```text
alb.ingress.kubernetes.io/certificate-arn
alb.ingress.kubernetes.io/listen-ports: [{"HTTP":80},{"HTTPS":443}]
alb.ingress.kubernetes.io/ssl-redirect: 443
```
