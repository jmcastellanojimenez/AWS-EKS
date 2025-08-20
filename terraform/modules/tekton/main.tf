# Tekton Terraform module
# Deploys Tekton Pipelines, Triggers, and Dashboard for CI/CD automation
# Integrates with GitHub webhooks and container registries

terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.16"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.8"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.14"
    }
  }
}

# Tekton Pipelines namespace
resource "kubernetes_namespace" "tekton_pipelines" {
  metadata {
    name = var.namespace
    labels = merge({
      name                                 = var.namespace
      "app.kubernetes.io/name"            = "tekton-pipelines"
      "app.kubernetes.io/part-of"         = var.project_name
      "app.kubernetes.io/managed-by"      = "terraform"
      "environment"                       = var.environment
      "pod-security.kubernetes.io/enforce" = var.security_config.enable_pod_security_standards ? "baseline" : "privileged"
      "pod-security.kubernetes.io/audit"   = var.security_config.enable_pod_security_standards ? "baseline" : "privileged"
      "pod-security.kubernetes.io/warn"    = var.security_config.enable_pod_security_standards ? "baseline" : "privileged"
    }, var.additional_labels)
    
    annotations = var.additional_annotations
  }
}

# Tekton Triggers namespace (if different from pipelines)
resource "kubernetes_namespace" "tekton_triggers" {
  count = var.enable_triggers ? 1 : 0

  metadata {
    name = "tekton-triggers"
    labels = merge({
      name                                 = "tekton-triggers"
      "app.kubernetes.io/name"            = "tekton-triggers"
      "app.kubernetes.io/part-of"         = var.project_name
      "app.kubernetes.io/managed-by"      = "terraform"
      "environment"                       = var.environment
      "pod-security.kubernetes.io/enforce" = var.security_config.enable_pod_security_standards ? "baseline" : "privileged"
      "pod-security.kubernetes.io/audit"   = var.security_config.enable_pod_security_standards ? "baseline" : "privileged"
      "pod-security.kubernetes.io/warn"    = var.security_config.enable_pod_security_standards ? "baseline" : "privileged"
    }, var.additional_labels)
    
    annotations = var.additional_annotations
  }
}

# Container registry secret
resource "kubernetes_secret" "container_registry" {
  metadata {
    name      = "container-registry-secret"
    namespace = kubernetes_namespace.tekton_pipelines.metadata[0].name
  }

  data = {
    username = var.container_registry.username
    password = var.container_registry.password
    url      = var.container_registry.url
    region   = var.container_registry.region
  }

  type = "Opaque"
}

# GitHub webhook secret
resource "kubernetes_secret" "github_webhook" {
  count = var.enable_triggers ? 1 : 0

  metadata {
    name      = "github-webhook-secret"
    namespace = var.enable_triggers ? kubernetes_namespace.tekton_triggers[0].metadata[0].name : kubernetes_namespace.tekton_pipelines.metadata[0].name
  }

  data = {
    secretToken = var.github_config.webhook_secret
    token       = var.github_config.token
    appId       = var.github_config.app_id
    privateKey  = var.github_config.private_key
  }

  type = "Opaque"
}

# Tekton Pipelines configuration
resource "kubernetes_config_map" "tekton_config" {
  metadata {
    name      = "config-defaults"
    namespace = kubernetes_namespace.tekton_pipelines.metadata[0].name
  }

  data = {
    "default-timeout-minutes"        = parseint(replace(var.pipeline_config.default_timeout, "h", ""), 10) * 60
    "default-service-account"        = var.pipeline_config.default_service_account
    "default-managed-by-label-value" = "tekton-pipelines"
    "default-pod-template"          = yamlencode({
      securityContext = var.security_config.run_as_non_root ? {
        runAsNonRoot = true
        runAsUser    = 65532
        runAsGroup   = 65532
        fsGroup      = 65532
      } : {}
    })
  }
}

# Feature flags configuration
resource "kubernetes_config_map" "feature_flags" {
  metadata {
    name      = "feature-flags"
    namespace = kubernetes_namespace.tekton_pipelines.metadata[0].name
  }

  data = {
    "enable-api-fields"         = var.pipeline_config.enable_api_fields
    "enable-tekton-oci-bundles" = tostring(var.pipeline_config.enable_tekton_oci_bundles)
    "enable-custom-tasks"       = tostring(var.pipeline_config.enable_custom_tasks)
    "enable-provenance-in-status" = tostring(var.pipeline_config.enable_provenance)
    "results-from"              = "termination-message"
    "running-in-environment-with-injected-sidecars" = "true"
  }
}

