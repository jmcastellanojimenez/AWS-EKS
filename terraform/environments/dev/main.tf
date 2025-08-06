terraform {
  required_version = ">= 1.3"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.0"
    }
  }

  backend "s3" {
    key                  = "dev/terraform.tfstate"
    workspace_key_prefix = "environments"
    encrypt              = true
    dynamodb_table       = "eks-learning-lab-terraform-lock"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}

# Import shared configuration
module "shared" {
  source = "../../shared"
  
  environment  = var.environment
  cluster_name = var.cluster_name
}

locals {
  # Use shared module outputs
  common_tags      = module.shared.common_tags
  cluster_name     = module.shared.cluster_name
  env_config       = module.shared.env_config
  security_config  = module.shared.security_config
  addon_versions   = module.shared.addon_versions
  cost_thresholds  = module.shared.cost_thresholds
}

# VPC Module
module "vpc" {
  source = "../../modules/vpc"

  project_name         = var.project_name
  environment          = var.environment
  cluster_name         = local.cluster_name
  vpc_cidr             = var.vpc_cidr
  enable_nat_gateway   = local.env_config.enable_nat_gateway
  enable_vpc_endpoints = local.env_config.enable_vpc_endpoints
  enable_flow_logs     = local.env_config.enable_flow_logs
}

# EKS Cluster Module
module "eks" {
  source = "../../modules/eks"

  project_name            = var.project_name
  environment             = var.environment
  cluster_name            = local.cluster_name
  kubernetes_version      = var.kubernetes_version
  vpc_id                  = module.vpc.vpc_id
  public_subnet_ids       = module.vpc.public_subnet_ids
  private_subnet_ids      = module.vpc.private_subnet_ids
  cluster_role_arn        = module.iam.eks_cluster_role_arn
  node_group_role_arn     = module.iam.eks_node_group_role_arn
  ebs_csi_driver_role_arn = module.iam.ebs_csi_driver_role_arn

  # Cost-optimized settings for dev
  instance_types     = local.env_config.instance_types
  capacity_type      = local.env_config.capacity_type
  desired_capacity   = local.env_config.desired_capacity
  min_capacity       = local.env_config.min_capacity
  max_capacity       = local.env_config.max_capacity
  node_disk_size     = var.node_disk_size

  # Security settings
  endpoint_private_access = local.security_config.endpoint_private_access
  endpoint_public_access  = local.security_config.endpoint_public_access
  public_access_cidrs     = local.security_config.public_access_cidrs
  cluster_log_types       = local.security_config.cluster_log_types

  # Add-on versions
  vpc_cni_version         = local.addon_versions.vpc_cni
  kube_proxy_version      = local.addon_versions.kube_proxy
  coredns_version         = local.addon_versions.coredns
  ebs_csi_driver_version  = local.addon_versions.ebs_csi_driver

  depends_on = [module.vpc, module.iam]
}

# IAM Module
module "iam" {
  source = "../../modules/iam"

  project_name      = var.project_name
  environment       = var.environment
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_provider_url

  depends_on = [module.eks]
}

# S3 Bucket for storing cluster information and backups
resource "aws_s3_bucket" "cluster_data" {
  bucket = "${var.project_name}-${local.environment}-cluster-data-${random_id.bucket_suffix.hex}"

  tags = local.common_tags
}

resource "aws_s3_bucket_versioning" "cluster_data" {
  bucket = aws_s3_bucket.cluster_data.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_encryption" "cluster_data" {
  bucket = aws_s3_bucket.cluster_data.id

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
}

resource "aws_s3_bucket_public_access_block" "cluster_data" {
  bucket = aws_s3_bucket.cluster_data.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# CloudWatch Dashboard for monitoring
resource "aws_cloudwatch_dashboard" "eks_cluster" {
  dashboard_name = "${var.project_name}-${local.environment}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/EKS", "cluster_failed_request_count", "ClusterName", local.cluster_name],
            [".", "cluster_request_total", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "EKS Cluster Metrics"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/EC2", "CPUUtilization", "AutoScalingGroupName", "${local.cluster_name}-nodes"],
            [".", "NetworkIn", ".", "."],
            [".", "NetworkOut", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Node Group Metrics"
          period  = 300
        }
      }
    ]
  })

  tags = local.common_tags
}

# Cost Budget for the environment
resource "aws_budgets_budget" "eks_learning_lab" {
  name       = "${var.project_name}-${local.environment}-budget"
  budget_type = "COST"
  limit_amount = local.cost_thresholds[local.environment]
  limit_unit   = "USD"
  time_unit    = "MONTHLY"
  time_period_start = "2024-01-01_00:00"

  cost_filters = {
    Tag = ["Project:${var.project_name}"]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                 = 80
    threshold_type            = "PERCENTAGE"
    notification_type         = "ACTUAL"
    subscriber_email_addresses = ["admin@example.com"]  # Update with your email
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                 = 100
    threshold_type            = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = ["admin@example.com"]  # Update with your email
  }

  tags = local.common_tags
}