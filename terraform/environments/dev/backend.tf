# ============================================================================
# Terraform Backend Configuration
# ============================================================================
# Centralized state management using S3 and DynamoDB for state locking
# ============================================================================

terraform {
  backend "s3" {
    # S3 bucket for state storage
    bucket = "eks-learning-lab-terraform-state-011921741593"
    
    # State file path - using consistent naming convention
    # This matches the DynamoDB lock entry pattern
    key = "eks-platform/dev/terraform.tfstate"
    
    # AWS Region
    region = "us-east-1"
    
    # Enable state file encryption
    encrypt = true
    
    # DynamoDB table for state locking
    dynamodb_table = "eks-learning-lab-terraform-lock"
    
    # Enable versioning for state file history
    # Note: Versioning should be enabled on the S3 bucket
  }
}