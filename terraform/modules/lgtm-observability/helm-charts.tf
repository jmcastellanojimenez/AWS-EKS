# ==============================================================================
# Helm Chart Deployments for LGTM Stack
# ==============================================================================

# ==============================================================================
# Prometheus - Metrics Collection
# ==============================================================================

resource "helm_release" "prometheus" {
  count = var.enable_prometheus ? 1 : 0

  name       = "prometheus"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "prometheus"
  version    = local.chart_versions.prometheus
  namespace  = kubernetes_namespace.observability.metadata[0].name
  timeout    = 600  # Increased timeout to 10 minutes
  wait       = true
  wait_for_jobs = false

  values = [yamlencode({
    # Global settings
    global = {
      scrape_interval = "15s"
      evaluation_interval = "15s"
    }

    # Prometheus server configuration
    server = {
      name = "prometheus-server"
      
      # Resource configuration
      resources = var.prometheus_resources
      
      # Node affinity - prefer system nodes for control plane components
      affinity = {
        nodeAffinity = {
          preferredDuringSchedulingIgnoredDuringExecution = [
            {
              weight = 100
              preference = {
                matchExpressions = [
                  {
                    key = "node-type"
                    operator = "In"
                    values = ["control"]
                  }
                ]
              }
            }
          ]
        }
      }
      
      # Persistence
      persistentVolume = {
        enabled = local.current_env.enable_persistence
        size    = var.prometheus_storage_size
        storageClass = local.current_env.storage_class
      }
      
      # Retention
      retention = var.prometheus_retention
      
      # Service configuration
      service = {
        type = "ClusterIP"
        servicePort = 80
      }
      
      # Configuration
      configMapOverrides = {
        prometheus_yml = {
          global = {
            scrape_interval = "15s"
            evaluation_interval = "15s"
          }
          
          scrape_configs = [
            # Kubernetes API server
            {
              job_name = "kubernetes-apiservers"
              kubernetes_sd_configs = [{
                role = "endpoints"
              }]
              scheme = "https"
              tls_config = {
                ca_file = "/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"
              }
              bearer_token_file = "/var/run/secrets/kubernetes.io/serviceaccount/token"
              relabel_configs = [
                {
                  source_labels = ["__meta_kubernetes_namespace", "__meta_kubernetes_service_name", "__meta_kubernetes_endpoint_port_name"]
                  action = "keep"
                  regex = "default;kubernetes;https"
                }
              ]
            },
            
            # Kubernetes nodes
            {
              job_name = "kubernetes-nodes"
              kubernetes_sd_configs = [{
                role = "node"
              }]
              scheme = "https"
              tls_config = {
                ca_file = "/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"
              }
              bearer_token_file = "/var/run/secrets/kubernetes.io/serviceaccount/token"
              relabel_configs = [
                {
                  action = "labelmap"
                  regex = "__meta_kubernetes_node_label_(.+)"
                }
              ]
            },
            
            # Kubernetes pods
            {
              job_name = "kubernetes-pods"
              kubernetes_sd_configs = [{
                role = "pod"
              }]
              relabel_configs = [
                {
                  source_labels = ["__meta_kubernetes_pod_annotation_prometheus_io_scrape"]
                  action = "keep"
                  regex = "true"
                },
                {
                  source_labels = ["__meta_kubernetes_pod_annotation_prometheus_io_path"]
                  action = "replace"
                  target_label = "__metrics_path__"
                  regex = "(.+)"
                },
                {
                  source_labels = ["__address__", "__meta_kubernetes_pod_annotation_prometheus_io_port"]
                  action = "replace"
                  regex = "([^:]+)(?::[0-9]+)?;([0-9]+)"
                  replacement = "$1:$2"
                  target_label = "__address__"
                }
              ]
            },
            
            # EcoTrack microservices (Spring Boot Actuator)
            {
              job_name = "ecotrack-microservices"
              kubernetes_sd_configs = [{
                role = "pod"
                namespaces = {
                  names = ["ecotrack"]
                }
              }]
              metrics_path = "/actuator/prometheus"
              relabel_configs = [
                {
                  source_labels = ["__meta_kubernetes_pod_label_app_kubernetes_io_name"]
                  action = "keep"
                  regex = "(user-service|product-service|order-service|payment-service|notification-service)"
                },
                {
                  source_labels = ["__meta_kubernetes_pod_container_port_number"]
                  action = "keep"
                  regex = "8080"
                }
              ]
            }
          ]
        }
      }
    }

    # Alert Manager
    alertmanager = {
      enabled = false  # Disable in dev to reduce resources
      persistentVolume = {
        enabled = local.current_env.enable_persistence
        size = "2Gi"
        storageClass = local.current_env.storage_class
      }
    }

    # Node Exporter
    nodeExporter = {
      enabled = local.current_env.enable_node_exporter
      resources = {
        requests = {
          cpu = "50m"
          memory = "64Mi"
        }
        limits = {
          cpu = "100m"
          memory = "128Mi"
        }
      }
    }

    # Kube State Metrics
    kubeStateMetrics = {
      enabled = local.current_env.enable_kube_state
      resources = {
        requests = {
          cpu = "50m"
          memory = "64Mi"
        }
        limits = {
          cpu = "100m"
          memory = "128Mi"
        }
      }
    }

    # Pushgateway (disabled for this use case)
    pushgateway = {
      enabled = false
    }
  })]

  depends_on = [kubernetes_namespace.observability]
}

