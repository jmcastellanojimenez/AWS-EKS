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

output "public_subnet_ids" {
  description = "Public subnet IDs from EKS cluster"
  value       = data.aws_subnets.public.ids
}

output "private_subnet_ids" {
  description = "Private subnet IDs from EKS cluster"
  value       = data.aws_subnets.private.ids
}