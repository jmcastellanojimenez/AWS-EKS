# NGINX Ingress Pattern Infrastructure
# This module provides minimal infrastructure for NGINX Ingress Controller

locals {
  common_tags = {
    Project     = "k8s-ingress-workshop"
    Environment = var.environment
    CreatedBy   = "terraform"
    Pattern     = "nginx"
    Purpose     = "nginx-ingress-demo"
  }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Get EKS cluster information
data "aws_eks_cluster" "main" {
  name = "eks-learning-lab-${var.environment}"
}

data "aws_iam_openid_connect_provider" "eks" {
  url = data.aws_eks_cluster.main.identity[0].oidc[0].issuer
}

# Get VPC information from EKS cluster
data "aws_vpc" "eks" {
  id = data.aws_eks_cluster.main.vpc_config[0].vpc_id
}

data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.eks.id]
  }
  
  filter {
    name   = "tag:Type"
    values = ["public"]
  }
}

data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.eks.id]
  }
  
  filter {
    name   = "tag:Type"
    values = ["private"]
  }
}

# IAM role for External-DNS (NGINX pattern specific)
resource "aws_iam_role" "external_dns" {
  name = "${var.environment}-nginx-external-dns-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Federated = data.aws_iam_openid_connect_provider.eks.arn
        }
        Condition = {
          StringEquals = {
            "${replace(data.aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub" = "system:serviceaccount:external-dns:external-dns"
            "${replace(data.aws_iam_openid_connect_provider.eks.url, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })
  
  tags = local.common_tags
}

# IAM policy for External-DNS Route53 access
resource "aws_iam_role_policy" "external_dns" {
  name = "${var.environment}-nginx-external-dns-policy"
  role = aws_iam_role.external_dns.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "route53:ChangeResourceRecordSets"
        ]
        Resource = [
          "arn:aws:route53:::hostedzone/${var.hosted_zone_id}"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "route53:ListHostedZones",
          "route53:ListResourceRecordSets",
          "route53:ListTagsForResource"
        ]
        Resource = "*"
      }
    ]
  })
}

# IAM role for cert-manager (NGINX pattern specific)
resource "aws_iam_role" "cert_manager" {
  name = "${var.environment}-nginx-cert-manager-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Federated = data.aws_iam_openid_connect_provider.eks.arn
        }
        Condition = {
          StringEquals = {
            "${replace(data.aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub" = "system:serviceaccount:cert-manager:cert-manager"
            "${replace(data.aws_iam_openid_connect_provider.eks.url, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })
  
  tags = local.common_tags
}

# IAM policy for cert-manager Route53 access
resource "aws_iam_role_policy" "cert_manager" {
  name = "${var.environment}-nginx-cert-manager-policy"
  role = aws_iam_role.cert_manager.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "route53:GetChange"
        ]
        Resource = [
          "arn:aws:route53:::change/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "route53:ChangeResourceRecordSets",
          "route53:ListResourceRecordSets"
        ]
        Resource = [
          "arn:aws:route53:::hostedzone/${var.hosted_zone_id}"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "route53:ListHostedZonesByName"
        ]
        Resource = "*"
      }
    ]
  })
}