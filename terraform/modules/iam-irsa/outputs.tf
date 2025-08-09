output "ebs_csi_driver_role_arn" {
  description = "ARN of the EBS CSI driver IAM role"
  value       = aws_iam_role.ebs_csi_driver.arn
}

output "external_dns_role_arn" {
  description = "ARN of the External-DNS IAM role"
  value       = aws_iam_role.external_dns.arn
}

output "cert_manager_role_arn" {
  description = "ARN of the cert-manager IAM role"
  value       = aws_iam_role.cert_manager.arn
}