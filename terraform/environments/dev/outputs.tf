output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = module.eks.cluster_security_group_id
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = module.eks.cluster_certificate_authority_data
  sensitive   = true
}

output "cluster_version" {
  description = "EKS cluster Kubernetes version"
  value       = module.eks.cluster_version
}

output "node_group_arn" {
  description = "Amazon Resource Name (ARN) of the EKS Node Group"
  value       = module.eks.node_group_arn
}

output "node_security_group_id" {
  description = "ID of the node group security group"
  value       = module.eks.node_security_group_id
}

output "oidc_provider_arn" {
  description = "ARN of the OIDC Provider for the EKS cluster"
  value       = module.eks.oidc_provider_arn
}

output "oidc_provider_url" {
  description = "URL of the OIDC Provider for the EKS cluster"
  value       = module.eks.oidc_provider_url
}

output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = module.vpc.private_subnet_ids
}

output "kubeconfig_command" {
  description = "Command to update kubeconfig"
  value       = module.eks.kubeconfig_command
}

output "ebs_csi_driver_role_arn" {
  description = "ARN of the EBS CSI driver IAM role"
  value       = module.iam_irsa.ebs_csi_driver_role_arn
}

output "external_dns_role_arn" {
  description = "ARN of the External-DNS IAM role"
  value       = module.iam_irsa.external_dns_role_arn
}

output "cert_manager_role_arn" {
  description = "ARN of the cert-manager IAM role"
  value       = module.iam_irsa.cert_manager_role_arn
}

# ===================================
# Workflow 2: Ingress + API Gateway Stack Outputs  
# ===================================

# cert-manager outputs
output "cert_manager_ready" {
  description = "Whether cert-manager is ready"
  value       = try(module.cert_manager.ready, false)
}

output "cert_manager_namespace" {
  description = "cert-manager namespace"
  value       = try(module.cert_manager.namespace, "")
}

output "letsencrypt_staging_issuer" {
  description = "Let's Encrypt staging ClusterIssuer name"
  value       = try(module.cert_manager.letsencrypt_staging_issuer, "")
}

output "letsencrypt_prod_issuer" {
  description = "Let's Encrypt production ClusterIssuer name"
  value       = try(module.cert_manager.letsencrypt_prod_issuer, "")
}

# external-dns outputs
output "external_dns_ready" {
  description = "Whether external-dns is ready"
  value       = try(module.external_dns.ready, false)
}

output "external_dns_namespace" {
  description = "external-dns namespace"
  value       = try(module.external_dns.namespace, "")
}

output "external_dns_provider" {
  description = "Configured DNS provider"
  value       = try(module.external_dns.dns_provider, "")
}

# Ambassador outputs
output "ambassador_ready" {
  description = "Whether Ambassador is ready"
  value       = try(module.ambassador.ready, false)
}

output "ambassador_namespace" {
  description = "Ambassador namespace"
  value       = try(module.ambassador.namespace, "")
}

output "ambassador_service_name" {
  description = "Ambassador service name"
  value       = try(module.ambassador.service_name, "")
}

output "ambassador_hostname" {
  description = "Primary hostname for API Gateway"
  value       = try(module.ambassador.primary_hostname, "")
}

output "ambassador_load_balancer_info" {
  description = "Information about Ambassador Load Balancer"
  value       = try(module.ambassador.load_balancer_hostname, "")
}

output "ambassador_mapping_example" {
  description = "Example Mapping CRD for connecting applications"
  value       = try(module.ambassador.mapping_example, {})
}

# Ingress stack summary
output "ingress_stack_summary" {
  description = "Summary of deployed ingress components"
  value = {
    cert_manager = {
      ready     = try(module.cert_manager.ready, false)
      namespace = try(module.cert_manager.namespace, "")
      version   = var.cert_manager_version
    }
    external_dns = {
      ready     = try(module.external_dns.ready, false)
      namespace = try(module.external_dns.namespace, "")
      provider  = var.dns_provider
      version   = var.external_dns_version
    }
    ambassador = {
      ready       = try(module.ambassador.ready, false)
      namespace   = try(module.ambassador.namespace, "")
      hostname    = var.ingress_domain
      replicas    = var.ambassador_replica_count
      version     = var.ambassador_version
    }
  }
}

