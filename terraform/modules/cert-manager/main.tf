# cert-manager Terraform module
# Deploys cert-manager for automatic SSL certificate management via Let's Encrypt
# Sized appropriately for t3.large nodes with future workflow headroom

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
  }
}

# cert-manager namespace
resource "kubernetes_namespace" "cert_manager" {
  metadata {
    name = "cert-manager"
    labels = {
      "name" = "cert-manager"
      "cert-manager.io/disable-validation" = "true"
    }
  }
}

# cert-manager Helm release
resource "helm_release" "cert_manager" {
  name       = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  version    = var.cert_manager_version
  namespace  = kubernetes_namespace.cert_manager.metadata[0].name

  # Resource sizing for t3.large nodes with future workflow headroom
  values = [
    yamlencode({
      installCRDs = true
      
      # cert-manager controller resources
      resources = {
        requests = {
          cpu    = "10m"
          memory = "32Mi"
        }
        limits = {
          cpu    = "100m"
          memory = "128Mi"
        }
      }

      # Webhook resources
      webhook = {
        resources = {
          requests = {
            cpu    = "10m"
            memory = "32Mi"
          }
          limits = {
            cpu    = "100m"
            memory = "128Mi"
          }
        }
      }

      # CA Injector resources
      cainjector = {
        resources = {
          requests = {
            cpu    = "10m"
            memory = "32Mi"
          }
          limits = {
            cpu    = "100m"
            memory = "128Mi"
          }
        }
      }

      # Security context
      securityContext = {
        runAsNonRoot = true
        runAsUser    = 1000
        runAsGroup   = 1000
        fsGroup      = 1000
      }

      # Node selection for efficient resource utilization
      nodeSelector = {
        "kubernetes.io/arch" = "amd64"
      }

      # Pod anti-affinity for high availability
      affinity = {
        podAntiAffinity = {
          preferredDuringSchedulingIgnoredDuringExecution = [
            {
              weight = 100
              podAffinityTerm = {
                labelSelector = {
                  matchExpressions = [
                    {
                      key      = "app.kubernetes.io/name"
                      operator = "In"
                      values   = ["cert-manager"]
                    }
                  ]
                }
                topologyKey = "kubernetes.io/hostname"
              }
            }
          ]
        }
      }

      # Prometheus monitoring
      prometheus = {
        enabled = var.enable_monitoring
        servicemonitor = {
          enabled = var.enable_monitoring
        }
      }
    })
  ]

  depends_on = [kubernetes_namespace.cert_manager]
}

# Let's Encrypt staging ClusterIssuer for testing
resource "kubernetes_manifest" "letsencrypt_staging" {
  count = var.enable_letsencrypt ? 1 : 0

  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = "letsencrypt-staging"
    }
    spec = {
      acme = {
        server = "https://acme-staging-v02.api.letsencrypt.org/directory"
        email  = var.letsencrypt_email
        privateKeySecretRef = {
          name = "letsencrypt-staging"
        }
        solvers = [
          {
            http01 = {
              ingress = {
                class = "ambassador"
              }
            }
          }
        ]
      }
    }
  }

  depends_on = [helm_release.cert_manager]
}

# Let's Encrypt production ClusterIssuer
resource "kubernetes_manifest" "letsencrypt_prod" {
  count = var.enable_letsencrypt ? 1 : 0

  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = "letsencrypt-prod"
    }
    spec = {
      acme = {
        server = "https://acme-v02.api.letsencrypt.org/directory"
        email  = var.letsencrypt_email
        privateKeySecretRef = {
          name = "letsencrypt-prod"
        }
        solvers = [
          {
            http01 = {
              ingress = {
                class = "ambassador"
              }
            }
          }
        ]
      }
    }
  }

  depends_on = [helm_release.cert_manager]
}

# Wait for cert-manager to be ready
resource "kubernetes_deployment" "cert_manager_ready" {
  count = 1

  wait_for_rollout = true
  
  metadata {
    name      = "cert-manager-readiness-check"
    namespace = kubernetes_namespace.cert_manager.metadata[0].name
  }

  spec {
    replicas = 0  # This is just a readiness check, no actual pods

    selector {
      match_labels = {
        app = "cert-manager-readiness"
      }
    }

    template {
      metadata {
        labels = {
          app = "cert-manager-readiness"
        }
      }

      spec {
        container {
          name  = "readiness"
          image = "alpine:3.18"
          command = ["sleep", "1"]
        }
      }
    }
  }

  depends_on = [
    helm_release.cert_manager,
    kubernetes_manifest.letsencrypt_staging,
    kubernetes_manifest.letsencrypt_prod
  ]

  timeouts {
    create = "5m"
    update = "5m"
  }
}