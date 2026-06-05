# Backups and Recovery

CloudOpsHub uses two backup layers:

- RDS automated backups and manual snapshots for PostgreSQL.
- Velero for Kubernetes resource backups.

## RDS Snapshot

Create and validate a manual RDS snapshot:

```bash
export AWS_REGION=us-east-1
export DB_INSTANCE_ID=cloudopshub-prod-postgres
chmod +x scripts/create-rds-snapshot.sh
./scripts/create-rds-snapshot.sh
```

This waits until the snapshot is complete and prints the snapshot status.

## Velero Install

Install Velero with AWS/S3 for Kubernetes resource backups:

```bash
export AWS_REGION=us-east-1
export CLUSTER_NAME=cloudopshub-prod
chmod +x scripts/install-velero-aws.sh
./scripts/install-velero-aws.sh
```

The script creates a private S3 bucket, creates or reuses the `cloudopshub-velero` IAM user, writes `credentials-velero`, and installs Velero with `--use-volume-snapshots=false`.

## Kubernetes Backup

Create a backup of the CloudOpsHub namespace:

```bash
chmod +x scripts/create-velero-backup.sh
./scripts/create-velero-backup.sh
```

The backup script excludes `targetgroupbindings.elbv2.k8s.aws`. Those resources bind Kubernetes to existing AWS ALB target groups and should not be duplicated during restore validation.

## Restore Validation

Restore into a separate namespace to prove that backups work without overwriting production:

```bash
export BACKUP_NAME=<backup-name>
chmod +x scripts/validate-velero-restore.sh
./scripts/validate-velero-restore.sh
```

Validate restored resources:

```bash
kubectl get pods,svc -n cloudopshub-restore-test
```

The restore script also excludes ALB TargetGroupBindings so the test namespace can restore backend/frontend workloads without trying to claim the production ALB target group.

## Production Notes

- Keep RDS automated backups enabled.
- Test RDS restore into a new instance before any production cutover.
- Use restore validation regularly, not only after an incident.
- Do not restore over the production namespace unless you have an approved recovery plan.
