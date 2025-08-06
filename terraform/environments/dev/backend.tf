# Backend configuration for dev environment
# This file is used to configure the Terraform backend for storing state

# The actual backend configuration is in main.tf
# This file exists to document the backend requirements

# Required S3 bucket: eks-learning-lab-terraform-state-${AWS_ACCOUNT_ID}
# Required DynamoDB table: eks-learning-lab-terraform-lock

# Backend will be configured with these values:
# bucket = "eks-learning-lab-terraform-state-${AWS_ACCOUNT_ID}"
# key    = "dev/terraform.tfstate"
# region = "us-east-1"
# encrypt = true
# dynamodb_table = "eks-learning-lab-terraform-lock"

# To initialize with backend configuration, run:
# terraform init -backend-config="bucket=eks-learning-lab-terraform-state-${AWS_ACCOUNT_ID}"