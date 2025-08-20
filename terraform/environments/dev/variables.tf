# Development Environment Variables

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "eks-platform"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "owner" {
  description = "Owner of the resources"
  type        = string
  default     = "platform-team"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "availability_zones_count" {
  description = "Number of availability zones to use"
  type        = number
  default     = 3
}

# Networking
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
}

variable "single_nat_gateway" {
  description = "Use single NAT gateway for cost optimization"
  type        = bool
  default     = true
}

# EKS Configuration
variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.28"
}

# Domain and DNS
variable "domain_name" {
  description = "Primary domain name"
  type        = string
  default     = "example.com"
}

variable "letsencrypt_email" {
  description = "Email for Let's Encrypt certificates"
  type        = string
  default     = "admin@example.com"
}

variable "cloudflare_email" {
  description = "Cloudflare account email"
  type        = string
  default     = "admin@example.com"
}

variable "cloudflare_api_token" {
  description = "Cloudflare API token"
  type        = string
  sensitive   = true
  default     = "placeholder-token"
}

# Observability
variable "grafana_admin_password" {
  description = "Grafana admin password"
  type        = string
  sensitive   = true
  default     = "admin123"
}

# GitOps
variable "gitops_repo_url" {
  description = "GitOps repository URL"
  type        = string
  default     = "https://github.com/your-org/gitops-config"
}

variable "gitops_repo_branch" {
  description = "GitOps repository branch"
  type        = string
  default     = "main"
}

# Slack Integration (Optional)
variable "slack_webhook_url" {
  description = "Slack webhook URL for notifications"
  type        = string
  default     = ""
  sensitive   = true
}

# Database Configuration
variable "postgres_password" {
  description = "PostgreSQL password"
  type        = string
  sensitive   = true
  default     = "secure-postgres-password"
}

variable "postgres_backup_access_key" {
  description = "AWS access key for PostgreSQL backups"
  type        = string
  sensitive   = true
  default     = ""
}

variable "postgres_backup_secret_key" {
  description = "AWS secret key for PostgreSQL backups"
  type        = string
  sensitive   = true
  default     = ""
}

# Ingress Stack Variables
variable "ingress_domain" {
  description = "Domain for ingress configuration"
  type        = string
  default     = ""
}

variable "cert_manager_version" {
  description = "cert-manager version"
  type        = string
  default     = "v1.13.0"
}

variable "enable_letsencrypt" {
  description = "Enable Let's Encrypt certificates"
  type        = bool
  default     = true
}

variable "enable_monitoring" {
  description = "Enable monitoring for components"
  type        = bool
  default     = true
}

variable "external_dns_version" {
  description = "external-dns version"
  type        = string
  default     = "6.28.6"
}

variable "dns_provider" {
  description = "DNS provider for external-dns"
  type        = string
  default     = "cloudflare"
}

variable "domain_filters" {
  description = "Domain filters for external-dns"
  type        = list(string)
  default     = []
}

variable "external_dns_role_arn" {
  description = "External DNS IAM role ARN"
  type        = string
  default     = ""
}

variable "ambassador_version" {
  description = "Ambassador version"
  type        = string
  default     = "8.9.1"
}

variable "ambassador_replica_count" {
  description = "Number of Ambassador replicas"
  type        = number
  default     = 2
}

variable "load_balancer_scheme" {
  description = "Load balancer scheme"
  type        = string
  default     = "internet-facing"
}

variable "enable_tls" {
  description = "Enable TLS for Ambassador"
  type        = bool
  default     = true
}

variable "cors_origins" {
  description = "CORS origins for Ambassador"
  type        = list(string)
  default     = ["*"]
}

# LGTM Observability Variables
variable "observability_namespace" {
  description = "Namespace for observability components"
  type        = string
  default     = "observability"
}

variable "grafana_domain" {
  description = "Grafana domain"
  type        = string
  default     = ""
}

variable "enable_grafana_alerts" {
  description = "Enable Grafana alerts"
  type        = bool
  default     = true
}

variable "enable_prometheus" {
  description = "Enable Prometheus"
  type        = bool
  default     = true
}

variable "enable_mimir" {
  description = "Enable Mimir"
  type        = bool
  default     = false
}

variable "enable_loki" {
  description = "Enable Loki"
  type        = bool
  default     = true
}

variable "enable_tempo" {
  description = "Enable Tempo"
  type        = bool
  default     = true
}

variable "prometheus_resources" {
  description = "Resource limits for Prometheus"
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
      memory = "128Mi"
    }
    limits = {
      cpu    = "500m"
      memory = "512Mi"
    }
  }
}

variable "grafana_resources" {
  description = "Resource limits for Grafana"
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
      memory = "128Mi"
    }
    limits = {
      cpu    = "200m"
      memory = "256Mi"
    }
  }
}

variable "mimir_resources" {
  description = "Resource limits for Mimir"
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
      memory = "128Mi"
    }
    limits = {
      cpu    = "500m"
      memory = "512Mi"
    }
  }
}

variable "loki_resources" {
  description = "Resource limits for Loki"
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
      memory = "128Mi"
    }
    limits = {
      cpu    = "500m"
      memory = "512Mi"
    }
  }
}

variable "tempo_resources" {
  description = "Resource limits for Tempo"
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
      memory = "128Mi"
    }
    limits = {
      cpu    = "500m"
      memory = "512Mi"
    }
  }
}

variable "prometheus_storage_size" {
  description = "Storage size for Prometheus"
  type        = string
  default     = "10Gi"
}

variable "grafana_storage_size" {
  description = "Storage size for Grafana"
  type        = string
  default     = "5Gi"
}

variable "prometheus_retention" {
  description = "Prometheus retention period"
  type        = string
  default     = "15d"
}

variable "s3_lifecycle_enabled" {
  description = "Enable S3 lifecycle for observability"
  type        = bool
  default     = true
}

variable "s3_transition_days" {
  description = "Days before transitioning to IA storage"
  type        = number
  default     = 30
}

variable "s3_expiration_days" {
  description = "Days before expiring objects"
  type        = number
  default     = 365
}