# Tekton Pipelines installation
resource "kubectl_manifest" "tekton_pipelines" {
  yaml_body = <<-YAML
    apiVersion: v1
    kind: List
    items:
    - apiVersion: v1
      kind: ServiceAccount
      metadata:
        name: tekton-pipelines-controller
        namespace: ${kubernetes_namespace.tekton_pipelines.metadata[0].name}
        annotations: ${jsonencode(var.service_account_annotations)}
        labels:
          app.kubernetes.io/component: controller
          app.kubernetes.io/instance: default
          app.kubernetes.io/part-of: tekton-pipelines
    - apiVersion: v1
      kind: ServiceAccount
      metadata:
        name: tekton-pipelines-webhook
        namespace: ${kubernetes_namespace.tekton_pipelines.metadata[0].name}
        annotations: ${jsonencode(var.service_account_annotations)}
        labels:
          app.kubernetes.io/component: webhook
          app.kubernetes.io/instance: default
          app.kubernetes.io/part-of: tekton-pipelines
  YAML

  depends_on = [kubernetes_namespace.tekton_pipelines]
}

# Install Tekton Pipelines using kubectl
resource "null_resource" "install_tekton_pipelines" {
  provisioner "local-exec" {
    command = <<-EOT
      kubectl apply --filename https://storage.googleapis.com/tekton-releases/pipeline/previous/${var.tekton_version}/release.yaml
    EOT
  }

  depends_on = [
    kubernetes_namespace.tekton_pipelines,
    kubernetes_config_map.tekton_config,
    kubernetes_config_map.feature_flags
  ]

  triggers = {
    version = var.tekton_version
  }
}

# Install Tekton Triggers
resource "null_resource" "install_tekton_triggers" {
  count = var.enable_triggers ? 1 : 0

  provisioner "local-exec" {
    command = <<-EOT
      kubectl apply --filename https://storage.googleapis.com/tekton-releases/triggers/previous/${var.tekton_triggers_version}/release.yaml
      kubectl apply --filename https://storage.googleapis.com/tekton-releases/triggers/previous/${var.tekton_triggers_version}/interceptors.yaml
    EOT
  }

  depends_on = [
    kubernetes_namespace.tekton_triggers,
    null_resource.install_tekton_pipelines
  ]

  triggers = {
    version = var.tekton_triggers_version
  }
}

# Install Tekton Dashboard
resource "null_resource" "install_tekton_dashboard" {
  count = var.enable_dashboard ? 1 : 0

  provisioner "local-exec" {
    command = <<-EOT
      kubectl apply --filename https://storage.googleapis.com/tekton-releases/dashboard/previous/${var.tekton_dashboard_version}/release.yaml
    EOT
  }

  depends_on = [
    kubernetes_namespace.tekton_pipelines,
    null_resource.install_tekton_pipelines
  ]

  triggers = {
    version = var.tekton_dashboard_version
  }
}

# Wait for Tekton components to be ready
resource "null_resource" "wait_for_tekton" {
  provisioner "local-exec" {
    command = <<-EOT
      kubectl wait --for=condition=ready pod -l app.kubernetes.io/part-of=tekton-pipelines -n ${kubernetes_namespace.tekton_pipelines.metadata[0].name} --timeout=300s
      ${var.enable_triggers ? "kubectl wait --for=condition=ready pod -l app.kubernetes.io/part-of=tekton-triggers -n tekton-triggers --timeout=300s" : ""}
      ${var.enable_dashboard ? "kubectl wait --for=condition=ready pod -l app.kubernetes.io/part-of=tekton-dashboard -n tekton-pipelines --timeout=300s" : ""}
    EOT
  }

  depends_on = [
    null_resource.install_tekton_pipelines,
    null_resource.install_tekton_triggers,
    null_resource.install_tekton_dashboard
  ]
}

# Pipeline service account with registry access
resource "kubernetes_service_account" "pipeline_sa" {
  metadata {
    name      = var.pipeline_config.default_service_account
    namespace = kubernetes_namespace.tekton_pipelines.metadata[0].name
    annotations = merge({
      "tekton.dev/docker-0" = var.container_registry.url
    }, var.service_account_annotations)
  }

  secret {
    name = kubernetes_secret.container_registry.metadata[0].name
  }

  depends_on = [null_resource.install_tekton_pipelines]
}

# RBAC for pipeline service account
resource "kubernetes_cluster_role_binding" "pipeline_sa_binding" {
  count = var.enable_rbac ? 1 : 0

  metadata {
    name = "tekton-pipeline-sa-binding"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "edit"
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.pipeline_sa.metadata[0].name
    namespace = kubernetes_service_account.pipeline_sa.metadata[0].namespace
  }
}

# Tekton Dashboard ingress
resource "kubernetes_manifest" "dashboard_ingress" {
  count = var.enable_dashboard && var.enable_ingress && var.dashboard_hostname != "" ? 1 : 0

  manifest = {
    apiVersion = "getambassador.io/v3alpha1"
    kind       = "Mapping"
    metadata = {
      name      = "tekton-dashboard"
      namespace = kubernetes_namespace.tekton_pipelines.metadata[0].name
    }
    spec = {
      hostname = var.dashboard_hostname
      prefix   = "/"
      service  = "tekton-dashboard:9097"
      timeout_ms = 30000
    }
  }

  depends_on = [null_resource.install_tekton_dashboard]
}

