output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = module.eks.cluster_security_group_id
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = module.eks.cluster_certificate_authority_data
  sensitive   = true
}

output "cluster_version" {
  description = "EKS cluster Kubernetes version"
  value       = module.eks.cluster_version
}

output "node_group_arn" {
  description = "Amazon Resource Name (ARN) of the EKS Node Group"
  value       = module.eks.node_group_arn
}

output "node_security_group_id" {
  description = "ID of the node group security group"
  value       = module.eks.node_security_group_id
}

output "oidc_provider_arn" {
  description = "ARN of the OIDC Provider for the EKS cluster"
  value       = module.eks.oidc_provider_arn
}

output "oidc_provider_url" {
  description = "URL of the OIDC Provider for the EKS cluster"
  value       = module.eks.oidc_provider_url
}

output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = module.vpc.private_subnet_ids
}

output "kubeconfig_command" {
  description = "Command to update kubeconfig"
  value       = module.eks.kubeconfig_command
}

output "aws_load_balancer_controller_role_arn" {
  description = "ARN of the AWS Load Balancer Controller IAM role"
  value       = module.iam.aws_load_balancer_controller_role_arn
}

output "external_dns_role_arn" {
  description = "ARN of the External DNS IAM role"
  value       = module.iam.external_dns_role_arn
}

output "cluster_autoscaler_role_arn" {
  description = "ARN of the Cluster Autoscaler IAM role"
  value       = module.iam.cluster_autoscaler_role_arn
}

output "cluster_data_bucket" {
  description = "S3 bucket for cluster data and backups"
  value       = aws_s3_bucket.cluster_data.bucket
}

output "cost_dashboard_url" {
  description = "URL to the CloudWatch dashboard"
  value       = "https://console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${aws_cloudwatch_dashboard.eks_cluster.dashboard_name}"
}

output "estimated_monthly_cost" {
  description = "Estimated monthly cost for this environment"
  value = {
    eks_cluster    = "$72.00"    # $0.10/hour * 24 * 30
    ec2_instances  = "$7.30"     # t3.small spot ~$0.0052/hour * 24 * 30
    ebs_storage    = "$2.00"     # 20GB * $0.10/GB
    data_transfer  = "$3.00"     # Estimated
    total_estimated = "$84.30"   # Without NAT Gateway
    savings_vs_ondemand = "$23.70" # Spot savings
  }
}

# Environment-specific information
output "environment_info" {
  description = "Information about this environment"
  value = {
    environment     = local.environment
    cost_optimized  = true
    auto_shutdown   = true
    spot_instances  = true
    learning_mode   = true
    budget_limit    = "$${local.cost_thresholds[local.environment]}"
  }
}