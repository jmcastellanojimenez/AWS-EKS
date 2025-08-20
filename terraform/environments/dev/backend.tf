# Terraform Backend Configuration
# Update the bucket name and region to match your setup

terraform {
  backend "s3" {
    bucket         = "eks-learning-lab-terraform-state-011921741593"
    key            = "eks-platform/dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "eks-learning-lab-terraform-lock"
    encrypt        = true
  }
}