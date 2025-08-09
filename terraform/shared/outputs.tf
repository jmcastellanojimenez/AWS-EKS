output "hosted_zone_id" {
  description = "Route53 hosted zone ID"
  value       = aws_route53_zone.demo.zone_id
}

output "domain_name" {
  description = "Domain name"
  value       = aws_route53_zone.demo.name
}

output "external_dns_role_arn" {
  description = "IAM role ARN for External-DNS"
  value       = aws_iam_role.external_dns.arn
}

output "cert_manager_role_arn" {
  description = "IAM role ARN for cert-manager"
  value       = aws_iam_role.cert_manager.arn
}

output "name_servers" {
  description = "Route53 name servers"
  value       = aws_route53_zone.demo.name_servers
}