# external-dns Terraform module
# Deploys external-dns for automatic DNS record management with Cloudflare
# Uses existing IRSA setup from Workflow 1

terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.16"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.8"
    }
  }
}

# external-dns namespace
resource "kubernetes_namespace" "external_dns" {
  metadata {
    name = "external-dns"
    labels = {
      name = "external-dns"
    }
  }
}

# Service Account for external-dns with IRSA
resource "kubernetes_service_account" "external_dns" {
  metadata {
    name      = "external-dns"
    namespace = kubernetes_namespace.external_dns.metadata[0].name
    annotations = var.service_account_role_arn != "" ? {
      "eks.amazonaws.com/role-arn" = var.service_account_role_arn
    } : {}
  }
}

# Cloudflare API token secret (when using Cloudflare)
resource "kubernetes_secret" "cloudflare_token" {
  count = var.dns_provider == "cloudflare" && var.cloudflare_api_token != "" ? 1 : 0

  metadata {
    name      = "cloudflare-token"
    namespace = kubernetes_namespace.external_dns.metadata[0].name
  }

  data = {
    token = var.cloudflare_api_token
  }

  type = "Opaque"
}

# external-dns Helm release
resource "helm_release" "external_dns" {
  name       = "external-dns"
  repository = "https://kubernetes-sigs.github.io/external-dns"
  chart      = "external-dns"
  version    = var.external_dns_version
  namespace  = kubernetes_namespace.external_dns.metadata[0].name

  values = [
    yamlencode({
      # Provider configuration
      provider = var.dns_provider
      
      # Domain filtering
      domainFilters = var.domain_filters
      
      # Resource sizing for t3.large nodes
      resources = {
        requests = {
          cpu    = "10m"
          memory = "32Mi"
        }
        limits = {
          cpu    = "100m"
          memory = "128Mi"
        }
      }

      # Service account
      serviceAccount = {
        create = false
        name   = kubernetes_service_account.external_dns.metadata[0].name
      }

      # Security context
      securityContext = {
        runAsNonRoot = true
        runAsUser    = 65534
        runAsGroup   = 65534
        fsGroup      = 65534
      }

      # Sources to monitor
      sources = var.sources

      # Cloudflare specific configuration
      env = var.dns_provider == "cloudflare" ? [
        {
          name = "CF_API_TOKEN"
          valueFrom = {
            secretKeyRef = {
              name = "cloudflare-token"
              key  = "token"
            }
          }
        }
      ] : []

      # Route53 configuration for AWS
      aws = var.dns_provider == "aws" ? {
        region          = var.aws_region
        zoneType        = var.aws_zone_type
        assumeRoleArn   = var.service_account_role_arn
      } : {}

      # Sync policy
      policy = var.sync_policy

      # Registry for tracking DNS records
      registry = "txt"
      txtPrefix = var.txt_prefix
      txtOwnerId = var.txt_owner_id

      # Log configuration
      logLevel = var.log_level
      logFormat = "text"

      # Interval between DNS updates
      interval = var.sync_interval

      # Node selection
      nodeSelector = {
        "kubernetes.io/arch" = "amd64"
      }

      # Tolerations for spot instances
      tolerations = [
        {
          key      = "node.kubernetes.io/spot"
          operator = "Exists"
          effect   = "NoSchedule"
        }
      ]

      # Prometheus monitoring
      metrics = {
        enabled = var.enable_monitoring
        serviceMonitor = {
          enabled = var.enable_monitoring
        }
      }

      # Replica count for high availability
      replicaCount = var.replica_count

      # Pod disruption budget
      podDisruptionBudget = {
        enabled    = var.replica_count > 1
        minAvailable = 1
      }
    })
  ]

  depends_on = [
    kubernetes_namespace.external_dns,
    kubernetes_service_account.external_dns,
    kubernetes_secret.cloudflare_token
  ]
}

# Wait for external-dns to be ready
resource "kubernetes_deployment" "external_dns_ready" {
  count = 1

  wait_for_rollout = true
  
  metadata {
    name      = "external-dns-readiness-check"
    namespace = kubernetes_namespace.external_dns.metadata[0].name
  }

  spec {
    replicas = 0  # This is just a readiness check

    selector {
      match_labels = {
        app = "external-dns-readiness"
      }
    }

    template {
      metadata {
        labels = {
          app = "external-dns-readiness"
        }
      }

      spec {
        container {
          name  = "readiness"
          image = "alpine:3.18"
          command = ["sleep", "1"]
        }
      }
    }
  }

  depends_on = [helm_release.external_dns]

  timeouts {
    create = "3m"
    update = "3m"
  }
}