# ==============================================================================
# LGTM Observability Stack Outputs
# ==============================================================================

output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = data.aws_eks_cluster.cluster.name
}

output "grafana_admin_password" {
  description = "Grafana admin password"
  value       = var.grafana_admin_password
  sensitive   = true
}

output "observability_namespace" {
  description = "Kubernetes namespace for observability components"
  value       = module.lgtm_observability.namespace
}

output "prometheus_endpoint" {
  description = "Prometheus server endpoint"
  value       = module.lgtm_observability.prometheus_endpoint
}

output "grafana_endpoint" {
  description = "Grafana dashboard endpoint"
  value       = module.lgtm_observability.grafana_endpoint
}