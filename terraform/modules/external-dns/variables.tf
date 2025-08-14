variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name (dev/staging/prod)"
  type        = string
}

variable "external_dns_version" {
  description = "external-dns Helm chart version"
  type        = string
  default     = "1.14.3"
}

variable "dns_provider" {
  description = "DNS provider (cloudflare, aws, google, etc.)"
  type        = string
  default     = "cloudflare"
  
  validation {
    condition     = contains(["cloudflare", "aws", "google", "azure"], var.dns_provider)
    error_message = "Supported DNS providers: cloudflare, aws, google, azure."
  }
}

variable "domain_filters" {
  description = "List of domains that external-dns will manage"
  type        = list(string)
  default     = []
}

variable "sources" {
  description = "Sources to monitor for DNS entries"
  type        = list(string)
  default     = ["service", "ingress", "ambassador-host"]
}

variable "sync_policy" {
  description = "How external-dns will modify DNS records (sync, upsert-only)"
  type        = string
  default     = "upsert-only"
}

variable "sync_interval" {
  description = "Interval between DNS synchronizations"
  type        = string
  default     = "1m"
}

variable "log_level" {
  description = "Log level for external-dns"
  type        = string
  default     = "info"
}

variable "txt_prefix" {
  description = "TXT record prefix for DNS ownership tracking"
  type        = string
  default     = "external-dns-"
}

variable "txt_owner_id" {
  description = "Unique identifier for this external-dns instance"
  type        = string
  default     = "eks-foundation"
}

variable "replica_count" {
  description = "Number of external-dns replicas"
  type        = number
  default     = 1
}

variable "enable_monitoring" {
  description = "Enable Prometheus monitoring"
  type        = bool
  default     = false
}

# Cloudflare specific variables
variable "cloudflare_api_token" {
  description = "Cloudflare API token (sensitive)"
  type        = string
  default     = ""
  sensitive   = true
}

# AWS specific variables
variable "aws_region" {
  description = "AWS region for Route53"
  type        = string
  default     = "us-east-1"
}

variable "aws_zone_type" {
  description = "AWS Route53 zone type (public, private)"
  type        = string
  default     = "public"
}

variable "service_account_role_arn" {
  description = "IAM role ARN for external-dns service account (IRSA)"
  type        = string
  default     = ""
}