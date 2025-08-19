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
  value       = kubernetes_manifest.letsencrypt_issuer.manifest.metadata.name
}