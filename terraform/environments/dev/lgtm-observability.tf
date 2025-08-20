# ==============================================================================
# Workflow 3: LGTM Observability Stack Configuration
# ==============================================================================

# Data source to get cluster information from existing EKS cluster
data "aws_eks_cluster" "cluster" {
  name = module.foundation.cluster_name
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.foundation.cluster_name
}

# Kubernetes and Helm providers for LGTM stack
provider "kubernetes" {
  alias = "lgtm"

  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

provider "helm" {
  alias = "lgtm"

  kubernetes {
    host                   = data.aws_eks_cluster.cluster.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}

# LGTM Observability Stack Module
module "lgtm_observability" {
  source = "../../modules/lgtm-observability"

  # Cluster information
  cluster_name                       = module.foundation.cluster_name
  cluster_endpoint                   = module.foundation.cluster_endpoint
  cluster_certificate_authority_data = module.foundation.cluster_certificate_authority_data

  # Environment configuration
  environment    = var.environment
  namespace      = var.observability_namespace
  aws_region     = var.aws_region
  aws_account_id = data.aws_caller_identity.current.account_id

  # IRSA configuration
  oidc_provider_arn = module.foundation.oidc_provider_arn

  # Grafana configuration
  grafana_admin_password = var.grafana_admin_password
  grafana_domain         = var.grafana_domain
  enable_grafana_alerts  = var.enable_grafana_alerts
  slack_webhook_url      = var.slack_webhook_url

  # Component toggles
  enable_prometheus = var.enable_prometheus
  enable_mimir      = var.enable_mimir
  enable_loki       = var.enable_loki
  enable_tempo      = var.enable_tempo

  # Resource configuration
  prometheus_resources = var.prometheus_resources
  grafana_resources    = var.grafana_resources
  mimir_resources      = var.mimir_resources
  loki_resources       = var.loki_resources
  tempo_resources      = var.tempo_resources

  # Storage configuration
  prometheus_storage_size = var.prometheus_storage_size
  grafana_storage_size    = var.grafana_storage_size
  prometheus_retention    = var.prometheus_retention

  # S3 lifecycle
  s3_lifecycle_enabled = var.s3_lifecycle_enabled
  s3_transition_days   = var.s3_transition_days
  s3_expiration_days   = var.s3_expiration_days

  # Tags
  tags = merge(local.common_tags, {
    Workflow  = "3"
    Component = "LGTM-Observability"
    Purpose   = "Monitoring-Logging-Tracing"
  })

  providers = {
    kubernetes = kubernetes.lgtm
    helm       = helm.lgtm
  }

  depends_on = [
    module.foundation
  ]
}

# Data source for AWS account ID (imported from main.tf scope)
# data "aws_caller_identity" "current" {} # Already defined in main.tf