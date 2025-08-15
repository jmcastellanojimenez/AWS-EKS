# ==============================================================================
# LGTM Observability Stack Main Configuration
# ==============================================================================

# Create observability namespace
resource "kubernetes_namespace" "observability" {
  metadata {
    name = var.namespace
    labels = merge(local.common_labels, {
      "app.kubernetes.io/name" = "observability"
    })
  }
}

# ==============================================================================
# Service Accounts with IRSA
# ==============================================================================

# Mimir Service Account
resource "kubernetes_service_account" "mimir" {
  count = var.enable_mimir ? 1 : 0

  metadata {
    name      = local.mimir_service_account
    namespace = kubernetes_namespace.observability.metadata[0].name
    labels    = local.common_labels
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.mimir[0].arn
    }
  }

  depends_on = [aws_iam_role.mimir]
}

# Loki Service Account
resource "kubernetes_service_account" "loki" {
  count = var.enable_loki ? 1 : 0

  metadata {
    name      = local.loki_service_account
    namespace = kubernetes_namespace.observability.metadata[0].name
    labels    = local.common_labels
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.loki[0].arn
    }
  }

  depends_on = [aws_iam_role.loki]
}

# Tempo Service Account
resource "kubernetes_service_account" "tempo" {
  count = var.enable_tempo ? 1 : 0

  metadata {
    name      = local.tempo_service_account
    namespace = kubernetes_namespace.observability.metadata[0].name
    labels    = local.common_labels
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.tempo[0].arn
    }
  }

  depends_on = [aws_iam_role.tempo]
}

# Grafana Service Account
resource "kubernetes_service_account" "grafana" {
  metadata {
    name      = local.grafana_service_account
    namespace = kubernetes_namespace.observability.metadata[0].name
    labels    = local.common_labels
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.grafana.arn
    }
  }

  depends_on = [aws_iam_role.grafana]
}

# ==============================================================================
# ConfigMaps for Component Configurations
# ==============================================================================

# Grafana ConfigMap for datasources
resource "kubernetes_config_map" "grafana_datasources" {
  metadata {
    name      = "grafana-datasources"
    namespace = kubernetes_namespace.observability.metadata[0].name
    labels    = local.common_labels
  }

  data = {
    "datasources.yaml" = yamlencode({
      apiVersion = 1
      datasources = compact([
        {
          name      = local.grafana_datasources.prometheus.name
          type      = local.grafana_datasources.prometheus.type
          url       = local.grafana_datasources.prometheus.url
          access    = "proxy"
          isDefault = true
        },
        var.enable_loki ? {
          name   = local.grafana_datasources.loki.name
          type   = local.grafana_datasources.loki.type
          url    = local.grafana_datasources.loki.url
          access = "proxy"
        } : null,
        var.enable_tempo ? {
          name   = local.grafana_datasources.tempo.name
          type   = local.grafana_datasources.tempo.type
          url    = local.grafana_datasources.tempo.url
          access = "proxy"
        } : null,
        var.enable_mimir ? {
          name   = local.grafana_datasources.mimir.name
          type   = local.grafana_datasources.mimir.type
          url    = local.grafana_datasources.mimir.url
          access = "proxy"
        } : null
      ])
    })
  }
}

# ==============================================================================
# Secrets
# ==============================================================================

# Grafana admin password secret
resource "kubernetes_secret" "grafana_credentials" {
  metadata {
    name      = "grafana-credentials"
    namespace = kubernetes_namespace.observability.metadata[0].name
    labels    = local.common_labels
  }

  data = {
    admin-user     = "admin"
    admin-password = var.grafana_admin_password
  }

  type = "Opaque"
}

# Slack webhook secret (if provided)
resource "kubernetes_secret" "slack_webhook" {
  count = var.slack_webhook_url != "" ? 1 : 0

  metadata {
    name      = "slack-webhook"
    namespace = kubernetes_namespace.observability.metadata[0].name
    labels    = local.common_labels
  }

  data = {
    webhook-url = var.slack_webhook_url
  }

  type = "Opaque"
}