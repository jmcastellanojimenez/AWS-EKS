# EKS Foundation Platform - Onboarding Guide

## Welcome to the EKS Foundation Platform

This comprehensive guide will help you get started with the EKS Foundation Platform, a cloud-agnostic, enterprise-grade Kubernetes infrastructure designed specifically for microservices architectures.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Environment Setup](#environment-setup)
3. [Access Configuration](#access-configuration)
4. [Platform Overview](#platform-overview)
5. [Workflow Deployment Guide](#workflow-deployment-guide)
6. [Development Environment Setup](#development-environment-setup)
7. [Common Operations](#common-operations)
8. [Troubleshooting](#troubleshooting)
9. [Getting Help](#getting-help)

## Prerequisites

### Required Tools

Before you begin, ensure you have the following tools installed:

```bash
# AWS CLI (version 2.x)
aws --version

# Terraform (version 1.5+)
terraform version

# kubectl (compatible with EKS 1.28+)
kubectl version --client

# Helm (version 3.x)
helm version

# Git
git --version
```

### Required Access

- **AWS Account Access**: IAM user with appropriate permissions
- **GitHub Repository Access**: Read/write access to the platform repository
- **Slack Workspace**: Access to platform team channels (optional)
- **Domain Access**: Cloudflare DNS management (for ingress setup)

### Knowledge Prerequisites

- Basic understanding of Kubernetes concepts
- Familiarity with Terraform and Infrastructure as Code
- Understanding of AWS services (EKS, VPC, IAM, S3)
- Basic knowledge of containerization and microservices

## Environment Setup

### 1. Clone the Repository

```bash
git clone https://github.com/your-org/eks-learning-lab.git
cd eks-learning-lab
```

### 2. Configure AWS Credentials

```bash
# Configure AWS CLI
aws configure

# Verify access
aws sts get-caller-identity
```

### 3. Set Environment Variables

```bash
# Copy and customize environment variables
cp terraform/environments/dev/terraform.tfvars.example terraform/environments/dev/terraform.tfvars

# Edit the variables file
vim terraform/environments/dev/terraform.tfvars
```

Required variables:
```hcl
# AWS Configuration
aws_region = "us-east-1"
aws_account_id = "123456789012"

# Environment Configuration
environment = "dev"
cluster_name = "eks-learning-lab-dev-cluster"

# Domain Configuration
domain_name = "ecotrack.dev"
cloudflare_api_token = "your-cloudflare-token"

# Slack Integration (optional)
slack_webhook_url = "https://hooks.slack.com/services/..."
```

## Access Configuration

### 1. IAM Permissions

Ensure your AWS user has the following managed policies:
- `AmazonEKSClusterPolicy`
- `AmazonEKSWorkerNodePolicy`
- `AmazonEKS_CNI_Policy`
- `AmazonEC2ContainerRegistryReadOnly`

Custom policy for Terraform operations:
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ec2:*",
                "eks:*",
                "iam:*",
                "s3:*",
                "route53:*",
                "acm:*",
                "elasticloadbalancing:*"
            ],
            "Resource": "*"
        }
    ]
}
```

### 2. Terraform Backend Setup

Initialize the Terraform backend:

```bash
cd terraform/environments/dev
terraform init
```

### 3. Verify Setup

```bash
# Test Terraform configuration
terraform plan -var-file="terraform.tfvars"

# Verify AWS connectivity
aws eks list-clusters --region us-east-1
```

## Platform Overview

### Architecture Components

The platform consists of 7 sequential workflows:

1. **🏗️ Foundation Platform**: VPC, EKS cluster, IAM roles, CNI
2. **🌐 Ingress + API Gateway**: Ambassador, cert-manager, external-dns
3. **📈 Observability Stack**: LGTM stack (Loki, Grafana, Tempo, Mimir)
4. **🔄 GitOps & Deployment**: ArgoCD, Tekton
5. **🔐 Security Foundation**: OpenBao, OPA Gatekeeper, Falco
6. **🛡️ Service Mesh**: Istio with mTLS
7. **📊 Data Services**: PostgreSQL, Redis, Kafka

### Resource Requirements

```yaml
Cluster Configuration:
  Instance Type: t3.large (2 vCPU, 8GB RAM)
  Auto-scaling: 3-10 nodes
  Capacity Type: SPOT instances (cost optimization)
  
Total Platform Resources:
  CPU: ~8 cores
  Memory: ~16GB RAM
  Storage: ~200GB EBS
  
Microservices Allocation:
  CPU: ~5 cores reserved
  Memory: ~10GB RAM reserved
  Replicas: 3 per service
```

## Workflow Deployment Guide

### Phase 1: Foundation Infrastructure (Required First)

Deploy the core infrastructure components:

```bash
cd terraform/environments/dev

# 1. Deploy VPC and networking
terraform apply -target=module.vpc -var-file="terraform.tfvars" -auto-approve

# 2. Deploy IAM roles
terraform apply -target=module.iam -var-file="terraform.tfvars" -auto-approve

# 3. Deploy EKS cluster
terraform apply -target=module.eks -var-file="terraform.tfvars" -auto-approve

# 4. Update kubeconfig
aws eks update-kubeconfig --region us-east-1 --name eks-learning-lab-dev-cluster

# 5. Verify cluster
kubectl get nodes
kubectl get pods -A
```

**Expected Output:**
- 3 worker nodes in Ready state
- All system pods running in kube-system namespace
- EBS CSI driver and other add-ons deployed

### Phase 2: Ingress and External Access

```bash
# 1. Deploy cert-manager
terraform apply -target=module.cert-manager -var-file="terraform.tfvars" -auto-approve

# 2. Deploy external-dns
terraform apply -target=module.external-dns -var-file="terraform.tfvars" -auto-approve

# 3. Deploy Ambassador
terraform apply -target=module.ambassador -var-file="terraform.tfvars" -auto-approve

# 4. Verify ingress components
kubectl get pods -n cert-manager
kubectl get pods -n external-dns
kubectl get pods -n ambassador
```

**Expected Output:**
- cert-manager pods running and ready
- external-dns pod managing DNS records
- Ambassador pods providing ingress capability

### Phase 3: Observability Stack

```bash
# Deploy LGTM observability stack
terraform apply -target=module.lgtm-observability -var-file="terraform.tfvars" -auto-approve

# Verify observability components
kubectl get pods -n observability

# Access Grafana (in new terminal)
kubectl port-forward -n observability svc/grafana 3000:80

# Get Grafana admin password
kubectl get secret -n observability grafana-credentials -o jsonpath='{.data.admin-password}' | base64 -d
```

**Expected Output:**
- Prometheus, Loki, Grafana, and Tempo pods running
- Grafana accessible at http://localhost:3000
- Dashboards showing cluster metrics

### Phase 4-7: Advanced Workflows (Parallel Deployment)

After completing phases 1-3, you can deploy the remaining workflows in parallel:

```bash
# GitOps & Deployment
terraform apply -target=module.argocd -var-file="terraform.tfvars" -auto-approve

# Security Foundation
terraform apply -target=module.security-foundation -var-file="terraform.tfvars" -auto-approve

# Service Mesh
terraform apply -target=module.istio -var-file="terraform.tfvars" -auto-approve

# Data Services
terraform apply -target=module.data-services -var-file="terraform.tfvars" -auto-approve
```

## Development Environment Setup

### Local Development Tools

```bash
# Install additional development tools
brew install k9s          # Kubernetes CLI UI
brew install kubectx       # Kubernetes context switching
brew install stern         # Multi-pod log tailing
brew install dive          # Docker image analysis
```

### IDE Configuration

#### VS Code Extensions
- Kubernetes
- Terraform
- YAML
- GitLens
- Docker

#### IntelliJ IDEA Plugins
- Kubernetes
- Terraform and HCL
- Docker
- AWS Toolkit

### Local Testing Environment

```bash
# Create local development namespace
kubectl create namespace dev-local
kubectl config set-context --current --namespace=dev-local

# Deploy sample application for testing
kubectl apply -f examples/sample-app/
```

## Common Operations

### Daily Operations

#### Check Cluster Health
```bash
# Node status
kubectl get nodes

# Pod status across namespaces
kubectl get pods -A

# Resource usage
kubectl top nodes
kubectl top pods -A
```

#### Access Services
```bash
# Grafana dashboard
kubectl port-forward -n observability svc/grafana 3000:80

# Prometheus UI
kubectl port-forward -n observability svc/prometheus-server 9090:80

# Ambassador admin interface
kubectl port-forward -n ambassador svc/ambassador-admin 8877:8877
```

#### View Logs
```bash
# Application logs
kubectl logs -f deployment/user-service -n ecotrack

# System component logs
kubectl logs -f -n kube-system -l app=aws-load-balancer-controller

# Aggregated logs via stern
stern user-service -n ecotrack
```

### Maintenance Operations

#### Update Cluster
```bash
# Check current version
kubectl version --short

# Update cluster (via AWS Console or CLI)
aws eks update-cluster-version --name eks-learning-lab-dev-cluster --version 1.29

# Update node groups
aws eks update-nodegroup-version --cluster-name eks-learning-lab-dev-cluster --nodegroup-name <nodegroup-name>
```

#### Scale Resources
```bash
# Scale application
kubectl scale deployment user-service --replicas=5 -n ecotrack

# Scale cluster nodes (via Terraform)
terraform apply -var="node_desired_size=5" -var-file="terraform.tfvars"
```

#### Backup Operations
```bash
# Backup cluster configuration
kubectl get all -A -o yaml > cluster-backup-$(date +%Y%m%d).yaml

# Backup persistent data
kubectl exec -it postgres-primary-1 -n ecotrack -- pg_dumpall -U postgres > db-backup-$(date +%Y%m%d).sql
```

## Troubleshooting

### Common Issues and Solutions

#### Pod Startup Issues

**Problem**: Pods stuck in Pending state
```bash
# Diagnose the issue
kubectl describe pod <pod-name> -n <namespace>
kubectl get events -n <namespace> --sort-by='.lastTimestamp'
```

**Common Causes**:
- Insufficient cluster resources
- Image pull errors
- PVC mounting issues
- Node selector constraints

**Solutions**:
```bash
# Check node resources
kubectl describe nodes

# Check image availability
kubectl get pods <pod-name> -n <namespace> -o jsonpath='{.spec.containers[*].image}'

# Check PVC status
kubectl get pvc -n <namespace>
```

#### Network Connectivity Issues

**Problem**: Services cannot communicate
```bash
# Test service connectivity
kubectl exec -it <pod-name> -n <namespace> -- curl http://service-name:port/health

# Check DNS resolution
kubectl exec -it <pod-name> -n <namespace> -- nslookup service-name.namespace.svc.cluster.local
```

**Solutions**:
```bash
# Check service endpoints
kubectl get endpoints -n <namespace>

# Verify network policies
kubectl get networkpolicy -n <namespace>

# Check Istio configuration (if using service mesh)
istioctl proxy-status
```

#### Storage Issues

**Problem**: PVC stuck in Pending state
```bash
# Check PVC status
kubectl describe pvc <pvc-name> -n <namespace>

# Check storage class
kubectl get storageclass
```

**Solutions**:
```bash
# Verify EBS CSI driver
kubectl get pods -n kube-system -l app=ebs-csi-controller

# Check AWS EBS limits
aws ec2 describe-account-attributes --attribute-names supported-platforms
```

#### Observability Issues

**Problem**: Metrics not appearing in Grafana
```bash
# Check Prometheus targets
kubectl port-forward -n observability svc/prometheus-server 9090:80
# Navigate to http://localhost:9090/targets

# Check service monitor configuration
kubectl get servicemonitor -A
```

**Solutions**:
```bash
# Verify Prometheus configuration
kubectl get configmap -n observability prometheus-server -o yaml

# Check pod annotations for scraping
kubectl get pods -n <namespace> -o yaml | grep -A 5 -B 5 prometheus
```

### Emergency Procedures

#### Cluster Recovery
```bash
# 1. Assess cluster state
kubectl get nodes
kubectl get pods -A --field-selector=status.phase!=Running

# 2. Restart failed components
kubectl rollout restart deployment/<deployment-name> -n <namespace>

# 3. Scale down and up if needed
kubectl scale deployment <deployment-name> --replicas=0 -n <namespace>
kubectl scale deployment <deployment-name> --replicas=3 -n <namespace>
```

#### Data Recovery
```bash
# 1. Check backup availability
aws s3 ls s3://your-backup-bucket/

# 2. Restore from backup
kubectl apply -f backup-manifests/

# 3. Verify data integrity
kubectl exec -it postgres-primary-1 -n ecotrack -- psql -U postgres -c "\l"
```

### Performance Troubleshooting

#### High Resource Usage
```bash
# Identify resource-intensive pods
kubectl top pods -A --sort-by=cpu
kubectl top pods -A --sort-by=memory

# Check node resource allocation
kubectl describe nodes | grep -A 5 "Allocated resources"

# Analyze application metrics
curl -s http://service-name.namespace.svc.cluster.local:8080/actuator/metrics
```

#### Slow Response Times
```bash
# Check application health
curl -s http://service-name.namespace.svc.cluster.local:8080/actuator/health

# Analyze distributed traces (if Tempo is configured)
kubectl port-forward -n observability svc/tempo-query-frontend 3200:3200

# Check database performance
kubectl exec -it postgres-primary-1 -n ecotrack -- psql -U postgres -c "SELECT * FROM pg_stat_activity;"
```

## Getting Help

### Documentation Resources

- **Platform Documentation**: All README files in the repository
- **Terraform Modules**: Individual module documentation in `terraform/modules/*/README.md`
- **Kubernetes Documentation**: [kubernetes.io](https://kubernetes.io/docs/)
- **AWS EKS Documentation**: [AWS EKS User Guide](https://docs.aws.amazon.com/eks/)

### Support Channels

#### Internal Support
- **Slack Channel**: #platform-team
- **Email**: platform-team@company.com
- **On-call**: Use PagerDuty for urgent issues

#### Community Resources
- **EKS Community**: [AWS EKS GitHub](https://github.com/aws/amazon-eks-pod-identity-webhook)
- **Kubernetes Community**: [Kubernetes Slack](https://kubernetes.slack.com/)
- **Terraform Community**: [HashiCorp Discuss](https://discuss.hashicorp.com/)

### Escalation Procedures

#### Issue Severity Levels

**P0 - Critical**: Complete service outage, data loss risk
- **Response Time**: Immediate (< 15 minutes)
- **Escalation**: On-call engineer + management
- **Contact**: PagerDuty alert + Slack #incidents

**P1 - High**: Major functionality impaired, significant user impact
- **Response Time**: < 1 hour
- **Escalation**: On-call engineer
- **Contact**: Slack #platform-team

**P2 - Medium**: Minor functionality impaired, limited user impact
- **Response Time**: < 4 hours
- **Escalation**: Next business day
- **Contact**: GitHub issue + Slack #platform-team

**P3 - Low**: Cosmetic issues, no user impact
- **Response Time**: < 24 hours
- **Escalation**: Planned maintenance
- **Contact**: GitHub issue

### Knowledge Base

#### Frequently Asked Questions

**Q: How do I access the Grafana dashboard?**
A: Use `kubectl port-forward -n observability svc/grafana 3000:80` and access http://localhost:3000

**Q: How do I get the Grafana admin password?**
A: Run `kubectl get secret -n observability grafana-credentials -o jsonpath='{.data.admin-password}' | base64 -d`

**Q: How do I scale my application?**
A: Use `kubectl scale deployment <app-name> --replicas=<number> -n <namespace>`

**Q: How do I check if my pods are healthy?**
A: Use `kubectl get pods -n <namespace>` and `kubectl describe pod <pod-name> -n <namespace>`

**Q: How do I view application logs?**
A: Use `kubectl logs -f deployment/<app-name> -n <namespace>` or `stern <app-name> -n <namespace>`

#### Best Practices

1. **Always use namespaces** for application deployments
2. **Set resource requests and limits** for all containers
3. **Use health checks** (liveness and readiness probes)
4. **Implement proper logging** with structured JSON format
5. **Monitor resource usage** regularly
6. **Keep documentation updated** when making changes
7. **Test changes in dev environment** before production
8. **Use GitOps practices** for deployment management

#### Common Commands Reference

```bash
# Cluster Information
kubectl cluster-info
kubectl get nodes
kubectl get namespaces

# Pod Management
kubectl get pods -A
kubectl describe pod <pod-name> -n <namespace>
kubectl logs -f <pod-name> -n <namespace>
kubectl exec -it <pod-name> -n <namespace> -- /bin/bash

# Service Management
kubectl get services -A
kubectl describe service <service-name> -n <namespace>
kubectl port-forward service/<service-name> <local-port>:<service-port> -n <namespace>

# Resource Monitoring
kubectl top nodes
kubectl top pods -A
kubectl get events -A --sort-by='.lastTimestamp'

# Configuration Management
kubectl get configmap -A
kubectl get secret -A
kubectl describe configmap <configmap-name> -n <namespace>
```

---

## Next Steps

After completing this onboarding guide, you should be able to:

1. ✅ Deploy and manage the EKS Foundation Platform
2. ✅ Access and use the observability stack
3. ✅ Troubleshoot common issues
4. ✅ Deploy and manage microservices applications
5. ✅ Monitor platform health and performance

### Advanced Topics

Once you're comfortable with the basics, explore these advanced topics:

- **GitOps with ArgoCD**: Automated application deployment
- **Service Mesh with Istio**: Advanced traffic management and security
- **Security with OPA Gatekeeper**: Policy enforcement and compliance
- **Data Services**: PostgreSQL, Redis, and Kafka management
- **Cost Optimization**: Resource optimization and cost monitoring

### Contributing

To contribute to the platform:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly in dev environment
5. Submit a pull request
6. Update documentation as needed

Welcome to the EKS Foundation Platform! 🚀