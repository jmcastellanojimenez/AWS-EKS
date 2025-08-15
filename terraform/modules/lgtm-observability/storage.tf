# ==============================================================================
# S3 Storage for LGTM Observability Components
# ==============================================================================

# Mimir Metrics Storage
resource "aws_s3_bucket" "mimir" {
  count  = var.enable_mimir ? 1 : 0
  bucket = local.mimir_bucket

  tags = merge(var.tags, {
    Name        = local.mimir_bucket
    Component   = "mimir"
    Environment = var.environment
  })
}

resource "aws_s3_bucket_versioning" "mimir" {
  count  = var.enable_mimir ? 1 : 0
  bucket = aws_s3_bucket.mimir[0].id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "mimir" {
  count  = var.enable_mimir ? 1 : 0
  bucket = aws_s3_bucket.mimir[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "mimir" {
  count  = var.enable_mimir && var.s3_lifecycle_enabled ? 1 : 0
  bucket = aws_s3_bucket.mimir[0].id

  rule {
    id     = "mimir_lifecycle"
    status = "Enabled"

    transition {
      days          = var.s3_transition_days
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 30
      storage_class = "GLACIER"
    }

    expiration {
      days = var.s3_expiration_days
    }
  }
}

# Loki Log Storage
resource "aws_s3_bucket" "loki" {
  count  = var.enable_loki ? 1 : 0
  bucket = local.loki_bucket

  tags = merge(var.tags, {
    Name        = local.loki_bucket
    Component   = "loki"
    Environment = var.environment
  })
}

resource "aws_s3_bucket_versioning" "loki" {
  count  = var.enable_loki ? 1 : 0
  bucket = aws_s3_bucket.loki[0].id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "loki" {
  count  = var.enable_loki ? 1 : 0
  bucket = aws_s3_bucket.loki[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "loki" {
  count  = var.enable_loki && var.s3_lifecycle_enabled ? 1 : 0
  bucket = aws_s3_bucket.loki[0].id

  rule {
    id     = "loki_lifecycle"
    status = "Enabled"

    transition {
      days          = var.s3_transition_days
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 30
      storage_class = "GLACIER"
    }

    expiration {
      days = var.s3_expiration_days
    }
  }
}

# Tempo Trace Storage
resource "aws_s3_bucket" "tempo" {
  count  = var.enable_tempo ? 1 : 0
  bucket = local.tempo_bucket

  tags = merge(var.tags, {
    Name        = local.tempo_bucket
    Component   = "tempo"
    Environment = var.environment
  })
}

resource "aws_s3_bucket_versioning" "tempo" {
  count  = var.enable_tempo ? 1 : 0
  bucket = aws_s3_bucket.tempo[0].id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tempo" {
  count  = var.enable_tempo ? 1 : 0
  bucket = aws_s3_bucket.tempo[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "tempo" {
  count  = var.enable_tempo && var.s3_lifecycle_enabled ? 1 : 0
  bucket = aws_s3_bucket.tempo[0].id

  rule {
    id     = "tempo_lifecycle"
    status = "Enabled"

    transition {
      days          = var.s3_transition_days
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 30
      storage_class = "GLACIER"
    }

    expiration {
      days = var.s3_expiration_days
    }
  }
}

# ==============================================================================
# S3 Bucket Policies
# ==============================================================================

# Mimir S3 Policy
data "aws_iam_policy_document" "mimir_s3_policy" {
  count = var.enable_mimir ? 1 : 0

  statement {
    sid    = "MimirS3Access"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket"
    ]
    resources = [
      aws_s3_bucket.mimir[0].arn,
      "${aws_s3_bucket.mimir[0].arn}/*"
    ]
  }
}

# Loki S3 Policy
data "aws_iam_policy_document" "loki_s3_policy" {
  count = var.enable_loki ? 1 : 0

  statement {
    sid    = "LokiS3Access"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket"
    ]
    resources = [
      aws_s3_bucket.loki[0].arn,
      "${aws_s3_bucket.loki[0].arn}/*"
    ]
  }
}

# Tempo S3 Policy
data "aws_iam_policy_document" "tempo_s3_policy" {
  count = var.enable_tempo ? 1 : 0

  statement {
    sid    = "TempoS3Access"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket"
    ]
    resources = [
      aws_s3_bucket.tempo[0].arn,
      "${aws_s3_bucket.tempo[0].arn}/*"
    ]
  }
}