# Observability Module Variables

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

variable "aws_region" {
  description = "AWS region"
  type        = string
}

# S3 Buckets
variable "prometheus_s3_bucket" {
  description = "S3 bucket for Prometheus/Mimir data"
  type        = string
}

variable "loki_s3_bucket" {
  description = "S3 bucket for Loki data"
  type        = string
}

variable "tempo_s3_bucket" {
  description = "S3 bucket for Tempo data"
  type        = string
}

# IRSA Role ARNs
variable "mimir_irsa_role_arn" {
  description = "IAM role ARN for Mimir"
  type        = string
}

variable "loki_irsa_role_arn" {
  description = "IAM role ARN for Loki"
  type        = string
}

variable "tempo_irsa_role_arn" {
  description = "IAM role ARN for Tempo"
  type        = string
}

# Helm Chart Versions
variable "prometheus_stack_version" {
  description = "kube-prometheus-stack Helm chart version"
  type        = string
  default     = "55.5.0"
}

variable "mimir_version" {
  description = "Mimir Helm chart version"
  type        = string
  default     = "5.1.3"
}

variable "loki_version" {
  description = "Loki Helm chart version"
  type        = string
  default     = "5.41.4"
}

variable "promtail_version" {
  description = "Promtail Helm chart version"
  type        = string
  default     = "6.15.3"
}

variable "tempo_version" {
  description = "Tempo Helm chart version"
  type        = string
  default     = "1.7.1"
}

variable "grafana_version" {
  description = "Grafana Helm chart version"
  type        = string
  default     = "7.0.19"
}

variable "opentelemetry_operator_version" {
  description = "OpenTelemetry Operator Helm chart version"
  type        = string
  default     = "0.47.0"
}

# Configuration
variable "grafana_admin_password" {
  description = "Grafana admin password"
  type        = string
  sensitive   = true
  default     = "admin123"
}

variable "prometheus_retention" {
  description = "Prometheus data retention period"
  type        = string
  default     = "15d"
}

variable "prometheus_storage_size" {
  description = "Prometheus storage size"
  type        = string
  default     = "100Gi"
}

variable "enable_grafana_ingress" {
  description = "Enable Grafana ingress"
  type        = bool
  default     = true
}

variable "enable_opentelemetry" {
  description = "Enable OpenTelemetry components"
  type        = bool
  default     = true
}

variable "otel_sampling_rate" {
  description = "OpenTelemetry sampling rate"
  type        = string
  default     = "0.1"
}