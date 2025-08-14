# Ingress + API Gateway Stack (Workflow 2)
# Depends on existing EKS cluster from Foundation Platform (Workflow 1)

# Data sources to reference existing infrastructure
data "aws_eks_cluster" "foundation" {
  name = local.cluster_name
}

data "aws_eks_cluster_auth" "foundation" {
  name = local.cluster_name
}

# Kubernetes provider configuration
provider "kubernetes" {
  alias = "ingress_stack"
  
  host                   = data.aws_eks_cluster.foundation.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.foundation.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.foundation.token

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", local.cluster_name]
  }
}

# Helm provider configuration
provider "helm" {
  alias = "ingress_stack"
  
  kubernetes {
    host                   = data.aws_eks_cluster.foundation.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.foundation.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.foundation.token

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", local.cluster_name]
    }
  }
}

# Local values for Workflow 2 configuration
locals {
  # Domain configuration for ingress
  ingress_domain = var.ingress_domain != "" ? var.ingress_domain : "${var.environment}.${var.project_name}.local"
  
  # Resource sizing configuration for t3.large nodes
  # Total planned allocation: ~1.2 CPU, ~768Mi memory
  # Remaining headroom: ~2.8 CPU, ~1.2Gi memory for workflows 3-7
}

# cert-manager Module
module "cert_manager" {
  source = "../../modules/cert-manager"
  
  providers = {
    kubernetes = kubernetes.ingress_stack
    helm       = helm.ingress_stack
  }

  project_name         = var.project_name
  environment          = var.environment
  cert_manager_version = var.cert_manager_version
  enable_letsencrypt   = var.enable_letsencrypt
  letsencrypt_email    = var.letsencrypt_email
  enable_monitoring    = var.enable_monitoring

  depends_on = [
    data.aws_eks_cluster.foundation,
    data.aws_eks_cluster_auth.foundation
  ]
}

# external-dns Module
module "external_dns" {
  source = "../../modules/external-dns"
  
  providers = {
    kubernetes = kubernetes.ingress_stack
    helm       = helm.ingress_stack
  }

  project_name              = var.project_name
  environment               = var.environment
  external_dns_version      = var.external_dns_version
  dns_provider              = var.dns_provider
  domain_filters            = var.domain_filters
  cloudflare_api_token      = var.cloudflare_api_token
  service_account_role_arn  = var.external_dns_role_arn != "" ? var.external_dns_role_arn : module.iam_irsa.external_dns_role_arn
  enable_monitoring         = var.enable_monitoring

  depends_on = [
    module.cert_manager
  ]
}

# Ambassador (Emissary-Ingress) Module  
module "ambassador" {
  source = "../../modules/ambassador"
  
  providers = {
    kubernetes = kubernetes.ingress_stack
    helm       = helm.ingress_stack
  }

  project_name         = var.project_name
  environment          = var.environment
  ambassador_version   = var.ambassador_version
  hostname             = local.ingress_domain
  replica_count        = var.ambassador_replica_count
  load_balancer_scheme = var.load_balancer_scheme
  enable_tls           = var.enable_tls
  acme_email           = var.letsencrypt_email
  cors_origins         = var.cors_origins
  enable_monitoring    = var.enable_monitoring

  depends_on = [
    module.cert_manager,
    module.external_dns
  ]
}