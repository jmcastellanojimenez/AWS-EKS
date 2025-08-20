# Ingress + API Gateway Module
terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

locals {
  common_labels = {
    "app.kubernetes.io/managed-by" = "terraform"
    "app.kubernetes.io/part-of"    = var.project_name
  }
}

# Namespace for ingress components
resource "kubernetes_namespace" "ingress" {
  metadata {
    name = "ingress-system"
    labels = merge(local.common_labels, {
      "app.kubernetes.io/component" = "ingress"
    })
  }
}

# cert-manager
resource "helm_release" "cert_manager" {
  name       = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  version    = var.cert_manager_version
  namespace  = kubernetes_namespace.ingress.metadata[0].name

  set {
    name  = "installCRDs"
    value = "true"
  }

  set {
    name  = "global.leaderElection.namespace"
    value = kubernetes_namespace.ingress.metadata[0].name
  }

  set {
    name  = "prometheus.enabled"
    value = "false"
  }

  set {
    name  = "prometheus.servicemonitor.enabled"
    value = "false"
  }

  values = [
    yamlencode({
      resources = {
        requests = {
          cpu    = "50m"
          memory = "64Mi"
        }
        limits = {
          cpu    = "200m"
          memory = "256Mi"
        }
      }
      webhook = {
        resources = {
          requests = {
            cpu    = "25m"
            memory = "32Mi"
          }
          limits = {
            cpu    = "100m"
            memory = "128Mi"
          }
        }
      }
      cainjector = {
        resources = {
          requests = {
            cpu    = "50m"
            memory = "64Mi"
          }
          limits = {
            cpu    = "200m"
            memory = "256Mi"
          }
        }
      }
    })
  ]

  depends_on = [kubernetes_namespace.ingress]
}

# Wait for cert-manager CRDs to be available
resource "time_sleep" "wait_for_cert_manager_crds" {
  depends_on      = [helm_release.cert_manager]
  create_duration = "30s"
}

# ClusterIssuer for Let's Encrypt
resource "null_resource" "letsencrypt_issuer" {
  triggers = {
    cluster_name = var.cluster_name
    aws_region   = var.aws_region
  }

  provisioner "local-exec" {
    command = <<-EOT
      # Configure kubectl to use the EKS cluster
      aws eks update-kubeconfig --region ${self.triggers.aws_region} --name ${self.triggers.cluster_name}
      
      # Apply the ClusterIssuer with validation disabled to avoid API issues
      cat <<EOF | kubectl apply --validate=false -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: ${var.letsencrypt_email}
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - dns01:
        cloudflare:
          email: ${var.cloudflare_email}
          apiTokenSecretRef:
            name: cloudflare-api-token
            key: api-token
EOF
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      aws eks update-kubeconfig --region ${self.triggers.aws_region} --name ${self.triggers.cluster_name} 2>/dev/null || true
      kubectl delete clusterissuer letsencrypt-prod --ignore-not-found=true 2>/dev/null || true
    EOT
  }

  depends_on = [time_sleep.wait_for_cert_manager_crds]
}

# Cloudflare API token secret
resource "kubernetes_secret" "cloudflare_api_token" {
  metadata {
    name      = "cloudflare-api-token"
    namespace = kubernetes_namespace.ingress.metadata[0].name
  }

  data = {
    api-token = var.cloudflare_api_token
  }

  type = "Opaque"
}

# external-dns - Temporarily disabled due to timeout issues
# TODO: Re-enable once external DNS configuration is resolved
/*
resource "helm_release" "external_dns" {
  name       = "external-dns"
  repository = "https://kubernetes-sigs.github.io/external-dns/"
  chart      = "external-dns"
  version    = var.external_dns_version
  namespace  = kubernetes_namespace.ingress.metadata[0].name

  # Add timeout and wait configuration
  wait             = true
  timeout          = 300
  cleanup_on_fail  = true
  atomic           = true
  create_namespace = false

  values = [
    yamlencode({
      provider = "cloudflare"
      env = [
        {
          name = "CF_API_TOKEN"
          valueFrom = {
            secretKeyRef = {
              name = kubernetes_secret.cloudflare_api_token.metadata[0].name
              key  = "api-token"
            }
          }
        }
      ]
      domainFilters = var.domain_filters
      policy        = "sync"
      registry      = "txt"
      txtOwnerId    = var.cluster_name

      resources = {
        requests = {
          cpu    = "25m"
          memory = "32Mi"
        }
        limits = {
          cpu    = "100m"
          memory = "128Mi"
        }
      }

      serviceMonitor = {
        enabled = false
      }

      metrics = {
        enabled = true
      }

      # Add more robust settings for external-dns
      interval = "1m"
      logLevel = "info"

      # Handle DNS zones more gracefully
      ignoreHostnameAnnotation = false
    })
  ]

  depends_on = [kubernetes_secret.cloudflare_api_token]
}
*/

