# Ambassador (Emissary-Ingress) Terraform module
# Deploys Ambassador as API Gateway with AWS NLB integration
# Sized for production traffic with resource headroom for future workflows

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

# Ambassador namespace
resource "kubernetes_namespace" "ambassador" {
  metadata {
    name = var.namespace
    labels = {
      name = var.namespace
      "ambassador.io/ambassador-id" = var.ambassador_id
    }
  }
}

# Ambassador CRDs (installed separately to avoid race conditions)
resource "helm_release" "ambassador_crds" {
  name       = "ambassador-crds"
  repository = "https://app.getambassador.io"
  chart      = "emissary-crds"
  version    = var.ambassador_version
  namespace  = kubernetes_namespace.ambassador.metadata[0].name

  # Don't wait for CRDs installation to complete
  wait          = false
  wait_for_jobs = false
}

# Ambassador main deployment
resource "helm_release" "ambassador" {
  name       = "ambassador"
  repository = "https://app.getambassador.io"
  chart      = "emissary-ingress"
  version    = var.ambassador_version
  namespace  = kubernetes_namespace.ambassador.metadata[0].name

  values = [
    yamlencode({
      # Ambassador ID for multi-tenancy
      ambassadorId = var.ambassador_id

      # Replica configuration for high availability
      replicaCount = var.replica_count

      # Resource sizing for t3.large nodes with production traffic
      resources = {
        requests = {
          cpu    = "200m"  # Higher for API Gateway traffic
          memory = "256Mi"
        }
        limits = {
          cpu    = "1000m"
          memory = "512Mi"
        }
      }

      # Service configuration for AWS NLB
      service = {
        type = "LoadBalancer"
        ports = [
          {
            name       = "http"
            port       = 80
            targetPort = 8080
            protocol   = "TCP"
          },
          {
            name       = "https"
            port       = 443
            targetPort = 8443
            protocol   = "TCP"
          }
        ]
        
        # AWS Load Balancer annotations for NLB
        annotations = merge({
          "service.beta.kubernetes.io/aws-load-balancer-type"                              = "nlb"
          "service.beta.kubernetes.io/aws-load-balancer-scheme"                           = var.load_balancer_scheme
          "service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled" = "true"
          "service.beta.kubernetes.io/aws-load-balancer-backend-protocol"                 = "tcp"
          "service.beta.kubernetes.io/aws-load-balancer-connection-idle-timeout"          = "60"
          "service.beta.kubernetes.io/aws-load-balancer-healthcheck-protocol"             = "tcp"
          "service.beta.kubernetes.io/aws-load-balancer-healthcheck-port"                 = "8877"
          "external-dns.alpha.kubernetes.io/hostname"                                     = var.hostname != "" ? var.hostname : ""
        }, var.service_annotations)
      }

      # Environment-specific configuration
      env = {
        AMBASSADOR_NAMESPACE = kubernetes_namespace.ambassador.metadata[0].name
      }

      # Security context
      securityContext = {
        runAsUser = 8888
        runAsGroup = 8888
        fsGroup = 8888
        runAsNonRoot = true
      }

      # Pod security context
      podSecurityContext = {
        runAsUser = 8888
        runAsGroup = 8888
        fsGroup = 8888
        runAsNonRoot = true
      }

      # Affinity rules for proper distribution
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
                      values   = ["emissary-ingress"]
                    }
                  ]
                }
                topologyKey = "kubernetes.io/hostname"
              }
            }
          ]
        }
      }

      # Node selection
      nodeSelector = {
        "kubernetes.io/arch" = "amd64"
      }

      # Tolerations for spot instances
      tolerations = [
        {
          key      = "node.kubernetes.io/spot"
          operator = "Exists"
          effect   = "NoSchedule"
        }
      ]

      # Health checks
      livenessProbe = {
        httpGet = {
          path   = "/ambassador/v0/check_alive"
          port   = 8877
          scheme = "HTTP"
        }
        initialDelaySeconds = 30
        periodSeconds       = 15
        timeoutSeconds      = 5
        failureThreshold    = 3
      }

      readinessProbe = {
        httpGet = {
          path   = "/ambassador/v0/check_ready"
          port   = 8877
          scheme = "HTTP"
        }
        initialDelaySeconds = 10
        periodSeconds       = 5
        timeoutSeconds      = 3
        failureThreshold    = 3
      }

      # Metrics and monitoring
      metrics = {
        serviceMonitor = {
          enabled = var.enable_monitoring
        }
      }

      # Admin service
      adminService = {
        create = true
        type   = "ClusterIP"
        port   = 8877
        annotations = {
          "service.alpha.kubernetes.io/tolerate-unready-endpoints" = "true"
        }
      }

      # RBAC
      rbac = {
        create = true
      }

      serviceAccount = {
        create = true
        name   = "ambassador"
      }

      # Pod disruption budget
      podDisruptionBudget = {
        enabled      = var.replica_count > 1
        minAvailable = 1
      }

      # Additional Ambassador configuration
      ambassador = {
        config = {
          # Enable gRPC-Web
          grpc_web = {
            enabled = true
          }
          
          # Enable proper protocol detection
          use_remote_address = true
          
          # CORS configuration for API Gateway
          cors = {
            origins = var.cors_origins
            methods = ["GET", "POST", "PUT", "DELETE", "OPTIONS", "PATCH"]
            headers = ["Content-Type", "Authorization"]
            credentials = true
            exposed_headers = ["X-Total-Count"]
            max_age = 86400
          }
        }
      }
    })
  ]

  depends_on = [
    kubernetes_namespace.ambassador,
    helm_release.ambassador_crds
  ]

  # Wait for Ambassador to be ready before proceeding
  wait          = true
  wait_for_jobs = true
  timeout       = 600  # 10 minutes
}

