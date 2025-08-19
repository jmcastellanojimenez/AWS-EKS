# Data Services Module Outputs

output "namespace" {
  description = "Data services namespace"
  value       = kubernetes_namespace.data_services.metadata[0].name
}

# PostgreSQL Outputs
output "postgres_cluster_name" {
  description = "PostgreSQL cluster name"
  value       = kubernetes_manifest.postgres_cluster.manifest.metadata.name
}

output "postgres_primary_service" {
  description = "PostgreSQL primary service name"
  value       = "postgres-cluster-rw"
}

output "postgres_readonly_service" {
  description = "PostgreSQL read-only service name"
  value       = "postgres-cluster-ro"
}

output "postgres_connection_string" {
  description = "PostgreSQL connection string template"
  value       = "postgresql://${var.postgres_username}:${var.postgres_password}@postgres-cluster-rw.${kubernetes_namespace.data_services.metadata[0].name}.svc.cluster.local:5432/${var.postgres_database}"
  sensitive   = true
}

output "postgres_credentials_secret" {
  description = "PostgreSQL credentials secret name"
  value       = kubernetes_secret.postgres_credentials.metadata[0].name
}

# Redis Outputs
output "redis_cluster_name" {
  description = "Redis cluster name"
  value       = kubernetes_manifest.redis_failover.manifest.metadata.name
}

output "redis_service_name" {
  description = "Redis service name"
  value       = "rfs-redis-cluster"
}

output "redis_sentinel_service_name" {
  description = "Redis Sentinel service name"
  value       = "rfs-redis-cluster-sentinel"
}

output "redis_connection_string" {
  description = "Redis connection string"
  value       = "redis://rfs-redis-cluster.${kubernetes_namespace.data_services.metadata[0].name}.svc.cluster.local:6379"
}

# Kafka Outputs
output "kafka_cluster_name" {
  description = "Kafka cluster name"
  value       = kubernetes_manifest.kafka_cluster.manifest.metadata.name
}

output "kafka_bootstrap_servers" {
  description = "Kafka bootstrap servers"
  value       = "kafka-cluster-kafka-bootstrap.${kubernetes_namespace.data_services.metadata[0].name}.svc.cluster.local:9092"
}

output "kafka_bootstrap_servers_tls" {
  description = "Kafka bootstrap servers with TLS"
  value       = "kafka-cluster-kafka-bootstrap.${kubernetes_namespace.data_services.metadata[0].name}.svc.cluster.local:9093"
}

output "zookeeper_service_name" {
  description = "Zookeeper service name"
  value       = "kafka-cluster-zookeeper-client"
}

output "zookeeper_connection_string" {
  description = "Zookeeper connection string"
  value       = "kafka-cluster-zookeeper-client.${kubernetes_namespace.data_services.metadata[0].name}.svc.cluster.local:2181"
}

# Service Endpoints for Applications
output "service_endpoints" {
  description = "Service endpoints for applications"
  value = {
    postgres = {
      primary  = "postgres-cluster-rw.${kubernetes_namespace.data_services.metadata[0].name}.svc.cluster.local:5432"
      readonly = "postgres-cluster-ro.${kubernetes_namespace.data_services.metadata[0].name}.svc.cluster.local:5432"
    }
    redis = {
      service  = "rfs-redis-cluster.${kubernetes_namespace.data_services.metadata[0].name}.svc.cluster.local:6379"
      sentinel = "rfs-redis-cluster-sentinel.${kubernetes_namespace.data_services.metadata[0].name}.svc.cluster.local:26379"
    }
    kafka = {
      bootstrap     = "kafka-cluster-kafka-bootstrap.${kubernetes_namespace.data_services.metadata[0].name}.svc.cluster.local:9092"
      bootstrap_tls = "kafka-cluster-kafka-bootstrap.${kubernetes_namespace.data_services.metadata[0].name}.svc.cluster.local:9093"
    }
    zookeeper = {
      client = "kafka-cluster-zookeeper-client.${kubernetes_namespace.data_services.metadata[0].name}.svc.cluster.local:2181"
    }
  }
}

# Monitoring Outputs
output "service_monitors" {
  description = "Service monitor names for monitoring integration"
  value = {
    postgres = kubernetes_manifest.postgres_service_monitor.manifest.metadata.name
    redis    = kubernetes_manifest.redis_service_monitor.manifest.metadata.name
    kafka    = kubernetes_manifest.kafka_service_monitor.manifest.metadata.name
  }
}

# Storage Information
output "storage_info" {
  description = "Storage configuration information"
  value = {
    postgres = {
      size         = var.postgres_storage_size
      storage_class = var.storage_class
    }
    redis = {
      size         = var.redis_storage_size
      storage_class = var.storage_class
    }
    kafka = {
      size         = var.kafka_storage_size
      storage_class = var.storage_class
    }
    zookeeper = {
      size         = var.zookeeper_storage_size
      storage_class = var.storage_class
    }
  }
}