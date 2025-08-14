output "namespace" {
  description = "The Kubernetes namespace where Ambassador is deployed"
  value       = kubernetes_namespace.ambassador.metadata[0].name
}

output "service_name" {
  description = "The name of the Ambassador service"
  value       = "ambassador"
}

output "admin_service_name" {
  description = "The name of the Ambassador admin service"
  value       = "ambassador-admin"
}

output "helm_release_name" {
  description = "The name of the Ambassador Helm release"
  value       = helm_release.ambassador.name
}

output "helm_release_version" {
  description = "The version of the deployed Ambassador Helm chart"
  value       = helm_release.ambassador.version
}

output "ambassador_id" {
  description = "The Ambassador instance identifier"
  value       = var.ambassador_id
}

output "load_balancer_hostname" {
  description = "The hostname of the AWS Network Load Balancer"
  value       = "Use kubectl get svc ambassador -n ${kubernetes_namespace.ambassador.metadata[0].name} to get the actual hostname"
}

output "primary_hostname" {
  description = "The primary hostname configured for the API Gateway"
  value       = var.hostname
}

output "health_check_path" {
  description = "The health check endpoint path"
  value       = "/health"
}

output "admin_port" {
  description = "The port for Ambassador admin interface"
  value       = 8877
}

output "http_port" {
  description = "The HTTP port for Ambassador"
  value       = 80
}

output "https_port" {
  description = "The HTTPS port for Ambassador"
  value       = 443
}

output "ready" {
  description = "Indicates that Ambassador is ready for use"
  value       = true
  depends_on  = [kubernetes_deployment.ambassador_ready]
}

output "mapping_example" {
  description = "Example Mapping CRD for connecting applications"
  value = {
    apiVersion = "getambassador.io/v3alpha1"
    kind       = "Mapping"
    metadata = {
      name      = "example-service"
      namespace = "default"
    }
    spec = {
      hostname = var.hostname != "" ? var.hostname : "*"
      prefix   = "/api/v1/"
      service  = "example-service:80"
      timeout_ms = var.default_timeout * 1000
    }
  }
}