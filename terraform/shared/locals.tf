locals {
  # Common tags applied to all resources
  common_tags = merge(
    {
      Project     = var.project_name
      Environment = var.environment
      CreatedBy   = "terraform"
      Repository  = "eks-learning-lab"
      Region      = var.aws_region
    },
    var.additional_tags
  )

  # Cluster name with environment prefix
  cluster_name = var.cluster_name != "" ? var.cluster_name : "${var.project_name}-${var.environment}"

  # Cost optimization settings based on environment
  cost_optimized_settings = {
    dev = {
      enable_nat_gateway   = false  # Disable NAT for dev to save costs
      enable_vpc_endpoints = false
      enable_flow_logs     = false
      capacity_type        = "SPOT"
      desired_capacity     = 1
      min_capacity         = 1
      max_capacity         = 2
      instance_types       = ["t3.medium"]
    }
    staging = {
      enable_nat_gateway   = true
      enable_vpc_endpoints = false
      enable_flow_logs     = false
      capacity_type        = "SPOT"
      desired_capacity     = 2
      min_capacity         = 1
      max_capacity         = 3
      instance_types       = ["t3.medium"]
    }
    prod = {
      enable_nat_gateway   = true
      enable_vpc_endpoints = true
      enable_flow_logs     = true
      capacity_type        = "ON_DEMAND"
      desired_capacity     = 3
      min_capacity         = 2
      max_capacity         = 6
      instance_types       = ["t3.medium", "t3.large"]
    }
  }

  # Environment-specific settings
  env_config = local.cost_optimized_settings[var.environment]

  # Network configuration
  vpc_cidr = var.vpc_cidr
  azs      = slice(data.aws_availability_zones.available.names, 0, 2)

  # Kubernetes add-on versions (latest stable)
  addon_versions = {
    vpc_cni              = "v1.15.1-eksbuild.1"
    kube_proxy           = "v1.28.2-eksbuild.2"
    coredns              = "v1.10.1-eksbuild.5"
    ebs_csi_driver       = "v1.24.0-eksbuild.1"
    aws_load_balancer    = "v2.6.1"
    cluster_autoscaler   = "v1.28.2"
    external_dns         = "v0.13.6"
  }

  # Security and compliance settings
  security_config = {
    encrypt_secrets           = true
    enable_envelope_encryption = true
    enable_cluster_logging    = true
    cluster_log_types         = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
    endpoint_private_access   = true
    endpoint_public_access    = true
    public_access_cidrs       = ["0.0.0.0/0"]  # Restrict this in production
  }

  # Cost monitoring thresholds
  cost_thresholds = {
    dev     = 50   # $50/month
    staging = 75   # $75/month
    prod    = 200  # $200/month
  }

  # Backup and disaster recovery settings
  backup_config = {
    retention_days = var.environment == "prod" ? 30 : 7
    backup_window  = "03:00-04:00"
    maintenance_window = "sun:04:00-sun:05:00"
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}