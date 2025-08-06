# Import shared variables
variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "eks-learning-lab"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = ""
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.28"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "instance_types" {
  description = "List of EC2 instance types for the node group"
  type        = list(string)
  default     = ["t3.small"]
}

variable "capacity_type" {
  description = "Type of capacity associated with the EKS Node Group"
  type        = string
  default     = "SPOT"
}

variable "desired_capacity" {
  description = "Desired number of nodes"
  type        = number
  default     = 1
}

variable "min_capacity" {
  description = "Minimum number of nodes"
  type        = number
  default     = 1
}

variable "max_capacity" {
  description = "Maximum number of nodes"
  type        = number
  default     = 2
}

variable "node_disk_size" {
  description = "Disk size for worker nodes (in GB)"
  type        = number
  default     = 20
}

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway for private subnets"
  type        = bool
  default     = false
}

variable "enable_vpc_endpoints" {
  description = "Enable VPC endpoints for AWS services"
  type        = bool
  default     = false
}

variable "enable_flow_logs" {
  description = "Enable VPC Flow Logs"
  type        = bool
  default     = false
}

variable "additional_tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# Import locals from shared module
locals {
  # Import shared locals
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    CreatedBy   = "terraform"
    Repository  = "eks-learning-lab"
    Region      = var.aws_region
  }

  cluster_name = var.cluster_name != "" ? var.cluster_name : "${var.project_name}-${var.environment}"

  # Environment-specific cost optimizations
  env_config = {
    enable_nat_gateway   = var.enable_nat_gateway
    enable_vpc_endpoints = var.enable_vpc_endpoints
    enable_flow_logs     = var.enable_flow_logs
    capacity_type        = var.capacity_type
    desired_capacity     = var.desired_capacity
    min_capacity         = var.min_capacity
    max_capacity         = var.max_capacity
    instance_types       = var.instance_types
  }

  # Add-on versions
  addon_versions = {
    vpc_cni              = "v1.15.1-eksbuild.1"
    kube_proxy           = "v1.28.2-eksbuild.2"
    coredns              = "v1.10.1-eksbuild.5"
    ebs_csi_driver       = "v1.24.0-eksbuild.1"
  }

  # Security configuration
  security_config = {
    endpoint_private_access = true
    endpoint_public_access  = true
    public_access_cidrs     = ["0.0.0.0/0"]
    cluster_log_types       = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  }

  # Cost thresholds
  cost_thresholds = {
    dev     = 50
    staging = 75
    prod    = 200
  }
}