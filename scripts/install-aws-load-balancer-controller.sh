#!/usr/bin/env bash
set -euo pipefail

AWS_REGION="${AWS_REGION:-us-east-1}"
CLUSTER_NAME="${CLUSTER_NAME:-cloudopshub-prod}"
POLICY_NAME="${POLICY_NAME:-AWSLoadBalancerControllerIAMPolicy}"
ROLE_NAME="${ROLE_NAME:-AmazonEKSLoadBalancerControllerRole-${CLUSTER_NAME}}"
SERVICE_ACCOUNT="${SERVICE_ACCOUNT:-aws-load-balancer-controller}"
NAMESPACE="${NAMESPACE:-kube-system}"
CONTROLLER_VERSION="${CONTROLLER_VERSION:-1.14.0}"
IAM_POLICY_URL="${IAM_POLICY_URL:-https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.14.1/docs/install/iam_policy.json}"

require() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "$1 is required but not installed or not on PATH."
    exit 1
  fi
}

require aws
require curl
require helm
require kubectl
require openssl

ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
OIDC_ISSUER="$(aws eks describe-cluster --name "${CLUSTER_NAME}" --region "${AWS_REGION}" --query "cluster.identity.oidc.issuer" --output text)"
OIDC_PROVIDER="${OIDC_ISSUER#https://}"
OIDC_PROVIDER_ARN="arn:aws:iam::${ACCOUNT_ID}:oidc-provider/${OIDC_PROVIDER}"

if ! aws iam get-open-id-connect-provider --open-id-connect-provider-arn "${OIDC_PROVIDER_ARN}" >/dev/null 2>&1; then
  echo "Creating IAM OIDC provider for ${CLUSTER_NAME}"
  OIDC_HOST="${OIDC_PROVIDER%%/*}"
  THUMBPRINT="$(echo | openssl s_client -servername "${OIDC_HOST}" -showcerts -connect "${OIDC_HOST}:443" 2>/dev/null | openssl x509 -fingerprint -noout -sha1 | cut -d= -f2 | tr -d :)"
  aws iam create-open-id-connect-provider \
    --url "${OIDC_ISSUER}" \
    --client-id-list sts.amazonaws.com \
    --thumbprint-list "${THUMBPRINT}" >/dev/null
fi

POLICY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/${POLICY_NAME}"
if ! aws iam get-policy --policy-arn "${POLICY_ARN}" >/dev/null 2>&1; then
  echo "Creating ${POLICY_NAME}"
  curl -fsSL "${IAM_POLICY_URL}" -o /tmp/aws-load-balancer-controller-iam-policy.json
  aws iam create-policy \
    --policy-name "${POLICY_NAME}" \
    --policy-document file:///tmp/aws-load-balancer-controller-iam-policy.json >/dev/null
fi

TRUST_POLICY="/tmp/aws-load-balancer-controller-trust-policy.json"
cat > "${TRUST_POLICY}" <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "${OIDC_PROVIDER_ARN}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "${OIDC_PROVIDER}:aud": "sts.amazonaws.com",
          "${OIDC_PROVIDER}:sub": "system:serviceaccount:${NAMESPACE}:${SERVICE_ACCOUNT}"
        }
      }
    }
  ]
}
EOF

if ! aws iam get-role --role-name "${ROLE_NAME}" >/dev/null 2>&1; then
  echo "Creating IAM role ${ROLE_NAME}"
  aws iam create-role \
    --role-name "${ROLE_NAME}" \
    --assume-role-policy-document "file://${TRUST_POLICY}" >/dev/null
else
  aws iam update-assume-role-policy \
    --role-name "${ROLE_NAME}" \
    --policy-document "file://${TRUST_POLICY}" >/dev/null
fi

aws iam attach-role-policy \
  --role-name "${ROLE_NAME}" \
  --policy-arn "${POLICY_ARN}" >/dev/null || true

kubectl create serviceaccount "${SERVICE_ACCOUNT}" -n "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -
kubectl annotate serviceaccount "${SERVICE_ACCOUNT}" \
  -n "${NAMESPACE}" \
  "eks.amazonaws.com/role-arn=arn:aws:iam::${ACCOUNT_ID}:role/${ROLE_NAME}" \
  --overwrite

VPC_ID="$(aws eks describe-cluster --name "${CLUSTER_NAME}" --region "${AWS_REGION}" --query "cluster.resourcesVpcConfig.vpcId" --output text)"
SUBNET_IDS="$(aws ec2 describe-subnets \
  --region "${AWS_REGION}" \
  --filters "Name=vpc-id,Values=${VPC_ID}" "Name=map-public-ip-on-launch,Values=true" \
  --query "Subnets[].SubnetId" \
  --output text)"

for subnet in ${SUBNET_IDS}; do
  aws ec2 create-tags \
    --region "${AWS_REGION}" \
    --resources "${subnet}" \
    --tags "Key=kubernetes.io/cluster/${CLUSTER_NAME},Value=shared" "Key=kubernetes.io/role/elb,Value=1"
done

helm repo add eks https://aws.github.io/eks-charts
helm repo update eks

helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n "${NAMESPACE}" \
  --set clusterName="${CLUSTER_NAME}" \
  --set serviceAccount.create=false \
  --set serviceAccount.name="${SERVICE_ACCOUNT}" \
  --version "${CONTROLLER_VERSION}"

kubectl rollout status deployment/aws-load-balancer-controller -n "${NAMESPACE}" --timeout=180s
kubectl get deployment aws-load-balancer-controller -n "${NAMESPACE}"