# ==============================================================================
# Grafana - Visualization and Alerting
# ==============================================================================

resource "helm_release" "grafana" {
  name       = "grafana"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "grafana"
  version    = local.chart_versions.grafana
  namespace  = kubernetes_namespace.observability.metadata[0].name
  timeout    = 900  # Extended timeout for SPOT instances (15 minutes)
  wait       = true
  wait_for_jobs = false
  
  # Force cleanup on failure
  replace = true
  cleanup_on_fail = true
  force_update = true

  values = [yamlencode({
    # Service account
    serviceAccount = {
      create = false
      name = kubernetes_service_account.grafana.metadata[0].name
    }

    # Resource configuration
    resources = var.grafana_resources

    # Node affinity - prefer system nodes for control plane components
    affinity = {
      nodeAffinity = {
        preferredDuringSchedulingIgnoredDuringExecution = [
          {
            weight = 100
            preference = {
              matchExpressions = [
                {
                  key = "node-type"
                  operator = "In"
                  values = ["control"]
                }
              ]
            }
          }
        ]
      }
    }

    # Persistence
    persistence = {
      enabled = local.current_env.enable_persistence
      size = var.grafana_storage_size
      storageClassName = local.current_env.storage_class
    }

    # Admin credentials
    admin = {
      existingSecret = kubernetes_secret.grafana_credentials.metadata[0].name
      userKey = "admin-user"
      passwordKey = "admin-password"
    }

    # Data sources
    datasources = {
      "datasources.yaml" = {
        apiVersion = 1
        datasources = concat([
          {
            name = "Prometheus"
            type = "prometheus"
            url = "http://prometheus-server.${var.namespace}.svc.cluster.local"
            access = "proxy"
            isDefault = true
          }
        ],
        var.enable_loki ? [{
          name = "Loki"
          type = "loki"
          url = "http://loki.${var.namespace}.svc.cluster.local:3100"
          access = "proxy"
        }] : [],
        var.enable_tempo ? [{
          name = "Tempo"
          type = "tempo"
          url = "http://tempo.${var.namespace}.svc.cluster.local:3100"
          access = "proxy"
        }] : [],
        var.enable_mimir ? [{
          name = "Mimir"
          type = "prometheus"
          url = "http://mimir-nginx.${var.namespace}.svc.cluster.local/prometheus"
          access = "proxy"
        }] : [])
      }
    }

    # Dashboard providers
    dashboardProviders = {
      "dashboardproviders.yaml" = {
        apiVersion = 1
        providers = [
          {
            name = "default"
            orgId = 1
            folder = ""
            type = "file"
            disableDeletion = false
            editable = true
            options = {
              path = "/var/lib/grafana/dashboards/default"
            }
          }
        ]
      }
    }

    # Pre-configured dashboards - DISABLED for SPOT instances to avoid timeout
    # dashboards = {
    #   default = {
    #     kubernetes-cluster = {
    #       gnetId = 7249
    #       revision = 1
    #       datasource = "Prometheus"
    #     }
    #     kubernetes-pods = {
    #       gnetId = 6336
    #       revision = 1
    #       datasource = "Prometheus"
    #     }
    #     spring-boot = {
    #       gnetId = 12900
    #       revision = 1
    #       datasource = "Prometheus"
    #     }
    #     ambassador-dashboard = {
    #       gnetId = 13758
    #       revision = 1
    #       datasource = "Prometheus"
    #     }
    #   }
    # }

    # Service configuration
    service = {
      type = "ClusterIP"
      port = 80
    }

    # Security context
    securityContext = {
      runAsNonRoot = true
      runAsUser = 472
      fsGroup = 472
    }

    # SPOT instance optimizations
    nodeSelector = var.environment == "dev" ? {
      "kubernetes.io/arch" = "amd64"
    } : {}

    tolerations = var.environment == "dev" ? [
      {
        key = "kubernetes.io/arch"
        operator = "Equal"
        value = "amd64"
        effect = "NoSchedule"
      }
    ] : []

    # Startup and readiness probes optimized for SPOT instances
    livenessProbe = {
      httpGet = {
        path = "/api/health"
        port = 3000
      }
      initialDelaySeconds = 120  # Extended delay for SPOT instances
      periodSeconds = 30
      timeoutSeconds = 10
      failureThreshold = 5
    }

    readinessProbe = {
      httpGet = {
        path = "/api/health"
        port = 3000
      }
      initialDelaySeconds = 60   # Extended delay for SPOT instances
      periodSeconds = 10
      timeoutSeconds = 5
      failureThreshold = 10
    }

    # Environment variables
    env = merge(
      {},
      var.slack_webhook_url != "" ? {
        GF_ALERTING_SLACK_WEBHOOK_URL = {
          valueFrom = {
            secretKeyRef = {
              name = kubernetes_secret.slack_webhook[0].metadata[0].name
              key = "webhook-url"
            }
          }
        }
      } : {}
    )

    # Grafana configuration
    "grafana.ini" = {
      analytics = {
        check_for_updates = false
      }
      alerting = {
        enabled = var.enable_grafana_alerts
      }
      unified_alerting = {
        enabled = var.enable_grafana_alerts
      }
      log = {
        mode = "console"
        level = var.environment == "dev" ? "debug" : "info"
      }
      paths = {
        data = "/var/lib/grafana/"
        logs = "/var/log/grafana"
        plugins = "/var/lib/grafana/plugins"
        provisioning = "/etc/grafana/provisioning"
      }
      server = {
        protocol = "http"
        http_port = 3000
        domain = var.grafana_domain != "" ? var.grafana_domain : "localhost"
        root_url = var.grafana_domain != "" ? "https://${var.grafana_domain}" : "http://localhost:3000"
      }
    }
  })]

  depends_on = [
    kubernetes_namespace.observability,
    kubernetes_service_account.grafana,
    kubernetes_secret.grafana_credentials,
    helm_release.prometheus
    # Removed loki dependency since it's disabled by default
  ]
}

