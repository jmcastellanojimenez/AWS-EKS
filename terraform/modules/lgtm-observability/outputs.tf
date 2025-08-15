# ==============================================================================
# LGTM Observability Stack Outputs
# ==============================================================================

# ==============================================================================
# General Outputs
# ==============================================================================

output "namespace" {
  description = "Kubernetes namespace for observability components"
  value       = kubernetes_namespace.observability.metadata[0].name
}

output "observability_ready" {
  description = "Overall observability stack readiness"
  value       = "true"
}

# ==============================================================================
# Resource Summary
# ==============================================================================

output "total_cpu_requests" {
  description = "Total CPU requests across all components (in millicores)"
  value       = "${local.total_resources.cpu_requests}m"
}

output "total_memory_requests" {
  description = "Total memory requests across all components (in Mi)"
  value       = "${local.total_resources.memory_requests}Mi"
}

output "remaining_cluster_capacity" {
  description = "Estimated remaining cluster capacity after observability stack"
  value = {
    cpu_cores    = "~${2.0 - (local.total_resources.cpu_requests / 1000)} cores remaining"
    memory_gb    = "~${1.2 - (local.total_resources.memory_requests / 1024)} GB remaining"
    note         = "Based on t3.large node capacity minus foundation + ingress + observability"
  }
}

# ==============================================================================
# Component Endpoints
# ==============================================================================

output "prometheus_endpoint" {
  description = "Prometheus server endpoint for internal cluster access"
  value       = var.enable_prometheus ? "http://prometheus-server.${var.namespace}.svc.cluster.local" : null
}

output "grafana_endpoint" {
  description = "Grafana endpoint for internal cluster access"
  value       = "http://grafana.${var.namespace}.svc.cluster.local"
}

output "loki_endpoint" {
  description = "Loki endpoint for internal cluster access"
  value       = var.enable_loki ? "http://loki.${var.namespace}.svc.cluster.local:3100" : null
}

output "tempo_endpoint" {
  description = "Tempo endpoint for internal cluster access"
  value       = var.enable_tempo ? "http://tempo.${var.namespace}.svc.cluster.local:3100" : null
}

output "mimir_endpoint" {
  description = "Mimir endpoint for internal cluster access"
  value       = var.enable_mimir ? "http://mimir-nginx.${var.namespace}.svc.cluster.local/prometheus" : null
}

# ==============================================================================
# Access Information
# ==============================================================================

output "grafana_admin_credentials" {
  description = "Grafana admin access information"
  value = {
    username       = "admin"
    password_hint  = "Stored in Kubernetes secret: ${kubernetes_secret.grafana_credentials.metadata[0].name}"
    access_command = "kubectl port-forward -n ${var.namespace} svc/grafana 3000:80"
    url           = "http://localhost:3000"
  }
  sensitive = true
}

output "grafana_password_command" {
  description = "Command to retrieve Grafana admin password"
  value       = "kubectl get secret -n ${var.namespace} ${kubernetes_secret.grafana_credentials.metadata[0].name} -o jsonpath='{.data.admin-password}' | base64 -d"
}

# ==============================================================================
# S3 Storage Information
# ==============================================================================

output "s3_buckets" {
  description = "S3 buckets created for observability data storage"
  value = {
    mimir = var.enable_mimir ? aws_s3_bucket.mimir[0].id : null
    loki  = var.enable_loki ? aws_s3_bucket.loki[0].id : null
    tempo = var.enable_tempo ? aws_s3_bucket.tempo[0].id : null
  }
}

output "s3_storage_lifecycle" {
  description = "S3 storage lifecycle configuration"
  value = {
    enabled           = var.s3_lifecycle_enabled
    transition_days   = var.s3_transition_days
    expiration_days   = var.s3_expiration_days
    cold_storage_note = "Data transitions to IA after ${var.s3_transition_days} days, Glacier after 30 days"
  }
}

# ==============================================================================
# IRSA Information
# ==============================================================================