# Default Host configuration for the API Gateway
resource "kubernetes_manifest" "default_host" {
  count = var.hostname != "" ? 1 : 0

  manifest = {
    apiVersion = "getambassador.io/v3alpha1"
    kind       = "Host"
    metadata = {
      name      = "default-host"
      namespace = kubernetes_namespace.ambassador.metadata[0].name
    }
    spec = {
      hostname = var.hostname
      acmeProvider = var.enable_tls ? {
        authority = var.acme_provider_authority
        email     = var.acme_email
      } : null
      tlsSecret = var.enable_tls ? {
        name = "ambassador-tls"
      } : null
      requestPolicy = {
        insecure = {
          action = var.redirect_cleartext_from == 80 ? "Redirect" : "Route"
        }
      }
    }
  }

  depends_on = [helm_release.ambassador]
}

# Default Mapping for health checks
resource "kubernetes_manifest" "health_mapping" {
  manifest = {
    apiVersion = "getambassador.io/v3alpha1"
    kind       = "Mapping"
    metadata = {
      name      = "health-check"
      namespace = kubernetes_namespace.ambassador.metadata[0].name
    }
    spec = {
      hostname = var.hostname != "" ? var.hostname : "*"
      prefix   = "/health"
      service  = "ambassador-admin:8877"
      rewrite  = "/ambassador/v0/check_ready"
    }
  }

  depends_on = [helm_release.ambassador]
}

# Wait for Ambassador to be fully ready
resource "kubernetes_deployment" "ambassador_ready" {
  count = 1

  wait_for_rollout = true
  
  metadata {
    name      = "ambassador-readiness-check"
    namespace = kubernetes_namespace.ambassador.metadata[0].name
  }

  spec {
    replicas = 0

    selector {
      match_labels = {
        app = "ambassador-readiness"
      }
    }

    template {
      metadata {
        labels = {
          app = "ambassador-readiness"
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
    helm_release.ambassador,
    kubernetes_manifest.default_host,
    kubernetes_manifest.health_mapping
  ]

  timeouts {
    create = "10m"
    update = "10m"
  }
}