# ==============================================================================
# Loki - Log Aggregation
# ==============================================================================

resource "helm_release" "loki" {
  count = var.enable_loki ? 1 : 0

  name       = "loki"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "loki-stack"
  version    = local.chart_versions.loki
  namespace  = kubernetes_namespace.observability.metadata[0].name
  timeout    = 600  # Increased timeout for Loki
  wait       = true
  wait_for_jobs = false
  
  # Force cleanup on failure
  replace = true
  cleanup_on_fail = true
  force_update = true

  values = [yamlencode({
    # Loki configuration
    loki = {
      enabled = true
      
      # Service account
      serviceAccount = {
        create = false
        name = kubernetes_service_account.loki[0].metadata[0].name
      }

      # Resources
      resources = var.loki_resources

      # Persistence
      persistence = {
        enabled = local.current_env.enable_persistence
        size = "10Gi"
        storageClassName = local.current_env.storage_class
      }

      # Configuration
      config = {
        auth_enabled = false
        
        server = {
          http_listen_port = 3100
        }
        
        ingester = {
          lifecycler = {
            address = "127.0.0.1"
            ring = {
              kvstore = {
                store = "inmemory"
              }
              replication_factor = 1
            }
            final_sleep = "0s"
          }
          chunk_idle_period = "5m"
          chunk_retain_period = "30s"
        }
        
        schema_config = {
          configs = [{
            from = "2020-10-24"
            store = "boltdb-shipper"
            object_store = "aws"
            schema = "v11"
            index = {
              prefix = "index_"
              period = "24h"
            }
          }]
        }
        
        storage_config = {
          boltdb_shipper = {
            active_index_directory = "/loki/boltdb-shipper-active"
            cache_location = "/loki/boltdb-shipper-cache"
            shared_store = "s3"
          }
          aws = {
            s3 = "s3://${aws_s3_bucket.loki[0].id}"
            region = var.aws_region
          }
        }
        
        limits_config = {
          enforce_metric_name = false
          reject_old_samples = true
          reject_old_samples_max_age = "168h"
        }
        
        chunk_store_config = {
          max_look_back_period = "0s"
        }
        
        table_manager = {
          retention_deletes_enabled = false
          retention_period = "0s"
        }
      }
    }

    # Promtail configuration
    promtail = {
      enabled = true
      
      # Resources
      resources = {
        requests = {
          cpu = "50m"
          memory = "128Mi"
        }
        limits = {
          cpu = "100m"
          memory = "256Mi"
        }
      }

      # Configuration
      config = {
        server = {
          http_listen_port = 9080
          grpc_listen_port = 0
        }
        positions = {
          filename = "/tmp/positions.yaml"
        }
        clients = [{
          url = "http://loki:3100/loki/api/v1/push"
        }]
        scrape_configs = [{
          job_name = "kubernetes-pods"
          kubernetes_sd_configs = [{
            role = "pod"
          }]
          relabel_configs = [
            {
              source_labels = ["__meta_kubernetes_pod_node_name"]
              target_label = "__host__"
            },
            {
              action = "labelmap"
              regex = "__meta_kubernetes_pod_label_(.+)"
            },
            {
              action = "replace"
              replacement = "/var/log/pods/*$1/*.log"
              separator = "/"
              source_labels = ["__meta_kubernetes_pod_uid", "__meta_kubernetes_pod_container_name"]
              target_label = "__path__"
            }
          ]
        }]
      }
    }

    # Fluent Bit (disabled in favor of Promtail)
    fluent-bit = {
      enabled = false
    }

    # Grafana (disabled, using separate installation)
    grafana = {
      enabled = false
    }
  })]

  depends_on = [
    kubernetes_namespace.observability,
    kubernetes_service_account.loki,
    aws_s3_bucket.loki,
    helm_release.prometheus  # Deploy Loki after Prometheus
  ]
}

