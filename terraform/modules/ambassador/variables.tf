variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name (dev/staging/prod)"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace for Ambassador"
  type        = string
  default     = "ambassador"
}

variable "ambassador_version" {
  description = "Ambassador (Emissary-Ingress) Helm chart version"
  type        = string
  default     = "8.9.1"
}

variable "ambassador_id" {
  description = "Ambassador instance identifier for multi-tenancy"
  type        = string
  default     = "default"
}

variable "replica_count" {
  description = "Number of Ambassador replicas for high availability"
  type        = number
  default     = 2
  
  validation {
    condition     = var.replica_count >= 1 && var.replica_count <= 5
    error_message = "Replica count must be between 1 and 5."
  }
}

variable "hostname" {
  description = "Primary hostname for the API Gateway"
  type        = string
  default     = ""
}

variable "load_balancer_scheme" {
  description = "AWS Load Balancer scheme (internet-facing or internal)"
  type        = string
  default     = "internet-facing"
  
  validation {
    condition     = contains(["internet-facing", "internal"], var.load_balancer_scheme)
    error_message = "Load balancer scheme must be either 'internet-facing' or 'internal'."
  }
}

variable "service_annotations" {
  description = "Additional annotations for the Ambassador service"
  type        = map(string)
  default     = {}
}

variable "enable_tls" {
  description = "Enable automatic TLS certificate management"
  type        = bool
  default     = true
}

variable "acme_provider_authority" {
  description = "ACME provider authority URL (Let's Encrypt)"
  type        = string
  default     = "https://acme-v02.api.letsencrypt.org/directory"
}

variable "acme_email" {
  description = "Email address for ACME certificate registration"
  type        = string
  default     = "admin@example.com"
}

variable "redirect_cleartext_from" {
  description = "Port to redirect cleartext traffic from (0 to disable)"
  type        = number
  default     = 80
}

variable "cors_origins" {
  description = "List of allowed CORS origins"
  type        = list(string)
  default     = ["*"]
}

variable "enable_monitoring" {
  description = "Enable Prometheus monitoring for Ambassador"
  type        = bool
  default     = false
}

variable "enable_admin_service" {
  description = "Enable Ambassador admin service"
  type        = bool
  default     = true
}

variable "log_level" {
  description = "Log level for Ambassador (debug, info, warn, error)"
  type        = string
  default     = "info"
  
  validation {
    condition     = contains(["debug", "info", "warn", "error"], var.log_level)
    error_message = "Log level must be one of: debug, info, warn, error."
  }
}

variable "additional_hosts" {
  description = "Additional hostnames to configure"
  type        = list(string)
  default     = []
}

variable "default_timeout" {
  description = "Default timeout for Ambassador requests (in seconds)"
  type        = number
  default     = 30
}