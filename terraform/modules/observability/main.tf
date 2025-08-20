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

# OpenTelemetry components temporarily disabled to resolve CRD issues
# Will be re-enabled once core LGTM stack is deployed successfully

# # OpenTelemetry Operator
# resource "helm_release" "opentelemetry_operator" {
#   name       = "opentelemetry-operator"
#   repository = "https://open-telemetry.github.io/opentelemetry-helm-charts"
#   chart      = "opentelemetry-operator"
#   version    = var.opentelemetry_operator_version
#   namespace  = kubernetes_namespace.observability.metadata[0].name
#
#   values = [
#     yamlencode({
#       manager = {
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
#       admissionWebhooks = {
#         certManager = {
#           enabled = true
#         }
#       }
#     })
#   ]
#
#   depends_on = [kubernetes_namespace.observability]
# }

# Prometheus Stack (kube-prometheus-stack)
resource "helm_release" "prometheus_stack" {
  name       = "prometheus"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = var.prometheus_stack_version
  namespace  = kubernetes_namespace.observability.metadata[0].name
  
  timeout       = 900
  wait          = true
  wait_for_jobs = true

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

          # OpenTelemetry scrape configs temporarily disabled
          # additionalScrapeConfigs = [
          #   {
          #     job_name = "opentelemetry-collector"
          #     static_configs = [
          #       {
          #         targets = ["otel-collector.${kubernetes_namespace.observability.metadata[0].name}.svc.cluster.local:8888"]
          #       }
          #     ]
          #   }
          # ]
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
  
  timeout       = 900
  wait          = true
  wait_for_jobs = true

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

  depends_on = [helm_release.tempo]
}

# Loki for logs
resource "helm_release" "loki" {
  name       = "loki"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "loki"
  version    = var.loki_version
  namespace  = kubernetes_namespace.observability.metadata[0].name
  
  timeout       = 900
  wait          = true
  wait_for_jobs = true

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

  depends_on = [helm_release.prometheus_stack]
}

# Promtail for log collection
resource "helm_release" "promtail" {
  name       = "promtail"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "promtail"
  version    = var.promtail_version
  namespace  = kubernetes_namespace.observability.metadata[0].name
  
  timeout       = 600
  wait          = true
  wait_for_jobs = true

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
  
  timeout       = 900
  wait          = true
  wait_for_jobs = true

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

  depends_on = [helm_release.loki]
}

# OpenTelemetry components temporarily disabled to resolve CRD issues
# Will be re-enabled once core LGTM stack is deployed successfully

# # Wait for OpenTelemetry operator CRDs to be available
# resource "time_sleep" "wait_for_otel_crds" {
#   depends_on      = [helm_release.opentelemetry_operator]
#   create_duration = "30s"
# }
#
# # OpenTelemetry Collector
# resource "null_resource" "otel_collector" {
#   triggers = {
#     cluster_name = var.cluster_name
#     aws_region   = var.aws_region
#   }
#
#   provisioner "local-exec" {
#     command = <<-EOT
#       # Configure kubectl to use the EKS cluster
#       aws eks update-kubeconfig --region ${self.triggers.aws_region} --name ${self.triggers.cluster_name}
#       
#       # Apply the OpenTelemetry Collector
#       cat <<EOF | kubectl apply --validate=false -f -
# apiVersion: opentelemetry.io/v1alpha1
# kind: OpenTelemetryCollector
# metadata:
#   name: otel-collector
#   namespace: observability
# spec:
#   mode: deployment
#   replicas: 2
#   config: |
#     receivers:
#       otlp:
#         protocols:
#           grpc:
#             endpoint: 0.0.0.0:4317
#     processors:
#       batch: {}
#     exporters:
#       otlp:
#         endpoint: http://tempo-distributor.observability.svc.cluster.local:4317
#         tls:
#           insecure: true
#     service:
#       pipelines:
#         traces:
#           receivers: [otlp]
#           processors: [batch]
#           exporters: [otlp]
# EOF
#     EOT
#   }
#
#   depends_on = [
#     time_sleep.wait_for_otel_crds,
#     helm_release.tempo
#   ]
# }
#
# # OpenTelemetry Instrumentation for Java
# resource "null_resource" "otel_instrumentation_java" {
#   triggers = {
#     cluster_name = var.cluster_name
#     aws_region   = var.aws_region
#   }
#
#   provisioner "local-exec" {
#     command = <<-EOT
#       # Configure kubectl to use the EKS cluster
#       aws eks update-kubeconfig --region ${self.triggers.aws_region} --name ${self.triggers.cluster_name}
#       
#       # Apply the OpenTelemetry Instrumentation
#       cat <<EOF | kubectl apply --validate=false -f -
# apiVersion: opentelemetry.io/v1alpha1
# kind: Instrumentation
# metadata:
#   name: java-instrumentation
#   namespace: observability
# spec:
#   exporter:
#     endpoint: http://otel-collector.observability.svc.cluster.local:4317
#   java:
#     image: ghcr.io/open-telemetry/opentelemetry-operator/autoinstrumentation-java:1.32.0
# EOF
#     EOT
#   }
#
#   depends_on = [time_sleep.wait_for_otel_crds]
# }

# Grafana
resource "helm_release" "grafana" {
  name       = "grafana"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "grafana"
  version    = var.grafana_version
  namespace  = kubernetes_namespace.observability.metadata[0].name
  
  timeout       = 600
  wait          = true
  wait_for_jobs = true

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

  depends_on = [helm_release.mimir]
}