# ==============================================================================
# Tempo - Distributed Tracing
# ==============================================================================

resource "helm_release" "tempo" {
  count = var.enable_tempo ? 1 : 0

  name       = "tempo"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "tempo-distributed"
  version    = local.chart_versions.tempo
  namespace  = kubernetes_namespace.observability.metadata[0].name
  timeout    = 600
  wait       = true
  wait_for_jobs = false
  
  # Force cleanup on failure
  replace = true
  cleanup_on_fail = true
  force_update = true

  values = [yamlencode({
    # Global settings
    global = {
      image = {
        registry = "docker.io"
      }
    }

    # Service account
    serviceAccount = {
      create = false
      name = kubernetes_service_account.tempo[0].metadata[0].name
    }

    # Tempo configuration
    tempo = {
      repository = "grafana/tempo"
      tag = "2.2.2"
      
      # Storage configuration
      storage = {
        trace = {
          backend = "s3"
          s3 = {
            bucket = aws_s3_bucket.tempo[0].id
            region = var.aws_region
            # Use IRSA, no access keys needed
          }
        }
      }
      
      # Receivers configuration
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
        jaeger = {
          protocols = {
            thrift_http = {
              endpoint = "0.0.0.0:14268"
            }
            grpc = {
              endpoint = "0.0.0.0:14250"
            }
          }
        }
        zipkin = {
          endpoint = "0.0.0.0:9411"
        }
      }
    }

    # Resource configuration
    ingester = {
      replicas = local.current_env.replica_count
      resources = var.tempo_resources
    }

    distributor = {
      replicas = local.current_env.replica_count
      resources = {
        requests = {
          cpu = "100m"
          memory = "128Mi"
        }
        limits = {
          cpu = "200m"
          memory = "256Mi"
        }
      }
    }

    querier = {
      replicas = local.current_env.replica_count
      resources = {
        requests = {
          cpu = "100m"
          memory = "128Mi"
        }
        limits = {
          cpu = "200m"
          memory = "256Mi"
        }
      }
    }

    queryFrontend = {
      replicas = local.current_env.replica_count
      resources = {
        requests = {
          cpu = "50m"
          memory = "64Mi"
        }
        limits = {
          cpu = "100m"
          memory = "128Mi"
        }
      }
    }

    compactor = {
      replicas = 1
      resources = {
        requests = {
          cpu = "50m"
          memory = "64Mi"
        }
        limits = {
          cpu = "100m"
          memory = "128Mi"
        }
      }
    }
  })]

  depends_on = [
    kubernetes_namespace.observability,
    kubernetes_service_account.tempo,
    aws_s3_bucket.tempo
  ]
}

