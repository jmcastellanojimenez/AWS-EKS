# Observability Module Outputs

output "namespace" {
  description = "Observability namespace"
  value       = kubernetes_namespace.observability.metadata[0].name
}

output "prometheus_service_name" {
  description = "Prometheus service name"
  value       = "prometheus-kube-prometheus-prometheus"
}

output "grafana_service_name" {
  description = "Grafana service name"
  value       = "grafana"
}

output "loki_service_name" {
  description = "Loki service name"
  value       = "loki-gateway"
}

output "tempo_service_name" {
  description = "Tempo service name"
  value       = "tempo-query-frontend"
}

output "mimir_service_name" {
  description = "Mimir service name"
  value       = "mimir-query-frontend"
}

output "otel_collector_service_name" {
  description = "OpenTelemetry Collector service name"
  value       = "otel-collector"
}

output "grafana_url" {
  description = "Grafana URL"
  value       = "https://${var.domain_name}/grafana"
}

output "prometheus_url" {
  description = "Prometheus URL"
  value       = "http://prometheus-kube-prometheus-prometheus.${kubernetes_namespace.observability.metadata[0].name}.svc.cluster.local:9090"
}

output "loki_url" {
  description = "Loki URL"
  value       = "http://loki-gateway.${kubernetes_namespace.observability.metadata[0].name}.svc.cluster.local"
}

output "tempo_url" {
  description = "Tempo URL"
  value       = "http://tempo-query-frontend.${kubernetes_namespace.observability.metadata[0].name}.svc.cluster.local:3200"
}

output "otel_collector_endpoint" {
  description = "OpenTelemetry Collector OTLP endpoint"
  value       = "http://otel-collector.${kubernetes_namespace.observability.metadata[0].name}.svc.cluster.local:4317"
}