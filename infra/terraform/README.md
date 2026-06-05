Terraform layout and quickstart

1. Install Terraform (>= 1.0) and AWS CLI. Configure `aws configure` with credentials.
2. Bootstrap remote state backend resources:

```bash
cd infra/terraform
chmod +x backend-bootstrap.sh
./backend-bootstrap.sh
```

3. Initialize Terraform with the S3/DynamoDB backend:

```bash
export TF_VAR_db_password='<strong-db-password>'
terraform init
terraform plan -var-file=env.dev.tfvars
terraform apply -var-file=env.dev.tfvars
```

This will create the S3 bucket and DynamoDB lock table, then provision a VPC, EKS cluster, managed node group, and Multi-AZ RDS PostgreSQL database.

For production multi-AZ:

```bash
export TF_VAR_db_password='<strong-db-password>'
terraform plan -var-file=env.prod.tfvars
terraform apply -var-file=env.prod.tfvars
aws eks update-kubeconfig --name "$(terraform output -raw cluster_name)" --region us-east-1
```

Note: This configuration now uses remote state backend storage in `us-east-1` and locking via DynamoDB.
