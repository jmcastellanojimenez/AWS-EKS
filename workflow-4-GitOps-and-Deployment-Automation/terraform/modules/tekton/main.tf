terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.11"
    }
  }
}

# Tekton namespace
resource "kubernetes_namespace" "tekton_pipelines" {
  metadata {
    name = var.namespace
    labels = {
      name = var.namespace
      "pod-security.kubernetes.io/enforce" = "baseline"
      "pod-security.kubernetes.io/warn"    = "baseline"
      "pod-security.kubernetes.io/audit"   = "baseline"
    }
  }
}

# Tekton IRSA role for accessing AWS services
resource "aws_iam_role" "tekton_role" {
  name = "${var.project_name}-${var.environment}-tekton-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = var.oidc_provider_arn
        }
        Condition = {
          StringEquals = {
            "${replace(var.oidc_provider_url, "https://", "")}:sub": "system:serviceaccount:${var.namespace}:tekton-build-sa"
            "${replace(var.oidc_provider_url, "https://", "")}:aud": "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = var.tags
}

# Tekton IAM policy for ECR, S3, and Secrets Manager access
resource "aws_iam_policy" "tekton_policy" {
  name        = "${var.project_name}-${var.environment}-tekton-policy"
  description = "Policy for Tekton to access ECR, S3, and other AWS services"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage",
          "ecr:CreateRepository",
          "ecr:DescribeRepositories",
          "ecr:DescribeImages",
          "ecr:BatchDeleteImage"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.artifacts_bucket}",
          "arn:aws:s3:::${var.artifacts_bucket}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [
          "arn:aws:secretsmanager:${var.aws_region}:*:secret:tekton/*",
          "arn:aws:secretsmanager:${var.aws_region}:*:secret:github/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "tekton_policy_attachment" {
  policy_arn = aws_iam_policy.tekton_policy.arn
  role       = aws_iam_role.tekton_role.name
}

# S3 bucket for build artifacts and cache
resource "aws_s3_bucket" "tekton_artifacts" {
  count  = var.create_artifacts_bucket ? 1 : 0
  bucket = var.artifacts_bucket

  tags = var.tags
}

resource "aws_s3_bucket_versioning" "tekton_artifacts_versioning" {
  count  = var.create_artifacts_bucket ? 1 : 0
  bucket = aws_s3_bucket.tekton_artifacts[0].id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tekton_artifacts_encryption" {
  count  = var.create_artifacts_bucket ? 1 : 0
  bucket = aws_s3_bucket.tekton_artifacts[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Tekton Pipelines installation
resource "helm_release" "tekton_pipelines" {
  name             = "tekton-pipelines"
  repository       = "https://cdfoundation.github.io/tekton-helm-chart"
  chart            = "tekton-pipelines"
  version          = var.tekton_version
  namespace        = kubernetes_namespace.tekton_pipelines.metadata[0].name
  create_namespace = false
  timeout          = 600
  wait             = true

  values = [
    templatefile("${path.module}/pipelines-values.yaml.tpl", {
      namespace         = var.namespace
      enable_monitoring = var.enable_monitoring
      storage_class     = var.storage_class
    })
  ]

  depends_on = [kubernetes_namespace.tekton_pipelines]
}

# Tekton Triggers installation
resource "helm_release" "tekton_triggers" {
  name             = "tekton-triggers"
  repository       = "https://cdfoundation.github.io/tekton-helm-chart"
  chart            = "tekton-triggers"
  version          = var.tekton_triggers_version
  namespace        = kubernetes_namespace.tekton_pipelines.metadata[0].name
  create_namespace = false
  timeout          = 600
  wait             = true

  values = [
    templatefile("${path.module}/triggers-values.yaml.tpl", {
      namespace         = var.namespace
      enable_monitoring = var.enable_monitoring
    })
  ]

  depends_on = [helm_release.tekton_pipelines]
}

# Tekton Dashboard
resource "helm_release" "tekton_dashboard" {
  name             = "tekton-dashboard"
  repository       = "https://cdfoundation.github.io/tekton-helm-chart"
  chart            = "tekton-dashboard"
  version          = var.tekton_dashboard_version
  namespace        = kubernetes_namespace.tekton_pipelines.metadata[0].name
  create_namespace = false
  timeout          = 600
  wait             = true

  values = [
    templatefile("${path.module}/dashboard-values.yaml.tpl", {
      namespace     = var.namespace
      domain        = var.dashboard_domain
      enable_tls    = var.enable_tls
    })
  ]

  depends_on = [helm_release.tekton_pipelines]
}

# Service account for Tekton builds with IRSA
resource "kubernetes_service_account" "tekton_build_sa" {
  metadata {
    name      = "tekton-build-sa"
    namespace = kubernetes_namespace.tekton_pipelines.metadata[0].name
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.tekton_role.arn
    }
  }

  depends_on = [kubernetes_namespace.tekton_pipelines]
}

# Cluster role for Tekton build service account
resource "kubernetes_cluster_role" "tekton_build_role" {
  metadata {
    name = "tekton-build-role"
  }

  rule {
    api_groups = [""]
    resources  = ["pods", "services", "configmaps", "secrets"]
    verbs      = ["get", "list", "create", "update", "patch", "delete"]
  }

  rule {
    api_groups = ["apps"]
    resources  = ["deployments", "replicasets"]
    verbs      = ["get", "list", "create", "update", "patch", "delete"]
  }

  rule {
    api_groups = ["tekton.dev"]
    resources  = ["tasks", "taskruns", "pipelines", "pipelineruns"]
    verbs      = ["get", "list", "create", "update", "patch", "delete"]
  }
}

resource "kubernetes_cluster_role_binding" "tekton_build_binding" {
  metadata {
    name = "tekton-build-binding"
  }
  
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.tekton_build_role.metadata[0].name
  }
  
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.tekton_build_sa.metadata[0].name
    namespace = kubernetes_namespace.tekton_pipelines.metadata[0].name
  }
}

# Docker config secret for private registries
resource "kubernetes_secret" "docker_config" {
  count = var.docker_registry_secret != "" ? 1 : 0
  
  metadata {
    name      = "docker-config"
    namespace = kubernetes_namespace.tekton_pipelines.metadata[0].name
  }
  
  data = {
    ".dockerconfigjson" = var.docker_registry_secret
  }
  
  type = "kubernetes.io/dockerconfigjson"

  depends_on = [kubernetes_namespace.tekton_pipelines]
}

# GitHub webhook secret
resource "kubernetes_secret" "github_webhook_secret" {
  count = var.github_webhook_secret != "" ? 1 : 0
  
  metadata {
    name      = "github-webhook-secret"
    namespace = kubernetes_namespace.tekton_pipelines.metadata[0].name
  }
  
  data = {
    secretToken = var.github_webhook_secret
  }
  
  type = "Opaque"

  depends_on = [kubernetes_namespace.tekton_pipelines]
}

# GitHub token secret for API access
resource "kubernetes_secret" "github_token_secret" {
  count = var.github_token != "" ? 1 : 0
  
  metadata {
    name      = "github-token-secret"
    namespace = kubernetes_namespace.tekton_pipelines.metadata[0].name
  }
  
  data = {
    token = var.github_token
  }
  
  type = "Opaque"

  depends_on = [kubernetes_namespace.tekton_pipelines]
}