# Two-phase approach: Install CRDs first, then the workload
# Phase 1: Install only CRDs
resource "helm_release" "ambassador_crds" {
  name       = "ambassador-crds"
  repository = "https://app.getambassador.io"
  chart      = "emissary-ingress"
  version    = var.ambassador_version
  namespace  = kubernetes_namespace.ingress.metadata[0].name

  # Install only CRDs, disable all workloads
  skip_crds        = false
  wait             = true
  timeout          = 300
  cleanup_on_fail  = true
  atomic           = true
  create_namespace = false

  values = [
    yamlencode({
      # Disable ALL workload components - only install CRDs
      replicaCount = 0
      
      # Completely disable the main deployment
      deployment = {
        enabled = false
      }
      
      # Disable service creation
      service = {
        create = false
      }
      
      # Disable all additional components
      rbac = {
        create = false
      }
      
      serviceAccount = {
        create = false
      }
      
      # Disable all Ambassador features
      agent = {
        enabled = false
      }
      
      enableAES = false
      
      # Disable all automatic resource creation
      createDefaultListeners  = false
      createDevPortalMappings = false
      createDefaultModules    = false
      createDefaultHosts      = false
      createDefaultMapping    = false
      
      emissaryConfig = {
        create = false
      }
      
      # Disable monitoring
      serviceMonitor = {
        enabled = false
      }
      
      prometheusExporter = {
        enabled = false
      }
    })
  ]

  depends_on = [kubernetes_namespace.ingress]
}

# Phase 2: Install the actual Ambassador workload after CRDs are ready
resource "helm_release" "ambassador" {
  name       = "ambassador"
  repository = "https://app.getambassador.io"
  chart      = "emissary-ingress"
  version    = var.ambassador_version
  namespace  = kubernetes_namespace.ingress.metadata[0].name

  # Skip CRDs since they're already installed
  skip_crds        = true
  wait             = true
  timeout          = 600
  cleanup_on_fail  = true
  atomic           = true
  create_namespace = false

  values = [
    yamlencode({
      replicaCount = var.ambassador_replica_count

      # Aggressive approach to disable ALL default resource creation
      agent = {
        enabled = false
      }

      # Disable all Ambassador Edge Stack features
      enableAES = false

      # Disable all automatic configuration creation
      createDefaultListeners  = false
      createDevPortalMappings = false
      createDefaultModules    = false
      createDefaultHosts      = false
      createDefaultMapping    = false

      # Disable specific components that might create custom resources
      emissaryConfig = {
        create = false
      }

      # Force minimal installation - just the core workload
      image = {
        repository = "docker.io/datawire/emissary"
      }

      # Additional safety measures
      deploymentStrategy = {
        type = "RollingUpdate"
      }

      service = {
        type = "LoadBalancer"
        annotations = {
          "service.beta.kubernetes.io/aws-load-balancer-type"                              = "nlb"
          "service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled" = "true"
          "service.beta.kubernetes.io/aws-load-balancer-backend-protocol"                  = "tcp"
        }
      }

      env = {
        AMBASSADOR_NAMESPACE = kubernetes_namespace.ingress.metadata[0].name
      }

      resources = {
        requests = {
          cpu    = "200m"
          memory = "256Mi"
        }
        limits = {
          cpu    = "500m"
          memory = "512Mi"
        }
      }

      autoscaling = {
        enabled                        = true
        minReplicas                    = var.ambassador_replica_count
        maxReplicas                    = var.ambassador_max_replicas
        targetCPUUtilizationPercentage = 70
      }

      podDisruptionBudget = {
        enabled      = true
        minAvailable = 1
      }

      serviceMonitor = {
        enabled = false
      }

      prometheusExporter = {
        enabled = false
      }
    })
  ]

  depends_on = [helm_release.ambassador_crds]
}

