variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name (dev/staging/prod)"
  type        = string
}

variable "cert_manager_version" {
  description = "cert-manager Helm chart version"
  type        = string
  default     = "v1.13.3"
}

variable "enable_letsencrypt" {
  description = "Enable Let's Encrypt ClusterIssuers"
  type        = bool
  default     = true
}

variable "letsencrypt_email" {
  description = "Email address for Let's Encrypt registration"
  type        = string
  default     = "admin@example.com"
}

variable "enable_monitoring" {
  description = "Enable Prometheus monitoring for cert-manager"
  type        = bool
  default     = false
}