output "service_accounts" {
  description = "Service accounts with IRSA configuration"
  value = {
    grafana = {
      name      = kubernetes_service_account.grafana.metadata[0].name
      role_arn  = aws_iam_role.grafana.arn
    }
    mimir = var.enable_mimir ? {
      name      = kubernetes_service_account.mimir[0].metadata[0].name
      role_arn  = aws_iam_role.mimir[0].arn
    } : null
    loki = var.enable_loki ? {
      name      = kubernetes_service_account.loki[0].metadata[0].name
      role_arn  = aws_iam_role.loki[0].arn
    } : null
    tempo = var.enable_tempo ? {
      name      = kubernetes_service_account.tempo[0].metadata[0].name
      role_arn  = aws_iam_role.tempo[0].arn
    } : null
  }
}

# ==============================================================================
# Component Status
# ==============================================================================

output "prometheus_ready" {
  description = "Prometheus deployment status"
  value       = var.enable_prometheus ? "deployed" : "disabled"
}

output "grafana_ready" {
  description = "Grafana deployment status"
  value       = "deployed"
}

output "loki_ready" {
  description = "Loki deployment status"
  value       = var.enable_loki ? "deployed" : "disabled"
}

output "tempo_ready" {
  description = "Tempo deployment status"
  value       = var.enable_tempo ? "deployed" : "disabled"
}

output "mimir_ready" {
  description = "Mimir deployment status"
  value       = var.enable_mimir ? "deployed" : "disabled"
}

# ==============================================================================
# Integration Information
# ==============================================================================

output "data_sources_configured" {
  description = "Data sources automatically configured in Grafana"
  value = compact([
    var.enable_prometheus ? "Prometheus (metrics collection)" : null,
    var.enable_loki ? "Loki (log aggregation)" : null,
    var.enable_tempo ? "Tempo (distributed tracing)" : null,
    var.enable_mimir ? "Mimir (long-term metrics storage)" : null,
    "CloudWatch (AWS metrics - optional)"
  ])
}

output "microservices_integration" {
  description = "EcoTrack microservices integration guide"
  value = {
    metrics_endpoint   = "/actuator/prometheus"
    logs_collection   = "Automatic via Promtail"
    tracing_endpoint  = var.enable_tempo ? "http://tempo.${var.namespace}.svc.cluster.local:4317" : null
    required_annotations = {
      "prometheus.io/scrape" = "true"
      "prometheus.io/path"   = "/actuator/prometheus"
      "prometheus.io/port"   = "8080"
    }
  }
}

# ==============================================================================
# Next Steps
# ==============================================================================

output "post_deployment_commands" {
  description = "Commands to verify and access the observability stack"
  value = {
    check_pods      = "kubectl get pods -n ${var.namespace}"
    check_services  = "kubectl get svc -n ${var.namespace}"
    access_grafana  = "kubectl port-forward -n ${var.namespace} svc/grafana 3000:80"
    get_password    = "kubectl get secret -n ${var.namespace} ${kubernetes_secret.grafana_credentials.metadata[0].name} -o jsonpath='{.data.admin-password}' | base64 -d"
    check_storage   = "aws s3 ls | grep lgtm"
  }
}

output "dashboard_urls" {
  description = "Grafana dashboard access after port-forward"
  value = {
    grafana_ui         = "http://localhost:3000"
    kubernetes_cluster = "http://localhost:3000/d/7249/kubernetes-cluster-monitoring-via-prometheus"
    spring_boot        = "http://localhost:3000/d/12900/spring-boot-statistics"
    ambassador         = "http://localhost:3000/d/13758/ambassador-edge-stack"
  }
}

# ==============================================================================
# Alerting Configuration
# ==============================================================================

output "alerting_info" {
  description = "Alerting configuration information"
  value = {
    enabled            = var.enable_grafana_alerts
    slack_configured   = var.slack_webhook_url != ""
    alert_manager_url  = var.enable_prometheus ? "http://prometheus-alertmanager.${var.namespace}.svc.cluster.local" : null
    grafana_alerts_url = "http://localhost:3000/alerting"
  }
}