# Service Mesh Module Variables

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

# Istio Configuration
variable "istio_version" {
  description = "Istio version"
  type        = string
  default     = "1.19.3"
}

variable "mtls_mode" {
  description = "mTLS mode for service mesh"
  type        = string
  default     = "STRICT"
  validation {
    condition     = contains(["STRICT", "PERMISSIVE", "DISABLE"], var.mtls_mode)
    error_message = "mTLS mode must be STRICT, PERMISSIVE, or DISABLE."
  }
}

variable "trace_sampling_rate" {
  description = "Trace sampling rate (0.0 to 100.0)"
  type        = number
  default     = 1.0
  validation {
    condition     = var.trace_sampling_rate >= 0.0 && var.trace_sampling_rate <= 100.0
    error_message = "Trace sampling rate must be between 0.0 and 100.0."
  }
}

# Gateway Configuration
variable "gateway_min_replicas" {
  description = "Minimum number of gateway replicas"
  type        = number
  default     = 2
}

variable "gateway_max_replicas" {
  description = "Maximum number of gateway replicas"
  type        = number
  default     = 5
}

variable "enable_gateway_autoscaling" {
  description = "Enable gateway autoscaling"
  type        = bool
  default     = true
}

# Observability Integration
variable "enable_kiali" {
  description = "Enable Kiali service mesh observability"
  type        = bool
  default     = true
}

variable "kiali_version" {
  description = "Kiali version"
  type        = string
  default     = "1.75.0"
}

variable "enable_jaeger" {
  description = "Enable Jaeger tracing (alternative to Tempo)"
  type        = bool
  default     = false
}

variable "jaeger_version" {
  description = "Jaeger version"
  type        = string
  default     = "0.71.11"
}

# Traffic Management
variable "enable_traffic_management" {
  description = "Enable advanced traffic management features"
  type        = bool
  default     = true
}

variable "circuit_breaker_enabled" {
  description = "Enable circuit breaker by default"
  type        = bool
  default     = true
}

variable "retry_policy_enabled" {
  description = "Enable retry policies by default"
  type        = bool
  default     = true
}

variable "timeout_policy_enabled" {
  description = "Enable timeout policies by default"
  type        = bool
  default     = true
}

# Security Configuration
variable "enable_authorization_policies" {
  description = "Enable Istio authorization policies"
  type        = bool
  default     = true
}

variable "enable_security_policies" {
  description = "Enable security policies"
  type        = bool
  default     = true
}

variable "jwt_authentication_enabled" {
  description = "Enable JWT authentication"
  type        = bool
  default     = false
}

# Performance Configuration
variable "proxy_resources" {
  description = "Resource configuration for Istio proxy sidecars"
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
      cpu    = "2000m"
      memory = "1024Mi"
    }
  }
}

variable "pilot_resources" {
  description = "Resource configuration for Istio pilot"
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
      memory = "2Gi"
    }
  }
}

# Monitoring Configuration
variable "enable_prometheus_integration" {
  description = "Enable Prometheus metrics collection"
  type        = bool
  default     = true
}

variable "enable_grafana_integration" {
  description = "Enable Grafana dashboard integration"
  type        = bool
  default     = true
}

variable "enable_tempo_integration" {
  description = "Enable Tempo tracing integration"
  type        = bool
  default     = true
}

variable "metrics_retention" {
  description = "Metrics retention period"
  type        = string
  default     = "15d"
}

# Multi-cluster Configuration
variable "enable_multi_cluster" {
  description = "Enable multi-cluster service mesh"
  type        = bool
  default     = false
}

variable "cluster_network" {
  description = "Cluster network identifier for multi-cluster"
  type        = string
  default     = ""
}

variable "mesh_id" {
  description = "Mesh ID for multi-cluster setup"
  type        = string
  default     = ""
}

# Advanced Configuration
variable "enable_wasm_plugins" {
  description = "Enable WebAssembly plugin support"
  type        = bool
  default     = false
}

variable "enable_ambient_mode" {
  description = "Enable Istio ambient mode (experimental)"
  type        = bool
  default     = false
}

variable "proxy_log_level" {
  description = "Log level for Istio proxy sidecars"
  type        = string
  default     = "warning"
  validation {
    condition     = contains(["trace", "debug", "info", "warning", "error", "critical", "off"], var.proxy_log_level)
    error_message = "Proxy log level must be one of: trace, debug, info, warning, error, critical, off."
  }
}

variable "pilot_log_level" {
  description = "Log level for Istio pilot"
  type        = string
  default     = "info"
  validation {
    condition     = contains(["trace", "debug", "info", "warning", "error", "critical", "off"], var.pilot_log_level)
    error_message = "Pilot log level must be one of: trace, debug, info, warning, error, critical, off."
  }
}