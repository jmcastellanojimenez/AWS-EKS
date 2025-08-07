# 📋 EKS Learning Lab - Deployment Guide

Complete step-by-step deployment guide for the EKS Learning Lab.

## 🎯 Prerequisites

### AWS Account Setup

1. **AWS Account** with administrative access
2. **AWS CLI** installed and configured
3. **Sufficient Quotas** in us-east-1 region:
   - VPC: 5
   - Internet Gateways: 5  
   - EKS Clusters: 10
   - EC2 Instances: 10

### GitHub Repository Setup

1. **Fork or Clone** this repository
2. **GitHub Actions** enabled
3. **Required Secrets** configured (see below)

## 🔑 Required GitHub Secrets

Navigate to **Settings** → **Secrets and variables** → **Actions** and add:

| Secret Name | Value | Description |
|-------------|-------|-------------|
| `AWS_REGION` | `us-east-1` | AWS region for deployment |
| `AWS_ROLE_ARN` | `arn:aws:iam::011921741593:role/GitHubActions-EKS-Deploy` | IAM role for OIDC authentication |
| `AWS_ACCOUNT_ID` | `011921741593` | Your AWS account ID |

## 🏗️ AWS IAM Setup

### 1. Create OIDC Identity Provider

```bash
# Get GitHub OIDC provider thumbprint
aws iam create-open-id-connect-provider \
    --url https://token.actions.githubusercontent.com \
    --client-id-list sts.amazonaws.com \
    --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
```

### 2. Create IAM Role for GitHub Actions

```bash
# Create trust policy
cat > github-actions-trust-policy.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Federated": "arn:aws:iam::011921741593:oidc-provider/token.actions.githubusercontent.com"
            },
            "Action": "sts:AssumeRoleWithWebIdentity",
            "Condition": {
                "StringEquals": {
                    "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
                },
                "StringLike": {
                    "token.actions.githubusercontent.com:sub": "repo:your-username/eks-learning-lab:*"
                }
            }
        }
    ]
}
EOF

# Create the role
aws iam create-role \
    --role-name GitHubActions-EKS-Deploy \
    --assume-role-policy-document file://github-actions-trust-policy.json

# Attach necessary policies
aws iam attach-role-policy \
    --role-name GitHubActions-EKS-Deploy \
    --policy-arn arn:aws:iam::aws:policy/AdministratorAccess
```

### 3. Create S3 Backend for Terraform State

```bash
# Create S3 bucket for Terraform state
aws s3 mb s3://eks-learning-lab-terraform-state-011921741593

# Enable versioning
aws s3api put-bucket-versioning \
    --bucket eks-learning-lab-terraform-state-011921741593 \
    --versioning-configuration Status=Enabled

# Create DynamoDB table for state locking
aws dynamodb create-table \
    --table-name eks-learning-lab-terraform-lock \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5
```

## 🚀 Deployment Steps

### Step 1: Plan Infrastructure

1. Navigate to **Actions** tab in your GitHub repository
2. Select **🚀 EKS Infrastructure Management** workflow
3. Click **Run workflow**
4. Configure parameters:
   - **Action**: `plan`
   - **Environment**: `dev`
   - **Confirm Destroy**: Leave empty
   - **Auto Approve**: `false`
5. Click **Run workflow**

The plan will show:
- ✅ Resources to be created
- 💰 Estimated monthly cost
- 🔒 Security scan results
- 📊 Cost analysis

### Step 2: Deploy Infrastructure

1. After reviewing the plan, run the workflow again:
   - **Action**: `apply`
   - **Environment**: `dev`
   - **Auto Approve**: `true` (or `false` for manual approval)
2. Click **Run workflow**

Deployment includes:
- 🏗️ EKS cluster creation (~15 minutes)
- 🌐 VPC and networking setup
- 👥 IAM roles and policies
- 🔐 Security groups and policies
- 📊 CloudWatch dashboard
- 💰 Cost budget setup

### Step 3: Tool Installation

Tools are automatically installed after successful infrastructure deployment:

1. **Core Tools** (~5 minutes):
   - AWS Load Balancer Controller
   - Cluster Autoscaler
   - Metrics Server
   - Kubernetes Dashboard

2. **GitOps Tools** (~8 minutes):
   - ArgoCD
   - Argo Workflows
   - Tekton Pipelines
   - Flux
   - Sealed Secrets

3. **Service Mesh** (~10 minutes):
   - Istio
   - Linkerd
   - Cilium/Hubble CLI
   - Open Service Mesh

4. **Security Tools** (~12 minutes):
   - HashiCorp Vault
   - OPA Gatekeeper  
   - Kyverno
   - Falco
   - Trivy Operator

5. **Observability Stack** (~15 minutes):
   - Prometheus & Grafana
   - Jaeger
   - OpenTelemetry
   - ELK Stack (Elasticsearch, Kibana, Filebeat)

## 🔍 Verification

### 1. Check Cluster Status

```bash
# Configure kubectl
aws eks update-kubeconfig --region us-east-1 --name eks-learning-lab-dev

# Verify cluster
kubectl cluster-info
kubectl get nodes
kubectl get pods --all-namespaces
```

### 2. Access Web Interfaces

