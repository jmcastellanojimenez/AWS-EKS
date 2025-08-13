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

locals {
  # Common tags applied to all resources
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    CreatedBy   = "terraform"
    Repository  = "eks-foundation-platform"
    Region      = var.aws_region
  }

  # Cluster name
  cluster_name = var.cluster_name != "" ? var.cluster_name : "${var.project_name}-${var.environment}"

  # Kubernetes add-on versions (latest stable)
  addon_versions = {
    vpc_cni              = "v1.15.1-eksbuild.1"
    kube_proxy           = "v1.28.2-eksbuild.2"
    coredns              = "v1.10.1-eksbuild.5"
    ebs_csi_driver       = "v1.24.0-eksbuild.1"
  }
}

# VPC Module
module "vpc" {
  source = "../../modules/vpc"

  project_name         = var.project_name
  environment          = var.environment
  cluster_name         = local.cluster_name
  vpc_cidr             = var.vpc_cidr
  enable_nat_gateway   = var.enable_nat_gateway
  enable_vpc_endpoints = var.enable_vpc_endpoints
  enable_flow_logs     = var.enable_flow_logs
}

# Basic IAM Module (cluster and node group roles)
module "iam" {
  source = "../../modules/iam"

  project_name = var.project_name
  environment  = var.environment
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

  # Node group settings
  instance_types     = var.instance_types
  capacity_type      = var.capacity_type
  desired_capacity   = var.desired_capacity
  min_capacity       = var.min_capacity
  max_capacity       = var.max_capacity
  node_disk_size     = var.node_disk_size

  # Security settings
  endpoint_private_access = true
  endpoint_public_access  = true
  public_access_cidrs     = ["0.0.0.0/0"]
  cluster_log_types       = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  # Add-on versions
  vpc_cni_version         = local.addon_versions.vpc_cni
  kube_proxy_version      = local.addon_versions.kube_proxy
  coredns_version         = local.addon_versions.coredns
  ebs_csi_driver_version  = local.addon_versions.ebs_csi_driver

  depends_on = [module.vpc, module.iam]
}

# IRSA IAM Module (roles that depend on OIDC provider)
module "iam_irsa" {
  source = "../../modules/iam-irsa"

  project_name      = var.project_name
  environment       = var.environment
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_provider_url

  depends_on = [module.eks]
}

# EBS CSI Driver Addon (applied after IRSA roles are created)
resource "aws_eks_addon" "ebs_csi_driver" {
  cluster_name                = module.eks.cluster_name
  addon_name                  = "aws-ebs-csi-driver"
  addon_version               = local.addon_versions.ebs_csi_driver
  service_account_role_arn    = module.iam_irsa.ebs_csi_driver_role_arn
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = local.common_tags

  depends_on = [module.eks, module.iam_irsa]
}