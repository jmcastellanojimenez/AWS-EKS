# Data Services Module Variables

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "storage_class" {
  description = "Storage class for persistent volumes"
  type        = string
  default     = "gp3"
}

# PostgreSQL Configuration
variable "postgres_instances" {
  description = "Number of PostgreSQL instances"
  type        = number
  default     = 3
}

variable "postgres_database" {
  description = "PostgreSQL database name"
  type        = string
  default     = "ecotrack"
}

variable "postgres_username" {
  description = "PostgreSQL username"
  type        = string
  default     = "ecotrack"
}

variable "postgres_password" {
  description = "PostgreSQL password"
  type        = string
  sensitive   = true
}

variable "postgres_storage_size" {
  description = "PostgreSQL storage size"
  type        = string
  default     = "100Gi"
}

variable "postgres_backup_bucket" {
  description = "S3 bucket for PostgreSQL backups"
  type        = string
}

variable "postgres_backup_access_key" {
  description = "AWS access key for PostgreSQL backups"
  type        = string
  sensitive   = true
}

variable "postgres_backup_secret_key" {
  description = "AWS secret key for PostgreSQL backups"
  type        = string
  sensitive   = true
}

variable "cloudnative_pg_version" {
  description = "CloudNativePG operator version"
  type        = string
  default     = "0.19.1"
}

# Redis Configuration
variable "redis_replicas" {
  description = "Number of Redis replicas"
  type        = number
  default     = 3
}

variable "redis_sentinel_replicas" {
  description = "Number of Redis Sentinel replicas"
  type        = number
  default     = 3
}

variable "redis_storage_size" {
  description = "Redis storage size"
  type        = string
  default     = "10Gi"
}

variable "redis_operator_version" {
  description = "Redis operator version"
  type        = string
  default     = "3.2.9"
}

# Kafka Configuration
variable "kafka_replicas" {
  description = "Number of Kafka replicas"
  type        = number
  default     = 3
}

variable "zookeeper_replicas" {
  description = "Number of Zookeeper replicas"
  type        = number
  default     = 3
}

variable "kafka_storage_size" {
  description = "Kafka storage size"
  type        = string
  default     = "100Gi"
}

variable "zookeeper_storage_size" {
  description = "Zookeeper storage size"
  type        = string
  default     = "10Gi"
}

variable "strimzi_version" {
  description = "Strimzi Kafka operator version"
  type        = string
  default     = "0.38.0"
}

variable "create_sample_topic" {
  description = "Create a sample Kafka topic"
  type        = bool
  default     = true
}

# Monitoring Configuration
variable "enable_monitoring" {
  description = "Enable monitoring for data services"
  type        = bool
  default     = true
}

variable "metrics_retention" {
  description = "Metrics retention period"
  type        = string
  default     = "30d"
}

# Resource Configuration
variable "postgres_resources" {
  description = "PostgreSQL resource configuration"
  type = object({
    requests = object({
      cpu    = string
      memory = string
    })
    limits = object({
      cpu    = string
      memory = string
    })
  })
  default = {
    requests = {
      cpu    = "500m"
      memory = "1Gi"
    }
    limits = {
      cpu    = "1000m"
      memory = "2Gi"
    }
  }
}

variable "redis_resources" {
  description = "Redis resource configuration"
  type = object({
    requests = object({
      cpu    = string
      memory = string
    })
    limits = object({
      cpu    = string
      memory = string
    })
  })
  default = {
    requests = {
      cpu    = "100m"
      memory = "256Mi"
    }
    limits = {
      cpu    = "200m"
      memory = "512Mi"
    }
  }
}

variable "kafka_resources" {
  description = "Kafka resource configuration"
  type = object({
    requests = object({
      cpu    = string
      memory = string
    })
    limits = object({
      cpu    = string
      memory = string
    })
  })
  default = {
    requests = {
      cpu    = "500m"
      memory = "1Gi"
    }
    limits = {
      cpu    = "1000m"
      memory = "2Gi"
    }
  }
}

variable "zookeeper_resources" {
  description = "Zookeeper resource configuration"
  type = object({
    requests = object({
      cpu    = string
      memory = string
    })
    limits = object({
      cpu    = string
      memory = string
    })
  })
  default = {
    requests = {
      cpu    = "250m"
      memory = "512Mi"
    }
    limits = {
      cpu    = "500m"
      memory = "1Gi"
    }
  }
}