variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name (dev/staging/prod)"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace for ArgoCD"
  type        = string
  default     = "argocd"
}

variable "argocd_version" {
  description = "ArgoCD Helm chart version"
  type        = string
  default     = "5.51.6"
}

variable "replica_count" {
  description = "Number of ArgoCD server replicas for high availability"
  type        = number
  default     = 2
  
  validation {
    condition     = var.replica_count >= 1 && var.replica_count <= 5
    error_message = "Replica count must be between 1 and 5."
  }
}

variable "hostname" {
  description = "Hostname for ArgoCD UI access"
  type        = string
  default     = ""
}

variable "enable_tls" {
  description = "Enable TLS for ArgoCD UI"
  type        = bool
  default     = true
}

variable "admin_password" {
  description = "Initial admin password for ArgoCD (will be bcrypt hashed)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "enable_dex" {
  description = "Enable Dex for OIDC authentication"
  type        = bool
  default     = false
}

variable "dex_config" {
  description = "Dex OIDC configuration"
  type = object({
    issuer_url    = optional(string, "")
    client_id     = optional(string, "")
    client_secret = optional(string, "")
  })
  default = {}
}

variable "rbac_config" {
  description = "RBAC configuration for ArgoCD"
  type        = string
  default     = ""
}

variable "enable_monitoring" {
  description = "Enable Prometheus monitoring for ArgoCD"
  type        = bool
  default     = true
}

variable "enable_notifications" {
  description = "Enable ArgoCD notifications controller"
  type        = bool
  default     = true
}

variable "notification_config" {
  description = "Notification configuration for ArgoCD"
  type = object({
    slack_token   = optional(string, "")
    slack_channel = optional(string, "")
    email_host    = optional(string, "")
    email_port    = optional(number, 587)
    email_from    = optional(string, "")
  })
  default = {}
}

variable "repository_credentials" {
  description = "Git repository credentials for ArgoCD"
  type = list(object({
    url      = string
    username = optional(string, "")
    password = optional(string, "")
    ssh_key  = optional(string, "")
  }))
  default   = []
  sensitive = true
}

variable "application_projects" {
  description = "ArgoCD application projects configuration"
  type = list(object({
    name                = string
    description         = optional(string, "")
    source_repos        = list(string)
    destinations        = list(object({
      namespace = string
      server    = optional(string, "https://kubernetes.default.svc")
    }))
    cluster_resource_whitelist = optional(list(object({
      group = string
      kind  = string
    })), [])
    namespace_resource_whitelist = optional(list(object({
      group = string
      kind  = string
    })), [])
  }))
  default = []
}

variable "sync_windows" {
  description = "Sync windows configuration for controlled deployments"
  type = list(object({
    kind         = string
    schedule     = string
    duration     = string
    applications = list(string)
    manual_sync  = optional(bool, true)
  }))
  default = []
}

variable "resource_customizations" {
  description = "Custom resource configurations for ArgoCD"
  type        = string
  default     = ""
}

variable "server_config" {
  description = "ArgoCD server configuration"
  type = object({
    url                     = optional(string, "")
    insecure                = optional(bool, false)
    grpc_web                = optional(bool, true)
    disable_auth            = optional(bool, false)
    enable_proxy_extension  = optional(bool, false)
  })
  default = {}
}

variable "controller_config" {
  description = "ArgoCD application controller configuration"
  type = object({
    operation_processors    = optional(number, 10)
    status_processors      = optional(number, 20)
    app_resync_period      = optional(string, "180s")
    repo_server_timeout    = optional(string, "60s")
  })
  default = {}
}

variable "repo_server_config" {
  description = "ArgoCD repository server configuration"
  type = object({
    parallelism_limit = optional(number, 0)
    timeout           = optional(string, "60s")
  })
  default = {}
}

variable "redis_ha_enabled" {
  description = "Enable Redis HA for ArgoCD"
  type        = bool
  default     = true
}

variable "enable_applicationset" {
  description = "Enable ApplicationSet controller"
  type        = bool
  default     = true
}

variable "service_account_annotations" {
  description = "Annotations for ArgoCD service accounts (for IRSA)"
  type        = map(string)
  default     = {}
}

variable "additional_labels" {
  description = "Additional labels to apply to all ArgoCD resources"
  type        = map(string)
  default     = {}
}

variable "additional_annotations" {
  description = "Additional annotations to apply to all ArgoCD resources"
  type        = map(string)
  default     = {}
}

variable "log_level" {
  description = "Log level for ArgoCD components (debug, info, warn, error)"
  type        = string
  default     = "info"
  
  validation {
    condition     = contains(["debug", "info", "warn", "error"], var.log_level)
    error_message = "Log level must be one of: debug, info, warn, error."
  }
}

variable "enable_ingress" {
  description = "Enable ingress for ArgoCD server"
  type        = bool
  default     = true
}

variable "ingress_class" {
  description = "Ingress class for ArgoCD"
  type        = string
  default     = "ambassador"
}

variable "storage_class" {
  description = "Storage class for ArgoCD persistent volumes"
  type        = string
  default     = "gp3"
}

variable "storage_size" {
  description = "Storage size for ArgoCD persistent volumes"
  type        = string
  default     = "10Gi"
}