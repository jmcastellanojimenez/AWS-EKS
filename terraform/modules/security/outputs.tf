# Security Module Outputs

output "namespace" {
  description = "Security namespace"
  value       = kubernetes_namespace.security.metadata[0].name
}

# OpenBao Outputs
output "openbao_service_name" {
  description = "OpenBao service name"
  value       = "openbao"
}

output "openbao_url" {
  description = "OpenBao URL"
  value       = "https://openbao.${kubernetes_namespace.security.metadata[0].name}.svc.cluster.local:8200"
}

output "openbao_ui_url" {
  description = "OpenBao UI URL"
  value       = "https://openbao-ui.${kubernetes_namespace.security.metadata[0].name}.svc.cluster.local:8200"
}

# External Secrets Outputs
output "external_secrets_operator" {
  description = "External Secrets Operator service name"
  value       = "external-secrets"
}

# OPA Gatekeeper Outputs
output "gatekeeper_service_name" {
  description = "OPA Gatekeeper service name"
  value       = "gatekeeper-webhook-service"
}

# NOTE: Commented out until Gatekeeper policies are re-enabled
/* 
output "gatekeeper_policies" {
  description = "Deployed Gatekeeper policies"
  value = {
    pod_security_policy      = kubernetes_manifest.pod_security_policy.manifest.metadata.name
    resource_requirements    = kubernetes_manifest.resource_requirements_policy.manifest.metadata.name
  }
}

output "gatekeeper_constraints" {
  description = "Deployed Gatekeeper constraints"
  value = {
    pod_security_constraint      = kubernetes_manifest.pod_security_constraint.manifest.metadata.name
    resource_requirements_constraint = kubernetes_manifest.resource_requirements_constraint.manifest.metadata.name
  }
}
*/

# Falco Outputs
output "falco_service_name" {
  description = "Falco service name"
  value       = "falco"
}

output "falco_sidekick_service_name" {
  description = "Falco Sidekick service name"
  value       = "falco-falcosidekick"
}

# Security Configuration
output "security_configuration" {
  description = "Security configuration summary"
  value = {
    secrets_management = {
      provider = "openbao"
      external_secrets_enabled = true
    }
    policy_enforcement = {
      provider = "opa-gatekeeper"
      pod_security_enabled = var.enable_pod_security_policies
      resource_policies_enabled = var.enable_resource_policies
    }
    runtime_security = {
      provider = "falco"
      driver_kind = var.falco_driver_kind
      alerts_enabled = var.slack_webhook_url != ""
    }
    compliance = {
      framework = var.compliance_framework
      audit_retention = var.audit_log_retention
    }
  }
}

# Service Endpoints for Integration
output "service_endpoints" {
  description = "Service endpoints for integration with other components"
  value = {
    openbao = {
      api = "https://openbao.${kubernetes_namespace.security.metadata[0].name}.svc.cluster.local:8200"
      ui  = "https://openbao-ui.${kubernetes_namespace.security.metadata[0].name}.svc.cluster.local:8200"
    }
    external_secrets = {
      webhook = "https://external-secrets-webhook.${kubernetes_namespace.security.metadata[0].name}.svc.cluster.local:9443"
    }
    gatekeeper = {
      webhook = "https://gatekeeper-webhook-service.${kubernetes_namespace.security.metadata[0].name}.svc.cluster.local:443"
    }
    falco = {
      metrics = "http://falco.${kubernetes_namespace.security.metadata[0].name}.svc.cluster.local:8765/metrics"
      grpc    = "falco.${kubernetes_namespace.security.metadata[0].name}.svc.cluster.local:5060"
    }
  }
}

# Monitoring Integration
output "monitoring_integration" {
  description = "Monitoring integration information"
  value = {
    service_monitors = [
      "external-secrets",
      "openbao",
      "gatekeeper",
      "falco"
    ]
    metrics_endpoints = {
      external_secrets = "/metrics"
      openbao         = "/v1/sys/metrics"
      gatekeeper      = "/metrics"
      falco          = "/metrics"
    }
  }
}

# Security Policies Summary
output "security_policies" {
  description = "Summary of deployed security policies"
  value = {
    constraint_templates = [
      "k8srequiredsecuritycontext",
      "k8srequiredresources"
    ]
    constraints = [
      "must-have-security-context",
      "must-have-resources"
    ]
    policy_actions = {
      violation_action = var.policy_violation_action
    }
  }
}