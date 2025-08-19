# GitOps Module Outputs

output "namespace" {
  description = "GitOps namespace"
  value       = kubernetes_namespace.gitops.metadata[0].name
}

# ArgoCD Outputs
output "argocd_server_service_name" {
  description = "ArgoCD server service name"
  value       = "argocd-server"
}

output "argocd_url" {
  description = "ArgoCD URL"
  value       = "https://${var.domain_name}/argocd"
}

output "argocd_admin_secret_name" {
  description = "ArgoCD admin secret name"
  value       = "argocd-initial-admin-secret"
}

# Tekton Outputs
output "tekton_pipelines_controller" {
  description = "Tekton Pipelines controller service name"
  value       = "tekton-pipelines-controller"
}

output "tekton_triggers_controller" {
  description = "Tekton Triggers controller service name"
  value       = "tekton-triggers-controller"
}

# GitOps Configuration
output "gitops_configuration" {
  description = "GitOps configuration summary"
  value = {
    repository_url    = var.gitops_repo_url
    repository_branch = var.gitops_repo_branch
    applications_path = var.gitops_repo_path
    app_of_apps_name  = kubernetes_manifest.app_of_apps.manifest.metadata.name
  }
}

# CI/CD Pipeline Outputs
output "pipeline_configuration" {
  description = "CI/CD pipeline configuration"
  value = {
    build_pipeline_name     = kubernetes_manifest.build_pipeline.manifest.metadata.name
    trivy_task_name        = kubernetes_manifest.trivy_task.manifest.metadata.name
    security_scanning_enabled = var.enable_security_scanning
    image_signing_enabled   = var.enable_image_signing
    build_timeout          = var.build_timeout
  }
}

# Service Endpoints
output "service_endpoints" {
  description = "GitOps service endpoints"
  value = {
    argocd = {
      server = "argocd-server.${kubernetes_namespace.gitops.metadata[0].name}.svc.cluster.local:80"
      grpc   = "argocd-server.${kubernetes_namespace.gitops.metadata[0].name}.svc.cluster.local:443"
    }
    tekton = {
      pipelines_controller = "tekton-pipelines-controller.${kubernetes_namespace.gitops.metadata[0].name}.svc.cluster.local:9090"
      triggers_controller  = "tekton-triggers-controller.${kubernetes_namespace.gitops.metadata[0].name}.svc.cluster.local:9090"
    }
  }
}

# Monitoring Integration
output "monitoring_integration" {
  description = "Monitoring integration information"
  value = {
    service_monitors = [
      "argocd-metrics",
      "argocd-server-metrics", 
      "argocd-repo-server-metrics",
      "tekton-pipelines-controller",
      "tekton-triggers-controller"
    ]
    metrics_endpoints = {
      argocd_controller = "/metrics"
      argocd_server     = "/metrics"
      argocd_repo_server = "/metrics"
      tekton_controller = "/metrics"
      tekton_webhook    = "/metrics"
    }
  }
}

# GitHub Integration
output "github_integration" {
  description = "GitHub integration configuration"
  value = var.enable_github_webhooks ? {
    webhook_enabled    = true
    event_listener     = "github-listener"
    webhook_secret     = var.github_webhook_secret != "" ? "configured" : "not_configured"
  } : {
    webhook_enabled = false
  }
}

# Application Deployment Status
output "application_deployment" {
  description = "Application deployment configuration"
  value = {
    app_of_apps_deployed = true
    auto_sync_enabled    = true
    self_heal_enabled    = true
    prune_enabled        = true
  }
}