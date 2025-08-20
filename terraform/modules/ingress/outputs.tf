# Ingress Module Outputs

output "namespace" {
  description = "Ingress namespace"
  value       = kubernetes_namespace.ingress.metadata[0].name
}

output "ambassador_service_name" {
  description = "Ambassador service name"
  value       = "${helm_release.ambassador.name}-emissary-ingress"
}

output "ambassador_load_balancer_hostname" {
  description = "Ambassador load balancer hostname"
  value       = "ambassador.${var.domain_name}"
}

output "cert_manager_namespace" {
  description = "cert-manager namespace"
  value       = kubernetes_namespace.ingress.metadata[0].name
}

output "external_dns_namespace" {
  description = "external-dns namespace"
  value       = kubernetes_namespace.ingress.metadata[0].name
}

output "letsencrypt_issuer_name" {
  description = "Let's Encrypt ClusterIssuer name"
  value       = "letsencrypt-prod"
}

output "ambassador_ready" {
  description = "Ambassador deployment readiness"
  value       = helm_release.ambassador.status == "deployed"
}

output "cert_manager_ready" {
  description = "cert-manager deployment readiness"
  value       = helm_release.cert_manager.status == "deployed"
}

output "external_dns_ready" {
  description = "external-dns deployment readiness"
  value       = helm_release.external_dns.status == "deployed"
}

output "ambassador_module_applied" {
  description = "Ambassador module configuration applied"
  value       = null_resource.ambassador_module.id != null
}

output "ambassador_host_applied" {
  description = "Ambassador host configuration applied"
  value       = null_resource.ambassador_host.id != null
}

output "letsencrypt_issuer_applied" {
  description = "Let's Encrypt issuer configuration applied"
  value       = null_resource.letsencrypt_issuer.id != null
}