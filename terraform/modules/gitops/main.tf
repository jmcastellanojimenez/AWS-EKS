# GitOps & CI/CD Module
terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
  }
}

locals {
  common_labels = {
    "app.kubernetes.io/managed-by" = "terraform"
    "app.kubernetes.io/part-of"    = var.project_name
  }
}

# GitOps namespace
resource "kubernetes_namespace" "gitops" {
  metadata {
    name = "gitops"
    labels = merge(local.common_labels, {
      "app.kubernetes.io/component" = "gitops"
    })
  }
}

# ArgoCD
resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.argocd_version
  namespace  = kubernetes_namespace.gitops.metadata[0].name

  values = [
    yamlencode({
      global = {
        domain = var.domain_name
      }

      configs = {
        params = {
          "server.insecure" = true
        }
        cm = {
          "application.instanceLabelKey" = "argocd.argoproj.io/instance"
          "server.enable.proxy.extension" = true
          url = "https://${var.domain_name}/argocd"
        }
      }

      controller = {
        resources = {
          requests = {
            cpu    = "250m"
            memory = "512Mi"
          }
          limits = {
            cpu    = "2"
            memory = "2Gi"
          }
        }
        metrics = {
          enabled = true
          serviceMonitor = {
            enabled = true
          }
        }
      }

      server = {
        resources = {
          requests = {
            cpu    = "100m"
            memory = "128Mi"
          }
          limits = {
            cpu    = "500m"
            memory = "512Mi"
          }
        }
        metrics = {
          enabled = true
          serviceMonitor = {
            enabled = true
          }
        }
        ingress = {
          enabled = true
          annotations = {
            "kubernetes.io/ingress.class" = "ambassador"
            "getambassador.io/config" = yamlencode({
              apiVersion = "getambassador.io/v3alpha1"
              kind       = "Mapping"
              name       = "argocd-server"
              prefix     = "/argocd/"
              service    = "argocd-server.${kubernetes_namespace.gitops.metadata[0].name}:80"
              timeout_ms = 30000
            })
          }
          hosts = [var.domain_name]
          paths = ["/argocd"]
        }
      }

      repoServer = {
        resources = {
          requests = {
            cpu    = "100m"
            memory = "256Mi"
          }
          limits = {
            cpu    = "1"
            memory = "1Gi"
          }
        }
        metrics = {
          enabled = true
          serviceMonitor = {
            enabled = true
          }
        }
      }

      applicationSet = {
        enabled = true
        resources = {
          requests = {
            cpu    = "100m"
            memory = "128Mi"
          }
          limits = {
            cpu    = "500m"
            memory = "512Mi"
          }
        }
        metrics = {
          enabled = true
          serviceMonitor = {
            enabled = true
          }
        }
      }

      notifications = {
        enabled = true
        resources = {
          requests = {
            cpu    = "100m"
            memory = "128Mi"
          }
          limits = {
            cpu    = "500m"
            memory = "512Mi"
          }
        }
        metrics = {
          enabled = true
          serviceMonitor = {
            enabled = true
          }
        }
      }
    })
  ]

  depends_on = [kubernetes_namespace.gitops]
}

# Tekton Pipelines
resource "helm_release" "tekton_pipelines" {
  name       = "tekton-pipelines"
  repository = "https://cdfoundation.github.io/tekton-helm-chart"
  chart      = "tekton-pipelines"
  version    = var.tekton_version
  namespace  = kubernetes_namespace.gitops.metadata[0].name

  values = [
    yamlencode({
      controller = {
        resources = {
          requests = {
            cpu    = "100m"
            memory = "128Mi"
          }
          limits = {
            cpu    = "1"
            memory = "1Gi"
          }
        }
      }

      webhook = {
        resources = {
          requests = {
            cpu    = "100m"
            memory = "128Mi"
          }
          limits = {
            cpu    = "500m"
            memory = "512Mi"
          }
        }
      }
    })
  ]

  depends_on = [kubernetes_namespace.gitops]
}

# Tekton Triggers
resource "helm_release" "tekton_triggers" {
  name       = "tekton-triggers"
  repository = "https://cdfoundation.github.io/tekton-helm-chart"
  chart      = "tekton-triggers"
  version    = var.tekton_triggers_version
  namespace  = kubernetes_namespace.gitops.metadata[0].name

  values = [
    yamlencode({
      controller = {
        resources = {
          requests = {
            cpu    = "100m"
            memory = "128Mi"
          }
          limits = {
            cpu    = "500m"
            memory = "512Mi"
          }
        }
      }

      webhook = {
        resources = {
          requests = {
            cpu    = "100m"
            memory = "128Mi"
          }
          limits = {
            cpu    = "500m"
            memory = "512Mi"
          }
        }
      }
    })
  ]

  depends_on = [helm_release.tekton_pipelines]
}

