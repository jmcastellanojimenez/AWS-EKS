# Ingress Module Variables

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

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "domain_name" {
  description = "Primary domain name"
  type        = string
}

variable "domain_filters" {
  description = "Domain filters for external-dns"
  type        = list(string)
  default     = []
}

variable "letsencrypt_email" {
  description = "Email for Let's Encrypt certificates"
  type        = string
}

variable "cloudflare_email" {
  description = "Cloudflare account email"
  type        = string
}

variable "cloudflare_api_token" {
  description = "Cloudflare API token"
  type        = string
  sensitive   = true
}

variable "cert_manager_version" {
  description = "cert-manager Helm chart version"
  type        = string
  default     = "v1.13.2"
}

variable "external_dns_version" {
  description = "external-dns Helm chart version"
  type        = string
  default     = "1.13.1"
}

variable "ambassador_version" {
  description = "Ambassador Helm chart version"
  type        = string
  default     = "8.8.2"
}

variable "ambassador_replica_count" {
  description = "Number of Ambassador replicas"
  type        = number
  default     = 2
}

variable "ambassador_max_replicas" {
  description = "Maximum number of Ambassador replicas for autoscaling"
  type        = number
  default     = 5
}

variable "enable_ambassador_dev_portal" {
  description = "Enable Ambassador Developer Portal"
  type        = bool
  default     = false
}

variable "enable_rate_limiting" {
  description = "Enable rate limiting"
  type        = bool
  default     = true
}

variable "enable_circuit_breakers" {
  description = "Enable circuit breakers"
  type        = bool
  default     = true
}