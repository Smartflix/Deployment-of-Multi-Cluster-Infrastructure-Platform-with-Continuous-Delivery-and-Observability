terraform {
  backend "s3" {
    bucket         = "cloudopshub-terraform-state-us-east-1"
    key            = "cloudopshub/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "cloudopshub-terraform-locks"
    encrypt        = true
  }
}
