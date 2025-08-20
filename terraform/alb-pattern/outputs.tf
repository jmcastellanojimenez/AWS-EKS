output "lb_controller_role_arn" {
  description = "IAM role ARN for AWS Load Balancer Controller"
  value       = aws_iam_role.lb_controller.arn
}

output "external_dns_role_arn" {
  description = "IAM role ARN for External-DNS"
  value       = aws_iam_role.external_dns.arn
}

output "cert_manager_role_arn" {
  description = "IAM role ARN for cert-manager"
  value       = aws_iam_role.cert_manager.arn
}

output "vpc_id" {
  description = "VPC ID from EKS cluster"
  value       = data.aws_vpc.eks.id
}

output "private_subnet_ids" {
  description = "Private subnet IDs from EKS cluster"
  value       = data.aws_subnets.private.ids
}