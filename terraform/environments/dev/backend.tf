# Terraform Backend Configuration
# Update the bucket name and region to match your setup

terraform {
  backend "s3" {
    bucket         = "your-terraform-state-bucket"
    key            = "eks-platform/dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}