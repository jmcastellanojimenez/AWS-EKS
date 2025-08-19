# 🚀 EKS Platform Deployment Guide

## Quick Start

### 1. Prerequisites
```bash
# Install required tools
brew install terraform kubectl helm awscli

# Configure AWS credentials
aws configure
```

### 2. Configure Environment
```bash
# Copy and edit configuration
cp terraform/environments/dev/terraform.tfvars.example terraform/environments/dev/terraform.tfvars
# Edit with your values: domain, Cloudflare token, etc.
```

### 3. Deploy Platform
```bash
# Make script executable
chmod +x scripts/deploy.sh

# Deploy to dev environment
./scripts/deploy.sh dev
```

## 🏗️ What Gets Deployed

### Workflow 1: Foundation Platform
- **VPC**: Multi-AZ with public/private subnets
- **EKS Cluster**: Managed control plane + node groups
- **IAM**: IRSA roles for all components
- **Add-ons**: VPC-CNI, EBS CSI, Load Balancer Controller

### Workflow 2: Ingress + API Gateway
- **Ambassador**: API Gateway with NLB
- **cert-manager**: Let's Encrypt SSL certificates
- **external-dns**: Automatic DNS management via Cloudflare

### Workflow 3: LGTM Observability Stack
- **Prometheus**: Metrics collection + alerting
- **Mimir**: Long-term metrics storage (S3)
- **Loki**: Log aggregation (S3)
- **Tempo**: Distributed tracing (S3)
- **Grafana**: Unified dashboards
- **OpenTelemetry**: Auto-instrumentation for Java apps

### Workflow 4: GitOps & CI/CD
- **ArgoCD**: GitOps application deployment
- **Tekton**: CI/CD pipelines with Kaniko builds
- **Trivy**: Security scanning

## 🔧 Configuration

### Required Variables
```hcl
# terraform/environments/dev/terraform.tfvars
domain_name           = "your-domain.dev"
letsencrypt_email     = "admin@your-domain.com"
cloudflare_api_token  = "your-cloudflare-token"
grafana_admin_password = "secure-password"
```

### Optional Customizations
- **Node Groups**: Modify instance types and scaling
- **Observability**: Adjust retention periods and storage
- **Security**: Configure additional policies

## 🚀 Deployment Process

### Automated Deployment
```bash
# Deploy everything
./scripts/deploy.sh dev

# Skip confirmation prompts
./scripts/deploy.sh dev true
```

### Manual Step-by-Step
```bash
cd terraform/environments/dev

# 1. Initialize
terraform init

# 2. Plan
terraform plan -var-file="terraform.tfvars"

# 3. Apply
terraform apply -var-file="terraform.tfvars"

# 4. Configure kubectl
aws eks update-kubeconfig --region us-east-1 --name eks-platform-dev-cluster
```

## 📊 Access Your Platform

### Grafana Dashboard
```bash
# URL: https://your-domain.dev/grafana
# Username: admin
# Password: (from terraform.tfvars)
```

### ArgoCD Dashboard
```bash
# URL: https://your-domain.dev/argocd
# Username: admin
# Get password:
kubectl get secret argocd-initial-admin-secret -n gitops -o jsonpath="{.data.password}" | base64 -d
```

### Kubectl Access
```bash
# Update kubeconfig
aws eks update-kubeconfig --region us-east-1 --name eks-platform-dev-cluster

# Verify access
kubectl get nodes
kubectl get pods -A
```

## 🔍 Verification

### Check All Components
```bash
# System components
kubectl get pods -n kube-system

# Ingress components  
kubectl get pods -n ingress-system

# Observability stack
kubectl get pods -n observability

# GitOps components
kubectl get pods -n gitops
```

### Test Observability
```bash
# Port forward Grafana
kubectl port-forward -n observability svc/grafana 3000:80

# Access: http://localhost:3000
```

## 🧹 Cleanup

### Destroy Environment
```bash
# Destroy everything (DANGEROUS!)
./scripts/destroy.sh dev DESTROY
```

## 🚨 Troubleshooting

### Common Issues

**Terraform State Lock**
```bash
# If deployment fails with state lock
terraform force-unlock <LOCK_ID> -force
```

**DNS Issues**
```bash
# Check external-dns logs
kubectl logs -n ingress-system -l app.kubernetes.io/name=external-dns
```

**Certificate Issues**
```bash
# Check cert-manager logs
kubectl logs -n ingress-system -l app.kubernetes.io/name=cert-manager
```

**Pod Startup Issues**
```bash
# Check pod events
kubectl describe pod <pod-name> -n <namespace>
kubectl get events -n <namespace> --sort-by='.lastTimestamp'
```

## 📈 Scaling

### Node Scaling
- **Cluster Autoscaler**: Automatically scales nodes based on demand
- **Manual Scaling**: Modify `desired_size` in terraform.tfvars

### Application Scaling
- **HPA**: Horizontal Pod Autoscaler configured for all apps
- **VPA**: Vertical Pod Autoscaler (optional)

## 🔐 Security

### Built-in Security
- **IRSA**: IAM roles for service accounts
- **Network Policies**: Pod-to-pod communication control
- **Pod Security Standards**: Enforced via OPA Gatekeeper
- **mTLS**: Service mesh encryption
- **Secrets Management**: External secrets with OpenBao

### Security Scanning
- **Trivy**: Container vulnerability scanning
- **Falco**: Runtime security monitoring
- **OPA Gatekeeper**: Policy enforcement

## 💰 Cost Optimization

### Automatic Optimizations
- **Spot Instances**: 60-70% cost savings
- **S3 Lifecycle**: Automatic data tiering
- **Right-sizing**: Resource optimization
- **Single NAT Gateway**: Dev environment cost savings

### Manual Optimizations
- **Reserved Instances**: For production workloads
- **Savings Plans**: For consistent usage
- **Resource Cleanup**: Regular unused resource removal

## 🔄 Updates

### Platform Updates
```bash
# Update Terraform modules
terraform init -upgrade

# Update Helm charts
helm repo update
```

### Application Updates
- **GitOps**: Update via ArgoCD applications
- **CI/CD**: Automated via Tekton pipelines

This deployment creates a production-ready, enterprise-grade Kubernetes platform with complete observability, security, and GitOps capabilities!