# Resource allocation summary for planning
output "resource_allocation" {
  description = "Resource allocation for Workflow 2 components"
  value = {
    cert_manager = {
      cpu_request = "10m"
      cpu_limit   = "100m"
      mem_request = "32Mi" 
      mem_limit   = "128Mi"
    }
    external_dns = {
      cpu_request = "10m"
      cpu_limit   = "100m"
      mem_request = "32Mi"
      mem_limit   = "128Mi"
    }
    ambassador = {
      cpu_request = "200m"
      cpu_limit   = "1000m"
      mem_request = "256Mi"
      mem_limit   = "512Mi"
      replicas    = var.ambassador_replica_count
    }
    total_workflow_2 = {
      cpu_request = "420m"  # 220m + 200m for 2 ambassador replicas
      cpu_limit   = "2200m" # 200m + 2000m for 2 ambassador replicas
      mem_request = "544Mi"  # 64Mi + 512Mi for 2 ambassador replicas
      mem_limit   = "768Mi"  # 256Mi + 512Mi for 2 ambassador replicas
    }
    remaining_capacity = {
      description = "Remaining capacity for workflows 3-7 on t3.large nodes"
      cpu_available = "~2.8 cores"
      memory_available = "~1.2Gi"
      suitable_for = "5 microservices + future workflows (LGTM, ArgoCD, Security, Istio, Data)"
    }
  }
}

# ===================================
# Workflow 3: LGTM Observability Stack Outputs
# ===================================

output "observability_namespace" {
  description = "Kubernetes namespace for observability components"
  value       = try(module.lgtm_observability.namespace, "")
}

output "observability_ready" {
  description = "Overall observability stack readiness"
  value       = try(module.lgtm_observability.observability_ready, false)
}

# Component endpoints
output "prometheus_endpoint" {
  description = "Prometheus server endpoint for internal cluster access"
  value       = try(module.lgtm_observability.prometheus_endpoint, "")
}

output "grafana_endpoint" {
  description = "Grafana endpoint for internal cluster access"
  value       = try(module.lgtm_observability.grafana_endpoint, "")
}

output "loki_endpoint" {
  description = "Loki endpoint for internal cluster access"
  value       = try(module.lgtm_observability.loki_endpoint, "")
}

output "tempo_endpoint" {
  description = "Tempo endpoint for internal cluster access"
  value       = try(module.lgtm_observability.tempo_endpoint, "")
}

output "mimir_endpoint" {
  description = "Mimir endpoint for internal cluster access"
  value       = try(module.lgtm_observability.mimir_endpoint, "")
}

# Access information
output "grafana_admin_credentials" {
  description = "Grafana admin access information"
  value       = try(module.lgtm_observability.grafana_admin_credentials, {})
  sensitive   = true
}

output "grafana_password_command" {
  description = "Command to retrieve Grafana admin password"
  value       = try(module.lgtm_observability.grafana_password_command, "")
}

# Resource utilization
output "observability_resource_usage" {
  description = "Resource usage summary for LGTM observability stack"
  value = {
    total_cpu_requests    = try(module.lgtm_observability.total_cpu_requests, "0m")
    total_memory_requests = try(module.lgtm_observability.total_memory_requests, "0Mi")
    remaining_capacity    = try(module.lgtm_observability.remaining_cluster_capacity, {})
  }
}

# S3 storage information
output "observability_storage" {
  description = "S3 buckets for observability data"
  value       = try(module.lgtm_observability.s3_buckets, {})
}

# Component status
output "observability_components" {
  description = "Status of individual observability components"
  value = {
    prometheus = try(module.lgtm_observability.prometheus_ready, "disabled")
    grafana    = try(module.lgtm_observability.grafana_ready, "disabled")
    loki       = try(module.lgtm_observability.loki_ready, "disabled")
    tempo      = try(module.lgtm_observability.tempo_ready, "disabled")
    mimir      = try(module.lgtm_observability.mimir_ready, "disabled")
  }
}

# Service accounts with IRSA
output "observability_service_accounts" {
  description = "Service accounts with IRSA configuration"
  value       = try(module.lgtm_observability.service_accounts, {})
}

# Data sources configured in Grafana
output "grafana_data_sources" {
  description = "Data sources automatically configured in Grafana"
  value       = try(module.lgtm_observability.data_sources_configured, [])
}

# Microservices integration guide
output "microservices_integration" {
  description = "Integration guide for EcoTrack microservices"
  value       = try(module.lgtm_observability.microservices_integration, {})
}

# Post-deployment commands
output "observability_commands" {
  description = "Commands to verify and access the observability stack"
  value       = try(module.lgtm_observability.post_deployment_commands, {})
}

# Dashboard URLs
output "grafana_dashboards" {
  description = "Grafana dashboard URLs after port-forward"
  value       = try(module.lgtm_observability.dashboard_urls, {})
}

# Alerting information
output "alerting_info" {
  description = "Alerting configuration information"
  value       = try(module.lgtm_observability.alerting_info, {})
}