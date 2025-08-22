# Security Module - OpenBao, OPA Gatekeeper, Falco
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
  }
}

locals {
  common_labels = {
    "app.kubernetes.io/managed-by" = "terraform"
    "app.kubernetes.io/part-of"    = var.project_name
  }
}

# Security namespace
resource "kubernetes_namespace" "security" {
  metadata {
    name = "security"
    labels = merge(local.common_labels, {
      "app.kubernetes.io/component" = "security"
    })
  }
}

# External Secrets Operator
resource "helm_release" "external_secrets" {
  name       = "external-secrets"
  repository = "https://charts.external-secrets.io"
  chart      = "external-secrets"
  version    = var.external_secrets_version
  namespace  = kubernetes_namespace.security.metadata[0].name
  
  # Prevent namespace ownership conflicts
  create_namespace = false
  depends_on = [kubernetes_namespace.security]

  values = [
    yamlencode({
      installCRDs = true
      
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

      webhook = {
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
      }

      certController = {
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
      }

      serviceMonitor = {
        enabled = true
      }
    })
  ]
}

# OpenBao (HashiCorp Vault alternative)
resource "helm_release" "openbao" {
  name       = "openbao"
  repository = "https://openbao.github.io/openbao-helm"
  chart      = "openbao"
  version    = var.openbao_version
  namespace  = kubernetes_namespace.security.metadata[0].name
  
  # Prevent namespace ownership conflicts
  create_namespace = false
  depends_on = [kubernetes_namespace.security]

  values = [
    yamlencode({
      global = {
        enabled = true
        tlsDisable = false
      }

      server = {
        enabled = true
        
        image = {
          repository = "quay.io/openbao/openbao"
          tag        = "2.0.0"
        }

        resources = {
          requests = {
            memory = "256Mi"
            cpu    = "250m"
          }
          limits = {
            memory = "1Gi"
            cpu    = "500m"
          }
        }

        readinessProbe = {
          enabled = true
          path    = "/v1/sys/health?standbyok=true&sealedcode=204&uninitcode=204"
        }

        livenessProbe = {
          enabled = true
          path    = "/v1/sys/health?standbyok=true"
          initialDelaySeconds = 60
        }

        dataStorage = {
          enabled      = true
          size         = var.openbao_storage_size
          storageClass = var.storage_class
        }

        auditStorage = {
          enabled      = true
          size         = "10Gi"
          storageClass = var.storage_class
        }

        standalone = {
          enabled = false
        }

        ha = {
          enabled  = true
          replicas = 3
          
          config = yamlencode({
            ui = true
            
            listener = {
              tcp = {
                address     = "[::]:8200"
                cluster_address = "[::]:8201"
                tls_disable = 0
                tls_cert_file = "/vault/userconfig/openbao-server-tls/tls.crt"
                tls_key_file  = "/vault/userconfig/openbao-server-tls/tls.key"
              }
            }

            storage = {
              raft = {
                path = "/vault/data"
                
                retry_join = [
                  {
                    leader_api_addr = "https://openbao-0.openbao-internal:8200"
                    leader_ca_cert_file = "/vault/userconfig/openbao-server-tls/ca.crt"
                  },
                  {
                    leader_api_addr = "https://openbao-1.openbao-internal:8200"
                    leader_ca_cert_file = "/vault/userconfig/openbao-server-tls/ca.crt"
                  },
                  {
                    leader_api_addr = "https://openbao-2.openbao-internal:8200"
                    leader_ca_cert_file = "/vault/userconfig/openbao-server-tls/ca.crt"
                  }
                ]
              }
            }

            service_registration = {
              kubernetes = {}
            }
          })
        }

        service = {
          enabled = true
          type    = "ClusterIP"
          port    = 8200
        }

        serviceMonitor = {
          enabled = true
        }
      }

      ui = {
        enabled = true
        serviceType = "ClusterIP"
      }

      injector = {
        enabled = true
        
        resources = {
          requests = {
            memory = "256Mi"
            cpu    = "250m"
          }
          limits = {
            memory = "512Mi"
            cpu    = "500m"
          }
        }
      }
    })
  ]
}

