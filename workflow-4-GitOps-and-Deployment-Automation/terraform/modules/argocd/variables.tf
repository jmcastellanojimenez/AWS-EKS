variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
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
  description = "Number of ArgoCD server replicas"
  type        = number
  default     = 2
}

variable "domain" {
  description = "Domain for ArgoCD access"
  type        = string
  default     = ""
}

variable "enable_tls" {
  description = "Enable TLS for ArgoCD"
  type        = bool
  default     = true
}

variable "admin_password" {
  description = "ArgoCD admin password"
  type        = string
  default     = ""
  sensitive   = true
}

variable "enable_notifications" {
  description = "Enable ArgoCD notifications"
  type        = bool
  default     = true
}

variable "slack_webhook_url" {
  description = "Slack webhook URL for notifications"
  type        = string
  default     = ""
  sensitive   = true
}

variable "git_url" {
  description = "Git repository URL"
  type        = string
  default     = ""
}

variable "git_username" {
  description = "Git username for repository access"
  type        = string
  default     = ""
}

variable "git_token" {
  description = "Git token for repository access"
  type        = string
  default     = ""
  sensitive   = true
}

variable "oidc_provider_arn" {
  description = "EKS OIDC provider ARN"
  type        = string
}

variable "oidc_provider_url" {
  description = "EKS OIDC provider URL"
  type        = string
}

variable "enable_monitoring" {
  description = "Enable monitoring for ArgoCD"
  type        = bool
  default     = true
}

variable "storage_class" {
  description = "Storage class for ArgoCD PVCs"
  type        = string
  default     = "gp3"
}

variable "storage_size" {
  description = "Storage size for ArgoCD"
  type        = string
  default     = "10Gi"
}

variable "tags" {
  description = "Tags to apply to AWS resources"
  type        = map(string)
  default     = {}
}
