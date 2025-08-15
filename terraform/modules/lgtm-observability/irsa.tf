# ==============================================================================
# IAM Roles for Service Accounts (IRSA) Configuration
# ==============================================================================

# Extract OIDC issuer from the provider ARN
locals {
  oidc_issuer = replace(var.oidc_provider_arn, "/^arn:aws:iam::[0-9]+:oidc-provider//", "")
}

# ==============================================================================
# Mimir IRSA
# ==============================================================================

# Trust policy for Mimir service account
data "aws_iam_policy_document" "mimir_trust_policy" {
  count = var.enable_mimir ? 1 : 0

  statement {
    effect = "Allow"
    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }
    actions = ["sts:AssumeRoleWithWebIdentity"]
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer}:sub"
      values   = ["system:serviceaccount:${var.namespace}:${local.mimir_service_account}"]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "mimir" {
  count              = var.enable_mimir ? 1 : 0
  name               = local.mimir_role_name
  assume_role_policy = data.aws_iam_policy_document.mimir_trust_policy[0].json

  tags = merge(var.tags, {
    Name        = local.mimir_role_name
    Component   = "mimir"
    Environment = var.environment
  })
}

resource "aws_iam_policy" "mimir_s3" {
  count  = var.enable_mimir ? 1 : 0
  name   = "${local.mimir_role_name}-s3-policy"
  policy = data.aws_iam_policy_document.mimir_s3_policy[0].json

  tags = merge(var.tags, {
    Name        = "${local.mimir_role_name}-s3-policy"
    Component   = "mimir"
    Environment = var.environment
  })
}

resource "aws_iam_role_policy_attachment" "mimir_s3" {
  count      = var.enable_mimir ? 1 : 0
  role       = aws_iam_role.mimir[0].name
  policy_arn = aws_iam_policy.mimir_s3[0].arn
}

# ==============================================================================
# Loki IRSA
# ==============================================================================

# Trust policy for Loki service account
data "aws_iam_policy_document" "loki_trust_policy" {
  count = var.enable_loki ? 1 : 0

  statement {
    effect = "Allow"
    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }
    actions = ["sts:AssumeRoleWithWebIdentity"]
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer}:sub"
      values   = ["system:serviceaccount:${var.namespace}:${local.loki_service_account}"]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "loki" {
  count              = var.enable_loki ? 1 : 0
  name               = local.loki_role_name
  assume_role_policy = data.aws_iam_policy_document.loki_trust_policy[0].json

  tags = merge(var.tags, {
    Name        = local.loki_role_name
    Component   = "loki"
    Environment = var.environment
  })
}

resource "aws_iam_policy" "loki_s3" {
  count  = var.enable_loki ? 1 : 0
  name   = "${local.loki_role_name}-s3-policy"
  policy = data.aws_iam_policy_document.loki_s3_policy[0].json

  tags = merge(var.tags, {
    Name        = "${local.loki_role_name}-s3-policy"
    Component   = "loki"
    Environment = var.environment
  })
}

resource "aws_iam_role_policy_attachment" "loki_s3" {
  count      = var.enable_loki ? 1 : 0
  role       = aws_iam_role.loki[0].name
  policy_arn = aws_iam_policy.loki_s3[0].arn
}

# ==============================================================================
# Tempo IRSA
# ==============================================================================

# Trust policy for Tempo service account
data "aws_iam_policy_document" "tempo_trust_policy" {
  count = var.enable_tempo ? 1 : 0

  statement {
    effect = "Allow"
    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }
    actions = ["sts:AssumeRoleWithWebIdentity"]
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer}:sub"
      values   = ["system:serviceaccount:${var.namespace}:${local.tempo_service_account}"]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "tempo" {
  count              = var.enable_tempo ? 1 : 0
  name               = local.tempo_role_name
  assume_role_policy = data.aws_iam_policy_document.tempo_trust_policy[0].json

  tags = merge(var.tags, {
    Name        = local.tempo_role_name
    Component   = "tempo"
    Environment = var.environment
  })
}

resource "aws_iam_policy" "tempo_s3" {
  count  = var.enable_tempo ? 1 : 0
  name   = "${local.tempo_role_name}-s3-policy"
  policy = data.aws_iam_policy_document.tempo_s3_policy[0].json

  tags = merge(var.tags, {
    Name        = "${local.tempo_role_name}-s3-policy"
    Component   = "tempo"
    Environment = var.environment
  })
}

resource "aws_iam_role_policy_attachment" "tempo_s3" {
  count      = var.enable_tempo ? 1 : 0
  role       = aws_iam_role.tempo[0].name
  policy_arn = aws_iam_policy.tempo_s3[0].arn
}

# ==============================================================================
# Grafana IRSA (for AWS CloudWatch integration if needed)
# ==============================================================================

# Trust policy for Grafana service account
data "aws_iam_policy_document" "grafana_trust_policy" {
  statement {
    effect = "Allow"
    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }
    actions = ["sts:AssumeRoleWithWebIdentity"]
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer}:sub"
      values   = ["system:serviceaccount:${var.namespace}:${local.grafana_service_account}"]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "grafana" {
  name               = local.grafana_role_name
  assume_role_policy = data.aws_iam_policy_document.grafana_trust_policy.json

  tags = merge(var.tags, {
    Name        = local.grafana_role_name
    Component   = "grafana"
    Environment = var.environment
  })
}

# CloudWatch read-only access for Grafana (optional, for AWS metrics)
resource "aws_iam_role_policy_attachment" "grafana_cloudwatch" {
  role       = aws_iam_role.grafana.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchReadOnlyAccess"
}