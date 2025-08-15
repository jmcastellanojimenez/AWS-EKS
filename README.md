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

### Execution Model
**Manual Only** - Workflow configured for exclusive manual execution:
- ❌ No automatic execution on code push/PR
- ✅ Manual trigger via Actions tab → "Run workflow"  
- 🔒 Complete control over infrastructure changes
- ⚠️ **Note**: GitHub may run workflow once on initial push after creation (ignore this)

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

---

## 🌐 Workflow 2: Ingress + API Gateway Stack

**Purpose**: Deploy complete ingress and API gateway infrastructure on existing EKS cluster from Workflow 1.

### Prerequisites
- **Workflow 1 must be deployed first** - Requires existing EKS cluster
- Same GitHub secrets: `AWS_ROLE_ARN`, `AWS_REGION`, `AWS_ACCOUNT_ID`
- Optional: `CLOUDFLARE_API_TOKEN` for DNS management

### Execution Model
**Manual Only** - Same pattern as Workflow 1:
- ❌ No automatic execution on code push/PR
- ✅ Manual trigger via Actions tab → "Run workflow"
- 🔒 Complete control over infrastructure changes

### Workflow Inputs
| Input | Options | Default | Description |
|-------|---------|---------|-------------|
| `action` | plan, apply, destroy | plan | Infrastructure action to perform |
| `environment` | dev, staging, prod | dev | Target environment |
| `confirm_destroy` | string | - | Type "CONFIRM-DESTROY" for destroy action |
| `auto_approve` | boolean | false | Auto-approve apply (bypasses manual approval) |

### Components Deployed
1. **🔐 cert-manager** - CNCF project for automatic SSL certificates
   - Let's Encrypt integration (staging + production)
   - Resource allocation: ~100m CPU, ~128Mi memory
2. **🌍 external-dns** - Automatic DNS record management
   - Cloudflare integration using IRSA
   - Resource allocation: ~100m CPU, ~128Mi memory
3. **🚀 Ambassador** - API Gateway with AWS Network Load Balancer
   - Emissary-Ingress with production-grade settings
   - Resource allocation: ~1000m CPU, ~512Mi memory per replica

### Usage

#### 1. Plan Ingress Stack
```
Workflow: 🌐 Workflow 2: Ingress + API Gateway Stack
- action: plan
- environment: dev
```
**Result**: Terraform plan for ingress components

#### 2. Deploy Ingress Stack
```
Workflow: 🌐 Workflow 2: Ingress + API Gateway Stack
- action: apply
- environment: dev
- auto_approve: true
```
**Result**: Complete ingress and API gateway infrastructure

#### 3. Destroy Ingress Stack
```
Workflow: 🌐 Workflow 2: Ingress + API Gateway Stack
- action: destroy
- environment: dev
- confirm_destroy: CONFIRM-DESTROY
```
**Result**: Clean removal of ingress components (preserves Workflow 1)

### Workflow Jobs
1. **validate-inputs** - Input validation and destroy confirmation
2. **check-foundation** - Verifies Workflow 1 deployment exists
3. **terraform-operation** - Deploy cert-manager → external-dns → ambassador
4. **summary** - Deployment status and component information

### Resource Planning
**Total Workflow 2 allocation on t3.large nodes:**
- **CPU**: ~1.2 cores (420m request, 2.2 cores limit)
- **Memory**: ~768Mi (544Mi request, 768Mi limit)
- **Remaining capacity**: ~2.8 cores CPU, ~1.2Gi memory
- **Future workflows**: Ready for LGTM, ArgoCD, Security, Istio, Data services
- **Microservices**: Space for 5 services (256Mi/512Mi each, 3 replicas)

### Application Integration
Connect your applications using Ambassador Mapping CRDs:
```yaml
apiVersion: getambassador.io/v3alpha1
kind: Mapping
metadata:
  name: my-api-service
  namespace: default
spec:
  hostname: "api.yourdomain.com"
  prefix: "/api/v1/"
  service: "my-service:80"
  timeout_ms: 30000
```

### Safety Features
- Foundation Platform dependency check
- Same destroy confirmation and approval protection as Workflow 1
- Targeted deployment (only affects ingress components)
- Shared Terraform state with Workflow 1

### Next Steps After Deployment
1. Get Load Balancer hostname: `kubectl get svc ambassador -n ambassador`
2. Configure DNS records (or use external-dns automation)
3. Deploy applications with Ambassador Mappings
4. Ready for Workflows 3-7 deployment

---

## 📈 Workflow 3: LGTM Observability Stack

**Purpose**: Deploy complete observability infrastructure (monitoring, logging, tracing) using the LGTM stack for EcoTrack microservices.

