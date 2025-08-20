# Service Mesh Module - Istio
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

# Istio system namespace
resource "kubernetes_namespace" "istio_system" {
  metadata {
    name = "istio-system"
    labels = merge(local.common_labels, {
      "app.kubernetes.io/component" = "service-mesh"
    })
  }
}

# Istio Base (CRDs and cluster roles)
resource "helm_release" "istio_base" {
  name       = "istio-base"
  repository = "https://istio-release.storage.googleapis.com/charts"
  chart      = "base"
  version    = var.istio_version
  namespace  = kubernetes_namespace.istio_system.metadata[0].name

  values = [
    yamlencode({
      global = {
        istioNamespace = kubernetes_namespace.istio_system.metadata[0].name
      }
    })
  ]

  depends_on = [kubernetes_namespace.istio_system]
}

# Istio Control Plane (istiod)
resource "helm_release" "istiod" {
  name       = "istiod"
  repository = "https://istio-release.storage.googleapis.com/charts"
  chart      = "istiod"
  version    = var.istio_version
  namespace  = kubernetes_namespace.istio_system.metadata[0].name

  values = [
    yamlencode({
      global = {
        istioNamespace = kubernetes_namespace.istio_system.metadata[0].name
        meshID         = var.cluster_name
        network        = var.cluster_name
      }

      pilot = {
        resources = {
          requests = {
            cpu    = "100m"
            memory = "128Mi"
          }
          limits = {
            cpu    = "500m"
            memory = "2Gi"
          }
        }

        env = {
          EXTERNAL_ISTIOD = false
          PILOT_TRACE_SAMPLING = var.trace_sampling_rate
          PILOT_ENABLE_WORKLOAD_ENTRY_AUTOREGISTRATION = true
          PILOT_ENABLE_CROSS_CLUSTER_WORKLOAD_ENTRY = true
        }

        traceSampling = var.trace_sampling_rate
      }

      telemetry = {
        v2 = {
          enabled = true
          prometheus = {
            configOverride = {
              metric_relabeling_configs = [
                {
                  source_labels = ["__name__"]
                  regex = "istio_.*"
                  target_label = "__tmp_istio_metric"
                },
                {
                  source_labels = ["__tmp_istio_metric", "source_app"]
                  regex = "istio_.*;(.*)"
                  target_label = "source_app"
                  replacement = "$1"
                }
              ]
            }
          }
        }
      }

      meshConfig = {
        accessLogFile = "/dev/stdout"
        defaultConfig = {
          gatewayTopology = {
            numTrustedProxies = 2
          }
          tracing = {
            sampling = var.trace_sampling_rate
            custom_tags = {
              cluster_name = {
                literal = {
                  value = var.cluster_name
                }
              }
            }
          }
        }
        extensionProviders = [
          {
            name = "tempo"
            envoyOtelAls = {
              service = "tempo-distributor.observability.svc.cluster.local"
              port    = 4317
            }
          }
        ]
        defaultProviders = {
          tracing = ["tempo"]
        }
      }
    })
  ]

  depends_on = [helm_release.istio_base]
}

# Istio Ingress Gateway
resource "helm_release" "istio_gateway" {
  name       = "istio-gateway"
  repository = "https://istio-release.storage.googleapis.com/charts"
  chart      = "gateway"
  version    = var.istio_version
  namespace  = kubernetes_namespace.istio_system.metadata[0].name

  values = [
    yamlencode({
      service = {
        type = "LoadBalancer"
        annotations = {
          "service.beta.kubernetes.io/aws-load-balancer-type"                              = "nlb"
          "service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled" = "true"
          "service.beta.kubernetes.io/aws-load-balancer-backend-protocol"                  = "tcp"
        }
        ports = [
          {
            name       = "status-port"
            port       = 15021
            protocol   = "TCP"
            targetPort = 15021
          },
          {
            name       = "http2"
            port       = 80
            protocol   = "TCP"
            targetPort = 8080
          },
          {
            name       = "https"
            port       = 443
            protocol   = "TCP"
            targetPort = 8443
          }
        ]
      }

      resources = {
        requests = {
          cpu    = "100m"
          memory = "128Mi"
        }
        limits = {
          cpu    = "2000m"
          memory = "1024Mi"
        }
      }

      autoscaling = {
        enabled                        = true
        minReplicas                   = var.gateway_min_replicas
        maxReplicas                   = var.gateway_max_replicas
        targetCPUUtilizationPercentage = 80
      }

      podDisruptionBudget = {
        minAvailable = 1
      }

      nodeSelector = {}
      tolerations  = []
      affinity     = {}
    })
  ]

  depends_on = [time_sleep.wait_for_istio_crds]
}

# Wait for Istio CRDs to be available
resource "time_sleep" "wait_for_istio_crds" {
  depends_on      = [helm_release.istiod]
  create_duration = "60s"
}

# Default Gateway for applications
resource "kubernetes_manifest" "default_gateway" {
  manifest = {
    apiVersion = "networking.istio.io/v1beta1"
    kind       = "Gateway"
    metadata = {
      name      = "default-gateway"
      namespace = kubernetes_namespace.istio_system.metadata[0].name
    }
    spec = {
      selector = {
        istio = "gateway"
      }
      servers = [
        {
          port = {
            number   = 80
            name     = "http"
            protocol = "HTTP"
          }
          hosts = ["*"]
          tls = {
            httpsRedirect = true
          }
        },
        {
          port = {
            number   = 443
            name     = "https"
            protocol = "HTTPS"
          }
          hosts = ["*"]
          tls = {
            mode = "SIMPLE"
            credentialName = "default-gateway-certs"
          }
        }
      ]
    }
  }

  depends_on = [time_sleep.wait_for_istio_crds, helm_release.istio_gateway]
}

