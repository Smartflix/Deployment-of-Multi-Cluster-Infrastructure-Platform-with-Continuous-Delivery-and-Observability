#!/usr/bin/env bash
set -euo pipefail

export AWS_REGION="us-east-1"
BUCKET_NAME="cloudopshub-terraform-state-us-east-1"
TABLE_NAME="cloudopshub-terraform-locks"

if ! aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
  echo "Creating S3 bucket $BUCKET_NAME in $AWS_REGION"
  if [[ "$AWS_REGION" == "us-east-1" ]]; then
    aws s3api create-bucket --bucket "$BUCKET_NAME" --region "$AWS_REGION"
  else
    aws s3api create-bucket \
      --bucket "$BUCKET_NAME" \
      --region "$AWS_REGION" \
      --create-bucket-configuration LocationConstraint=$AWS_REGION
  fi
  aws s3api put-bucket-versioning --bucket "$BUCKET_NAME" --versioning-configuration Status=Enabled
  aws s3api put-bucket-encryption --bucket "$BUCKET_NAME" --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
else
  echo "S3 bucket $BUCKET_NAME already exists"
fi

if ! aws dynamodb describe-table --table-name "$TABLE_NAME" >/dev/null 2>&1; then
  echo "Creating DynamoDB table $TABLE_NAME"
  aws dynamodb create-table \
    --table-name "$TABLE_NAME" \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST
else
  echo "DynamoDB table $TABLE_NAME already exists"
fi

echo "Bootstrap complete. Run 'terraform init' in infra/terraform next."
