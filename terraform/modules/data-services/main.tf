# Data Services Module - PostgreSQL, Redis, Kafka
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

# Data services namespace
resource "kubernetes_namespace" "data_services" {
  metadata {
    name = "data-services"
    labels = merge(local.common_labels, {
      "app.kubernetes.io/component" = "data-services"
    })
  }
}

# CloudNativePG Operator for PostgreSQL
resource "helm_release" "cloudnative_pg" {
  name       = "cloudnative-pg"
  repository = "https://cloudnative-pg.github.io/charts"
  chart      = "cloudnative-pg"
  version    = var.cloudnative_pg_version
  namespace  = kubernetes_namespace.data_services.metadata[0].name

  values = [
    yamlencode({
      fullnameOverride = "cnpg-operator"
      
      config = {
        data = {
          INHERITED_ANNOTATIONS = "service.beta.kubernetes.io/*"
          INHERITED_LABELS = "environment,workload,app"
        }
      }

      monitoring = {
        enabled = true
        podMonitorEnabled = true
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
    })
  ]

  depends_on = [kubernetes_namespace.data_services]
}

# PostgreSQL Cluster
resource "kubernetes_manifest" "postgres_cluster" {
  manifest = {
    apiVersion = "postgresql.cnpg.io/v1"
    kind       = "Cluster"
    metadata = {
      name      = "postgres-cluster"
      namespace = kubernetes_namespace.data_services.metadata[0].name
    }
    spec = {
      instances = var.postgres_instances
      primaryUpdateStrategy = "unsupervised"
      
      postgresql = {
        parameters = {
          max_connections = "200"
          shared_buffers = "256MB"
          effective_cache_size = "1GB"
          maintenance_work_mem = "64MB"
          checkpoint_completion_target = "0.9"
          wal_buffers = "16MB"
          default_statistics_target = "100"
          random_page_cost = "1.1"
          effective_io_concurrency = "200"
          work_mem = "4MB"
          min_wal_size = "1GB"
          max_wal_size = "4GB"
          max_worker_processes = "8"
          max_parallel_workers_per_gather = "2"
          max_parallel_workers = "8"
          max_parallel_maintenance_workers = "2"
        }
      }

      bootstrap = {
        initdb = {
          database = var.postgres_database
          owner    = var.postgres_username
          secret = {
            name = "postgres-credentials"
          }
        }
      }

      storage = {
        size         = var.postgres_storage_size
        storageClass = var.storage_class
      }

      resources = {
        requests = {
          memory = "1Gi"
          cpu    = "500m"
        }
        limits = {
          memory = "2Gi"
          cpu    = "1000m"
        }
      }

      monitoring = {
        enabled = true
        podMonitorEnabled = true
      }

      backup = {
        retentionPolicy = "30d"
        barmanObjectStore = {
          destinationPath = "s3://${var.postgres_backup_bucket}"
          s3Credentials = {
            accessKeyId = {
              name = "postgres-backup-credentials"
              key  = "ACCESS_KEY_ID"
            }
            secretAccessKey = {
              name = "postgres-backup-credentials"
              key  = "SECRET_ACCESS_KEY"
            }
          }
          wal = {
            retention = "7d"
          }
          data = {
            retention = "30d"
          }
        }
      }
    }
  }

  depends_on = [helm_release.cloudnative_pg]
}

# PostgreSQL credentials secret
resource "kubernetes_secret" "postgres_credentials" {
  metadata {
    name      = "postgres-credentials"
    namespace = kubernetes_namespace.data_services.metadata[0].name
  }

  data = {
    username = base64encode(var.postgres_username)
    password = base64encode(var.postgres_password)
  }

  type = "kubernetes.io/basic-auth"
}

# PostgreSQL backup credentials
resource "kubernetes_secret" "postgres_backup_credentials" {
  metadata {
    name      = "postgres-backup-credentials"
    namespace = kubernetes_namespace.data_services.metadata[0].name
  }

  data = {
    ACCESS_KEY_ID     = base64encode(var.postgres_backup_access_key)
    SECRET_ACCESS_KEY = base64encode(var.postgres_backup_secret_key)
  }

  type = "Opaque"
}

# Redis Operator
resource "helm_release" "redis_operator" {
  name       = "redis-operator"
  repository = "https://spotahome.github.io/redis-operator"
  chart      = "redis-operator"
  version    = var.redis_operator_version
  namespace  = kubernetes_namespace.data_services.metadata[0].name

  values = [
    yamlencode({
      image = {
        tag = "v1.2.4"
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

      serviceMonitor = {
        enabled = true
      }
    })
  ]

  depends_on = [kubernetes_namespace.data_services]
}

# Redis Failover Cluster
resource "kubernetes_manifest" "redis_failover" {
  manifest = {
    apiVersion = "databases.spotahome.com/v1"
    kind       = "RedisFailover"
    metadata = {
      name      = "redis-cluster"
      namespace = kubernetes_namespace.data_services.metadata[0].name
    }
    spec = {
      sentinel = {
        replicas = var.redis_sentinel_replicas
        resources = {
          requests = {
            memory = "128Mi"
            cpu    = "50m"
          }
          limits = {
            memory = "256Mi"
            cpu    = "100m"
          }
        }
      }
      redis = {
        replicas = var.redis_replicas
        resources = {
          requests = {
            memory = "256Mi"
            cpu    = "100m"
          }
          limits = {
            memory = "512Mi"
            cpu    = "200m"
          }
        }
        storage = {
          persistentVolumeClaim = {
            metadata = {
              name = "redis-storage"
            }
            spec = {
              accessModes = ["ReadWriteOnce"]
              storageClassName = var.storage_class
              resources = {
                requests = {
                  storage = var.redis_storage_size
                }
              }
            }
          }
        }
        exporter = {
          enabled = true
          image   = "oliver006/redis_exporter:v1.45.0"
        }
      }
    }
  }

  depends_on = [helm_release.redis_operator]
}

# Strimzi Kafka Operator
resource "helm_release" "strimzi_kafka" {
  name       = "strimzi-kafka"
  repository = "https://strimzi.io/charts/"
  chart      = "strimzi-kafka-operator"
  version    = var.strimzi_version
  namespace  = kubernetes_namespace.data_services.metadata[0].name

  values = [
    yamlencode({
      watchAnyNamespace = false
      watchNamespaces = [kubernetes_namespace.data_services.metadata[0].name]

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

      kafka = {
        resources = {
          requests = {
            cpu    = "200m"
            memory = "512Mi"
          }
          limits = {
            cpu    = "1000m"
            memory = "2Gi"
          }
        }
      }

      zookeeper = {
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
      }
    })
  ]

  depends_on = [kubernetes_namespace.data_services]
}

# Kafka Cluster
resource "kubernetes_manifest" "kafka_cluster" {
  manifest = {
    apiVersion = "kafka.strimzi.io/v1beta2"
    kind       = "Kafka"
    metadata = {
      name      = "kafka-cluster"
      namespace = kubernetes_namespace.data_services.metadata[0].name
    }
    spec = {
      kafka = {
        version  = "3.5.0"
        replicas = var.kafka_replicas
        listeners = [
          {
            name = "plain"
            port = 9092
            type = "internal"
            tls  = false
          },
          {
            name = "tls"
            port = 9093
            type = "internal"
            tls  = true
          }
        ]
        readinessProbe = {
          initialDelaySeconds = 15
          timeoutSeconds      = 5
        }
        livenessProbe = {
          initialDelaySeconds = 15
          timeoutSeconds      = 5
        }
        config = {
          "offsets.topic.replication.factor"         = min(var.kafka_replicas, 3)
          "transaction.state.log.replication.factor" = min(var.kafka_replicas, 3)
          "transaction.state.log.min.isr"            = min(var.kafka_replicas, 2)
          "default.replication.factor"               = min(var.kafka_replicas, 3)
          "min.insync.replicas"                      = min(var.kafka_replicas, 2)
          "inter.broker.protocol.version"            = "3.5"
          "log.message.format.version"               = "3.5"
          "log.retention.hours"                      = 168
          "log.segment.bytes"                        = 1073741824
          "log.retention.check.interval.ms"          = 300000
          "num.network.threads"                      = 3
          "num.io.threads"                           = 8
          "socket.send.buffer.bytes"                 = 102400
          "socket.receive.buffer.bytes"              = 102400
          "socket.request.max.bytes"                 = 104857600
          "num.partitions"                           = 1
          "num.recovery.threads.per.data.dir"       = 1
          "log.flush.interval.messages"              = 9223372036854775807
          "log.flush.interval.ms"                    = null
          "log.retention.bytes"                      = -1
          "log.segment.delete.delay.ms"              = 60000
          "zookeeper.connect"                        = "kafka-cluster-zookeeper-client:2181"
          "zookeeper.connection.timeout.ms"          = 18000
          "group.initial.rebalance.delay.ms"         = 0
        }
        storage = {
          type = "persistent-claim"
          size = var.kafka_storage_size
          class = var.storage_class
        }
        resources = {
          requests = {
            memory = "1Gi"
            cpu    = "500m"
          }
          limits = {
            memory = "2Gi"
            cpu    = "1000m"
          }
        }
        metricsConfig = {
          type = "jmxPrometheusExporter"
          valueFrom = {
            configMapKeyRef = {
              name = "kafka-metrics"
              key  = "kafka-metrics-config.yml"
            }
          }
        }
      }
      zookeeper = {
        replicas = var.zookeeper_replicas
        readinessProbe = {
          initialDelaySeconds = 15
          timeoutSeconds      = 5
        }
        livenessProbe = {
          initialDelaySeconds = 15
          timeoutSeconds      = 5
        }
        storage = {
          type = "persistent-claim"
          size = var.zookeeper_storage_size
          class = var.storage_class
        }
        resources = {
          requests = {
            memory = "512Mi"
            cpu    = "250m"
          }
          limits = {
            memory = "1Gi"
            cpu    = "500m"
          }
        }
        metricsConfig = {
          type = "jmxPrometheusExporter"
          valueFrom = {
            configMapKeyRef = {
              name = "kafka-metrics"
              key  = "zookeeper-metrics-config.yml"
            }
          }
        }
      }
      entityOperator = {
        topicOperator = {
          resources = {
            requests = {
              memory = "256Mi"
              cpu    = "100m"
            }
            limits = {
              memory = "512Mi"
              cpu    = "500m"
            }
          }
        }
        userOperator = {
          resources = {
            requests = {
              memory = "256Mi"
              cpu    = "100m"
            }
            limits = {
              memory = "512Mi"
              cpu    = "500m"
            }
          }
        }
      }
      kafkaExporter = {
        topicRegex = ".*"
        groupRegex = ".*"
        resources = {
          requests = {
            memory = "64Mi"
            cpu    = "100m"
          }
          limits = {
            memory = "128Mi"
            cpu    = "500m"
          }
        }
      }
    }
  }

  depends_on = [
    helm_release.strimzi_kafka,
    kubernetes_config_map.kafka_metrics
  ]
}

# Kafka metrics configuration
resource "kubernetes_config_map" "kafka_metrics" {
  metadata {
    name      = "kafka-metrics"
    namespace = kubernetes_namespace.data_services.metadata[0].name
  }

  data = {
    "kafka-metrics-config.yml" = yamlencode({
      lowercaseOutputName = true
      rules = [
        {
          pattern = "kafka.server<type=(.+), name=(.+)PerSec\\w*><>Count"
          name    = "kafka_server_$1_$2_total"
        },
        {
          pattern = "kafka.server<type=(.+), name=(.+)PerSec\\w*, topic=(.+)><>Count"
          name    = "kafka_server_$1_$2_total"
          labels = {
            topic = "$3"
          }
        }
      ]
    })

    "zookeeper-metrics-config.yml" = yamlencode({
      lowercaseOutputName = true
      rules = [
        {
          pattern = "org.apache.ZooKeeperService<name0=ReplicatedServer_id(\\d+)><>(\\w+)"
          name    = "zookeeper_$2"
          labels = {
            replicaId = "$1"
          }
        }
      ]
    })
  }
}

# Sample Kafka Topic
resource "kubernetes_manifest" "sample_kafka_topic" {
  count = var.create_sample_topic ? 1 : 0
  
  manifest = {
    apiVersion = "kafka.strimzi.io/v1beta2"
    kind       = "KafkaTopic"
    metadata = {
      name      = "sample-topic"
      namespace = kubernetes_namespace.data_services.metadata[0].name
      labels = {
        "strimzi.io/cluster" = "kafka-cluster"
      }
    }
    spec = {
      partitions = 3
      replicas   = min(var.kafka_replicas, 3)
      config = {
        "retention.ms"      = 604800000  # 7 days
        "segment.ms"        = 86400000   # 1 day
        "cleanup.policy"    = "delete"
        "compression.type"  = "producer"
      }
    }
  }

  depends_on = [kubernetes_manifest.kafka_cluster]
}

# Service Monitor for PostgreSQL
resource "kubernetes_manifest" "postgres_service_monitor" {
  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "ServiceMonitor"
    metadata = {
      name      = "postgres-cluster"
      namespace = kubernetes_namespace.data_services.metadata[0].name
      labels = {
        app = "postgres-cluster"
      }
    }
    spec = {
      selector = {
        matchLabels = {
          "cnpg.io/cluster" = "postgres-cluster"
        }
      }
      endpoints = [
        {
          port = "metrics"
          path = "/metrics"
        }
      ]
    }
  }

  depends_on = [kubernetes_manifest.postgres_cluster]
}

# Service Monitor for Redis
resource "kubernetes_manifest" "redis_service_monitor" {
  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "ServiceMonitor"
    metadata = {
      name      = "redis-cluster"
      namespace = kubernetes_namespace.data_services.metadata[0].name
      labels = {
        app = "redis-cluster"
      }
    }
    spec = {
      selector = {
        matchLabels = {
          app = "redis-exporter"
        }
      }
      endpoints = [
        {
          port = "redis-exporter"
          path = "/metrics"
        }
      ]
    }
  }

  depends_on = [kubernetes_manifest.redis_failover]
}

# Service Monitor for Kafka
resource "kubernetes_manifest" "kafka_service_monitor" {
  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "ServiceMonitor"
    metadata = {
      name      = "kafka-cluster"
      namespace = kubernetes_namespace.data_services.metadata[0].name
      labels = {
        app = "kafka-cluster"
      }
    }
    spec = {
      selector = {
        matchLabels = {
          "strimzi.io/cluster" = "kafka-cluster"
          "strimzi.io/kind"    = "Kafka"
        }
      }
      endpoints = [
        {
          port = "tcp-prometheus"
          path = "/metrics"
        }
      ]
    }
  }

  depends_on = [kubernetes_manifest.kafka_cluster]
}