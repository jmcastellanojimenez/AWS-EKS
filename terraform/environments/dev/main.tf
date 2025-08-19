# Development Environment Configuration
terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
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

# Configure providers
provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

data "aws_eks_cluster" "cluster" {
  name = module.foundation.cluster_name
  depends_on = [module.foundation]
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.foundation.cluster_name
  depends_on = [module.foundation]
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.cluster.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}

# Local values
locals {
  cluster_name = "${var.project_name}-${var.environment}-cluster"
}

# Workflow 1: Foundation Platform
module "foundation" {
  source = "../../modules/foundation"

  project_name              = var.project_name
  environment              = var.environment
  owner                    = var.owner
  aws_region               = var.aws_region
  availability_zones_count = var.availability_zones_count
  vpc_cidr                 = var.vpc_cidr
  private_subnet_cidrs     = var.private_subnet_cidrs
  public_subnet_cidrs      = var.public_subnet_cidrs
  single_nat_gateway       = var.single_nat_gateway
  kubernetes_version       = var.kubernetes_version
}

# IAM roles for observability components
module "observability_irsa_roles" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  for_each = toset(["mimir", "loki", "tempo"])

  role_name = "${local.cluster_name}-${each.key}"

  role_policy_arns = {
    policy = aws_iam_policy.observability_s3_policy[each.key].arn
  }

  oidc_providers = {
    ex = {
      provider_arn               = module.foundation.oidc_provider_arn
      namespace_service_accounts = ["observability:${each.key}"]
    }
  }

  depends_on = [module.foundation]
}

# S3 access policy for observability components
resource "aws_iam_policy" "observability_s3_policy" {
  for_each = toset(["mimir", "loki", "tempo"])
  
  name        = "${local.cluster_name}-${each.key}-s3-policy"
  description = "S3 access policy for ${each.key}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          module.foundation.observability_s3_buckets[each.key].arn,
          "${module.foundation.observability_s3_buckets[each.key].arn}/*"
        ]
      }
    ]
  })
}

# Workflow 2: Ingress + API Gateway
module "ingress" {
  source = "../../modules/ingress"

  project_name         = var.project_name
  environment         = var.environment
  cluster_name        = module.foundation.cluster_name
  domain_name         = var.domain_name
  domain_filters      = [var.domain_name]
  letsencrypt_email   = var.letsencrypt_email
  cloudflare_email    = var.cloudflare_email
  cloudflare_api_token = var.cloudflare_api_token

  depends_on = [module.foundation]
}

# Workflow 3: LGTM Observability Stack
module "observability" {
  source = "../../modules/observability"

  project_name      = var.project_name
  environment      = var.environment
  cluster_name     = module.foundation.cluster_name
  domain_name      = var.domain_name
  aws_region       = var.aws_region

  # S3 buckets
  prometheus_s3_bucket = module.foundation.observability_s3_buckets["prometheus"].bucket
  loki_s3_bucket      = module.foundation.observability_s3_buckets["loki"].bucket
  tempo_s3_bucket     = module.foundation.observability_s3_buckets["tempo"].bucket

  # IRSA roles
  mimir_irsa_role_arn = module.observability_irsa_roles["mimir"].iam_role_arn
  loki_irsa_role_arn  = module.observability_irsa_roles["loki"].iam_role_arn
  tempo_irsa_role_arn = module.observability_irsa_roles["tempo"].iam_role_arn

  grafana_admin_password = var.grafana_admin_password

  depends_on = [module.foundation, module.ingress]
}

# Workflow 4: GitOps & CI/CD
module "gitops" {
  source = "../../modules/gitops"

  project_name        = var.project_name
  environment        = var.environment
  cluster_name       = module.foundation.cluster_name
  domain_name        = var.domain_name
  gitops_repo_url    = var.gitops_repo_url
  gitops_repo_branch = var.gitops_repo_branch

  depends_on = [module.foundation, module.ingress, module.observability]
}

# Workflow 5: Security Foundation
module "security" {
  source = "../../modules/security"

  project_name      = var.project_name
  environment      = var.environment
  cluster_name     = module.foundation.cluster_name
  slack_webhook_url = var.slack_webhook_url

  depends_on = [module.foundation, module.ingress, module.observability]
}

# Workflow 6: Service Mesh
module "service_mesh" {
  source = "../../modules/service-mesh"

  project_name = var.project_name
  environment  = var.environment
  cluster_name = module.foundation.cluster_name
  domain_name  = var.domain_name

  depends_on = [module.foundation, module.ingress, module.observability]
}

# Workflow 7: Data Services
module "data_services" {
  source = "../../modules/data-services"

  project_name = var.project_name
  environment  = var.environment
  cluster_name = module.foundation.cluster_name

  # PostgreSQL Configuration
  postgres_password           = var.postgres_password
  postgres_backup_bucket      = "${var.project_name}-${var.environment}-postgres-backup"
  postgres_backup_access_key  = var.postgres_backup_access_key
  postgres_backup_secret_key  = var.postgres_backup_secret_key

  depends_on = [module.foundation, module.ingress, module.observability]
}

# Install AWS Load Balancer Controller
resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = "1.6.2"
  namespace  = "kube-system"

  set {
    name  = "clusterName"
    value = module.foundation.cluster_name
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.foundation.aws_load_balancer_controller_role_arn
  }

  set {
    name  = "region"
    value = var.aws_region
  }

  set {
    name  = "vpcId"
    value = module.foundation.vpc_id
  }

  depends_on = [module.foundation]
}

# Install Cluster Autoscaler
resource "helm_release" "cluster_autoscaler" {
  name       = "cluster-autoscaler"
  repository = "https://kubernetes.github.io/autoscaler"
  chart      = "cluster-autoscaler"
  version    = "9.29.0"
  namespace  = "kube-system"

  set {
    name  = "autoDiscovery.clusterName"
    value = module.foundation.cluster_name
  }

  set {
    name  = "awsRegion"
    value = var.aws_region
  }

  set {
    name  = "rbac.serviceAccount.create"
    value = "true"
  }

  set {
    name  = "rbac.serviceAccount.name"
    value = "cluster-autoscaler"
  }

  set {
    name  = "rbac.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.foundation.cluster_autoscaler_role_arn
  }

  set {
    name  = "extraArgs.scale-down-delay-after-add"
    value = "10m"
  }

  set {
    name  = "extraArgs.scale-down-unneeded-time"
    value = "10m"
  }

  set {
    name  = "extraArgs.scale-down-utilization-threshold"
    value = "0.5"
  }

  depends_on = [module.foundation]
}