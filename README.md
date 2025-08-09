# 🚀 EKS Learning Lab - Complete Kubernetes Infrastructure

> **Production-ready AWS EKS cluster with ingress patterns, cost optimization, and full automation**

This repository provides complete Infrastructure as Code solutions for AWS EKS with multiple ingress patterns, automated DNS management, SSL certificates, and comprehensive cost controls.

## 🎯 Quick Start

### Prerequisites
- AWS account with appropriate permissions
- GitHub repository with required secrets configured
- Basic understanding of Kubernetes and AWS

### Required GitHub Secrets
```bash
AWS_ROLE_ARN          # IAM role for OIDC authentication  
AWS_REGION           # AWS region (e.g., us-east-1)
AWS_ACCOUNT_ID       # AWS account ID
SLACK_WEBHOOK_URL    # Slack notifications (optional)
```

### One-Click Deployment

1. **Deploy EKS Infrastructure:**
   - Navigate to Actions → 🚀 EKS Infrastructure Management
   - Select environment (dev/staging/prod)  
   - Run workflow with "apply" action

2. **Deploy Ingress Pattern:**
   - Navigate to Actions → 🚀 Deploy Kubernetes Ingress Patterns
   - Choose ALB or NGINX pattern
   - Enable demo apps for testing

## 🏗️ Architecture Overview

### EKS Base Infrastructure
```
VPC (10.0.0.0/16) 
├── Public Subnets (2 AZs)
├── Private Subnets (2 AZs) 
├── EKS Control Plane ($72/month)
├── Worker Nodes (2x t3.medium SPOT ~$12/month)
└── Add-ons (VPC-CNI, CoreDNS, EBS CSI)
```

### Ingress Patterns

#### ALB Pattern
```
Internet → Route53 → ALB → ClusterIP Service → Pod
```
- AWS Load Balancer Controller
- External-DNS automation
- cert-manager SSL certificates
- Purple-themed demo app

#### NGINX Pattern  
```
Internet → Route53 → NLB → NGINX Controller → ClusterIP Service → Pod
```
- NGINX Ingress Controller
- External-DNS automation
- cert-manager SSL certificates
- Pink-themed demo app

## 💰 Cost Analysis

### Base Infrastructure
| Component | Monthly Cost |
|-----------|-------------|
| EKS Control Plane | $72.00 |
| 2x t3.medium SPOT nodes | ~$12.00 |
| EBS Storage (40GB) | ~$4.00 |
| **Base Total** | **~$88.00** |

### Ingress Patterns (Additional)
| Component | ALB Pattern | NGINX Pattern |
|-----------|-------------|---------------|
| Load Balancer | $16.00 (ALB) | $16.00 (NLB) |
| Route53 Hosted Zone | $0.50 | $0.50 |
| **Pattern Total** | **+$16.50** | **+$16.50** |

### Cost Optimization Features
- ✅ SPOT instances for worker nodes (80% savings)
- ✅ Automated shutdown workflows
- ✅ Resource right-sizing
- ✅ No NAT Gateway in dev (saves $45/month)
- ✅ Disabled VPC endpoints in dev (saves $22/month)

## 🚀 Available Workflows

### 1. 🚀 EKS Infrastructure Management
**Purpose:** Deploy, update, or destroy the base EKS cluster

**Capabilities:**
- Multi-environment support (dev, staging, prod)
- Plan, apply, and destroy actions
- Security scanning with TFSec
- Cost estimation with Infracost
- Auto-approval for dev environment

**Usage:**
```yaml
workflow_dispatch:
  inputs:
    action: [plan, apply, destroy]
    environment: [dev, staging, prod]
    auto_approve: boolean
```

### 2. 🚀 Deploy Kubernetes Ingress Patterns
**Purpose:** Deploy ALB or NGINX ingress with full automation

**Capabilities:**
- Choice between ALB and NGINX patterns
- Automated DNS and SSL certificate management
- Demo applications for testing
- End-to-end validation
- Dry-run mode

**Usage:**
```yaml
workflow_dispatch:
  inputs:
    ingress_pattern: [alb, nginx]
    deploy_demo_apps: boolean (default: true)
    dry_run: boolean (default: false)
    environment: [dev, staging, prod]
```

### 3. 🧹 Cleanup Kubernetes Ingress Resources
**Purpose:** Clean up ingress resources and infrastructure

**Capabilities:**
- Pattern-specific or complete cleanup
- Confirmation requirements for safety
- Reverse-order resource deletion
- Cost savings reporting

**Usage:**
```yaml
workflow_dispatch:
  inputs:
    ingress_pattern: [alb, nginx, all]
    confirm_cleanup: "CONFIRM-CLEANUP"
    cleanup_shared: boolean
```

### 4. 🧪 Test Kubernetes Ingress
**Purpose:** Comprehensive testing of deployed ingress patterns

**Capabilities:**
- Automated after deployment
- DNS resolution testing
- HTTP/HTTPS connectivity testing
- SSL certificate validation
- Application functionality testing

## 🌐 Accessing Applications

### EKS Cluster Access
```bash
# Update kubeconfig
aws eks update-kubeconfig --region us-east-1 --name eks-learning-lab-dev

# Verify access
kubectl cluster-info
kubectl get nodes
```

