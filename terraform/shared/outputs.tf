# Shared configuration outputs
output "common_tags" {
  description = "Common tags for all resources"
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
  description = "Security configuration"
  value       = local.security_config
}

output "addon_versions" {
  description = "Kubernetes addon versions"
  value       = local.addon_versions
}

output "cost_thresholds" {
  description = "Cost monitoring thresholds"
  value       = local.cost_thresholds
}

# Route53 outputs (conditional based on whether domain was created)
output "hosted_zone_id" {
  description = "Route53 hosted zone ID (empty if no domain configured)"
  value       = length(aws_route53_zone.demo) > 0 ? aws_route53_zone.demo[0].zone_id : ""
}

output "domain_name" {
  description = "Domain name"
  value       = var.domain_name
}

output "name_servers" {
  description = "Route53 name servers (empty if no domain configured)"
  value       = length(aws_route53_zone.demo) > 0 ? aws_route53_zone.demo[0].name_servers : []
}