# Default PeerAuthentication for mTLS
resource "kubernetes_manifest" "default_peer_authentication" {
  manifest = {
    apiVersion = "security.istio.io/v1beta1"
    kind       = "PeerAuthentication"
    metadata = {
      name      = "default"
      namespace = kubernetes_namespace.istio_system.metadata[0].name
    }
    spec = {
      mtls = {
        mode = var.mtls_mode
      }
    }
  }

  depends_on = [time_sleep.wait_for_istio_crds]
}

# Default DestinationRule for mTLS
resource "kubernetes_manifest" "default_destination_rule" {
  manifest = {
    apiVersion = "networking.istio.io/v1beta1"
    kind       = "DestinationRule"
    metadata = {
      name      = "default"
      namespace = kubernetes_namespace.istio_system.metadata[0].name
    }
    spec = {
      host = "*.local"
      trafficPolicy = {
        tls = {
          mode = "ISTIO_MUTUAL"
        }
      }
    }
  }

  depends_on = [time_sleep.wait_for_istio_crds]
}

# Telemetry configuration for observability
resource "kubernetes_manifest" "telemetry_v2" {
  manifest = {
    apiVersion = "telemetry.istio.io/v1alpha1"
    kind       = "Telemetry"
    metadata = {
      name      = "default"
      namespace = kubernetes_namespace.istio_system.metadata[0].name
    }
    spec = {
      metrics = [
        {
          providers = [
            {
              name = "prometheus"
            }
          ]
        }
      ]
      tracing = [
        {
          providers = [
            {
              name = "tempo"
            }
          ]
          customTags = {
            cluster_name = {
              literal = {
                value = var.cluster_name
              }
            }
            environment = {
              literal = {
                value = var.environment
              }
            }
          }
        }
      ]
      accessLogging = [
        {
          providers = [
            {
              name = "otel"
            }
          ]
        }
      ]
    }
  }

  depends_on = [time_sleep.wait_for_istio_crds]
}

# Service Monitor for Istio metrics
resource "kubernetes_manifest" "istio_service_monitor" {
  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "ServiceMonitor"
    metadata = {
      name      = "istio-system"
      namespace = kubernetes_namespace.istio_system.metadata[0].name
      labels = {
        app = "istiod"
      }
    }
    spec = {
      selector = {
        matchLabels = {
          app = "istiod"
        }
      }
      endpoints = [
        {
          port = "http-monitoring"
          path = "/stats/prometheus"
        }
      ]
    }
  }

  depends_on = [time_sleep.wait_for_istio_crds]
}

# Service Monitor for Istio Gateway
resource "kubernetes_manifest" "istio_gateway_service_monitor" {
  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "ServiceMonitor"
    metadata = {
      name      = "istio-gateway"
      namespace = kubernetes_namespace.istio_system.metadata[0].name
      labels = {
        app = "istio-gateway"
      }
    }
    spec = {
      selector = {
        matchLabels = {
          istio = "gateway"
        }
      }
      endpoints = [
        {
          port = "status-port"
          path = "/stats/prometheus"
        }
      ]
    }
  }

  depends_on = [time_sleep.wait_for_istio_crds, helm_release.istio_gateway]
}

# Kiali for service mesh observability (optional)
resource "helm_release" "kiali" {
  count = var.enable_kiali ? 1 : 0
  
  name       = "kiali-server"
  repository = "https://kiali.org/helm-charts"
  chart      = "kiali-server"
  version    = var.kiali_version
  namespace  = kubernetes_namespace.istio_system.metadata[0].name

  values = [
    yamlencode({
      auth = {
        strategy = "anonymous"
      }

      deployment = {
        resources = {
          requests = {
            cpu    = "100m"
            memory = "128Mi"
          }
          limits = {
            cpu    = "500m"
            memory = "1Gi"
          }
        }
      }

      external_services = {
        prometheus = {
          url = "http://prometheus-kube-prometheus-prometheus.observability.svc.cluster.local:9090"
        }
        grafana = {
          enabled = true
          in_cluster_url = "http://grafana.observability.svc.cluster.local:3000"
          url = "https://${var.domain_name}/grafana"
        }
        tracing = {
          enabled = true
          in_cluster_url = "http://tempo-query-frontend.observability.svc.cluster.local:3200"
          url = "https://${var.domain_name}/tempo"
        }
      }

      server = {
        web_root = "/kiali"
      }
    })
  ]

  depends_on = [time_sleep.wait_for_istio_crds]
}

# Jaeger for distributed tracing (optional, if not using Tempo)
resource "helm_release" "jaeger" {
  count = var.enable_jaeger ? 1 : 0
  
  name       = "jaeger"
  repository = "https://jaegertracing.github.io/helm-charts"
  chart      = "jaeger"
  version    = var.jaeger_version
  namespace  = kubernetes_namespace.istio_system.metadata[0].name

  values = [
    yamlencode({
      provisionDataStore = {
        cassandra = false
        elasticsearch = false
      }

      allInOne = {
        enabled = true
        resources = {
          requests = {
            cpu    = "100m"
            memory = "128Mi"
          }
          limits = {
            cpu    = "500m"
            memory = "1Gi"
          }
        }
      }

      storage = {
        type = "memory"
      }

      agent = {
        enabled = false
      }

      collector = {
        enabled = false
      }

      query = {
        enabled = false
      }
    })
  ]

  depends_on = [time_sleep.wait_for_istio_crds]
}