variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name (dev/staging/prod)"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace for Tekton"
  type        = string
  default     = "tekton-pipelines"
}

variable "tekton_version" {
  description = "Tekton Pipelines version"
  type        = string
  default     = "v0.53.0"
}

variable "tekton_triggers_version" {
  description = "Tekton Triggers version"
  type        = string
  default     = "v0.25.0"
}

variable "tekton_dashboard_version" {
  description = "Tekton Dashboard version"
  type        = string
  default     = "v0.40.0"
}

variable "enable_dashboard" {
  description = "Enable Tekton Dashboard"
  type        = bool
  default     = true
}

variable "enable_triggers" {
  description = "Enable Tekton Triggers"
  type        = bool
  default     = true
}

variable "enable_monitoring" {
  description = "Enable Prometheus monitoring for Tekton"
  type        = bool
  default     = true
}

variable "container_registry" {
  description = "Container registry configuration"
  type = object({
    url      = string
    username = optional(string, "")
    password = optional(string, "")
    region   = optional(string, "us-east-1")
  })
}

variable "github_config" {
  description = "GitHub integration configuration"
  type = object({
    webhook_secret = string
    token          = optional(string, "")
    app_id         = optional(string, "")
    private_key    = optional(string, "")
  })
  sensitive = true
}

variable "pipeline_config" {
  description = "Pipeline configuration settings"
  type = object({
    default_timeout        = optional(string, "1h")
    default_service_account = optional(string, "tekton-pipeline")
    enable_api_fields      = optional(string, "beta")
    enable_tekton_oci_bundles = optional(bool, true)
    enable_custom_tasks    = optional(bool, true)
    enable_provenance      = optional(bool, true)
  })
  default = {}
}

variable "resource_limits" {
  description = "Resource limits for Tekton components"
  type = object({
    controller = optional(object({
      cpu_request    = optional(string, "100m")
      memory_request = optional(string, "100Mi")
      cpu_limit      = optional(string, "1000m")
      memory_limit   = optional(string, "1Gi")
    }), {})
    webhook = optional(object({
      cpu_request    = optional(string, "100m")
      memory_request = optional(string, "100Mi")
      cpu_limit      = optional(string, "500m")
      memory_limit   = optional(string, "500Mi")
    }), {})
    dashboard = optional(object({
      cpu_request    = optional(string, "100m")
      memory_request = optional(string, "100Mi")
      cpu_limit      = optional(string, "500m")
      memory_limit   = optional(string, "500Mi")
    }), {})
  })
  default = {}
}

variable "storage_config" {
  description = "Storage configuration for Tekton workspaces"
  type = object({
    storage_class = optional(string, "gp3")
    cache_size    = optional(string, "10Gi")
    workspace_size = optional(string, "5Gi")
  })
  default = {}
}

variable "security_config" {
  description = "Security configuration for Tekton"
  type = object({
    enable_pod_security_standards = optional(bool, true)
    enable_network_policies      = optional(bool, true)
    run_as_non_root             = optional(bool, true)
    read_only_root_filesystem   = optional(bool, true)
  })
  default = {}
}

variable "webhook_config" {
  description = "Webhook configuration for Tekton Triggers"
  type = object({
    hostname     = optional(string, "")
    path_prefix  = optional(string, "/webhooks")
    enable_tls   = optional(bool, true)
    port         = optional(number, 8443)
  })
  default = {}
}

variable "service_account_annotations" {
  description = "Annotations for Tekton service accounts (for IRSA)"
  type        = map(string)
  default     = {}
}

variable "additional_labels" {
  description = "Additional labels to apply to all Tekton resources"
  type        = map(string)
  default     = {}
}

variable "additional_annotations" {
  description = "Additional annotations to apply to all Tekton resources"
  type        = map(string)
  default     = {}
}

variable "log_level" {
  description = "Log level for Tekton components (debug, info, warn, error)"
  type        = string
  default     = "info"
  
  validation {
    condition     = contains(["debug", "info", "warn", "error"], var.log_level)
    error_message = "Log level must be one of: debug, info, warn, error."
  }
}

variable "enable_ingress" {
  description = "Enable ingress for Tekton Dashboard"
  type        = bool
  default     = true
}

variable "ingress_class" {
  description = "Ingress class for Tekton Dashboard"
  type        = string
  default     = "ambassador"
}

variable "dashboard_hostname" {
  description = "Hostname for Tekton Dashboard access"
  type        = string
  default     = ""
}

variable "enable_rbac" {
  description = "Enable RBAC for Tekton"
  type        = bool
  default     = true
}

variable "custom_tasks" {
  description = "Custom task definitions to create"
  type = list(object({
    name        = string
    description = optional(string, "")
    image       = string
    script      = optional(string, "")
    params      = optional(list(object({
      name        = string
      type        = optional(string, "string")
      description = optional(string, "")
      default     = optional(string, "")
    })), [])
    workspaces = optional(list(object({
      name        = string
      description = optional(string, "")
      optional    = optional(bool, false)
    })), [])
    results = optional(list(object({
      name        = string
      description = optional(string, "")
    })), [])
  }))
  default = []
}

variable "pipeline_templates" {
  description = "Pipeline templates to create"
  type = list(object({
    name        = string
    description = optional(string, "")
    params      = optional(list(object({
      name        = string
      type        = optional(string, "string")
      description = optional(string, "")
      default     = optional(string, "")
    })), [])
    workspaces = optional(list(object({
      name        = string
      description = optional(string, "")
      optional    = optional(bool, false)
    })), [])
    tasks = list(object({
      name     = string
      taskRef  = string
      params   = optional(map(string), {})
      runAfter = optional(list(string), [])
    }))
  }))
  default = []
}

variable "notification_config" {
  description = "Notification configuration for pipeline events"
  type = object({
    slack_webhook_url = optional(string, "")
    email_smtp_host   = optional(string, "")
    email_smtp_port   = optional(number, 587)
    email_from        = optional(string, "")
  })
  default = {}
}

variable "performance_config" {
  description = "Performance tuning configuration"
  type = object({
    max_concurrent_pipelines = optional(number, 10)
    pipeline_timeout         = optional(string, "1h")
    task_timeout            = optional(string, "30m")
    enable_caching          = optional(bool, true)
  })
  default = {}
}