# Wait for Ambassador CRDs to be available
resource "time_sleep" "wait_for_ambassador_crds" {
  depends_on      = [helm_release.ambassador_crds]
  create_duration = "30s"
}

# Wait for Ambassador CRDs to be ready
resource "null_resource" "wait_for_ambassador_crd_ready" {
  triggers = {
    cluster_name = var.cluster_name
    aws_region   = var.aws_region
  }

  provisioner "local-exec" {
    command = <<-EOT
      # Configure kubectl to use the EKS cluster
      aws eks update-kubeconfig --region ${self.triggers.aws_region} --name ${self.triggers.cluster_name}
      
      # Wait for Ambassador CRDs to be available
      echo "Waiting for Ambassador CRDs to be available..."
      for i in {1..30}; do
        if kubectl get crd modules.getambassador.io hosts.getambassador.io >/dev/null 2>&1; then
          echo "Ambassador CRDs are now available"
          break
        fi
        echo "Attempt $i/30: Waiting for Ambassador CRDs..."
        sleep 10
      done
      
      # Final verification
      kubectl get crd modules.getambassador.io hosts.getambassador.io
    EOT
  }

  depends_on = [time_sleep.wait_for_ambassador_crds]
}

# Ambassador Module and Mappings
resource "null_resource" "ambassador_module" {
  triggers = {
    cluster_name = var.cluster_name
    aws_region   = var.aws_region
  }

  provisioner "local-exec" {
    command = <<-EOT
      # Configure kubectl to use the EKS cluster
      aws eks update-kubeconfig --region ${self.triggers.aws_region} --name ${self.triggers.cluster_name}
      
      # Apply the Module with validation disabled to avoid API issues
      cat <<EOF | kubectl apply --validate=false -f -
apiVersion: getambassador.io/v3alpha1
kind: Module
metadata:
  name: ambassador
  namespace: ingress-system
spec:
  config:
    diagnostics:
      enabled: true
    lua_scripts: []
    use_proxy_proto: false
    use_remote_address: true
    xff_num_trusted_hops: 1
    server_name: ${var.domain_name}
    enable_grpc_http11_bridge: false
    enable_grpc_web: false
    proper_case: false
    merge_slashes: false
    reject_requests_with_escaped_slashes: false
EOF
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      aws eks update-kubeconfig --region ${self.triggers.aws_region} --name ${self.triggers.cluster_name} 2>/dev/null || true
      kubectl delete module ambassador -n ingress-system --ignore-not-found=true 2>/dev/null || true
    EOT
  }

  depends_on = [null_resource.wait_for_ambassador_crd_ready]
}

# Default Ambassador Host
resource "null_resource" "ambassador_host" {
  triggers = {
    cluster_name = var.cluster_name
    aws_region   = var.aws_region
  }

  provisioner "local-exec" {
    command = <<-EOT
      # Configure kubectl to use the EKS cluster
      aws eks update-kubeconfig --region ${self.triggers.aws_region} --name ${self.triggers.cluster_name}
      
      # Apply the Host with validation disabled to avoid API issues
      cat <<EOF | kubectl apply --validate=false -f -
apiVersion: getambassador.io/v3alpha1
kind: Host
metadata:
  name: default-host
  namespace: ingress-system
spec:
  hostname: ${var.domain_name}
  acmeProvider:
    authority: https://acme-v02.api.letsencrypt.org/directory
    email: ${var.letsencrypt_email}
  tlsSecret:
    name: ambassador-certs
EOF
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      aws eks update-kubeconfig --region ${self.triggers.aws_region} --name ${self.triggers.cluster_name} 2>/dev/null || true
      kubectl delete host default-host -n ingress-system --ignore-not-found=true 2>/dev/null || true
    EOT
  }

  depends_on = [null_resource.wait_for_ambassador_crd_ready, time_sleep.wait_for_cert_manager_crds]
}