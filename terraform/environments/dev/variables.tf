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
  default     = ["t3.large"]
}

variable "capacity_type" {
  description = "Type of capacity associated with the EKS Node Group"
  type        = string
  default     = "SPOT"
}

variable "desired_capacity" {
  description = "Desired number of nodes"
  type        = number
  default     = 3
}

variable "min_capacity" {
  description = "Minimum number of nodes"
  type        = number
  default     = 3
}

variable "max_capacity" {
  description = "Maximum number of nodes"
  type        = number
  default     = 5
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

# ===================================
# Workflow 2: Ingress + API Gateway Stack Variables
# ===================================

variable "ingress_domain" {
  description = "Primary domain for ingress and API gateway"
  type        = string
  default     = ""
}

variable "enable_monitoring" {
  description = "Enable Prometheus monitoring for all components"
  type        = bool
  default     = false
}

# cert-manager variables
variable "cert_manager_version" {
  description = "cert-manager Helm chart version"
  type        = string
  default     = "v1.13.3"
}

variable "enable_letsencrypt" {
  description = "Enable Let's Encrypt certificate issuers"
  type        = bool
  default     = true
}

variable "letsencrypt_email" {
  description = "Email for Let's Encrypt certificate registration"
  type        = string
  default     = "admin@example.com"
}

# external-dns variables
variable "external_dns_version" {
  description = "external-dns Helm chart version"
  type        = string
  default     = "1.14.3"
}

variable "dns_provider" {
  description = "DNS provider (cloudflare, aws, google, azure)"
  type        = string
  default     = "cloudflare"
}

variable "domain_filters" {
  description = "Domains that external-dns will manage"
  type        = list(string)
  default     = []
}

variable "cloudflare_api_token" {
  description = "Cloudflare API token (sensitive)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "external_dns_role_arn" {
  description = "IAM role ARN for external-dns (if using AWS Route53)"
  type        = string
  default     = ""
}

# Ambassador variables
variable "ambassador_version" {
  description = "Ambassador (Emissary-Ingress) Helm chart version"
  type        = string
  default     = "8.9.1"
}

variable "ambassador_replica_count" {
  description = "Number of Ambassador replicas for high availability"
  type        = number
  default     = 2
}

variable "load_balancer_scheme" {
  description = "AWS Load Balancer scheme (internet-facing or internal)"
  type        = string
  default     = "internet-facing"
}

variable "enable_tls" {
  description = "Enable automatic TLS certificate management"
  type        = bool
  default     = true
}

variable "cors_origins" {
  description = "Allowed CORS origins for API Gateway"
  type        = list(string)
  default     = ["*"]
}

