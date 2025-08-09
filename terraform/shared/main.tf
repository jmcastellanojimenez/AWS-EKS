# Shared infrastructure configuration for ingress patterns
# This module provides common configurations and Route53 resources

# Route53 Hosted Zone for demo domain (only created if domain_name is provided)
resource "aws_route53_zone" "demo" {
  count = var.domain_name != "" ? 1 : 0
  name  = var.domain_name
  
  tags = merge(local.common_tags, {
    Name = "${var.domain_name}-hosted-zone"
    Type = "demo-domain"
  })
}