# OPA Gatekeeper
resource "helm_release" "gatekeeper" {
  name       = "gatekeeper"
  repository = "https://open-policy-agent.github.io/gatekeeper/charts"
  chart      = "gatekeeper"
  version    = var.gatekeeper_version
  namespace  = kubernetes_namespace.security.metadata[0].name
  
  # Prevent namespace ownership conflicts
  create_namespace = false
  depends_on = [kubernetes_namespace.security]

  values = [
    yamlencode({
      replicas = 3

      controllerManager = {
        resources = {
          requests = {
            cpu    = "100m"
            memory = "256Mi"
          }
          limits = {
            cpu    = "1000m"
            memory = "512Mi"
          }
        }
      }

      audit = {
        resources = {
          requests = {
            cpu    = "100m"
            memory = "256Mi"
          }
          limits = {
            cpu    = "1000m"
            memory = "512Mi"
          }
        }
      }

      violations = {
        allowedUsers = ["system:serviceaccount:gatekeeper-system:gatekeeper-admin"]
      }

      podSecurityPolicy = {
        enabled = false
      }

      enableDeleteOperations = false
      
      serviceMonitor = {
        enabled = true
      }
    })
  ]
}

# Falco Runtime Security
resource "helm_release" "falco" {
  name       = "falco"
  repository = "https://falcosecurity.github.io/charts"
  chart      = "falco"
  version    = var.falco_version
  namespace  = kubernetes_namespace.security.metadata[0].name
  
  # Prevent namespace ownership conflicts
  create_namespace = false
  depends_on = [kubernetes_namespace.security]

  values = [
    yamlencode({
      driver = {
        kind = "ebpf"
      }

      collectors = {
        enabled = true
      }

      falco = {
        rules_file = [
          "/etc/falco/falco_rules.yaml",
          "/etc/falco/falco_rules.local.yaml",
          "/etc/falco/k8s_audit_rules.yaml",
          "/etc/falco/rules.d"
        ]

        json_output = true
        json_include_output_property = true
        json_include_tags_property = true

        log_stderr = true
        log_syslog = false
        log_level = "info"

        priority = "debug"

        buffered_outputs = false
        outputs_queue_capacity = 0
        outputs_timeout = 2000

        syscall_event_drops = {
          actions = ["log", "alert"]
          rate = 0.03333
          max_burst = 1000
        }

        metrics = {
          enabled = true
          interval = "15s"
          output_rule = true
          rules_counters_enabled = true
          resource_utilization_enabled = true
          state_counters_enabled = true
          kernel_event_counters_enabled = true
          libbpf_stats_enabled = true
          plugins_metrics_enabled = true
        }
      }

      resources = {
        requests = {
          cpu    = "100m"
          memory = "512Mi"
        }
        limits = {
          cpu    = "1000m"
          memory = "1Gi"
        }
      }

      tolerations = [
        {
          effect   = "NoSchedule"
          key      = "node-role.kubernetes.io/master"
          operator = "Exists"
        },
        {
          effect   = "NoSchedule"
          key      = "node-role.kubernetes.io/control-plane"
          operator = "Exists"
        }
      ]

      serviceMonitor = {
        enabled = true
      }

      falcosidekick = {
        enabled = true
        
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

        config = {
          slack = {
            webhookurl = var.slack_webhook_url
            channel    = "#security-alerts"
            username   = "Falco"
            icon       = ":warning:"
            minimumpriority = "warning"
          }
        }
      }
    })
  ]
}

# Wait for OPA Gatekeeper CRDs to be available
resource "time_sleep" "wait_for_gatekeeper_crds" {
  depends_on      = [helm_release.gatekeeper]
  create_duration = "60s"
}

