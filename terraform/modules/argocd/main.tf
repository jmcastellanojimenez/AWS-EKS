# ArgoCD Terraform module
# Deploys ArgoCD GitOps platform with production-ready configuration
# Integrates with Ambassador ingress and supports IRSA for AWS services

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
    bcrypt = {
      source  = "viktorradnai/bcrypt"
      version = ">= 0.1.2"
    }
  }
}

# Generate bcrypt hash for admin password if provided
resource "bcrypt_hash" "admin_password" {
  count     = var.admin_password != "" ? 1 : 0
  cleartext = var.admin_password
  cost      = 10
}

# ArgoCD namespace
resource "kubernetes_namespace" "argocd" {
  metadata {
    name = var.namespace
    labels = merge({
      name                                 = var.namespace
      "app.kubernetes.io/name"            = "argocd"
      "app.kubernetes.io/part-of"         = var.project_name
      "app.kubernetes.io/managed-by"      = "terraform"
      "environment"                       = var.environment
    }, var.additional_labels)
    
    annotations = var.additional_annotations
  }
}

# ArgoCD configuration secret
resource "kubernetes_secret" "argocd_secret" {
  metadata {
    name      = "argocd-secret"
    namespace = kubernetes_namespace.argocd.metadata[0].name
    labels = {
      "app.kubernetes.io/name"       = "argocd-secret"
      "app.kubernetes.io/part-of"    = "argocd"
    }
  }

  data = {
    # Admin password (bcrypt hashed)
    "admin.password" = var.admin_password != "" ? bcrypt_hash.admin_password[0].id : ""
    
    # Server signature key for JWT tokens
    "server.secretkey" = base64encode(random_password.server_secret.result)
  }

  type = "Opaque"
}

# Generate random server secret key
resource "random_password" "server_secret" {
  length  = 32
  special = true
}

# Repository credentials secrets
resource "kubernetes_secret" "repo_credentials" {
  count = length(var.repository_credentials)

  metadata {
    name      = "repo-${count.index}"
    namespace = kubernetes_namespace.argocd.metadata[0].name
    labels = {
      "argocd.argoproj.io/secret-type" = "repository"
    }
  }

  data = {
    type     = var.repository_credentials[count.index].ssh_key != "" ? "git" : "git"
    url      = var.repository_credentials[count.index].url
    username = var.repository_credentials[count.index].username
    password = var.repository_credentials[count.index].password
    sshPrivateKey = var.repository_credentials[count.index].ssh_key
  }

  type = "Opaque"
}

# ArgoCD configuration ConfigMap
resource "kubernetes_config_map" "argocd_cm" {
  metadata {
    name      = "argocd-cm"
    namespace = kubernetes_namespace.argocd.metadata[0].name
    labels = {
      "app.kubernetes.io/name"    = "argocd-cm"
      "app.kubernetes.io/part-of" = "argocd"
    }
  }

  data = {
    # Server configuration
    "url" = var.server_config.url != "" ? var.server_config.url : (var.hostname != "" ? "https://${var.hostname}" : "")
    "application.instanceLabelKey" = "argocd.argoproj.io/instance"
    
    # OIDC configuration
    "oidc.config" = var.enable_dex && var.dex_config.issuer_url != "" ? yamlencode({
      name         = "OIDC"
      issuer       = var.dex_config.issuer_url
      clientId     = var.dex_config.client_id
      clientSecret = var.dex_config.client_secret
      requestedScopes = ["openid", "profile", "email", "groups"]
    }) : ""
    
    # Resource customizations
    "resource.customizations" = var.resource_customizations
    
    # Repository server timeout
    "timeout.reconciliation" = var.controller_config.app_resync_period
    
    # Enable gRPC-Web
    "server.grpc.web" = tostring(var.server_config.grpc_web)
    
    # Server configuration
    "server.insecure" = tostring(var.server_config.insecure)
  }
}

# ArgoCD RBAC configuration
resource "kubernetes_config_map" "argocd_rbac_cm" {
  count = var.rbac_config != "" ? 1 : 0

  metadata {
    name      = "argocd-rbac-cm"
    namespace = kubernetes_namespace.argocd.metadata[0].name
    labels = {
      "app.kubernetes.io/name"    = "argocd-rbac-cm"
      "app.kubernetes.io/part-of" = "argocd"
    }
  }

  data = {
    "policy.default" = "role:readonly"
    "policy.csv"     = var.rbac_config
  }
}

