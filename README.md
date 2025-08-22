# AWS EKS Infrastructure Platform

## Overview

This repository contains a **hybrid deployment approach** for AWS EKS infrastructure, combining reliable automation for core components with detailed manual runbooks for complex services.

## Architecture Strategy

### Automated Workflows (GitHub Actions)
We maintain **2 reliable automated workflows** that provide the essential foundation:

1. **🏗️ Foundation Platform** - Core EKS cluster, VPC, IAM, and add-ons
2. **🚪 Ingress & API Gateway Stack** - Ambassador, cert-manager, external-dns

### Manual Deployment Runbooks  
Complex services are deployed manually using detailed runbooks:

3. **📊 LGTM Observability Stack** - Prometheus, Loki, Tempo, Grafana
4. **🔄 GitOps & Deployment Automation** - ArgoCD, Tekton, CI/CD pipelines
5. **🔐 Security Foundation** - OpenBao, OPA Gatekeeper, Falco
6. **🛡️ Service Mesh** - Istio, Kiali, traffic management
7. **📊 Data Services** - PostgreSQL, Redis, Kafka

## Quick Start

### Prerequisites
- AWS CLI configured with appropriate permissions
- kubectl installed
- Helm 3.x installed
- Terraform 1.5+ installed
- GitHub repository with OIDC configured

### Required GitHub Secrets
```bash
AWS_ACCOUNT_ID      # Your AWS account ID
AWS_REGION          # Target AWS region (e.g., us-east-1)
AWS_ROLE_ARN        # OIDC role ARN for GitHub Actions
SLACK_WEBHOOK_URL   # Optional: Slack notifications
```

### Deployment Steps

#### Step 1: Deploy Foundation Platform
```bash
# Trigger the Foundation workflow via GitHub Actions
# Or deploy locally:
cd terraform/environments/dev
terraform init
terraform plan -var-file=foundation.tfvars
terraform apply -var-file=foundation.tfvars
```

**Foundation Components:**
- ✅ VPC with public/private subnets across 3 AZs
- ✅ EKS cluster with managed node groups (ON_DEMAND instances)
- ✅ IAM roles and IRSA configurations
- ✅ Core add-ons: EBS CSI, CoreDNS, kube-proxy, vpc-cni
- ✅ Cluster autoscaler and AWS Load Balancer Controller

#### Step 2: Deploy Ingress Stack
```bash
# Trigger the Ingress workflow via GitHub Actions
# Or deploy locally:
terraform plan -var-file=ingress.tfvars
terraform apply -var-file=ingress.tfvars
```

**Ingress Components:**
- ✅ Ambassador Edge Stack (API Gateway)
- ✅ cert-manager for TLS certificate automation
- ✅ external-dns for Route53 integration
- ✅ Automatic SSL/TLS termination
- ✅ Rate limiting and traffic policies

#### Step 3: Manual Services (Optional)
Choose and deploy additional services using the provided runbooks:

| Service | Complexity | Est. Time | Cost/Month |
|---------|------------|-----------|------------|
| LGTM Observability | Medium | 30-45 min | $35-45 |
| GitOps Automation | Medium | 45-60 min | $20-40 |
| Security Foundation | High | 60-90 min | $15-20 |
| Service Mesh | High | 45-60 min | $35-50 |
| Data Services | High | 60-90 min | $100-160 |

## Infrastructure Specifications

### Cluster Configuration
- **EKS Version**: 1.28
- **Node Groups**:
  - System: 2-3x t3.small (ON_DEMAND) - Core services
  - Workload: 2-4x t3.medium (ON_DEMAND) - Applications
- **Networking**: IPv4, private subnets with NAT Gateway
- **Storage**: GP3 EBS volumes, EFS for shared storage

### Cost Optimization
- **Foundation + Ingress**: ~$180/month
- **Complete Stack**: ~$400-500/month
- **Spot Instance Option**: Available in Terraform (not recommended for stability)

### Security Features
- **Network**: Private subnets, security groups, NACLs
- **IAM**: Least privilege, IRSA for pod-level permissions
- **Encryption**: EBS encryption, secrets encryption at rest
- **Compliance**: SOC 2, PCI DSS baseline configurations

## Repository Structure

```
├── .github/workflows/          # Automated workflows (Foundation + Ingress only)
├── terraform/
│   ├── environments/dev/       # Environment-specific configurations
│   └── modules/               # Terraform modules (Foundation + Ingress only)
├── 3. LGTM Observability Stack.md
├── 4. GitOps and Deployment Automation.md
├── 5. Security Foundation.md
├── 6. Service Mesh.md
├── 7. Data Services.md
└── README.md                  # This file
```

## Design Decisions

### Why Hybrid Approach?
After extensive testing, we determined that:

1. **Foundation + Ingress** workflows are rock-solid and rarely fail
2. **Complex services** (LGTM, GitOps, Security, Service Mesh, Data) had frequent CRD timing issues and dependency conflicts
3. **Manual deployment** provides better control and troubleshooting capabilities
4. **Cost efficiency** - only deploy what you actually need

### Benefits
- ✅ **Reliable Core**: Foundation and Ingress automation with 95%+ success rate
- ✅ **Flexible Extensions**: Deploy additional services as needed
- ✅ **Cost Control**: Pay only for services you deploy
- ✅ **Better Troubleshooting**: Manual deployment provides deeper understanding
- ✅ **Production Ready**: Core platform suitable for production workloads

### Trade-offs
- ⚠️ **Manual Effort**: Additional services require manual deployment
- ⚠️ **Learning Curve**: Operators need to understand Helm and Kubernetes
- ⚠️ **Consistency**: Manual deployments may vary between environments

## Operational Guidelines

### Development Workflow
1. **Start Small**: Deploy Foundation + Ingress for basic cluster
2. **Add Services**: Use runbooks to add observability, security, etc.
3. **Test Applications**: Deploy your applications to the cluster
4. **Monitor & Optimize**: Use observability stack to monitor performance

### Production Considerations
- Use separate AWS accounts for dev/staging/prod
- Implement proper backup strategies for stateful services
- Configure monitoring and alerting before deploying applications
- Review security runbooks and implement organizational policies

### Troubleshooting
- **Foundation Issues**: Check AWS IAM permissions and VPC configuration
- **Ingress Issues**: Verify DNS configuration and certificate management
- **Application Issues**: Use kubectl and observability tools for debugging

## Support and Maintenance

### Regular Tasks
- **Weekly**: Review cluster resource usage and costs
- **Monthly**: Update node group AMIs and EKS version (if needed)
- **Quarterly**: Review security configurations and policies

### Updates and Upgrades
- **Foundation/Ingress**: Update through GitHub Actions workflows
- **Manual Services**: Follow update procedures in each runbook
- **EKS Cluster**: Plan maintenance windows for control plane updates

## Contributing

When making changes:
1. Test in development environment first
2. Update relevant runbooks for manual services  
3. Maintain Foundation + Ingress automation reliability
4. Document any cost or security implications

## Resources

- [AWS EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Helm Charts](https://artifacthub.io/)

---

**Note**: This approach prioritizes reliability and cost-effectiveness over full automation. The core platform (Foundation + Ingress) provides a solid base for any Kubernetes workload, while additional services can be added incrementally based on actual needs.