# Pod Security Standards Policy
# NOTE: Commented out to avoid CRD dependency issues during initial deployment
# Uncomment and apply after Gatekeeper CRDs are installed
/* resource "kubernetes_manifest" "pod_security_policy" {
  manifest = {
    apiVersion = "templates.gatekeeper.sh/v1beta1"
    kind       = "ConstraintTemplate"
    metadata = {
      name = "k8srequiredsecuritycontext"
    }
    spec = {
      crd = {
        spec = {
          names = {
            kind = "K8sRequiredSecurityContext"
          }
          validation = {
            properties = {
              runAsNonRoot = {
                type = "boolean"
              }
              readOnlyRootFilesystem = {
                type = "boolean"
              }
              allowPrivilegeEscalation = {
                type = "boolean"
              }
            }
          }
        }
      }
      targets = [
        {
          target = "admission.k8s.gatekeeper.sh"
          rego = <<-EOF
            package k8srequiredsecuritycontext

            violation[{"msg": msg}] {
              container := input.review.object.spec.template.spec.containers[_]
              not container.securityContext.runAsNonRoot
              msg := sprintf("Container %v must run as non-root user", [container.name])
            }

            violation[{"msg": msg}] {
              container := input.review.object.spec.template.spec.containers[_]
              not container.securityContext.readOnlyRootFilesystem
              msg := sprintf("Container %v must have read-only root filesystem", [container.name])
            }

            violation[{"msg": msg}] {
              container := input.review.object.spec.template.spec.containers[_]
              container.securityContext.allowPrivilegeEscalation == true
              msg := sprintf("Container %v must not allow privilege escalation", [container.name])
            }
          EOF
        }
      ]
    }
  }

  depends_on = [time_sleep.wait_for_gatekeeper_crds]
} */

# Apply Pod Security Policy
# NOTE: Commented out - depends on pod_security_policy CRD
/* resource "kubernetes_manifest" "pod_security_constraint" {
  manifest = {
    apiVersion = "constraints.gatekeeper.sh/v1beta1"
    kind       = "K8sRequiredSecurityContext"
    metadata = {
      name = "must-have-security-context"
    }
    spec = {
      match = {
        kinds = [
          {
            apiGroups = ["apps"]
            kinds     = ["Deployment", "DaemonSet", "StatefulSet"]
          }
        ]
        excludedNamespaces = ["kube-system", "gatekeeper-system", "security"]
      }
      parameters = {
        runAsNonRoot             = true
        readOnlyRootFilesystem   = true
        allowPrivilegeEscalation = false
      }
    }
  }

  depends_on = [kubernetes_manifest.pod_security_policy]
} */

# Resource Requirements Policy
# NOTE: Commented out to avoid CRD dependency issues
/* resource "kubernetes_manifest" "resource_requirements_policy" {
  manifest = {
    apiVersion = "templates.gatekeeper.sh/v1beta1"
    kind       = "ConstraintTemplate"
    metadata = {
      name = "k8srequiredresources"
    }
    spec = {
      crd = {
        spec = {
          names = {
            kind = "K8sRequiredResources"
          }
          validation = {
            properties = {
              limits = {
                type = "array"
                items = {
                  type = "string"
                }
              }
              requests = {
                type = "array"
                items = {
                  type = "string"
                }
              }
            }
          }
        }
      }
      targets = [
        {
          target = "admission.k8s.gatekeeper.sh"
          rego = <<-EOF
            package k8srequiredresources

            violation[{"msg": msg}] {
              container := input.review.object.spec.template.spec.containers[_]
              not container.resources.limits
              msg := sprintf("Container %v must have resource limits", [container.name])
            }

            violation[{"msg": msg}] {
              container := input.review.object.spec.template.spec.containers[_]
              not container.resources.requests
              msg := sprintf("Container %v must have resource requests", [container.name])
            }
          EOF
        }
      ]
    }
  }

  depends_on = [time_sleep.wait_for_gatekeeper_crds]
} */

# Apply Resource Requirements Policy
# NOTE: Commented out - depends on resource_requirements_policy CRD
/* resource "kubernetes_manifest" "resource_requirements_constraint" {
  manifest = {
    apiVersion = "constraints.gatekeeper.sh/v1beta1"
    kind       = "K8sRequiredResources"
    metadata = {
      name = "must-have-resources"
    }
    spec = {
      match = {
        kinds = [
          {
            apiGroups = ["apps"]
            kinds     = ["Deployment", "DaemonSet", "StatefulSet"]
          }
        ]
        excludedNamespaces = ["kube-system", "gatekeeper-system", "security"]
      }
    }
  }

  depends_on = [kubernetes_manifest.resource_requirements_policy]
} */