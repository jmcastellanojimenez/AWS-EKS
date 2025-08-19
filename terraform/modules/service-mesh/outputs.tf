# Service Mesh Module Outputs

output "namespace" {
  description = "Istio system namespace"
  value       = kubernetes_namespace.istio_system.metadata[0].name
}

# Istio Control Plane Outputs
output "istiod_service_name" {
  description = "Istiod service name"
  value       = "istiod"
}

output "istio_gateway_service_name" {
  description = "Istio gateway service name"
  value       = "istio-gateway"
}

output "istio_version" {
  description = "Deployed Istio version"
  value       = var.istio_version
}

# Gateway Configuration
output "default_gateway_name" {
  description = "Default gateway name"
  value       = kubernetes_manifest.default_gateway.manifest.metadata.name
}

output "gateway_load_balancer" {
  description = "Gateway load balancer service"
  value       = "istio-gateway"
}

# Security Configuration
output "mtls_configuration" {
  description = "mTLS configuration"
  value = {
    mode                    = var.mtls_mode
    peer_authentication    = kubernetes_manifest.default_peer_authentication.manifest.metadata.name
    destination_rule       = kubernetes_manifest.default_destination_rule.manifest.metadata.name
  }
}

# Observability Integration
output "observability_integration" {
  description = "Observability integration configuration"
  value = {
    kiali_enabled    = var.enable_kiali
    jaeger_enabled   = var.enable_jaeger
    prometheus_integration = var.enable_prometheus_integration
    grafana_integration   = var.enable_grafana_integration
    tempo_integration     = var.enable_tempo_integration
    trace_sampling_rate   = var.trace_sampling_rate
  }
}

output "kiali_url" {
  description = "Kiali dashboard URL"
  value       = var.enable_kiali ? "https://${var.domain_name}/kiali" : null
}

output "jaeger_url" {
  description = "Jaeger UI URL"
  value       = var.enable_jaeger ? "https://${var.domain_name}/jaeger" : null
}

# Service Endpoints
output "service_endpoints" {
  description = "Service mesh endpoints"
  value = {
    istiod = {
      discovery = "istiod.${kubernetes_namespace.istio_system.metadata[0].name}.svc.cluster.local:15010"
      webhook   = "istiod.${kubernetes_namespace.istio_system.metadata[0].name}.svc.cluster.local:15017"
      metrics   = "istiod.${kubernetes_namespace.istio_system.metadata[0].name}.svc.cluster.local:15014"
    }
    gateway = {
      http  = "istio-gateway.${kubernetes_namespace.istio_system.metadata[0].name}.svc.cluster.local:80"
      https = "istio-gateway.${kubernetes_namespace.istio_system.metadata[0].name}.svc.cluster.local:443"
      status = "istio-gateway.${kubernetes_namespace.istio_system.metadata[0].name}.svc.cluster.local:15021"
    }
    kiali = var.enable_kiali ? {
      ui = "kiali-server.${kubernetes_namespace.istio_system.metadata[0].name}.svc.cluster.local:20001"
    } : null
    jaeger = var.enable_jaeger ? {
      ui    = "jaeger-query.${kubernetes_namespace.istio_system.metadata[0].name}.svc.cluster.local:16686"
      agent = "jaeger-agent.${kubernetes_namespace.istio_system.metadata[0].name}.svc.cluster.local:14268"
    } : null
  }
}

# Traffic Management Configuration
output "traffic_management" {
  description = "Traffic management configuration"
  value = {
    circuit_breaker_enabled = var.circuit_breaker_enabled
    retry_policy_enabled    = var.retry_policy_enabled
    timeout_policy_enabled  = var.timeout_policy_enabled
    traffic_management_enabled = var.enable_traffic_management
  }
}

# Security Policies
output "security_policies" {
  description = "Security policies configuration"
  value = {
    authorization_policies_enabled = var.enable_authorization_policies
    security_policies_enabled     = var.enable_security_policies
    jwt_authentication_enabled    = var.jwt_authentication_enabled
  }
}

# Monitoring Integration
output "monitoring_integration" {
  description = "Monitoring integration information"
  value = {
    service_monitors = [
      kubernetes_manifest.istio_service_monitor.manifest.metadata.name,
      kubernetes_manifest.istio_gateway_service_monitor.manifest.metadata.name
    ]
    metrics_endpoints = {
      istiod  = "/stats/prometheus"
      gateway = "/stats/prometheus"
    }
    telemetry_config = kubernetes_manifest.telemetry_v2.manifest.metadata.name
  }
}

# Configuration for Applications
output "application_configuration" {
  description = "Configuration information for applications using the service mesh"
  value = {
    sidecar_injection = {
      namespace_label = "istio-injection=enabled"
      pod_annotation  = "sidecar.istio.io/inject=true"
    }
    gateway_reference = {
      name      = kubernetes_manifest.default_gateway.manifest.metadata.name
      namespace = kubernetes_namespace.istio_system.metadata[0].name
    }
    mtls_mode = var.mtls_mode
    tracing = {
      enabled      = true
      sampling_rate = var.trace_sampling_rate
      provider     = "tempo"
    }
  }
}

# Multi-cluster Configuration
output "multi_cluster_config" {
  description = "Multi-cluster configuration"
  value = var.enable_multi_cluster ? {
    enabled      = true
    mesh_id      = var.mesh_id != "" ? var.mesh_id : var.cluster_name
    network      = var.cluster_network != "" ? var.cluster_network : var.cluster_name
    cluster_name = var.cluster_name
  } : null
}

# Resource Configuration Summary
output "resource_configuration" {
  description = "Resource configuration summary"
  value = {
    pilot_resources = var.pilot_resources
    proxy_resources = var.proxy_resources
    gateway_scaling = {
      min_replicas = var.gateway_min_replicas
      max_replicas = var.gateway_max_replicas
      autoscaling_enabled = var.enable_gateway_autoscaling
    }
  }
}

# Service Mesh Status
output "service_mesh_status" {
  description = "Service mesh deployment status"
  value = {
    istio_base_deployed    = true
    istiod_deployed       = true
    gateway_deployed      = true
    default_policies_applied = true
    observability_configured = true
  }
}