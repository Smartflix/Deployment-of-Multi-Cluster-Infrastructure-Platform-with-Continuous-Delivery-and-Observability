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
terraform init
terraform plan -var-file=env.dev.tfvars
terraform apply -var-file=env.dev.tfvars
```

This will create the S3 bucket and DynamoDB lock table, then provision a VPC, EKS cluster, and a managed node group for the `dev` environment.

Note: This configuration now uses remote state backend storage in `us-east-1` and locking via DynamoDB.
