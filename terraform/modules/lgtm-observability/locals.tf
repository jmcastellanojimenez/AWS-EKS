# ==============================================================================
# Local Values for LGTM Observability Stack
# ==============================================================================

locals {
  # Common labels for all resources
  common_labels = {
    "app.kubernetes.io/part-of"   = "lgtm-observability"
    "app.kubernetes.io/instance"  = var.environment
    "app.kubernetes.io/version"   = "1.0.0"
    "environment"                 = var.environment
  }

  # S3 bucket names
  mimir_bucket   = "${var.environment}-lgtm-mimir-${var.aws_account_id}"
  loki_bucket    = "${var.environment}-lgtm-loki-${var.aws_account_id}"
  tempo_bucket   = "${var.environment}-lgtm-tempo-${var.aws_account_id}"

  # Service account names
  mimir_service_account   = "mimir-sa"
  loki_service_account    = "loki-sa"
  tempo_service_account   = "tempo-sa"
  grafana_service_account = "grafana-sa"

  # IAM role names
  mimir_role_name   = "${var.cluster_name}-mimir-role"
  loki_role_name    = "${var.cluster_name}-loki-role"
  tempo_role_name   = "${var.cluster_name}-tempo-role"
  grafana_role_name = "${var.cluster_name}-grafana-role"

  # Helm chart versions (pinned for stability)
  chart_versions = {
    prometheus      = "25.8.0"
    grafana        = "7.0.11"
    loki           = "2.10.2"
    mimir          = "5.1.4"
    tempo          = "1.7.1"
  }

  # Component resource totals for documentation
  total_resources = {
    cpu_requests = (
      (var.enable_prometheus ? tonumber(split("m", var.prometheus_resources.requests.cpu)[0]) : 0) +
      (var.enable_grafana ? tonumber(split("m", var.grafana_resources.requests.cpu)[0]) : 0) +
      (var.enable_mimir ? tonumber(split("m", var.mimir_resources.requests.cpu)[0]) : 0) +
      (var.enable_loki ? tonumber(split("m", var.loki_resources.requests.cpu)[0]) : 0) +
      (var.enable_tempo ? tonumber(split("m", var.tempo_resources.requests.cpu)[0]) : 0)
    )
    memory_requests = (
      (var.enable_prometheus ? tonumber(split("Mi", var.prometheus_resources.requests.memory)[0]) : 0) +
      (var.enable_grafana ? tonumber(split("Mi", var.grafana_resources.requests.memory)[0]) : 0) +
      (var.enable_mimir ? tonumber(split("Mi", var.mimir_resources.requests.memory)[0]) : 0) +
      (var.enable_loki ? tonumber(split("Mi", var.loki_resources.requests.memory)[0]) : 0) +
      (var.enable_tempo ? tonumber(split("Mi", var.tempo_resources.requests.memory)[0]) : 0)
    )
  }

  # Grafana data sources configuration
  grafana_datasources = {
    prometheus = {
      name = "Prometheus"
      type = "prometheus"
      url  = "http://prometheus-server.${var.namespace}.svc.cluster.local"
    }
    loki = var.enable_loki ? {
      name = "Loki"
      type = "loki"
      url  = "http://loki.${var.namespace}.svc.cluster.local:3100"
    } : null
    tempo = var.enable_tempo ? {
      name = "Tempo"
      type = "tempo"
      url  = "http://tempo.${var.namespace}.svc.cluster.local:3100"
    } : null
    mimir = var.enable_mimir ? {
      name = "Mimir"
      type = "prometheus"
      url  = "http://mimir-nginx.${var.namespace}.svc.cluster.local/prometheus"
    } : null
  }

  # Environment-specific configurations
  env_configs = {
    dev = {
      replica_count           = 1
      enable_persistence     = false
      storage_class          = "gp2"
      enable_node_exporter   = false  # Disable to reduce resource usage
      enable_kube_state      = true
    }
    staging = {
      replica_count           = 2
      enable_persistence     = true
      storage_class          = "gp3"
      enable_node_exporter   = true
      enable_kube_state      = true
    }
    prod = {
      replica_count           = 3
      enable_persistence     = true
      storage_class          = "gp3"
      enable_node_exporter   = true
      enable_kube_state      = true
    }
  }

  # Current environment config
  current_env = local.env_configs[var.environment]
}