### Ingress Applications
After deploying ingress patterns with demo apps:

```bash
# ALB Pattern
curl http://demo-alb.k8s-demo.local
curl https://demo-alb.k8s-demo.local

# NGINX Pattern  
curl http://demo-nginx.k8s-demo.local
curl https://demo-nginx.k8s-demo.local
```

### Direct LoadBalancer Access
```bash
# Get LoadBalancer hostname from workflow outputs
kubectl get ingress  # For ALB pattern
kubectl get service -n ingress-nginx  # For NGINX pattern

# Test connectivity
curl http://<loadbalancer-hostname>
```

## 🔧 Technical Implementation

### Infrastructure as Code
- **Terraform** for all AWS resources
- **Helm** for Kubernetes applications
- **S3 backend** for state management
- **Modular architecture** for reusability

### Security Best Practices
- **IRSA** (IAM Roles for Service Accounts)
- **Least privilege** IAM policies
- **VPC security groups** with minimal access
- **Encrypted storage** and state files

### Automation Features
- **External-DNS** for Route53 record management
- **cert-manager** for SSL certificate automation
- **GitHub Actions** for CI/CD
- **Slack integration** for notifications

### Multi-Environment Support
```
environments/
├── dev/     # Cost-optimized, SPOT instances
├── staging/ # Balanced cost/reliability  
└── prod/    # High availability, ON_DEMAND instances
```

## 🔍 Troubleshooting

### Common Issues

**EKS cluster not accessible**
```bash
# Check cluster status
aws eks describe-cluster --name eks-learning-lab-dev

# Update kubeconfig
aws eks update-kubeconfig --region us-east-1 --name eks-learning-lab-dev

# Verify IAM permissions
aws sts get-caller-identity
```

**Workflow failures**
```bash
# Check workflow logs in GitHub Actions
# Common issues:
# - Missing GitHub secrets
# - Insufficient AWS permissions  
# - Terraform state conflicts
# - Resource limits exceeded
```

**LoadBalancer not accessible**
```bash
# Check ingress controller pods
kubectl get pods -n kube-system | grep aws-load-balancer
kubectl get pods -n ingress-nginx

# Check security groups
kubectl get ingress
kubectl describe ingress <ingress-name>
```

### Resource Cleanup
```bash
# Emergency cleanup (use with caution)
./scripts/cleanup-resources.sh

# Targeted cleanup
kubectl delete ingress --all
kubectl delete service --all
helm uninstall <release-name> -n <namespace>
```

## 🚀 Production Considerations

### Migration Strategy
1. **Development** → Test patterns in dev environment
2. **Staging** → Validate with production-like traffic  
3. **Production** → Deploy with full monitoring

### Security Hardening
- Migrate to production Let's Encrypt certificates
- Implement real domain names (not .local)
- Add WAF protection for load balancers
- Enable CloudTrail and GuardDuty
- Implement network policies

### Monitoring and Observability
- **Prometheus + Grafana** for metrics
- **Fluentd** for log aggregation
- **AWS X-Ray** for distributed tracing
- **Cost Explorer** for cost monitoring

### High Availability
- Multi-AZ load balancer deployment
- Cross-region disaster recovery
- Database backup strategies
- Automated failover procedures

## 📊 Monitoring Deployments

### GitHub Actions
- Real-time workflow progress
- Step-by-step execution logs
- Artifact uploads (kubeconfig, terraform plans)
- Integration with pull requests

### Slack Notifications
```json
{
  "webhook_url": "https://hooks.slack.com/...",
  "notifications": [
    "deployment_success",
    "deployment_failure", 
    "cost_threshold_exceeded",
    "cleanup_completed"
  ]
}
```

### Cost Monitoring
- Monthly budget alerts
- Resource tagging for cost allocation
- Automated shutdown during non-business hours
- Spot instance optimization

## 🤝 Best Practices

### Development Workflow
1. **Fork** repository for your organization
2. **Configure** GitHub secrets and variables
3. **Test** in dev environment first
4. **Review** costs and security scan results
5. **Deploy** to staging, then production

### Resource Management
- Use consistent naming conventions
- Tag all resources for cost tracking
- Implement resource quotas and limits
- Regular security audits and updates

### Documentation
- Keep README.md updated with changes
- Document custom configurations
- Maintain runbooks for common operations
- Share knowledge with team members

## 🆘 Support and Contributing

### Getting Help
- **GitHub Issues** for bug reports
- **Discussions** for questions and ideas
- **Documentation** in code comments
- **Examples** in demo applications

### Contributing
1. Fork the repository
2. Create feature branch
3. Test with both ALB and NGINX patterns  
4. Submit pull request with description
5. Update documentation as needed

## 📄 License

This project is licensed under the MIT License - see LICENSE file for details.

---

## 🚀 Ready to Deploy?

1. **Set up GitHub secrets** in your repository
2. **Run the EKS Infrastructure Management workflow** to deploy your cluster
3. **Choose an ingress pattern** and deploy with demo apps
4. **Test everything** with the validation workflow
5. **Start building** your applications!

**Total setup time:** ~15 minutes for a complete, production-ready Kubernetes infrastructure with ingress patterns.

**Monthly cost:** Starting at ~$88/month for base EKS cluster + ~$16.50/month per ingress pattern.