# ArgoCD notifications configuration
resource "kubernetes_config_map" "argocd_notifications_cm" {
  count = var.enable_notifications ? 1 : 0

  metadata {
    name      = "argocd-notifications-cm"
    namespace = kubernetes_namespace.argocd.metadata[0].name
    labels = {
      "app.kubernetes.io/name"    = "argocd-notifications-cm"
      "app.kubernetes.io/part-of" = "argocd"
    }
  }

  data = {
    "config.yaml" = yamlencode({
      triggers = {
        "on-deployed" = [
          {
            when = "app.status.operationState.phase in ['Succeeded'] and app.status.health.status == 'Healthy'"
            send = ["app-deployed"]
          }
        ]
        "on-health-degraded" = [
          {
            when = "app.status.health.status == 'Degraded'"
            send = ["app-health-degraded"]
          }
        ]
        "on-sync-failed" = [
          {
            when = "app.status.operationState.phase in ['Error', 'Failed']"
            send = ["app-sync-failed"]
          }
        ]
      }
      
      templates = {
        "app-deployed" = {
          message = "Application {{.app.metadata.name}} is now running new version."
          slack = {
            attachments = jsonencode([{
              title      = "{{.app.metadata.name}}"
              title_link = "{{.context.argocdUrl}}/applications/{{.app.metadata.name}}"
              color      = "good"
              fields = [{
                title = "Sync Status"
                value = "{{.app.status.sync.status}}"
                short = true
              }, {
                title = "Repository"
                value = "{{.app.spec.source.repoURL}}"
                short = true
              }]
            }])
          }
        }
        
        "app-health-degraded" = {
          message = "Application {{.app.metadata.name}} has degraded health status."
          slack = {
            attachments = jsonencode([{
              title      = "{{.app.metadata.name}}"
              title_link = "{{.context.argocdUrl}}/applications/{{.app.metadata.name}}"
              color      = "danger"
              fields = [{
                title = "Health Status"
                value = "{{.app.status.health.status}}"
                short = true
              }, {
                title = "Repository"
                value = "{{.app.spec.source.repoURL}}"
                short = true
              }]
            }])
          }
        }
        
        "app-sync-failed" = {
          message = "Application {{.app.metadata.name}} sync failed."
          slack = {
            attachments = jsonencode([{
              title      = "{{.app.metadata.name}}"
              title_link = "{{.context.argocdUrl}}/applications/{{.app.metadata.name}}"
              color      = "danger"
              fields = [{
                title = "Sync Status"
                value = "{{.app.status.sync.status}}"
                short = true
              }, {
                title = "Operation"
                value = "{{.app.status.operationState.operation.sync.revision}}"
                short = true
              }]
            }])
          }
        }
      }
      
      services = var.notification_config.slack_token != "" ? {
        slack = {
          token = var.notification_config.slack_token
        }
      } : {}
    })
  }
}

