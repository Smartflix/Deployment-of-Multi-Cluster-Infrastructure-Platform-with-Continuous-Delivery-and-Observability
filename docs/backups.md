# Backups and Recovery

We recommend Velero for cluster-level backups and a DB-specific backup for the Postgres database.

Velero install (example using S3):

```bash
velero install --provider aws --bucket <BUCKET> --secret-file ./credentials-velero --backup-location-config region=<REGION>
```

DB backups:
- Use `pg_dump` to create daily dumps and push to S3.
- Keep retention policy aligned with RPO requirements.

Recovery:
- For cluster restore: `velero restore create --from-backup <BACKUP>`
- For DB restore: `pg_restore` into a new DB instance and switch over via DNS or k8s service update.
