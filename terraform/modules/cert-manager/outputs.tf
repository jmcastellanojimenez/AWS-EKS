output "namespace" {
  description = "The Kubernetes namespace where cert-manager is deployed"
  value       = kubernetes_namespace.cert_manager.metadata[0].name
}

output "helm_release_name" {
  description = "The name of the cert-manager Helm release"
  value       = helm_release.cert_manager.name
}

output "helm_release_version" {
  description = "The version of the deployed cert-manager Helm chart"
  value       = helm_release.cert_manager.version
}

output "letsencrypt_staging_issuer" {
  description = "Name of the Let's Encrypt staging ClusterIssuer"
  value       = var.enable_letsencrypt ? "letsencrypt-staging" : null
}

output "letsencrypt_prod_issuer" {
  description = "Name of the Let's Encrypt production ClusterIssuer"
  value       = var.enable_letsencrypt ? "letsencrypt-prod" : null
}

output "ready" {
  description = "Indicates that cert-manager is ready for use"
  value       = true
  depends_on  = [kubernetes_deployment.cert_manager_ready]
}