# ArgoCD Helm release
resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.argocd_version
  namespace  = kubernetes_namespace.argocd.metadata[0].name

  values = [
    yamlencode({
      # Global configuration
      global = {
        image = {
          tag = "v2.8.7"
        }
        logging = {
          level = var.log_level
        }
        networkPolicy = {
          create = true
        }
      }

      # Server configuration
      server = {
        name = "argocd-server"
        
        replicas = var.replica_count
        
        autoscaling = {
          enabled     = var.replica_count > 1
          minReplicas = var.replica_count
          maxReplicas = var.replica_count * 2
          targetCPUUtilizationPercentage = 70
        }
        
        resources = {
          requests = {
            cpu    = "100m"
            memory = "128Mi"
          }
          limits = {
            cpu    = "500m"
            memory = "512Mi"
          }
        }
        
        serviceAccount = {
          create = true
          name   = "argocd-server"
          annotations = var.service_account_annotations
        }
        
        config = {
          "application.instanceLabelKey" = "argocd.argoproj.io/instance"
          "server.rbac.log.enforce.enable" = "false"
          "exec.enabled" = "true"
          "admin.enabled" = "true"
          "timeout.hard.reconciliation" = "0s"
          "timeout.reconciliation" = var.controller_config.app_resync_period
          "oidc.config" = var.enable_dex && var.dex_config.issuer_url != "" ? yamlencode({
            name         = "OIDC"
            issuer       = var.dex_config.issuer_url
            clientId     = var.dex_config.client_id
            clientSecret = var.dex_config.client_secret
            requestedScopes = ["openid", "profile", "email", "groups"]
          }) : ""
        }
        
        rbacConfig = var.rbac_config != "" ? {
          "policy.default" = "role:readonly"
          "policy.csv"     = var.rbac_config
        } : {}
        
        ingress = var.enable_ingress ? {
          enabled = true
          ingressClassName = var.ingress_class
          annotations = {
            "getambassador.io/config" = yamlencode({
              apiVersion = "getambassador.io/v3alpha1"
              kind       = "Mapping"
              name       = "argocd-server"
              prefix     = "/"
              service    = "argocd-server:80"
              host       = var.hostname
              timeout_ms = 30000
            })
          }
          hosts = var.hostname != "" ? [var.hostname] : []
          tls = var.enable_tls && var.hostname != "" ? [{
            secretName = "argocd-server-tls"
            hosts      = [var.hostname]
          }] : []
        } : {}
        
        metrics = {
          enabled = var.enable_monitoring
          serviceMonitor = {
            enabled = var.enable_monitoring
          }
        }
        
        affinity = {
          podAntiAffinity = {
            preferredDuringSchedulingIgnoredDuringExecution = [{
              weight = 100
              podAffinityTerm = {
                labelSelector = {
                  matchLabels = {
                    "app.kubernetes.io/name" = "argocd-server"
                  }
                }
                topologyKey = "kubernetes.io/hostname"
              }
            }]
          }
        }
      }

      # Application Controller configuration
      controller = {
        name = "argocd-application-controller"
        
        replicas = 1
        
        resources = {
          requests = {
            cpu    = "250m"
            memory = "512Mi"
          }
          limits = {
            cpu    = "2000m"
            memory = "2Gi"
          }
        }
        
        serviceAccount = {
          create = true
          name   = "argocd-application-controller"
          annotations = var.service_account_annotations
        }
        
        args = {
          operationProcessors    = var.controller_config.operation_processors
          statusProcessors      = var.controller_config.status_processors
          appResyncPeriod       = var.controller_config.app_resync_period
          repoServerTimeoutSeconds = parseint(replace(var.controller_config.repo_server_timeout, "s", ""), 10)
        }
        
        metrics = {
          enabled = var.enable_monitoring
          serviceMonitor = {
            enabled = var.enable_monitoring
          }
        }
      }

      # Repository Server configuration
      repoServer = {
        name = "argocd-repo-server"
        
        replicas = var.replica_count
        
        autoscaling = {
          enabled     = var.replica_count > 1
          minReplicas = var.replica_count
          maxReplicas = var.replica_count * 2
          targetCPUUtilizationPercentage = 70
        }
        
        resources = {
          requests = {
            cpu    = "100m"
            memory = "256Mi"
          }
          limits = {
            cpu    = "1000m"
            memory = "1Gi"
          }
        }
        
        serviceAccount = {
          create = true
          name   = "argocd-repo-server"
          annotations = var.service_account_annotations
        }
        
        env = [
          {
            name  = "ARGOCD_EXEC_TIMEOUT"
            value = var.repo_server_config.timeout
          }
        ]
        
        metrics = {
          enabled = var.enable_monitoring
          serviceMonitor = {
            enabled = var.enable_monitoring
          }
        }
        
        affinity = {
          podAntiAffinity = {
            preferredDuringSchedulingIgnoredDuringExecution = [{
              weight = 100
              podAffinityTerm = {
                labelSelector = {
                  matchLabels = {
                    "app.kubernetes.io/name" = "argocd-repo-server"
                  }
                }
                topologyKey = "kubernetes.io/hostname"
              }
            }]
          }
        }
      }

      # ApplicationSet Controller
      applicationSet = {
        enabled = var.enable_applicationset
        
        resources = {
          requests = {
            cpu    = "100m"
            memory = "128Mi"
          }
          limits = {
            cpu    = "500m"
            memory = "512Mi"
          }
        }
        
        serviceAccount = {
          create = true
          name   = "argocd-applicationset-controller"
          annotations = var.service_account_annotations
        }
        
        metrics = {
          enabled = var.enable_monitoring
          serviceMonitor = {
            enabled = var.enable_monitoring
          }
        }
      }

      # Notifications Controller
      notifications = {
        enabled = var.enable_notifications
        
        resources = {
          requests = {
            cpu    = "100m"
            memory = "128Mi"
          }
          limits = {
            cpu    = "500m"
            memory = "512Mi"
          }
        }
        
        serviceAccount = {
          create = true
          name   = "argocd-notifications-controller"
          annotations = var.service_account_annotations
        }
        
        metrics = {
          enabled = var.enable_monitoring
          serviceMonitor = {
            enabled = var.enable_monitoring
          }
        }
      }

      # Redis configuration
      redis = {
        enabled = true
        
        resources = {
          requests = {
            cpu    = "100m"
            memory = "128Mi"
          }
          limits = {
            cpu    = "200m"
            memory = "256Mi"
          }
        }
        
        persistence = {
          enabled      = true
          storageClass = var.storage_class
          size         = "8Gi"
        }
      }

      # Redis HA configuration
      redis-ha = {
        enabled = var.redis_ha_enabled
        
        persistentVolume = {
          enabled      = true
          storageClass = var.storage_class
          size         = var.storage_size
        }
        
        redis = {
          resources = {
            requests = {
              cpu    = "100m"
              memory = "200Mi"
            }
            limits = {
              cpu    = "300m"
              memory = "400Mi"
            }
          }
        }
        
        sentinel = {
          resources = {
            requests = {
              cpu    = "100m"
              memory = "200Mi"
            }
            limits = {
              cpu    = "300m"
              memory = "400Mi"
            }
          }
        }
      }

      # Dex configuration (OIDC)
      dex = {
        enabled = var.enable_dex
        
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
        
        serviceAccount = {
          create = true
          name   = "argocd-dex-server"
        }
      }

      # RBAC
      rbac = {
        create = true
      }
    })
  ]

  depends_on = [
    kubernetes_namespace.argocd,
    kubernetes_secret.argocd_secret,
    kubernetes_config_map.argocd_cm
  ]

  wait          = true
  wait_for_jobs = true
  timeout       = 600  # 10 minutes
}