### Prerequisites
- **Workflow 1 must be deployed first** - Requires existing EKS cluster with IRSA
- **Workflow 2 recommended** - Ambassador metrics integration available
- Same GitHub secrets: `AWS_ROLE_ARN`, `AWS_REGION`, `AWS_ACCOUNT_ID`
- Optional: `SLACK_WEBHOOK_URL` for alerting

### Execution Model
**Manual Only** - Same pattern as Workflows 1 & 2:
- ❌ No automatic execution on code push/PR
- ✅ Manual trigger via Actions tab → "Run workflow"
- 🔒 Complete control over infrastructure changes

### Components Deployed
1. **📊 Prometheus** - Metrics collection and short-term storage
   - Kubernetes service discovery with EcoTrack auto-discovery
   - Resource allocation: ~400m CPU, ~1024Mi memory
2. **💾 Mimir** - Long-term metrics storage with S3 backend
   - Unlimited retention with lifecycle policies
   - Resource allocation: ~300m CPU, ~512Mi memory
3. **📝 Loki** - Log aggregation with structured querying
   - Promtail for automatic log collection
   - Resource allocation: ~200m CPU, ~512Mi memory
4. **🔍 Tempo** - Distributed tracing (OpenTelemetry-compatible)
   - Object storage only, no database required
   - Resource allocation: ~150m CPU, ~256Mi memory
5. **📈 Grafana** - Unified dashboards and alerting
   - Pre-configured data sources and dashboards
   - Resource allocation: ~100m CPU, ~256Mi memory
6. **☁️ S3 Storage** - Unlimited data retention with lifecycle policies
   - Separate buckets for metrics, logs, and traces
   - Cost-optimized with IA/Glacier transitions

### Usage

#### 1. Plan Observability Stack
```
Workflow: 📈 Workflow 3: LGTM Observability Stack
- action: plan
- environment: dev
```
**Result**: Terraform plan for complete observability infrastructure

#### 2. Deploy Observability Stack
```
Workflow: 📈 Workflow 3: LGTM Observability Stack
- action: apply
- environment: dev
- auto_approve: true
```
**Result**: Complete LGTM stack with S3 storage and pre-configured dashboards

#### 3. Destroy Observability Stack
```
Workflow: 📈 Workflow 3: LGTM Observability Stack
- action: destroy
- environment: dev
- confirm_destroy: CONFIRM-DESTROY
```
**Result**: Clean removal of observability components (preserves Workflows 1 & 2)

### Resource Planning
**Total Workflow 3 allocation on t3.large nodes:**
- **CPU**: ~1.15 cores (1,250m request, 2.6 cores limit)
- **Memory**: ~2.6Gi (2,688Mi request, 5.1Gi limit)
- **S3 Storage**: ~10GB/month (~$0.25/month with lifecycle policies)
- **Remaining capacity**: ~1.65 cores CPU, ~0.5Gi memory per node
- **Future workflows**: Ready for GitOps, Security, Istio, Data services
- **EcoTrack microservices**: Space for 5 services with full observability

### Pre-configured Dashboards
- **Kubernetes Cluster Monitoring** - Node and cluster metrics
- **Kubernetes Pods Monitoring** - Pod performance and health
- **Spring Boot Applications** - JVM, HTTP, and custom business metrics
- **Ambassador API Gateway** - Traffic, latency, and error rates (if Workflow 2 deployed)
- **LGTM Stack Health** - Observability infrastructure monitoring

### EcoTrack Integration
**Automatic Discovery**: Prometheus automatically discovers microservices with annotations:
```yaml
annotations:
  prometheus.io/scrape: "true"
  prometheus.io/path: "/actuator/prometheus"
  prometheus.io/port: "8080"
```

**Tracing Integration**: OpenTelemetry endpoint for distributed tracing:
```yaml
env:
- name: OTEL_EXPORTER_OTLP_ENDPOINT
  value: "http://tempo.observability.svc.cluster.local:4317"
```

### Access Information
```bash
# Get Grafana password
kubectl get secret -n observability grafana-credentials -o jsonpath='{.data.admin-password}' | base64 -d

# Access Grafana
kubectl port-forward -n observability svc/grafana 3000:80
# URL: http://localhost:3000 (admin/<password>)

# Verify S3 storage
aws s3 ls | grep lgtm
```

### Alerting
- **Pre-configured alerts** for infrastructure and application metrics
- **Slack integration** via webhook (optional)
- **Critical alerts**: High CPU/memory, pod crashes, service downtime, high error rates

### Safety Features
- Foundation Platform dependency check
- Same destroy confirmation and approval protection as Workflows 1 & 2
- Targeted deployment (only affects observability components)  
- Shared Terraform state with existing workflows

### Next Steps After Deployment
1. Configure EcoTrack microservices with Prometheus annotations
2. Add OpenTelemetry instrumentation for distributed tracing
3. Set up custom Grafana alerts for business metrics
4. Monitor resource usage and adjust as needed
5. Ready for Workflows 4-7 deployment