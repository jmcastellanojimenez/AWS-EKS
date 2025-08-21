# ==============================================================================
# LGTM Observability Stack Variables
# ==============================================================================

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "cluster_endpoint" {
  description = "EKS cluster endpoint URL"
  type        = string
}

variable "cluster_certificate_authority_data" {
  description = "EKS cluster certificate authority data"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "namespace" {
  description = "Kubernetes namespace for observability components"
  type        = string
  default     = "observability"
}

variable "oidc_provider_arn" {
  description = "ARN of the OIDC provider for IRSA"
  type        = string
}

variable "aws_region" {
  description = "AWS region for S3 buckets and other resources"
  type        = string
}

variable "aws_account_id" {
  description = "AWS Account ID for resource naming"
  type        = string
}

# ==============================================================================
# Grafana Configuration
# ==============================================================================

variable "grafana_admin_password" {
  description = "Grafana admin password"
  type        = string
  default     = "admin"
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

# ==============================================================================
# Resource Configuration
# ==============================================================================

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

# ==============================================================================
# S3 Storage Configuration
# ==============================================================================

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

# ==============================================================================
# Component Toggles
# ==============================================================================

variable "enable_mimir" {
  description = "Enable Mimir for long-term metrics storage"
  type        = bool
  default     = false  # Disabled by default for stability
}

variable "enable_loki" {
  description = "Enable Loki for log aggregation"
  type        = bool
  default     = false  # Disabled by default for stability
}

variable "enable_tempo" {
  description = "Enable Tempo for distributed tracing"
  type        = bool
  default     = false  # Disabled by default for stability
}

variable "enable_prometheus" {
  description = "Enable Prometheus for metrics collection"
  type        = bool
  default     = true
}

variable "enable_grafana" {
  description = "Enable Grafana for dashboards and visualization"
  type        = bool
  default     = true
}

# ==============================================================================
# Resource Limits
# ==============================================================================

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

# ==============================================================================
# Tags
# ==============================================================================

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default = {
    Terraform = "true"
    Project   = "EKS-LGTM-Observability"
  }
}