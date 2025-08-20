# GitOps Module Variables

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "domain_name" {
  description = "Primary domain name"
  type        = string
}

# ArgoCD Configuration
variable "argocd_version" {
  description = "ArgoCD Helm chart version"
  type        = string
  default     = "5.51.4"
}

variable "argocd_admin_password" {
  description = "ArgoCD admin password"
  type        = string
  sensitive   = true
  default     = ""
}

# Tekton Configuration
variable "tekton_version" {
  description = "Tekton Pipelines Helm chart version"
  type        = string
  default     = "1.2.0"
}

variable "tekton_triggers_version" {
  description = "Tekton Triggers Helm chart version"
  type        = string
  default     = "0.21.1"
}

# GitOps Repository Configuration
variable "gitops_repo_url" {
  description = "GitOps repository URL"
  type        = string
}

variable "gitops_repo_branch" {
  description = "GitOps repository branch"
  type        = string
  default     = "main"
}

variable "gitops_repo_path" {
  description = "Path in GitOps repository for applications"
  type        = string
  default     = "applications"
}

# GitHub Integration
variable "enable_github_webhooks" {
  description = "Enable GitHub webhook integration"
  type        = bool
  default     = false
}

variable "github_webhook_secret" {
  description = "GitHub webhook secret"
  type        = string
  sensitive   = true
  default     = ""
}

# Container Registry Configuration
variable "container_registry" {
  description = "Container registry URL"
  type        = string
  default     = "ghcr.io"
}

variable "registry_credentials_secret" {
  description = "Container registry credentials secret name"
  type        = string
  default     = "registry-credentials"
}

# CI/CD Configuration
variable "enable_security_scanning" {
  description = "Enable security scanning in pipelines"
  type        = bool
  default     = true
}

variable "enable_image_signing" {
  description = "Enable container image signing"
  type        = bool
  default     = false
}

variable "build_timeout" {
  description = "Build timeout in minutes"
  type        = number
  default     = 30
}

# Resource Configuration
variable "argocd_resources" {
  description = "Resource configuration for ArgoCD components"
  type = object({
    controller = object({
      requests = object({
        cpu    = string
        memory = string
      })
      limits = object({
        cpu    = string
        memory = string
      })
    })
    server = object({
      requests = object({
        cpu    = string
        memory = string
      })
      limits = object({
        cpu    = string
        memory = string
      })
    })
    repo_server = object({
      requests = object({
        cpu    = string
        memory = string
      })
      limits = object({
        cpu    = string
        memory = string
      })
    })
  })
  default = {
    controller = {
      requests = {
        cpu    = "250m"
        memory = "512Mi"
      }
      limits = {
        cpu    = "2"
        memory = "2Gi"
      }
    }
    server = {
      requests = {
        cpu    = "100m"
        memory = "128Mi"
      }
      limits = {
        cpu    = "500m"
        memory = "512Mi"
      }
    }
    repo_server = {
      requests = {
        cpu    = "100m"
        memory = "256Mi"
      }
      limits = {
        cpu    = "1"
        memory = "1Gi"
      }
    }
  }
}

variable "tekton_resources" {
  description = "Resource configuration for Tekton components"
  type = object({
    controller = object({
      requests = object({
        cpu    = string
        memory = string
      })
      limits = object({
        cpu    = string
        memory = string
      })
    })
    webhook = object({
      requests = object({
        cpu    = string
        memory = string
      })
      limits = object({
        cpu    = string
        memory = string
      })
    })
  })
  default = {
    controller = {
      requests = {
        cpu    = "100m"
        memory = "128Mi"
      }
      limits = {
        cpu    = "1"
        memory = "1Gi"
      }
    }
    webhook = {
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
}