# Development Environment Configuration
terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
  }
}

# Configure providers
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

# Note: Kubernetes and Helm providers are configured in individual workflow files
# This main.tf only contains the foundation platform

# Data source for AWS account ID
data "aws_caller_identity" "current" {}

# Local values
locals {
  cluster_name = "${var.project_name}-${var.environment}-cluster"

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# Workflow 1: Foundation Platform
module "foundation" {
  source = "../../modules/foundation"

  project_name             = var.project_name
  environment              = var.environment
  owner                    = var.owner
  aws_region               = var.aws_region
  availability_zones_count = var.availability_zones_count
  vpc_cidr                 = var.vpc_cidr
  private_subnet_cidrs     = var.private_subnet_cidrs
  public_subnet_cidrs      = var.public_subnet_cidrs
  single_nat_gateway       = var.single_nat_gateway
  kubernetes_version       = var.kubernetes_version
}

# IAM roles for observability components
module "observability_irsa_roles" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  for_each = toset(["prometheus", "loki", "tempo"])

  role_name = "${local.cluster_name}-${each.key}"

  role_policy_arns = {
    policy = aws_iam_policy.observability_s3_policy[each.key].arn
  }

  oidc_providers = {
    ex = {
      provider_arn               = module.foundation.oidc_provider_arn
      namespace_service_accounts = ["observability:${each.key}"]
    }
  }

  depends_on = [module.foundation]
}

# S3 access policy for observability components
resource "aws_iam_policy" "observability_s3_policy" {
  for_each = toset(["prometheus", "loki", "tempo"])

  name        = "${local.cluster_name}-${each.key}-s3-policy"
  description = "S3 access policy for ${each.key}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          module.foundation.observability_s3_buckets[each.key].arn,
          "${module.foundation.observability_s3_buckets[each.key].arn}/*"
        ]
      }
    ]
  })
}

# Workflow 2: Ingress + API Gateway
module "ingress" {
  source = "../../modules/ingress"

  project_name         = var.project_name
  environment          = var.environment
  cluster_name         = module.foundation.cluster_name
  aws_region           = var.aws_region
  domain_name          = var.domain_name
  domain_filters       = [var.domain_name]
  letsencrypt_email    = var.letsencrypt_email
  cloudflare_email     = var.cloudflare_email
  cloudflare_api_token = var.cloudflare_api_token

  depends_on = [module.foundation]
}

# Workflow 3: LGTM Observability Stack - See lgtm-observability.tf

# Workflow 4: GitOps & CI/CD
module "gitops" {
  source = "../../modules/gitops"

  project_name       = var.project_name
  environment        = var.environment
  cluster_name       = module.foundation.cluster_name
  domain_name        = var.domain_name
  gitops_repo_url    = var.gitops_repo_url
  gitops_repo_branch = var.gitops_repo_branch

  depends_on = [module.foundation]
}

# Workflow 5: Security Foundation
module "security" {
  source = "../../modules/security"

  project_name      = var.project_name
  environment       = var.environment
  cluster_name      = module.foundation.cluster_name
  slack_webhook_url = var.slack_webhook_url

  depends_on = [module.foundation]
}

# Workflow 6: Service Mesh
module "service_mesh" {
  source = "../../modules/service-mesh"

  project_name = var.project_name
  environment  = var.environment
  cluster_name = module.foundation.cluster_name
  domain_name  = var.domain_name

  depends_on = [module.foundation]
}

# Workflow 7: Data Services
module "data_services" {
  source = "../../modules/data-services"

  project_name = var.project_name
  environment  = var.environment
  cluster_name = module.foundation.cluster_name

  # PostgreSQL Configuration
  postgres_password          = var.postgres_password
  postgres_backup_bucket     = "${var.project_name}-${var.environment}-postgres-backup"
  postgres_backup_access_key = var.postgres_backup_access_key
  postgres_backup_secret_key = var.postgres_backup_secret_key

  depends_on = [module.foundation]
}

# AWS Load Balancer Controller and Cluster Autoscaler will be installed by the foundation module