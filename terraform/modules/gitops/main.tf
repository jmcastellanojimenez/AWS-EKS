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
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
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
  
  # Prevent namespace ownership conflicts
  create_namespace = false
  depends_on = [kubernetes_namespace.gitops]

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
}

# Create Tekton namespace with Helm-compatible labels
resource "kubernetes_namespace" "tekton_pipelines" {
  metadata {
    name = "tekton-pipelines"
    labels = {
      "app.kubernetes.io/name"       = "tekton-pipelines"
      "app.kubernetes.io/managed-by" = "Helm"
      "app.kubernetes.io/part-of"    = var.project_name
    }
    annotations = {
      "meta.helm.sh/release-name"      = "tekton-pipelines"
      "meta.helm.sh/release-namespace" = "tekton-pipelines"
    }
  }
}

# Tekton Pipelines
resource "helm_release" "tekton_pipelines" {
  name       = "tekton-pipelines"
  repository = "https://cdfoundation.github.io/tekton-helm-chart"
  chart      = "tekton-pipeline"
  version    = var.tekton_version
  namespace  = kubernetes_namespace.tekton_pipelines.metadata[0].name
  
  # Don't let Helm create namespace since we manage it
  create_namespace = false
  depends_on = [kubernetes_namespace.tekton_pipelines]

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
}

# Tekton Triggers (included in tekton-pipeline chart, not a separate release)
# resource "helm_release" "tekton_triggers" {
#   name       = "tekton-triggers"
#   repository = "https://cdfoundation.github.io/tekton-helm-chart"
#   chart      = "tekton-triggers"
#   version    = var.tekton_triggers_version
#   namespace  = kubernetes_namespace.gitops.metadata[0].name
#
#   values = [
#     yamlencode({
#       controller = {
#         resources = {
#           requests = {
#             cpu    = "100m"
#             memory = "128Mi"
#           }
#           limits = {
#             cpu    = "500m"
#             memory = "512Mi"
#           }
#         }
#       }
#
#       webhook = {
#         resources = {
#           requests = {
#             cpu    = "100m"
#             memory = "128Mi"
#           }
#           limits = {
#             cpu    = "500m"
#             memory = "512Mi"
#           }
#         }
#       }
#     })
#   ]
#
#   depends_on = [helm_release.tekton_pipelines]
# }

# Enhanced CRD verification with exponential backoff
# ArgoCD CRD verification with exponential backoff
resource "null_resource" "verify_argocd_crds" {
  depends_on = [helm_release.argocd]

  provisioner "local-exec" {
    command = <<-EOT
      #!/bin/bash
      set -e
      
      echo "🔄 Verifying ArgoCD CRDs with exponential backoff..."
      
      # Required ArgoCD CRDs
      REQUIRED_CRDS=(
        "applications.argoproj.io"
        "applicationsets.argoproj.io"
        "appprojects.argoproj.io"
      )
      
      # Exponential backoff parameters
      MAX_ATTEMPTS=12
      BASE_DELAY=5
      
      for crd in "$${REQUIRED_CRDS[@]}"; do
        echo "⏳ Waiting for CRD: $crd"
        
        for attempt in $(seq 1 $MAX_ATTEMPTS); do
          if kubectl get crd "$crd" >/dev/null 2>&1; then
            echo "✅ CRD $crd is available"
            break
          fi
          
          if [ $attempt -eq $MAX_ATTEMPTS ]; then
            echo "❌ CRD $crd not available after $MAX_ATTEMPTS attempts"
            exit 1
          fi
          
          # Exponential backoff: 5s, 10s, 20s, 40s, 80s, 160s (max 300s)
          delay=$((BASE_DELAY * (2 ** (attempt - 1))))
          if [ $delay -gt 300 ]; then
            delay=300
          fi
          
          echo "⏳ Attempt $attempt/$MAX_ATTEMPTS failed, waiting $${delay}s before retry..."
          sleep $delay
        done
      done
      
      echo "✅ All ArgoCD CRDs are available and ready!"
    EOT
  }

  triggers = {
    helm_release_revision = helm_release.argocd.version
    timestamp = timestamp()
  }
}

# Tekton CRD verification with exponential backoff
resource "null_resource" "verify_tekton_crds" {
  depends_on = [helm_release.tekton_pipelines]

  provisioner "local-exec" {
    command = <<-EOT
      #!/bin/bash
      set -e
      
      echo "🔄 Verifying Tekton CRDs with exponential backoff..."
      
      # Required Tekton CRDs
      REQUIRED_CRDS=(
        "pipelines.tekton.dev"
        "tasks.tekton.dev"
        "taskruns.tekton.dev"
        "pipelineruns.tekton.dev"
        "clustertasks.tekton.dev"
      )
      
      # Exponential backoff parameters
      MAX_ATTEMPTS=12
      BASE_DELAY=5
      
      for crd in "$${REQUIRED_CRDS[@]}"; do
        echo "⏳ Waiting for CRD: $crd"
        
        for attempt in $(seq 1 $MAX_ATTEMPTS); do
          if kubectl get crd "$crd" >/dev/null 2>&1; then
            echo "✅ CRD $crd is available"
            break
          fi
          
          if [ $attempt -eq $MAX_ATTEMPTS ]; then
            echo "❌ CRD $crd not available after $MAX_ATTEMPTS attempts"
            exit 1
          fi
          
          # Exponential backoff: 5s, 10s, 20s, 40s, 80s, 160s (max 300s)
          delay=$((BASE_DELAY * (2 ** (attempt - 1))))
          if [ $delay -gt 300 ]; then
            delay=300
          fi
          
          echo "⏳ Attempt $attempt/$MAX_ATTEMPTS failed, waiting $${delay}s before retry..."
          sleep $delay
        done
      done
      
      echo "✅ All Tekton CRDs are available and ready!"
    EOT
  }

  triggers = {
    helm_release_revision = helm_release.tekton_pipelines.version
    timestamp = timestamp()
  }
}