# Network policies for security
resource "kubernetes_network_policy" "tekton_network_policy" {
  count = var.security_config.enable_network_policies ? 1 : 0

  metadata {
    name      = "tekton-network-policy"
    namespace = kubernetes_namespace.tekton_pipelines.metadata[0].name
  }

  spec {
    pod_selector {
      match_labels = {
        "app.kubernetes.io/part-of" = "tekton-pipelines"
      }
    }

    policy_types = ["Ingress", "Egress"]

    ingress {
      from {
        namespace_selector {
          match_labels = {
            name = kubernetes_namespace.tekton_pipelines.metadata[0].name
          }
        }
      }
      
      from {
        namespace_selector {
          match_labels = {
            name = var.enable_triggers ? kubernetes_namespace.tekton_triggers[0].metadata[0].name : ""
          }
        }
      }
    }

    egress {
      # Allow all egress for now (pipelines need to access external resources)
    }
  }

  depends_on = [null_resource.install_tekton_pipelines]
}

# Custom tasks
resource "kubernetes_manifest" "custom_tasks" {
  count = length(var.custom_tasks)

  manifest = {
    apiVersion = "tekton.dev/v1beta1"
    kind       = "Task"
    metadata = {
      name      = var.custom_tasks[count.index].name
      namespace = kubernetes_namespace.tekton_pipelines.metadata[0].name
    }
    spec = {
      description = var.custom_tasks[count.index].description
      params      = var.custom_tasks[count.index].params
      workspaces  = var.custom_tasks[count.index].workspaces
      results     = var.custom_tasks[count.index].results
      steps = [{
        name   = "main"
        image  = var.custom_tasks[count.index].image
        script = var.custom_tasks[count.index].script != "" ? var.custom_tasks[count.index].script : "echo 'No script provided'"
        securityContext = var.security_config.run_as_non_root ? {
          runAsNonRoot = true
          runAsUser    = 65532
          runAsGroup   = 65532
        } : {}
      }]
    }
  }

  depends_on = [null_resource.wait_for_tekton]
}

# Pipeline templates
resource "kubernetes_manifest" "pipeline_templates" {
  count = length(var.pipeline_templates)

  manifest = {
    apiVersion = "tekton.dev/v1beta1"
    kind       = "Pipeline"
    metadata = {
      name      = var.pipeline_templates[count.index].name
      namespace = kubernetes_namespace.tekton_pipelines.metadata[0].name
    }
    spec = {
      description = var.pipeline_templates[count.index].description
      params      = var.pipeline_templates[count.index].params
      workspaces  = var.pipeline_templates[count.index].workspaces
      tasks = [
        for task in var.pipeline_templates[count.index].tasks : {
          name = task.name
          taskRef = {
            name = task.taskRef
          }
          params = [
            for param_name, param_value in task.params : {
              name  = param_name
              value = param_value
            }
          ]
          runAfter = task.runAfter
        }
      ]
    }
  }

  depends_on = [
    null_resource.wait_for_tekton,
    kubernetes_manifest.custom_tasks
  ]
}

# Monitoring ServiceMonitor for Tekton
resource "kubernetes_manifest" "tekton_service_monitor" {
  count = var.enable_monitoring ? 1 : 0

  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "ServiceMonitor"
    metadata = {
      name      = "tekton-pipelines"
      namespace = kubernetes_namespace.tekton_pipelines.metadata[0].name
      labels = {
        "app.kubernetes.io/name"    = "tekton-pipelines"
        "app.kubernetes.io/part-of" = "tekton-pipelines"
      }
    }
    spec = {
      selector = {
        matchLabels = {
          "app.kubernetes.io/part-of" = "tekton-pipelines"
        }
      }
      endpoints = [
        {
          port = "http-metrics"
          path = "/metrics"
        }
      ]
    }
  }

  depends_on = [null_resource.wait_for_tekton]
}

# Storage class for pipeline workspaces
resource "kubernetes_storage_class" "pipeline_storage" {
  count = var.storage_config.storage_class == "tekton-pipeline-storage" ? 1 : 0

  metadata {
    name = "tekton-pipeline-storage"
  }

  storage_provisioner    = "ebs.csi.aws.com"
  reclaim_policy        = "Delete"
  volume_binding_mode   = "WaitForFirstConsumer"
  allow_volume_expansion = true

  parameters = {
    type      = "gp3"
    encrypted = "true"
  }
}

# Persistent volume claim template for caching
resource "kubernetes_manifest" "cache_pvc_template" {
  count = var.performance_config.enable_caching ? 1 : 0

  manifest = {
    apiVersion = "v1"
    kind       = "PersistentVolumeClaim"
    metadata = {
      name      = "tekton-cache-pvc"
      namespace = kubernetes_namespace.tekton_pipelines.metadata[0].name
    }
    spec = {
      accessModes = ["ReadWriteOnce"]
      resources = {
        requests = {
          storage = var.storage_config.cache_size
        }
      }
      storageClassName = var.storage_config.storage_class
    }
  }

  depends_on = [kubernetes_storage_class.pipeline_storage]
}