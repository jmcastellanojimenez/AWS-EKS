# LGTM Observability Stack with OpenTelemetry
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

# Configure providers using cluster information
data "aws_eks_cluster_auth" "cluster" {
  name = var.cluster_name
}

provider "kubernetes" {
  host                   = var.cluster_endpoint
  cluster_ca_certificate = base64decode(var.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

provider "helm" {
  kubernetes {
    host                   = var.cluster_endpoint
    cluster_ca_certificate = base64decode(var.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}

locals {
  common_labels = {
    "app.kubernetes.io/managed-by" = "terraform"
    "app.kubernetes.io/part-of"    = var.project_name
  }
}

# Observability namespace
resource "kubernetes_namespace" "observability" {
  metadata {
    name = "observability"
    labels = merge(local.common_labels, {
      "app.kubernetes.io/component" = "observability"
    })
  }
}

# OpenTelemetry Operator
resource "helm_release" "opentelemetry_operator" {
  name       = "opentelemetry-operator"
  repository = "https://open-telemetry.github.io/opentelemetry-helm-charts"
  chart      = "opentelemetry-operator"
  version    = var.opentelemetry_operator_version
  namespace  = kubernetes_namespace.observability.metadata[0].name

  values = [
    yamlencode({
      manager = {
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
      
      admissionWebhooks = {
        certManager = {
          enabled = true
        }
      }
    })
  ]

  depends_on = [kubernetes_namespace.observability]
}

# Prometheus Stack (kube-prometheus-stack)
resource "helm_release" "prometheus_stack" {
  name       = "prometheus"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = var.prometheus_stack_version
  namespace  = kubernetes_namespace.observability.metadata[0].name

  values = [
    yamlencode({
      prometheus = {
        prometheusSpec = {
          retention = "15d"
          retentionSize = "50GB"
          
          storageSpec = {
            volumeClaimTemplate = {
              spec = {
                storageClassName = "gp3"
                accessModes      = ["ReadWriteOnce"]
                resources = {
                  requests = {
                    storage = "100Gi"
                  }
                }
              }
            }
          }

          resources = {
            requests = {
              cpu    = "500m"
              memory = "2Gi"
            }
            limits = {
              cpu    = "2"
              memory = "4Gi"
            }
          }

          remoteWrite = [
            {
              url = "http://mimir-distributor.${kubernetes_namespace.observability.metadata[0].name}.svc.cluster.local:8080/api/v1/push"
              queueConfig = {
                batchSendDeadline = "5s"
                maxSamplesPerSend = 1000
                maxShards         = 10
              }
            }
          ]

          additionalScrapeConfigs = [
            {
              job_name = "opentelemetry-collector"
              static_configs = [
                {
                  targets = ["otel-collector.${kubernetes_namespace.observability.metadata[0].name}.svc.cluster.local:8888"]
                }
              ]
            }
          ]
        }
      }

      grafana = {
        enabled = false  # We'll deploy Grafana separately
      }

      alertmanager = {
        alertmanagerSpec = {
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
      }

      prometheusOperator = {
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

  depends_on = [kubernetes_namespace.observability]
}

# Mimir for long-term metrics storage
resource "helm_release" "mimir" {
  name       = "mimir"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "mimir-distributed"
  version    = var.mimir_version
  namespace  = kubernetes_namespace.observability.metadata[0].name

  values = [
    yamlencode({
      mimir = {
        structuredConfig = {
          common = {
            storage = {
              backend = "s3"
              s3 = {
                endpoint          = "s3.${var.aws_region}.amazonaws.com"
                bucket_name       = var.prometheus_s3_bucket
                region           = var.aws_region
              }
            }
          }
          
          blocks_storage = {
            s3 = {
              bucket_name = var.prometheus_s3_bucket
              region     = var.aws_region
            }
          }

          ruler_storage = {
            s3 = {
              bucket_name = var.prometheus_s3_bucket
              region     = var.aws_region
            }
          }

          alertmanager_storage = {
            s3 = {
              bucket_name = var.prometheus_s3_bucket
              region     = var.aws_region
            }
          }
        }
      }

      serviceAccount = {
        annotations = {
          "eks.amazonaws.com/role-arn" = var.mimir_irsa_role_arn
        }
      }

      distributor = {
        replicas = 2
        resources = {
          requests = {
            cpu    = "200m"
            memory = "512Mi"
          }
          limits = {
            cpu    = "1"
            memory = "1Gi"
          }
        }
      }

      ingester = {
        replicas = 3
        resources = {
          requests = {
            cpu    = "500m"
            memory = "1Gi"
          }
          limits = {
            cpu    = "2"
            memory = "4Gi"
          }
        }
        persistentVolume = {
          enabled      = true
          storageClass = "gp3"
          size         = "50Gi"
        }
      }

      querier = {
        replicas = 2
        resources = {
          requests = {
            cpu    = "200m"
            memory = "512Mi"
          }
          limits = {
            cpu    = "1"
            memory = "2Gi"
          }
        }
      }

      query_frontend = {
        replicas = 2
        resources = {
          requests = {
            cpu    = "200m"
            memory = "256Mi"
          }
          limits = {
            cpu    = "500m"
            memory = "1Gi"
          }
        }
      }

      compactor = {
        replicas = 1
        resources = {
          requests = {
            cpu    = "200m"
            memory = "512Mi"
          }
          limits = {
            cpu    = "1"
            memory = "2Gi"
          }
        }
        persistentVolume = {
          enabled      = true
          storageClass = "gp3"
          size         = "20Gi"
        }
      }

      store_gateway = {
        replicas = 2
        resources = {
          requests = {
            cpu    = "200m"
            memory = "512Mi"
          }
          limits = {
            cpu    = "1"
            memory = "2Gi"
          }
        }
        persistentVolume = {
          enabled      = true
          storageClass = "gp3"
          size         = "20Gi"
        }
      }
    })
  ]

  depends_on = [kubernetes_namespace.observability]
}

# Loki for logs
resource "helm_release" "loki" {
  name       = "loki"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "loki"
  version    = var.loki_version
  namespace  = kubernetes_namespace.observability.metadata[0].name

  values = [
    yamlencode({
      loki = {
        auth_enabled = false
        
        commonConfig = {
          replication_factor = 1
        }

        storage = {
          type = "s3"
          s3 = {
            endpoint   = "s3.${var.aws_region}.amazonaws.com"
            region     = var.aws_region
            bucketName = var.loki_s3_bucket
          }
        }

        schemaConfig = {
          configs = [
            {
              from         = "2023-01-01"
              store        = "boltdb-shipper"
              object_store = "s3"
              schema       = "v11"
              index = {
                prefix = "loki_index_"
                period = "24h"
              }
            }
          ]
        }
      }

      serviceAccount = {
        annotations = {
          "eks.amazonaws.com/role-arn" = var.loki_irsa_role_arn
        }
      }

      write = {
        replicas = 2
        resources = {
          requests = {
            cpu    = "200m"
            memory = "512Mi"
          }
          limits = {
            cpu    = "1"
            memory = "2Gi"
          }
        }
        persistence = {
          enabled      = true
          storageClass = "gp3"
          size         = "20Gi"
        }
      }

      read = {
        replicas = 2
        resources = {
          requests = {
            cpu    = "200m"
            memory = "512Mi"
          }
          limits = {
            cpu    = "1"
            memory = "2Gi"
          }
        }
      }

      backend = {
        replicas = 1
        resources = {
          requests = {
            cpu    = "200m"
            memory = "512Mi"
          }
          limits = {
            cpu    = "1"
            memory = "2Gi"
          }
        }
        persistence = {
          enabled      = true
          storageClass = "gp3"
          size         = "20Gi"
        }
      }

      gateway = {
        enabled = true
        replicas = 2
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

  depends_on = [kubernetes_namespace.observability]
}

# Promtail for log collection
resource "helm_release" "promtail" {
  name       = "promtail"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "promtail"
  version    = var.promtail_version
  namespace  = kubernetes_namespace.observability.metadata[0].name

  values = [
    yamlencode({
      config = {
        clients = [
          {
            url = "http://loki-gateway.${kubernetes_namespace.observability.metadata[0].name}.svc.cluster.local/loki/api/v1/push"
          }
        ]
      }

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

      tolerations = [
        {
          key      = "node-role.kubernetes.io/system"
          operator = "Exists"
          effect   = "NoSchedule"
        }
      ]
    })
  ]

  depends_on = [helm_release.loki]
}

# Tempo for distributed tracing
resource "helm_release" "tempo" {
  name       = "tempo"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "tempo-distributed"
  version    = var.tempo_version
  namespace  = kubernetes_namespace.observability.metadata[0].name

  values = [
    yamlencode({
      tempo = {
        storage = {
          trace = {
            backend = "s3"
            s3 = {
              bucket   = var.tempo_s3_bucket
              endpoint = "s3.${var.aws_region}.amazonaws.com"
              region   = var.aws_region
            }
          }
        }
      }

      serviceAccount = {
        annotations = {
          "eks.amazonaws.com/role-arn" = var.tempo_irsa_role_arn
        }
      }

      distributor = {
        replicas = 2
        resources = {
          requests = {
            cpu    = "200m"
            memory = "256Mi"
          }
          limits = {
            cpu    = "1"
            memory = "1Gi"
          }
        }
      }

      ingester = {
        replicas = 3
        resources = {
          requests = {
            cpu    = "500m"
            memory = "1Gi"
          }
          limits = {
            cpu    = "2"
            memory = "4Gi"
          }
        }
        persistence = {
          enabled      = true
          storageClass = "gp3"
          size         = "20Gi"
        }
      }

      querier = {
        replicas = 2
        resources = {
          requests = {
            cpu    = "200m"
            memory = "256Mi"
          }
          limits = {
            cpu    = "1"
            memory = "1Gi"
          }
        }
      }

      queryFrontend = {
        replicas = 2
        resources = {
          requests = {
            cpu    = "200m"
            memory = "256Mi"
          }
          limits = {
            cpu    = "500m"
            memory = "1Gi"
          }
        }
      }

      compactor = {
        replicas = 1
        resources = {
          requests = {
            cpu    = "200m"
            memory = "512Mi"
          }
          limits = {
            cpu    = "1"
            memory = "2Gi"
          }
        }
      }
    })
  ]

  depends_on = [kubernetes_namespace.observability]
}

# OpenTelemetry Collector
resource "kubernetes_manifest" "otel_collector" {
  manifest = {
    apiVersion = "opentelemetry.io/v1alpha1"
    kind       = "OpenTelemetryCollector"
    metadata = {
      name      = "otel-collector"
      namespace = kubernetes_namespace.observability.metadata[0].name
    }
    spec = {
      mode = "deployment"
      replicas = 2
      
      resources = {
        requests = {
          cpu    = "200m"
          memory = "256Mi"
        }
        limits = {
          cpu    = "1"
          memory = "1Gi"
        }
      }

      config = yamlencode({
        receivers = {
          otlp = {
            protocols = {
              grpc = {
                endpoint = "0.0.0.0:4317"
              }
              http = {
                endpoint = "0.0.0.0:4318"
              }
            }
          }
          prometheus = {
            config = {
              scrape_configs = [
                {
                  job_name        = "otel-collector"
                  scrape_interval = "30s"
                  static_configs = [
                    {
                      targets = ["0.0.0.0:8888"]
                    }
                  ]
                }
              ]
            }
          }
        }

        processors = {
          batch = {}
          memory_limiter = {
            limit_mib = 512
          }
          resource = {
            attributes = [
              {
                key    = "cluster.name"
                value  = var.cluster_name
                action = "upsert"
              }
            ]
          }
        }

        exporters = {
          otlp = {
            endpoint = "http://tempo-distributor.${kubernetes_namespace.observability.metadata[0].name}.svc.cluster.local:4317"
            tls = {
              insecure = true
            }
          }
          prometheus = {
            endpoint = "0.0.0.0:8889"
          }
          loki = {
            endpoint = "http://loki-gateway.${kubernetes_namespace.observability.metadata[0].name}.svc.cluster.local/loki/api/v1/push"
          }
        }

        service = {
          pipelines = {
            traces = {
              receivers  = ["otlp"]
              processors = ["memory_limiter", "resource", "batch"]
              exporters  = ["otlp"]
            }
            metrics = {
              receivers  = ["otlp", "prometheus"]
              processors = ["memory_limiter", "resource", "batch"]
              exporters  = ["prometheus"]
            }
            logs = {
              receivers  = ["otlp"]
              processors = ["memory_limiter", "resource", "batch"]
              exporters  = ["loki"]
            }
          }
        }
      })
    }
  }

  depends_on = [
    helm_release.opentelemetry_operator,
    helm_release.tempo,
    helm_release.loki
  ]
}

# OpenTelemetry Instrumentation for Java
resource "kubernetes_manifest" "otel_instrumentation_java" {
  manifest = {
    apiVersion = "opentelemetry.io/v1alpha1"
    kind       = "Instrumentation"
    metadata = {
      name      = "java-instrumentation"
      namespace = kubernetes_namespace.observability.metadata[0].name
    }
    spec = {
      exporter = {
        endpoint = "http://otel-collector.${kubernetes_namespace.observability.metadata[0].name}.svc.cluster.local:4317"
      }
      propagators = ["tracecontext", "baggage", "b3"]
      sampler = {
        type = "parentbased_traceidratio"
        argument = "0.1"  # 10% sampling
      }
      java = {
        image = "ghcr.io/open-telemetry/opentelemetry-operator/autoinstrumentation-java:1.32.0"
        env = [
          {
            name  = "OTEL_EXPORTER_OTLP_ENDPOINT"
            value = "http://otel-collector.${kubernetes_namespace.observability.metadata[0].name}.svc.cluster.local:4317"
          }
        ]
      }
    }
  }

  depends_on = [helm_release.opentelemetry_operator]
}

# Grafana
resource "helm_release" "grafana" {
  name       = "grafana"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "grafana"
  version    = var.grafana_version
  namespace  = kubernetes_namespace.observability.metadata[0].name

  values = [
    yamlencode({
      adminPassword = var.grafana_admin_password

      persistence = {
        enabled      = true
        storageClass = "gp3"
        size         = "10Gi"
      }

      resources = {
        requests = {
          cpu    = "100m"
          memory = "256Mi"
        }
        limits = {
          cpu    = "500m"
          memory = "1Gi"
        }
      }

      datasources = {
        "datasources.yaml" = {
          apiVersion = 1
          datasources = [
            {
              name      = "Prometheus"
              type      = "prometheus"
              url       = "http://prometheus-kube-prometheus-prometheus.${kubernetes_namespace.observability.metadata[0].name}.svc.cluster.local:9090"
              isDefault = true
            },
            {
              name = "Mimir"
              type = "prometheus"
              url  = "http://mimir-query-frontend.${kubernetes_namespace.observability.metadata[0].name}.svc.cluster.local:8080/prometheus"
            },
            {
              name = "Loki"
              type = "loki"
              url  = "http://loki-gateway.${kubernetes_namespace.observability.metadata[0].name}.svc.cluster.local"
            },
            {
              name = "Tempo"
              type = "tempo"
              url  = "http://tempo-query-frontend.${kubernetes_namespace.observability.metadata[0].name}.svc.cluster.local:3200"
            }
          ]
        }
      }

      dashboardProviders = {
        "dashboardproviders.yaml" = {
          apiVersion = 1
          providers = [
            {
              name            = "default"
              orgId           = 1
              folder          = ""
              type            = "file"
              disableDeletion = false
              editable        = true
              options = {
                path = "/var/lib/grafana/dashboards/default"
              }
            }
          ]
        }
      }

      dashboards = {
        default = {
          kubernetes-cluster-monitoring = {
            gnetId     = 7249
            revision   = 1
            datasource = "Prometheus"
          }
          kubernetes-pod-monitoring = {
            gnetId     = 6417
            revision   = 1
            datasource = "Prometheus"
          }
          opentelemetry-collector = {
            gnetId     = 15983
            revision   = 1
            datasource = "Prometheus"
          }
        }
      }

      serviceMonitor = {
        enabled = true
      }

      service = {
        type = "ClusterIP"
      }

      ingress = {
        enabled = true
        annotations = {
          "kubernetes.io/ingress.class"                 = "ambassador"
          "getambassador.io/config"                     = "---\napiVersion: getambassador.io/v3alpha1\nkind: Mapping\nname: grafana\nprefix: /grafana/\nservice: grafana.${kubernetes_namespace.observability.metadata[0].name}:80"
        }
        hosts = [
          {
            host = var.domain_name
            paths = [
              {
                path     = "/grafana"
                pathType = "Prefix"
              }
            ]
          }
        ]
      }
    })
  ]

  depends_on = [
    kubernetes_namespace.observability,
    helm_release.prometheus_stack,
    helm_release.mimir,
    helm_release.loki,
    helm_release.tempo
  ]
}