# ArgoCD Application Projects
resource "kubernetes_manifest" "application_projects" {
  count = length(var.application_projects)

  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "AppProject"
    metadata = {
      name      = var.application_projects[count.index].name
      namespace = kubernetes_namespace.argocd.metadata[0].name
    }
    spec = {
      description = var.application_projects[count.index].description
      
      sourceRepos = var.application_projects[count.index].source_repos
      
      destinations = var.application_projects[count.index].destinations
      
      clusterResourceWhitelist = var.application_projects[count.index].cluster_resource_whitelist
      
      namespaceResourceWhitelist = var.application_projects[count.index].namespace_resource_whitelist
      
      syncWindows = var.sync_windows
      
      roles = [
        {
          name = "admin"
          description = "Admin access to ${var.application_projects[count.index].name} project"
          policies = [
            "p, proj:${var.application_projects[count.index].name}:admin, applications, *, ${var.application_projects[count.index].name}/*, allow",
            "p, proj:${var.application_projects[count.index].name}:admin, repositories, *, *, allow",
            "p, proj:${var.application_projects[count.index].name}:admin, certificates, *, *, allow"
          ]
        },
        {
          name = "developer"
          description = "Developer access to ${var.application_projects[count.index].name} project"
          policies = [
            "p, proj:${var.application_projects[count.index].name}:developer, applications, get, ${var.application_projects[count.index].name}/*, allow",
            "p, proj:${var.application_projects[count.index].name}:developer, applications, sync, ${var.application_projects[count.index].name}/*, allow"
          ]
        },
        {
          name = "readonly"
          description = "Read-only access to ${var.application_projects[count.index].name} project"
          policies = [
            "p, proj:${var.application_projects[count.index].name}:readonly, applications, get, ${var.application_projects[count.index].name}/*, allow"
          ]
        }
      ]
    }
  }

  depends_on = [helm_release.argocd]
}