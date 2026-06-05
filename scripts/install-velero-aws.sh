#!/usr/bin/env bash
set -euo pipefail

AWS_REGION="${AWS_REGION:-us-east-1}"
CLUSTER_NAME="${CLUSTER_NAME:-cloudopshub-prod}"
VELERO_NAMESPACE="${VELERO_NAMESPACE:-velero}"
VELERO_IAM_USER="${VELERO_IAM_USER:-cloudopshub-velero}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "$1 is required before running this script."
    exit 1
  fi
}

require_command aws
require_command kubectl
require_command velero

ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
VELERO_BUCKET="${VELERO_BUCKET:-cloudopshub-velero-${ACCOUNT_ID}-${AWS_REGION}}"
CREDENTIALS_FILE="${CREDENTIALS_FILE:-${ROOT}/credentials-velero}"
POLICY_FILE="${POLICY_FILE:-${ROOT}/velero-policy.json}"

echo "Using AWS account: ${ACCOUNT_ID}"
echo "Using region: ${AWS_REGION}"
echo "Using bucket: ${VELERO_BUCKET}"
echo "Using IAM user: ${VELERO_IAM_USER}"

if ! aws s3api head-bucket --bucket "${VELERO_BUCKET}" >/dev/null 2>&1; then
  if [[ "${AWS_REGION}" == "us-east-1" ]]; then
    aws s3api create-bucket --bucket "${VELERO_BUCKET}" --region "${AWS_REGION}"
  else
    aws s3api create-bucket \
      --bucket "${VELERO_BUCKET}" \
      --region "${AWS_REGION}" \
      --create-bucket-configuration LocationConstraint="${AWS_REGION}"
  fi
fi

aws s3api put-public-access-block \
  --bucket "${VELERO_BUCKET}" \
  --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

aws s3api put-bucket-versioning \
  --bucket "${VELERO_BUCKET}" \
  --versioning-configuration Status=Enabled

if ! aws iam get-user --user-name "${VELERO_IAM_USER}" >/dev/null 2>&1; then
  aws iam create-user --user-name "${VELERO_IAM_USER}" >/dev/null
fi

cat > "${POLICY_FILE}" <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:AbortMultipartUpload",
        "s3:DeleteObject",
        "s3:GetObject",
        "s3:ListBucket",
        "s3:ListBucketMultipartUploads",
        "s3:PutObject"
      ],
      "Resource": [
        "arn:aws:s3:::${VELERO_BUCKET}",
        "arn:aws:s3:::${VELERO_BUCKET}/*"
      ]
    }
  ]
}
EOF

aws iam put-user-policy \
  --user-name "${VELERO_IAM_USER}" \
  --policy-name cloudopshub-velero-s3 \
  --policy-document "file://${POLICY_FILE}"

if [[ -f "${CREDENTIALS_FILE}" ]]; then
  echo "Reusing existing ${CREDENTIALS_FILE}"
else
  KEY_COUNT="$(aws iam list-access-keys --user-name "${VELERO_IAM_USER}" --query 'length(AccessKeyMetadata)' --output text)"
  if [[ "${KEY_COUNT}" -ge 2 ]]; then
    echo "IAM user ${VELERO_IAM_USER} already has 2 access keys."
    echo "Delete an old key or set CREDENTIALS_FILE to an existing Velero credentials file."
    exit 1
  fi

  read -r ACCESS_KEY_ID SECRET_ACCESS_KEY < <(
    aws iam create-access-key \
      --user-name "${VELERO_IAM_USER}" \
      --query 'AccessKey.[AccessKeyId,SecretAccessKey]' \
      --output text
  )

  cat > "${CREDENTIALS_FILE}" <<EOF
[default]
aws_access_key_id=${ACCESS_KEY_ID}
aws_secret_access_key=${SECRET_ACCESS_KEY}
EOF

  chmod 600 "${CREDENTIALS_FILE}"
fi

kubectl create namespace "${VELERO_NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

velero install \
  --provider aws \
  --plugins velero/velero-plugin-for-aws:latest \
  --bucket "${VELERO_BUCKET}" \
  --secret-file "${CREDENTIALS_FILE}" \
  --backup-location-config region="${AWS_REGION}" \
  --use-volume-snapshots=false \
  --namespace "${VELERO_NAMESPACE}"

kubectl rollout status deployment/velero -n "${VELERO_NAMESPACE}" --timeout=180s
velero backup-location get

echo ""
echo "Velero is installed for Kubernetes resource backups."
echo "Credentials were written to ${CREDENTIALS_FILE}; do not commit this file."
