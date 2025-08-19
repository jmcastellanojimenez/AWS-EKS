# Security Module Variables

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

variable "storage_class" {
  description = "Storage class for persistent volumes"
  type        = string
  default     = "gp3"
}

# External Secrets Configuration
variable "external_secrets_version" {
  description = "External Secrets Operator version"
  type        = string
  default     = "0.9.11"
}

# OpenBao Configuration
variable "openbao_version" {
  description = "OpenBao Helm chart version"
  type        = string
  default     = "0.25.0"
}

variable "openbao_storage_size" {
  description = "OpenBao storage size"
  type        = string
  default     = "10Gi"
}

variable "openbao_replicas" {
  description = "Number of OpenBao replicas"
  type        = number
  default     = 3
}

# OPA Gatekeeper Configuration
variable "gatekeeper_version" {
  description = "OPA Gatekeeper Helm chart version"
  type        = string
  default     = "3.14.0"
}

variable "gatekeeper_replicas" {
  description = "Number of Gatekeeper replicas"
  type        = number
  default     = 3
}

# Falco Configuration
variable "falco_version" {
  description = "Falco Helm chart version"
  type        = string
  default     = "3.8.4"
}

variable "falco_driver_kind" {
  description = "Falco driver kind (ebpf or module)"
  type        = string
  default     = "ebpf"
}

# Notification Configuration
variable "slack_webhook_url" {
  description = "Slack webhook URL for security alerts"
  type        = string
  default     = ""
  sensitive   = true
}

variable "slack_channel" {
  description = "Slack channel for security alerts"
  type        = string
  default     = "#security-alerts"
}

# Policy Configuration
variable "enable_pod_security_policies" {
  description = "Enable Pod Security Policies"
  type        = bool
  default     = true
}

variable "enable_resource_policies" {
  description = "Enable resource requirement policies"
  type        = bool
  default     = true
}

variable "enable_network_policies" {
  description = "Enable network policies"
  type        = bool
  default     = true
}

variable "policy_violation_action" {
  description = "Action for policy violations (warn or deny)"
  type        = string
  default     = "warn"
  validation {
    condition     = contains(["warn", "deny"], var.policy_violation_action)
    error_message = "Policy violation action must be 'warn' or 'deny'."
  }
}

# Security Scanning Configuration
variable "enable_vulnerability_scanning" {
  description = "Enable vulnerability scanning"
  type        = bool
  default     = true
}

variable "scan_schedule" {
  description = "Vulnerability scan schedule (cron format)"
  type        = string
  default     = "0 2 * * *"  # Daily at 2 AM
}

# Compliance Configuration
variable "compliance_framework" {
  description = "Compliance framework to enforce"
  type        = string
  default     = "cis"
  validation {
    condition     = contains(["cis", "pci", "soc2", "nist"], var.compliance_framework)
    error_message = "Compliance framework must be one of: cis, pci, soc2, nist."
  }
}

variable "audit_log_retention" {
  description = "Audit log retention period"
  type        = string
  default     = "90d"
}

# Resource Configuration
variable "security_resources" {
  description = "Resource configuration for security components"
  type = object({
    openbao = object({
      requests = object({
        cpu    = string
        memory = string
      })
      limits = object({
        cpu    = string
        memory = string
      })
    })
    gatekeeper = object({
      requests = object({
        cpu    = string
        memory = string
      })
      limits = object({
        cpu    = string
        memory = string
      })
    })
    falco = object({
      requests = object({
        cpu    = string
        memory = string
      })
      limits = object({
        cpu    = string
        memory = string
      })
    })
  })
  default = {
    openbao = {
      requests = {
        cpu    = "250m"
        memory = "256Mi"
      }
      limits = {
        cpu    = "500m"
        memory = "1Gi"
      }
    }
    gatekeeper = {
      requests = {
        cpu    = "100m"
        memory = "256Mi"
      }
      limits = {
        cpu    = "1000m"
        memory = "512Mi"
      }
    }
    falco = {
      requests = {
        cpu    = "100m"
        memory = "512Mi"
      }
      limits = {
        cpu    = "1000m"
        memory = "1Gi"
      }
    }
  }
}