# ==============================================================================
# Mimir - Long-term Metrics Storage
# ==============================================================================

resource "helm_release" "mimir" {
  count = var.enable_mimir ? 1 : 0

  name       = "mimir"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "mimir-distributed"
  version    = local.chart_versions.mimir
  namespace  = kubernetes_namespace.observability.metadata[0].name

  values = [yamlencode({
    # Global configuration
    global = {
      extraEnv = [
        {
          name = "AWS_REGION"
          value = var.aws_region
        }
      ]
    }

    # Service account
    serviceAccount = {
      create = false
      name = kubernetes_service_account.mimir[0].metadata[0].name
    }

    # Mimir configuration
    mimir = {
      structuredConfig = {
        multitenancy_enabled = false
        
        blocks_storage = {
          backend = "s3"
          s3 = {
            bucket_name = aws_s3_bucket.mimir[0].id
            region = var.aws_region
            # Use IRSA, no access keys needed
          }
        }
        
        ruler_storage = {
          backend = "s3"
          s3 = {
            bucket_name = aws_s3_bucket.mimir[0].id
            region = var.aws_region
          }
        }
        
        alertmanager_storage = {
          backend = "s3"
          s3 = {
            bucket_name = aws_s3_bucket.mimir[0].id
            region = var.aws_region
          }
        }
        
        server = {
          log_level = var.environment == "dev" ? "debug" : "info"
        }
      }
    }

    # Component configurations with resource limits
    ingester = {
      replicas = local.current_env.replica_count
      resources = var.mimir_resources
    }

    distributor = {
      replicas = local.current_env.replica_count
      resources = {
        requests = {
          cpu = "100m"
          memory = "256Mi"
        }
        limits = {
          cpu = "200m"
          memory = "512Mi"
        }
      }
    }

    querier = {
      replicas = local.current_env.replica_count
      resources = {
        requests = {
          cpu = "100m"
          memory = "256Mi"
        }
        limits = {
          cpu = "200m"
          memory = "512Mi"
        }
      }
    }

    query_frontend = {
      replicas = local.current_env.replica_count
      resources = {
        requests = {
          cpu = "50m"
          memory = "128Mi"
        }
        limits = {
          cpu = "100m"
          memory = "256Mi"
        }
      }
    }

    store_gateway = {
      replicas = local.current_env.replica_count
      resources = {
        requests = {
          cpu = "100m"
          memory = "256Mi"
        }
        limits = {
          cpu = "200m"
          memory = "512Mi"
        }
      }
    }

    compactor = {
      replicas = 1
      resources = {
        requests = {
          cpu = "100m"
          memory = "256Mi"
        }
        limits = {
          cpu = "200m"
          memory = "512Mi"
        }
      }
    }

    nginx = {
      replicas = local.current_env.replica_count
      resources = {
        requests = {
          cpu = "50m"
          memory = "64Mi"
        }
        limits = {
          cpu = "100m"
          memory = "128Mi"
        }
      }
    }
  })]

  depends_on = [
    kubernetes_namespace.observability,
    kubernetes_service_account.mimir,
    aws_s3_bucket.mimir
  ]
}