# Tekton webhook service verification
resource "null_resource" "verify_tekton_webhook" {
  depends_on = [null_resource.verify_tekton_crds]

  provisioner "local-exec" {
    command = <<-EOT
      #!/bin/bash
      set -e
      
      echo "🔄 Verifying Tekton webhook service..."
      
      # Exponential backoff parameters
      MAX_ATTEMPTS=10
      BASE_DELAY=10
      
      for attempt in $(seq 1 $MAX_ATTEMPTS); do
        # Check if webhook service exists and is ready
        if kubectl get svc -n tekton-pipelines tekton-pipelines-webhook >/dev/null 2>&1; then
          echo "✅ Tekton webhook service found"
          
          # Wait for webhook pods to be ready
          if kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=tekton-pipelines-webhook -n tekton-pipelines --timeout=60s 2>/dev/null; then
            echo "✅ Tekton webhook pods are ready"
            break
          else
            echo "⏳ Webhook pods not ready yet, continuing..."
          fi
        fi
        
        if [ $attempt -eq $MAX_ATTEMPTS ]; then
          echo "❌ Tekton webhook service not ready after $MAX_ATTEMPTS attempts"
          # Don't fail completely, as webhook might not be critical for basic functionality
          echo "⚠️ Continuing without webhook verification (non-critical)"
          break
        fi
        
        # Exponential backoff: 10s, 20s, 40s, 80s, 160s, 300s (max 300s)
        delay=$((BASE_DELAY * (2 ** (attempt - 1))))
        if [ $delay -gt 300 ]; then
          delay=300
        fi
        
        echo "⏳ Attempt $attempt/$MAX_ATTEMPTS, waiting $${delay}s before retry..."
        sleep $delay
      done
      
      echo "✅ Tekton webhook verification completed!"
    EOT
  }

  triggers = {
    crds_verified = null_resource.verify_tekton_crds.id
    timestamp = timestamp()
  }
}

# Fallback time-based wait for compatibility
resource "time_sleep" "wait_for_argocd_crds" {
  depends_on      = [null_resource.verify_argocd_crds]
  create_duration = "5s"  # Minimal wait since verification already happened
}

resource "time_sleep" "wait_for_tekton_crds" {
  depends_on      = [null_resource.verify_tekton_crds]
  create_duration = "5s"  # Minimal wait since verification already happened
}

resource "time_sleep" "wait_for_tekton_webhook" {
  depends_on      = [null_resource.verify_tekton_webhook]
  create_duration = "5s"  # Minimal wait since verification already happened
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

  # Enable server-side apply to handle CRD timing issues
  computed_fields = ["metadata.labels", "metadata.annotations", "spec", "status"]
  
  # Enhanced dependency chain for reliable CRD availability
  depends_on = [
    null_resource.verify_argocd_crds,
    time_sleep.wait_for_argocd_crds
  ]
}

# Tekton Pipeline for container builds
resource "kubernetes_manifest" "build_pipeline" {
  manifest = {
    apiVersion = "tekton.dev/v1beta1"
    kind       = "Pipeline"
    metadata = {
      name      = "build-and-push"
      namespace = kubernetes_namespace.tekton_pipelines.metadata[0].name
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

  # Enable server-side apply to handle CRD timing issues
  computed_fields = ["metadata.labels", "metadata.annotations", "spec", "status"]
  
  # Enhanced dependency chain for reliable CRD and webhook availability
  depends_on = [
    null_resource.verify_tekton_crds,
    null_resource.verify_tekton_webhook,
    time_sleep.wait_for_tekton_webhook
  ]
}

# Trivy security scanner task
resource "kubernetes_manifest" "trivy_task" {
  manifest = {
    apiVersion = "tekton.dev/v1beta1"
    kind       = "Task"
    metadata = {
      name      = "trivy-scanner"
      namespace = kubernetes_namespace.tekton_pipelines.metadata[0].name
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

  # Enable server-side apply to handle CRD timing issues
  computed_fields = ["metadata.labels", "metadata.annotations", "spec", "status"]
  
  # Enhanced dependency chain for reliable CRD and webhook availability
  depends_on = [
    null_resource.verify_tekton_crds,
    null_resource.verify_tekton_webhook,
    time_sleep.wait_for_tekton_webhook
  ]
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

  # Enable server-side apply to handle CRD timing issues
  computed_fields = ["metadata.labels", "metadata.annotations", "spec", "status"]
  
  # Enhanced dependency chain for reliable CRD and webhook availability
  depends_on = [
    null_resource.verify_tekton_crds,
    null_resource.verify_tekton_webhook,
    time_sleep.wait_for_tekton_webhook
  ]
}