# ArgoCD Application of Applications
resource "kubernetes_manifest" "app_of_apps" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "app-of-apps"
      namespace = kubernetes_namespace.gitops.metadata[0].name
      finalizers = ["resources-finalizer.argocd.argoproj.io"]
    }
    spec = {
      project = "default"
      source = {
        repoURL        = var.gitops_repo_url
        targetRevision = var.gitops_repo_branch
        path           = "applications"
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = kubernetes_namespace.gitops.metadata[0].name
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

  depends_on = [helm_release.argocd]
}

# Tekton Pipeline for container builds
resource "kubernetes_manifest" "build_pipeline" {
  manifest = {
    apiVersion = "tekton.dev/v1beta1"
    kind       = "Pipeline"
    metadata = {
      name      = "build-and-push"
      namespace = kubernetes_namespace.gitops.metadata[0].name
    }
    spec = {
      params = [
        {
          name        = "git-url"
          type        = "string"
          description = "Git repository URL"
        },
        {
          name        = "git-revision"
          type        = "string"
          description = "Git revision"
          default     = "main"
        },
        {
          name        = "image-name"
          type        = "string"
          description = "Container image name"
        },
        {
          name        = "image-tag"
          type        = "string"
          description = "Container image tag"
          default     = "latest"
        }
      ]
      workspaces = [
        {
          name        = "shared-data"
          description = "Shared workspace for pipeline tasks"
        }
      ]
      tasks = [
        {
          name = "fetch-source"
          taskRef = {
            name = "git-clone"
            kind = "ClusterTask"
          }
          workspaces = [
            {
              name      = "output"
              workspace = "shared-data"
            }
          ]
          params = [
            {
              name  = "url"
              value = "$(params.git-url)"
            },
            {
              name  = "revision"
              value = "$(params.git-revision)"
            }
          ]
        },
        {
          name = "security-scan"
          taskRef = {
            name = "trivy-scanner"
          }
          workspaces = [
            {
              name      = "source"
              workspace = "shared-data"
            }
          ]
          runAfter = ["fetch-source"]
        },
        {
          name = "build-and-push"
          taskRef = {
            name = "kaniko"
            kind = "ClusterTask"
          }
          workspaces = [
            {
              name      = "source"
              workspace = "shared-data"
            }
          ]
          params = [
            {
              name  = "IMAGE"
              value = "$(params.image-name):$(params.image-tag)"
            },
            {
              name  = "DOCKERFILE"
              value = "./Dockerfile"
            }
          ]
          runAfter = ["security-scan"]
        }
      ]
    }
  }

  depends_on = [helm_release.tekton_pipelines]
}

# Trivy security scanner task
resource "kubernetes_manifest" "trivy_task" {
  manifest = {
    apiVersion = "tekton.dev/v1beta1"
    kind       = "Task"
    metadata = {
      name      = "trivy-scanner"
      namespace = kubernetes_namespace.gitops.metadata[0].name
    }
    spec = {
      workspaces = [
        {
          name        = "source"
          description = "Source code workspace"
        }
      ]
      steps = [
        {
          name  = "trivy-scan"
          image = "aquasec/trivy:latest"
          script = <<-EOF
            #!/bin/sh
            cd $(workspaces.source.path)
            trivy fs --exit-code 0 --severity HIGH,CRITICAL --format table .
            trivy fs --exit-code 1 --severity CRITICAL --format json . > trivy-results.json
          EOF
          resources = {
            requests = {
              cpu    = "100m"
              memory = "128Mi"
            }
            limits = {
              cpu    = "500m"
              memory = "512Mi"
            }
          }
        }
      ]
    }
  }

  depends_on = [helm_release.tekton_pipelines]
}

# GitHub webhook EventListener
resource "kubernetes_manifest" "github_eventlistener" {
  count = var.enable_github_webhooks ? 1 : 0
  
  manifest = {
    apiVersion = "triggers.tekton.dev/v1beta1"
    kind       = "EventListener"
    metadata = {
      name      = "github-listener"
      namespace = kubernetes_namespace.gitops.metadata[0].name
    }
    spec = {
      serviceAccountName = "tekton-triggers-sa"
      triggers = [
        {
          name = "github-push"
          interceptors = [
            {
              ref = {
                name = "github"
              }
              params = [
                {
                  name  = "secretRef"
                  value = {
                    secretName = "github-webhook-secret"
                    secretKey  = "webhook-secret"
                  }
                },
                {
                  name = "eventTypes"
                  value = ["push"]
                }
              ]
            }
          ]
          bindings = [
            {
              ref = "github-push-binding"
            }
          ]
          template = {
            ref = "build-and-deploy-template"
          }
        }
      ]
    }
  }

  depends_on = [helm_release.tekton_triggers]
}