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

# ===================================
# Workflow 3: LGTM Observability Stack Variables
# ===================================

variable "observability_namespace" {
  description = "Kubernetes namespace for observability components"
  type        = string
  default     = "observability"
}

# Grafana configuration
variable "grafana_admin_password" {
  description = "Grafana admin password"
  type        = string
  default     = "admin123!"
  sensitive   = true
}

variable "grafana_domain" {
  description = "Domain for Grafana access"
  type        = string
  default     = ""
}

variable "enable_grafana_alerts" {
  description = "Enable Grafana alerting"
  type        = bool
  default     = true
}

variable "slack_webhook_url" {
  description = "Slack webhook URL for alerts"
  type        = string
  default     = ""
  sensitive   = true
}

# Component toggles
variable "enable_prometheus" {
  description = "Enable Prometheus for metrics collection"
  type        = bool
  default     = true
}

variable "enable_mimir" {
  description = "Enable Mimir for long-term metrics storage"
  type        = bool
  default     = true
}

variable "enable_loki" {
  description = "Enable Loki for log aggregation"
  type        = bool
  default     = true
}

variable "enable_tempo" {
  description = "Enable Tempo for distributed tracing"
  type        = bool
  default     = true
}

# Storage configuration
variable "prometheus_storage_size" {
  description = "Prometheus storage size"
  type        = string
  default     = "20Gi"
}

variable "grafana_storage_size" {
  description = "Grafana storage size"
  type        = string
  default     = "10Gi"
}

variable "prometheus_retention" {
  description = "Prometheus data retention period"
  type        = string
  default     = "7d"
}

# S3 lifecycle configuration
variable "s3_lifecycle_enabled" {
  description = "Enable S3 lifecycle policies"
  type        = bool
  default     = true
}

variable "s3_transition_days" {
  description = "Days before transitioning to cold storage"
  type        = number
  default     = 7
}

variable "s3_expiration_days" {
  description = "Days before object expiration"
  type        = number
  default     = 365
}

# Resource configuration
variable "prometheus_resources" {
  description = "Prometheus resource requests and limits"
  type = object({
    requests = object({
      cpu    = string
      memory = string
    })
    limits = object({
      cpu    = string
      memory = string
    })
  })
  default = {
    requests = {
      cpu    = "400m"
      memory = "1024Mi"
    }
    limits = {
      cpu    = "800m"
      memory = "2048Mi"
    }
  }
}

variable "grafana_resources" {
  description = "Grafana resource requests and limits"
  type = object({
    requests = object({
      cpu    = string
      memory = string
    })
    limits = object({
      cpu    = string
      memory = string
    })
  })
  default = {
    requests = {
      cpu    = "100m"
      memory = "256Mi"
    }
    limits = {
      cpu    = "200m"
      memory = "512Mi"
    }
  }
}

variable "mimir_resources" {
  description = "Mimir resource requests and limits"
  type = object({
    requests = object({
      cpu    = string
      memory = string
    })
    limits = object({
      cpu    = string
      memory = string
    })
  })
  default = {
    requests = {
      cpu    = "300m"
      memory = "512Mi"
    }
    limits = {
      cpu    = "600m"
      memory = "1024Mi"
    }
  }
}

variable "loki_resources" {
  description = "Loki resource requests and limits"
  type = object({
    requests = object({
      cpu    = string
      memory = string
    })
    limits = object({
      cpu    = string
      memory = string
    })
  })
  default = {
    requests = {
      cpu    = "200m"
      memory = "512Mi"
    }
    limits = {
      cpu    = "400m"
      memory = "1024Mi"
    }
  }
}

variable "tempo_resources" {
  description = "Tempo resource requests and limits"
  type = object({
    requests = object({
      cpu    = string
      memory = string
    })
    limits = object({
      cpu    = string
      memory = string
    })
  })
  default = {
    requests = {
      cpu    = "150m"
      memory = "256Mi"
    }
    limits = {
      cpu    = "300m"
      memory = "512Mi"
    }
  }
}

