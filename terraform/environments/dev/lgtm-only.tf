# ==============================================================================
# LGTM-Only Deployment Configuration
# ==============================================================================

terraform {
  required_version = ">= 1.6"
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

  backend "s3" {
    bucket = "eks-learning-lab-terraform-state-011921741593"
    key    = "eks-platform/dev/lgtm-terraform.tfstate"
    region = "us-east-1"
    encrypt = true
    dynamodb_table = "eks-learning-lab-terraform-lock"
  }
}

# Configure providers
provider "aws" {
  region = var.aws_region
}

# Data sources to get existing cluster information
data "aws_eks_cluster" "cluster" {
  name = "${var.project_name}-${var.environment}-cluster"
}

data "aws_eks_cluster_auth" "cluster" {
  name = data.aws_eks_cluster.cluster.name
}

data "aws_caller_identity" "current" {}

# Configure Kubernetes provider for existing EKS cluster
provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

# Configure Helm provider for existing EKS cluster  
provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.cluster.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}

# Get OIDC provider from existing cluster
data "aws_iam_openid_connect_provider" "cluster" {
  url = data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer
}

# Local values
locals {
  cluster_name = data.aws_eks_cluster.cluster.name
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# LGTM Observability Stack Module (standalone)
module "lgtm_observability" {
  source = "../../modules/lgtm-observability"

  # Cluster information from existing cluster
  cluster_name                       = data.aws_eks_cluster.cluster.name
  cluster_endpoint                   = data.aws_eks_cluster.cluster.endpoint
  cluster_certificate_authority_data = data.aws_eks_cluster.cluster.certificate_authority.0.data

  # Environment configuration
  environment    = var.environment
  namespace      = var.observability_namespace
  aws_region     = var.aws_region
  aws_account_id = data.aws_caller_identity.current.account_id

  # IRSA configuration from existing cluster
  oidc_provider_arn = data.aws_iam_openid_connect_provider.cluster.arn

  # Grafana configuration
  grafana_admin_password = var.grafana_admin_password
  grafana_domain         = var.grafana_domain
  enable_grafana_alerts  = var.enable_grafana_alerts
  slack_webhook_url      = var.slack_webhook_url

  # Component toggles - MINIMAL for SPOT instances
  enable_prometheus = var.enable_prometheus
  enable_grafana    = var.enable_grafana
  enable_mimir      = var.enable_mimir
  enable_loki       = var.enable_loki
  enable_tempo      = var.enable_tempo

  # Resource configuration - ULTRA-minimal for SPOT
  prometheus_resources = var.prometheus_resources
  grafana_resources    = var.grafana_resources
  mimir_resources      = var.mimir_resources
  loki_resources       = var.loki_resources
  tempo_resources      = var.tempo_resources

  # Storage configuration
  prometheus_storage_size = var.prometheus_storage_size
  grafana_storage_size    = var.grafana_storage_size
  prometheus_retention    = var.prometheus_retention

  # S3 lifecycle
  s3_lifecycle_enabled = var.s3_lifecycle_enabled
  s3_transition_days   = var.s3_transition_days
  s3_expiration_days   = var.s3_expiration_days

  # Tags
  tags = merge(local.common_tags, {
    Workflow  = "3"
    Component = "LGTM-Observability"
    Purpose   = "Monitoring-Logging-Tracing"
  })
}