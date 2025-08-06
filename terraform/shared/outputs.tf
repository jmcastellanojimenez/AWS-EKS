# Outputs from shared module
output "common_tags" {
  description = "Common tags applied to all resources"
  value       = local.common_tags
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = local.cluster_name
}

output "env_config" {
  description = "Environment-specific configuration"
  value       = local.env_config
}

output "security_config" {
  description = "Security and compliance settings"
  value       = local.security_config
}

output "addon_versions" {
  description = "Kubernetes add-on versions"
  value       = local.addon_versions
}

output "cost_thresholds" {
  description = "Cost monitoring thresholds"
  value       = local.cost_thresholds
}

output "backup_config" {
  description = "Backup and disaster recovery settings"
  value       = local.backup_config
}