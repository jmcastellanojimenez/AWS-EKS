# Ingress + API Gateway Module
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

# Namespace for ingress components
resource "kubernetes_namespace" "ingress" {
  metadata {
    name = "ingress-system"
    labels = merge(local.common_labels, {
      "app.kubernetes.io/component" = "ingress"
    })
  }
}

# cert-manager
resource "helm_release" "cert_manager" {
  name       = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  version    = var.cert_manager_version
  namespace  = kubernetes_namespace.ingress.metadata[0].name

  set {
    name  = "installCRDs"
    value = "true"
  }

  set {
    name  = "global.leaderElection.namespace"
    value = kubernetes_namespace.ingress.metadata[0].name
  }

  set {
    name  = "prometheus.enabled"
    value = "true"
  }

  set {
    name  = "prometheus.servicemonitor.enabled"
    value = "true"
  }

  values = [
    yamlencode({
      resources = {
        requests = {
          cpu    = "50m"
          memory = "64Mi"
        }
        limits = {
          cpu    = "200m"
          memory = "256Mi"
        }
      }
      webhook = {
        resources = {
          requests = {
            cpu    = "25m"
            memory = "32Mi"
          }
          limits = {
            cpu    = "100m"
            memory = "128Mi"
          }
        }
      }
      cainjector = {
        resources = {
          requests = {
            cpu    = "50m"
            memory = "64Mi"
          }
          limits = {
            cpu    = "200m"
            memory = "256Mi"
          }
        }
      }
    })
  ]

  depends_on = [kubernetes_namespace.ingress]
}

# Wait for cert-manager CRDs to be available
resource "time_sleep" "wait_for_cert_manager_crds" {
  depends_on      = [helm_release.cert_manager]
  create_duration = "30s"
}

# ClusterIssuer for Let's Encrypt
resource "kubernetes_manifest" "letsencrypt_issuer" {
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
            dns01 = {
              cloudflare = {
                email = var.cloudflare_email
                apiTokenSecretRef = {
                  name = "cloudflare-api-token"
                  key  = "api-token"
                }
              }
            }
          }
        ]
      }
    }
  }

  depends_on = [time_sleep.wait_for_cert_manager_crds]
}

# Cloudflare API token secret
resource "kubernetes_secret" "cloudflare_api_token" {
  metadata {
    name      = "cloudflare-api-token"
    namespace = kubernetes_namespace.ingress.metadata[0].name
  }

  data = {
    api-token = var.cloudflare_api_token
  }

  type = "Opaque"
}

# external-dns
resource "helm_release" "external_dns" {
  name       = "external-dns"
  repository = "https://kubernetes-sigs.github.io/external-dns/"
  chart      = "external-dns"
  version    = var.external_dns_version
  namespace  = kubernetes_namespace.ingress.metadata[0].name

  values = [
    yamlencode({
      provider = "cloudflare"
      env = [
        {
          name = "CF_API_TOKEN"
          valueFrom = {
            secretKeyRef = {
              name = kubernetes_secret.cloudflare_api_token.metadata[0].name
              key  = "api-token"
            }
          }
        }
      ]
      domainFilters = var.domain_filters
      policy        = "sync"
      registry      = "txt"
      txtOwnerId    = var.cluster_name

      resources = {
        requests = {
          cpu    = "25m"
          memory = "32Mi"
        }
        limits = {
          cpu    = "100m"
          memory = "128Mi"
        }
      }

      serviceMonitor = {
        enabled = true
      }

      metrics = {
        enabled = true
      }
    })
  ]

  depends_on = [kubernetes_secret.cloudflare_api_token]
}

# Ambassador (Emissary Ingress)
resource "helm_release" "ambassador" {
  name       = "ambassador"
  repository = "https://app.getambassador.io"
  chart      = "emissary-ingress"
  version    = var.ambassador_version
  namespace  = kubernetes_namespace.ingress.metadata[0].name

  values = [
    yamlencode({
      replicaCount = var.ambassador_replica_count

      service = {
        type = "LoadBalancer"
        annotations = {
          "service.beta.kubernetes.io/aws-load-balancer-type"                              = "nlb"
          "service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled" = "true"
          "service.beta.kubernetes.io/aws-load-balancer-backend-protocol"                  = "tcp"
        }
      }

      env = {
        AMBASSADOR_NAMESPACE = kubernetes_namespace.ingress.metadata[0].name
      }

      resources = {
        requests = {
          cpu    = "200m"
          memory = "256Mi"
        }
        limits = {
          cpu    = "500m"
          memory = "512Mi"
        }
      }

      autoscaling = {
        enabled                        = true
        minReplicas                    = var.ambassador_replica_count
        maxReplicas                    = var.ambassador_max_replicas
        targetCPUUtilizationPercentage = 70
      }

      podDisruptionBudget = {
        enabled      = true
        minAvailable = 1
      }

      serviceMonitor = {
        enabled = true
      }

      prometheusExporter = {
        enabled = true
      }
    })
  ]

  depends_on = [kubernetes_namespace.ingress]
}

# Wait for Ambassador CRDs to be available
resource "time_sleep" "wait_for_ambassador_crds" {
  depends_on      = [helm_release.ambassador]
  create_duration = "45s"
}

# Ambassador Module and Mappings
resource "kubernetes_manifest" "ambassador_module" {
  manifest = {
    apiVersion = "getambassador.io/v3alpha1"
    kind       = "Module"
    metadata = {
      name      = "ambassador"
      namespace = kubernetes_namespace.ingress.metadata[0].name
    }
    spec = {
      config = {
        diagnostics = {
          enabled = true
        }
        lua_scripts                          = []
        use_proxy_proto                      = false
        use_remote_address                   = true
        xff_num_trusted_hops                 = 1
        server_name                          = var.domain_name
        enable_grpc_http11_bridge            = false
        enable_grpc_web                      = false
        proper_case                          = false
        merge_slashes                        = false
        reject_requests_with_escaped_slashes = false
      }
    }
  }

  depends_on = [time_sleep.wait_for_ambassador_crds]
}

# Default Ambassador Host
resource "kubernetes_manifest" "ambassador_host" {
  manifest = {
    apiVersion = "getambassador.io/v3alpha1"
    kind       = "Host"
    metadata = {
      name      = "default-host"
      namespace = kubernetes_namespace.ingress.metadata[0].name
    }
    spec = {
      hostname = var.domain_name
      acmeProvider = {
        authority = "https://acme-v02.api.letsencrypt.org/directory"
        email     = var.letsencrypt_email
      }
      tlsSecret = {
        name = "ambassador-certs"
      }
    }
  }

  depends_on = [time_sleep.wait_for_ambassador_crds, time_sleep.wait_for_cert_manager_crds]
}