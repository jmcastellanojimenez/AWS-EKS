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

# ArgoCD namespace
resource "kubernetes_namespace" "argocd" {
  metadata {
    name = var.namespace
    labels = {
      name = var.namespace
    }
  }
}

# ArgoCD IRSA role for accessing AWS services
resource "aws_iam_role" "argocd_role" {
  name = "${var.project_name}-${var.environment}-argocd-role"
  
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
            "${replace(var.oidc_provider_url, "https://", "")}:sub": "system:serviceaccount:${var.namespace}:argocd-application-controller"
            "${replace(var.oidc_provider_url, "https://", "")}:aud": "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = var.tags
}

# ArgoCD IAM policy for ECR access
resource "aws_iam_policy" "argocd_policy" {
  name        = "${var.project_name}-${var.environment}-argocd-policy"
  description = "Policy for ArgoCD to access ECR and other AWS services"
  
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
          "ecr:DescribeRepositories",
          "ecr:DescribeImages"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [
          "arn:aws:secretsmanager:${var.aws_region}:*:secret:argocd/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "argocd_policy_attachment" {
  policy_arn = aws_iam_policy.argocd_policy.arn
  role       = aws_iam_role.argocd_role.name
}

# ArgoCD Helm release
resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.argocd_version
  namespace        = kubernetes_namespace.argocd.metadata[0].name
  create_namespace = false
  timeout          = 600
  wait             = true

  values = [
    templatefile("${path.module}/values.yaml.tpl", {
      namespace           = var.namespace
      replica_count       = var.replica_count
      domain              = var.domain
      enable_tls          = var.enable_tls
      enable_notifications = var.enable_notifications
      slack_webhook       = var.slack_webhook_url
      aws_region          = var.aws_region
      role_arn            = aws_iam_role.argocd_role.arn
      enable_monitoring   = var.enable_monitoring
      storage_class       = var.storage_class
      storage_size        = var.storage_size
    })
  ]

  depends_on = [
    kubernetes_namespace.argocd,
    aws_iam_role_policy_attachment.argocd_policy_attachment
  ]
}

# ArgoCD admin password secret (if not using OIDC)
resource "kubernetes_secret" "argocd_admin_password" {
  count = var.admin_password != "" ? 1 : 0
  
  metadata {
    name      = "argocd-initial-admin-secret"
    namespace = kubernetes_namespace.argocd.metadata[0].name
    labels = {
      "app.kubernetes.io/name" = "argocd-initial-admin-secret"
      "app.kubernetes.io/part-of" = "argocd"
    }
  }
  
  data = {
    password = bcrypt(var.admin_password)
  }
  
  type = "Opaque"

  depends_on = [kubernetes_namespace.argocd]
}

# ArgoCD CLI access service account
resource "kubernetes_service_account" "argocd_cli" {
  metadata {
    name      = "argocd-cli"
    namespace = kubernetes_namespace.argocd.metadata[0].name
  }
}

resource "kubernetes_cluster_role_binding" "argocd_cli" {
  metadata {
    name = "argocd-cli-admin"
  }
  
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }
  
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.argocd_cli.metadata[0].name
    namespace = kubernetes_namespace.argocd.metadata[0].name
  }
}

# Repository credentials secret for private Git repos
resource "kubernetes_secret" "git_credentials" {
  count = var.git_token != "" ? 1 : 0
  
  metadata {
    name      = "git-credentials"
    namespace = kubernetes_namespace.argocd.metadata[0].name
    labels = {
      "argocd.argoproj.io/secret-type" = "repository"
    }
  }
  
  data = {
    type     = "git"
    url      = var.git_url
    username = var.git_username
    password = var.git_token
  }
  
  type = "Opaque"

  depends_on = [helm_release.argocd]
}