```bash
# Grafana Dashboard
kubectl port-forward svc/prometheus-grafana -n monitoring 3000:80
# Access: http://localhost:3000 (admin/admin123)

# ArgoCD UI  
kubectl port-forward svc/argocd-server -n argocd 8080:443
# Access: https://localhost:8080 (admin/[get-password])

# Kubernetes Dashboard
kubectl port-forward svc/kubernetes-dashboard-kong-proxy -n kubernetes-dashboard 8443:443
# Access: https://localhost:8443

# Jaeger UI
kubectl port-forward svc/jaeger-query -n tracing 16686:16686
# Access: http://localhost:16686

# Kibana
kubectl port-forward svc/kibana-kibana -n logging 5601:5601
# Access: http://localhost:5601
```

### 3. Get Credentials

```bash
# ArgoCD admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Grafana admin password
echo "admin123"

# Kubernetes Dashboard token
kubectl -n kubernetes-dashboard create token admin-user
```

## ⚡ Common Deployment Scenarios

### Scenario 1: Fresh Development Environment

```yaml
# Workflow inputs
Action: apply
Environment: dev
Auto Approve: true
```

**Result**: Cost-optimized cluster with all learning tools installed.

### Scenario 2: Staging Environment

```yaml
# Workflow inputs  
Action: apply
Environment: staging
Auto Approve: false
```

**Result**: Higher availability cluster with manual approval gates.

### Scenario 3: Weekend Cost Savings

```yaml
# Friday evening
Action: destroy
Environment: dev
Confirm Destroy: CONFIRM-DESTROY

# Monday morning
Action: apply
Environment: dev
Auto Approve: true
```

**Result**: 65% cost savings during weekends.

## 🔧 Customization

### Environment-Specific Configurations

Edit `terraform/environments/{env}/terraform.tfvars`:

```hcl
# Development overrides
instance_types = ["t3.medium"]
desired_capacity = 1
min_capacity = 1
max_capacity = 2
enable_nat_gateway = false

# Staging overrides  
instance_types = ["t3.medium", "t3.large"]
desired_capacity = 2
min_capacity = 1
max_capacity = 3
enable_nat_gateway = true

# Production overrides
instance_types = ["t3.medium", "t3.large"] 
desired_capacity = 3
min_capacity = 2
max_capacity = 6
capacity_type = "ON_DEMAND"
```

### Tool Selection

Modify tool installation by editing workflow inputs:

```yaml
# Install only specific tool categories
Tool Category: [all, core, gitops, servicemesh, security, observability]
```

## 🚨 Troubleshooting

### Common Issues

#### 1. Permission Denied

```bash
# Error: Access denied
# Solution: Verify IAM role has sufficient permissions
aws sts get-caller-identity
```

#### 2. Quota Exceeded

```bash
# Error: VPC limit exceeded
# Solution: Request quota increase or clean up unused VPCs
aws service-quotas get-service-quota \
    --service-code vpc \
    --quota-code L-F678F1CE
```

#### 3. EKS Cluster Creation Failed

```bash
# Check CloudFormation stack
aws cloudformation describe-stacks \
    --stack-name eksctl-eks-learning-lab-dev-cluster

# Check EKS cluster logs
aws eks describe-cluster \
    --name eks-learning-lab-dev \
    --query 'cluster.logging'
```

#### 4. Tool Installation Timeout

```bash
# Check pod status
kubectl get pods --all-namespaces | grep -v Running

# Check events
kubectl get events --all-namespaces --sort-by='.lastTimestamp'

# Restart installation
kubectl delete job -n <namespace> <job-name>
```

### Support Resources

- 📖 [Troubleshooting Guide](TROUBLESHOOTING.md)
- 🐛 [GitHub Issues](https://github.com/your-repo/eks-learning-lab/issues)
- 💬 [Community Discussions](https://github.com/your-repo/eks-learning-lab/discussions)

## 🧹 Cleanup

### Partial Cleanup (Keep Infrastructure)

```bash
# Remove specific tools
helm uninstall prometheus -n monitoring
helm uninstall argocd -n argocd
```

### Full Cleanup

1. Run destroy workflow:
   ```yaml
   Action: destroy  
   Environment: dev
   Confirm Destroy: CONFIRM-DESTROY
   ```

2. Manual cleanup (if needed):
   ```bash
   # Remove S3 bucket
   aws s3 rb s3://eks-learning-lab-terraform-state-011921741593 --force
   
   # Remove DynamoDB table
   aws dynamodb delete-table --table-name eks-learning-lab-terraform-lock
   ```

## 📊 Cost Tracking

### Budget Setup

The deployment automatically creates:
- 💰 AWS Budget with email alerts
- 📊 CloudWatch cost dashboard
- 🔔 Cost anomaly detection

### Manual Cost Analysis

```bash
# Get current month costs
aws ce get-cost-and-usage \
    --time-period Start=2024-01-01,End=2024-01-31 \
    --granularity MONTHLY \
    --metrics BlendedCost

# Get cost by service
aws ce get-cost-and-usage \
    --time-period Start=2024-01-01,End=2024-01-31 \
    --granularity MONTHLY \
    --metrics BlendedCost \
    --group-by Type=DIMENSION,Key=SERVICE
```

## 🎓 Next Steps

After successful deployment:

1. 📚 Follow the [Learning Roadmap](LEARNING-ROADMAP.md)
2. 🛠️ Explore tool configurations in `configs/`
3. 🔒 Review [Security Guide](SECURITY.md)
4. 💰 Monitor costs with [Cost Optimization](COST-OPTIMIZATION.md)

---

**🎉 Congratulations! Your EKS Learning Lab is ready for exploration!**