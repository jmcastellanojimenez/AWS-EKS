# EKS Foundation Platform

## 🌐 VPC Infrastructure 🌐
✅ Public/private subnets (2+ AZs) - Required for:
  - Load balancers (Ambassador, Istio gateways)
  - Worker nodes in private subnets (security)
  - Multi-AZ deployment (high availability)
  
✅ Internet Gateway + Route tables - Required for:
  - External access to APIs
  - Container image pulls
  - External integrations (Stripe, SendGrid, etc.)

## 🏗️ EKS Cluster 🏗️
✅ Managed control plane - Handles:
  - All Kubernetes API operations
  - etcd management
  - Control plane scaling
  
✅ Managed node groups - Supports:
  - Auto-scaling for application load
  - Rolling updates for platform components
  - Cost optimization with spot instances

## 🔐 IAM & Security 🔐
✅ OIDC provider for IRSA - Required for:
  - ExternalSecret → OpenBao authentication
  - External-dns → Route53/Cloudflare access
  - S3 access for LGTM storage
  - Secure service account authentication
  
✅ Proper IAM roles - Enables:
  - Node group operations
  - Add-on management
  - AWS service integrations

## 📦 Essential Add-ons 📦
✅ vpc-cni - Foundation for:
  - Pod networking (required for all services)
  - Istio service mesh communication
  - Ambassador traffic routing
  
✅ kube-proxy - Required for:
  - Service discovery and load balancing
  - Platform component communication
  
✅ CoreDNS - Essential for:
  - Service name resolution
  - Microservice communication
  - External DNS resolution
  
✅ EBS CSI driver - Required for:
  - PostgreSQL persistent storage
  - Redis data persistence  
  - Kafka log storage
  - LGTM stack data retention

## 📊 Node Specifications:
- **Instance Type**: t3.large (2 vCPU, 8GB RAM)
- **Auto-scaling**: 3-5 nodes
- **Capacity Type**: SPOT instances for all environments
- **Region**: us-east-1 (US East - N. Virginia)

---

# Workflow Documentation

## 🏗️ Workflow 1: Foundation Platform

**Purpose**: Deploy essential EKS infrastructure with standardized worker node configuration.

### Prerequisites
- AWS CLI configured
- GitHub secrets configured:
  - `AWS_ROLE_ARN` - IAM role for GitHub Actions
  - `AWS_REGION` - Target AWS region (us-east-1)
  - `AWS_ACCOUNT_ID` - AWS account ID for S3 backend

### Workflow Inputs
| Input | Options | Default | Description |
|-------|---------|---------|-------------|
| `action` | plan, apply, destroy | plan | Infrastructure action to perform |
| `environment` | dev, staging, prod | dev | Target environment |
| `confirm_destroy` | string | - | Type "CONFIRM-DESTROY" for destroy action |
| `auto_approve` | boolean | false | Auto-approve apply (bypasses manual approval) |

### Usage

#### 1. Plan Infrastructure
```
Workflow: 🏗️ Workflow 1: Foundation Platform
- action: plan
- environment: dev
```
**Result**: Terraform plan generated for review

#### 2. Deploy Infrastructure
```
Workflow: 🏗️ Workflow 1: Foundation Platform  
- action: apply
- environment: dev
- auto_approve: true
```
**Result**: EKS cluster deployed with all essential components

#### 3. Destroy Infrastructure
```
Workflow: 🏗️ Workflow 1: Foundation Platform
- action: destroy
- environment: dev
- confirm_destroy: CONFIRM-DESTROY
```
**Result**: All infrastructure safely destroyed

### Workflow Jobs
1. **validate-inputs** - Input validation and destroy confirmation
2. **terraform-operation** - Core Terraform plan/apply/destroy operations
3. **summary** - Deployment status and cluster information

### Outputs
- **cluster-name** - EKS cluster name
- **cluster-endpoint** - Kubernetes API endpoint
- **kubectl configuration** - Automatically configured during apply

### Safety Features
- Destroy confirmation required (`CONFIRM-DESTROY`)
- Manual approval protection (unless `auto_approve=true`)
- Environment-specific settings
- Terraform state locking via DynamoDB

### Backend Configuration
- **S3 Bucket**: `eks-learning-lab-terraform-state-{AWS_ACCOUNT_ID}`
- **DynamoDB Table**: `eks-learning-lab-terraform-lock`
- **State Path**: `{environment}/terraform.tfstate`