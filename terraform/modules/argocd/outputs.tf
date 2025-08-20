output "namespace" {
  description = "The Kubernetes namespace where ArgoCD is deployed"
  value       = kubernetes_namespace.argocd.metadata[0].name
}

output "server_service_name" {
  description = "The name of the ArgoCD server service"
  value       = "argocd-server"
}

output "server_service_account" {
  description = "The name of the ArgoCD server service account"
  value       = "argocd-server"
}

output "controller_service_account" {
  description = "The name of the ArgoCD application controller service account"
  value       = "argocd-application-controller"
}

output "repo_server_service_account" {
  description = "The name of the ArgoCD repository server service account"
  value       = "argocd-repo-server"
}

output "applicationset_service_account" {
  description = "The name of the ArgoCD ApplicationSet controller service account"
  value       = var.enable_applicationset ? "argocd-applicationset-controller" : ""
}

output "notifications_service_account" {
  description = "The name of the ArgoCD notifications controller service account"
  value       = var.enable_notifications ? "argocd-notifications-controller" : ""
}

output "helm_release_name" {
  description = "The name of the ArgoCD Helm release"
  value       = helm_release.argocd.name
}

output "helm_release_version" {
  description = "The version of the deployed ArgoCD Helm chart"
  value       = helm_release.argocd.version
}

output "server_url" {
  description = "The URL for accessing ArgoCD server"
  value       = var.hostname != "" ? "https://${var.hostname}" : "Use kubectl port-forward to access ArgoCD server"
}

output "admin_password_secret" {
  description = "The name of the secret containing the admin password"
  value       = "argocd-secret"
}

output "server_port" {
  description = "The port for ArgoCD server"
  value       = 80
}

output "grpc_port" {
  description = "The gRPC port for ArgoCD server"
  value       = 443
}

output "application_projects" {
  description = "List of created ArgoCD application projects"
  value       = [for project in var.application_projects : project.name]
}

output "ready" {
  description = "Indicates that ArgoCD is ready for use"
  value       = true
  depends_on  = [helm_release.argocd]
}

output "cli_login_command" {
  description = "Command to login to ArgoCD using CLI"
  value       = var.hostname != "" ? "argocd login ${var.hostname}" : "kubectl port-forward svc/argocd-server -n ${kubernetes_namespace.argocd.metadata[0].name} 8080:443 && argocd login localhost:8080"
}

output "application_example" {
  description = "Example Application CRD for deploying applications"
  value = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "example-app"
      namespace = kubernetes_namespace.argocd.metadata[0].name
    }
    spec = {
      project = length(var.application_projects) > 0 ? var.application_projects[0].name : "default"
      source = {
        repoURL        = "https://github.com/example/example-app"
        targetRevision = "HEAD"
        path           = "manifests"
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = "default"
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
        syncOptions = [
          "CreateNamespace=true"
        ]
      }
    }
  }
}

output "service_accounts_for_irsa" {
  description = "Service accounts that need IRSA configuration"
  value = {
    server = {
      name      = "argocd-server"
      namespace = kubernetes_namespace.argocd.metadata[0].name
    }
    controller = {
      name      = "argocd-application-controller"
      namespace = kubernetes_namespace.argocd.metadata[0].name
    }
    repo_server = {
      name      = "argocd-repo-server"
      namespace = kubernetes_namespace.argocd.metadata[0].name
    }
    applicationset = var.enable_applicationset ? {
      name      = "argocd-applicationset-controller"
      namespace = kubernetes_namespace.argocd.metadata[0].name
    } : null
    notifications = var.enable_notifications ? {
      name      = "argocd-notifications-controller"
      namespace = kubernetes_namespace.argocd.metadata[0].name
    } : null
  }
}

output "monitoring_endpoints" {
  description = "Monitoring endpoints for ArgoCD components"
  value = var.enable_monitoring ? {
    server = {
      service = "argocd-server-metrics"
      port    = 8083
      path    = "/metrics"
    }
    controller = {
      service = "argocd-application-controller-metrics"
      port    = 8082
      path    = "/metrics"
    }
    repo_server = {
      service = "argocd-repo-server-metrics"
      port    = 8084
      path    = "/metrics"
    }
  } : {}
}