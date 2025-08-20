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
  description = "Kubernetes namespace for Tekton"
  type        = string
  default     = "tekton-pipelines"
}

variable "tekton_version" {
  description = "Tekton Pipelines Helm chart version"
  type        = string
  default     = "0.59.0"
}

variable "tekton_triggers_version" {
  description = "Tekton Triggers Helm chart version"
  type        = string
  default     = "0.25.0"
}

variable "tekton_dashboard_version" {
  description = "Tekton Dashboard Helm chart version"
  type        = string
  default     = "0.40.0"
}

variable "dashboard_domain" {
  description = "Domain for Tekton Dashboard access"
  type        = string
  default     = ""
}

variable "enable_tls" {
  description = "Enable TLS for Tekton Dashboard"
  type        = bool
  default     = true
}

variable "enable_monitoring" {
  description = "Enable monitoring for Tekton"
  type        = bool
  default     = true
}

variable "storage_class" {
  description = "Storage class for Tekton PVCs"
  type        = string
  default     = "gp3"
}

variable "artifacts_bucket" {
  description = "S3 bucket name for build artifacts"
  type        = string
}

variable "create_artifacts_bucket" {
  description = "Whether to create the artifacts S3 bucket"
  type        = bool
  default     = true
}

variable "docker_registry_secret" {
  description = "Docker registry credentials JSON"
  type        = string
  default     = ""
  sensitive   = true
}

variable "github_webhook_secret" {
  description = "GitHub webhook secret token"
  type        = string
  default     = ""
  sensitive   = true
}

variable "github_token" {
  description = "GitHub personal access token"
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

variable "tags" {
  description = "Tags to apply to AWS resources"
  type        = map(string)
  default     = {}
}
