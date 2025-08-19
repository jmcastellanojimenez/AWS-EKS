# Development Environment Outputs

# Foundation Platform Outputs
output "cluster_name" {
  description = "EKS cluster name"
  value       = module.foundation.cluster_name
}

output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.foundation.cluster_endpoint
}

output "aws_region" {
  description = "AWS region"
  value       = var.aws_region
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.foundation.vpc_id
}

# Ingress Outputs
output "domain_name" {
  description = "Primary domain name"
  value       = var.domain_name
}

output "ambassador_load_balancer" {
  description = "Ambassador load balancer hostname"
  value       = module.ingress.ambassador_load_balancer_hostname
}

# Observability Outputs
output "grafana_url" {
  description = "Grafana dashboard URL"
  value       = module.observability.grafana_url
}

output "grafana_admin_password" {
  description = "Grafana admin password"
  value       = var.grafana_admin_password
  sensitive   = true
}

output "prometheus_url" {
  description = "Prometheus URL"
  value       = module.observability.prometheus_url
}

# GitOps Outputs
output "argocd_url" {
  description = "ArgoCD dashboard URL"
  value       = "https://${var.domain_name}/argocd"
}

# Service Mesh Outputs
output "istio_gateway" {
  description = "Istio gateway service"
  value       = module.service_mesh.istio_gateway_service_name
}

output "kiali_url" {
  description = "Kiali dashboard URL"
  value       = module.service_mesh.kiali_url
}

# Data Services Outputs
output "postgres_connection_string" {
  description = "PostgreSQL connection string"
  value       = module.data_services.postgres_connection_string
  sensitive   = true
}

output "redis_connection_string" {
  description = "Redis connection string"
  value       = module.data_services.redis_connection_string
}

output "kafka_bootstrap_servers" {
  description = "Kafka bootstrap servers"
  value       = module.data_services.kafka_bootstrap_servers
}

# Security Outputs
output "openbao_url" {
  description = "OpenBao URL"
  value       = module.security.openbao_url
}

# Service Endpoints Summary
output "service_endpoints" {
  description = "All service endpoints"
  value = {
    grafana    = module.observability.grafana_url
    argocd     = "https://${var.domain_name}/argocd"
    kiali      = module.service_mesh.kiali_url
    openbao    = module.security.openbao_url
    postgres   = module.data_services.service_endpoints.postgres
    redis      = module.data_services.service_endpoints.redis
    kafka      = module.data_services.service_endpoints.kafka
  }
}

# Quick Access Commands
output "access_commands" {
  description = "Quick access commands"
  value = {
    kubeconfig = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.foundation.cluster_name}"
    grafana    = "kubectl port-forward -n observability svc/grafana 3000:80"
    argocd     = "kubectl port-forward -n gitops svc/argocd-server 8080:80"
    prometheus = "kubectl port-forward -n observability svc/prometheus-kube-prometheus-prometheus 9090:9090"
  }
}

# Platform Status
output "platform_status" {
  description = "Platform deployment status"
  value = {
    foundation_deployed    = true
    ingress_deployed      = true
    observability_deployed = true
    gitops_deployed       = true
    security_deployed     = true
    service_mesh_deployed = true
    data_services_deployed = true
    total_workflows       = 7
  }
}