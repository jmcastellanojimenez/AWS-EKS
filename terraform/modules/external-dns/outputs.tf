output "namespace" {
  description = "The Kubernetes namespace where external-dns is deployed"
  value       = kubernetes_namespace.external_dns.metadata[0].name
}

output "service_account_name" {
  description = "The name of the external-dns service account"
  value       = kubernetes_service_account.external_dns.metadata[0].name
}

output "helm_release_name" {
  description = "The name of the external-dns Helm release"
  value       = helm_release.external_dns.name
}

output "helm_release_version" {
  description = "The version of the deployed external-dns Helm chart"
  value       = helm_release.external_dns.version
}

output "dns_provider" {
  description = "The configured DNS provider"
  value       = var.dns_provider
}

output "domain_filters" {
  description = "The domains managed by external-dns"
  value       = var.domain_filters
}

output "ready" {
  description = "Indicates that external-dns is ready for use"
  value       = true
  depends_on  = [kubernetes_deployment.external_dns_ready]
}