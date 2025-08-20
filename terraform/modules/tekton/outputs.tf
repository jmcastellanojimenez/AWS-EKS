output "namespace" {
  description = "The Kubernetes namespace where Tekton Pipelines is deployed"
  value       = kubernetes_namespace.tekton_pipelines.metadata[0].name
}

output "triggers_namespace" {
  description = "The Kubernetes namespace where Tekton Triggers is deployed"
  value       = var.enable_triggers ? kubernetes_namespace.tekton_triggers[0].metadata[0].name : ""
}

output "pipeline_service_account" {
  description = "The name of the Tekton pipeline service account"
  value       = kubernetes_service_account.pipeline_sa.metadata[0].name
}

output "controller_service_account" {
  description = "The name of the Tekton controller service account"
  value       = "tekton-pipelines-controller"
}

output "webhook_service_account" {
  description = "The name of the Tekton webhook service account"
  value       = "tekton-pipelines-webhook"
}

output "dashboard_service_name" {
  description = "The name of the Tekton Dashboard service"
  value       = var.enable_dashboard ? "tekton-dashboard" : ""
}

output "dashboard_url" {
  description = "The URL for accessing Tekton Dashboard"
  value       = var.enable_dashboard && var.dashboard_hostname != "" ? "https://${var.dashboard_hostname}" : "Use kubectl port-forward to access Tekton Dashboard"
}

output "webhook_url" {
  description = "The webhook URL for GitHub integration"
  value       = var.enable_triggers && var.webhook_config.hostname != "" ? "https://${var.webhook_config.hostname}${var.webhook_config.path_prefix}" : "Configure ingress for webhook access"
}

output "container_registry_secret" {
  description = "The name of the container registry secret"
  value       = kubernetes_secret.container_registry.metadata[0].name
}

output "github_webhook_secret" {
  description = "The name of the GitHub webhook secret"
  value       = var.enable_triggers ? kubernetes_secret.github_webhook[0].metadata[0].name : ""
}

output "tekton_version" {
  description = "The version of Tekton Pipelines installed"
  value       = var.tekton_version
}

output "triggers_version" {
  description = "The version of Tekton Triggers installed"
  value       = var.enable_triggers ? var.tekton_triggers_version : ""
}

output "dashboard_version" {
  description = "The version of Tekton Dashboard installed"
  value       = var.enable_dashboard ? var.tekton_dashboard_version : ""
}

output "ready" {
  description = "Indicates that Tekton is ready for use"
  value       = true
  depends_on  = [null_resource.wait_for_tekton]
}

output "service_accounts_for_irsa" {
  description = "Service accounts that need IRSA configuration"
  value = {
    controller = {
      name      = "tekton-pipelines-controller"
      namespace = kubernetes_namespace.tekton_pipelines.metadata[0].name
    }
    webhook = {
      name      = "tekton-pipelines-webhook"
      namespace = kubernetes_namespace.tekton_pipelines.metadata[0].name
    }
    pipeline = {
      name      = kubernetes_service_account.pipeline_sa.metadata[0].name
      namespace = kubernetes_service_account.pipeline_sa.metadata[0].namespace
    }
  }
}

output "monitoring_endpoints" {
  description = "Monitoring endpoints for Tekton components"
  value = var.enable_monitoring ? {
    controller = {
      service = "tekton-pipelines-controller"
      port    = 9090
      path    = "/metrics"
    }
    webhook = {
      service = "tekton-pipelines-webhook"
      port    = 9090
      path    = "/metrics"
    }
  } : {}
}

output "custom_tasks" {
  description = "List of created custom tasks"
  value       = [for task in var.custom_tasks : task.name]
}

output "pipeline_templates" {
  description = "List of created pipeline templates"
  value       = [for pipeline in var.pipeline_templates : pipeline.name]
}

output "cli_commands" {
  description = "Useful CLI commands for Tekton"
  value = {
    list_pipelines    = "tkn pipeline list -n ${kubernetes_namespace.tekton_pipelines.metadata[0].name}"
    list_pipelineruns = "tkn pipelinerun list -n ${kubernetes_namespace.tekton_pipelines.metadata[0].name}"
    list_tasks        = "tkn task list -n ${kubernetes_namespace.tekton_pipelines.metadata[0].name}"
    list_taskruns     = "tkn taskrun list -n ${kubernetes_namespace.tekton_pipelines.metadata[0].name}"
    dashboard_port_forward = var.enable_dashboard ? "kubectl port-forward svc/tekton-dashboard -n ${kubernetes_namespace.tekton_pipelines.metadata[0].name} 9097:9097" : ""
  }
}

output "example_pipeline_run" {
  description = "Example PipelineRun for testing"
  value = {
    apiVersion = "tekton.dev/v1beta1"
    kind       = "PipelineRun"
    metadata = {
      name      = "example-pipeline-run"
      namespace = kubernetes_namespace.tekton_pipelines.metadata[0].name
    }
    spec = {
      serviceAccountName = kubernetes_service_account.pipeline_sa.metadata[0].name
      pipelineRef = length(var.pipeline_templates) > 0 ? {
        name = var.pipeline_templates[0].name
      } : null
      params = [
        {
          name  = "service-name"
          value = "example-service"
        },
        {
          name  = "source-repo"
          value = "https://github.com/example/example-service"
        }
      ]
      workspaces = [
        {
          name = "source-workspace"
          volumeClaimTemplate = {
            spec = {
              accessModes = ["ReadWriteOnce"]
              resources = {
                requests = {
                  storage = var.storage_config.workspace_size
                }
              }
              storageClassName = var.storage_config.storage_class
            }
          }
        }
      ]
    }
  }
}

output "webhook_example" {
  description = "Example webhook configuration for GitHub"
  value = var.enable_triggers ? {
    url          = var.webhook_config.hostname != "" ? "https://${var.webhook_config.hostname}${var.webhook_config.path_prefix}/github" : "Configure webhook URL"
    content_type = "application/json"
    secret       = "Use the webhook secret from ${kubernetes_secret.github_webhook[0].metadata[0].name}"
    events       = ["push", "pull_request"]
    active       = true
  } : {}
}

output "storage_config" {
  description = "Storage configuration for workspaces"
  value = {
    storage_class  = var.storage_config.storage_class
    cache_size     = var.storage_config.cache_size
    workspace_size = var.storage_config.workspace_size
  }
}

output "security_context" {
  description = "Security context configuration"
  value = var.security_config.run_as_non_root ? {
    runAsNonRoot = true
    runAsUser    = 65532
    runAsGroup   = 65532
    fsGroup      = 65532
  } : {}
}