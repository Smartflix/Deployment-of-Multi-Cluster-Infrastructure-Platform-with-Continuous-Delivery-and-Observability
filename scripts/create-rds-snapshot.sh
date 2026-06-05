#!/usr/bin/env bash
set -euo pipefail

AWS_REGION="${AWS_REGION:-us-east-1}"
DB_INSTANCE_ID="${DB_INSTANCE_ID:-cloudopshub-prod-postgres}"
SNAPSHOT_ID="${SNAPSHOT_ID:-${DB_INSTANCE_ID}-manual-$(date -u +%Y%m%d%H%M%S)}"

echo "Checking RDS instance status for ${DB_INSTANCE_ID}..."
aws rds describe-db-instances \
  --region "${AWS_REGION}" \
  --db-instance-identifier "${DB_INSTANCE_ID}" \
  --query "DBInstances[0].[DBInstanceIdentifier,DBInstanceStatus,MultiAZ,Endpoint.Address]" \
  --output table

echo "Waiting for ${DB_INSTANCE_ID} to become available..."
aws rds wait db-instance-available \
  --region "${AWS_REGION}" \
  --db-instance-identifier "${DB_INSTANCE_ID}"

echo "Creating snapshot ${SNAPSHOT_ID}..."
aws rds create-db-snapshot \
  --region "${AWS_REGION}" \
  --db-instance-identifier "${DB_INSTANCE_ID}" \
  --db-snapshot-identifier "${SNAPSHOT_ID}"

echo "Waiting for snapshot ${SNAPSHOT_ID} to complete..."
aws rds wait db-snapshot-completed \
  --region "${AWS_REGION}" \
  --db-snapshot-identifier "${SNAPSHOT_ID}"

aws rds describe-db-snapshots \
  --region "${AWS_REGION}" \
  --db-snapshot-identifier "${SNAPSHOT_ID}" \
  --query "DBSnapshots[0].[DBSnapshotIdentifier,Status,SnapshotCreateTime,AllocatedStorage]" \
  --output table
