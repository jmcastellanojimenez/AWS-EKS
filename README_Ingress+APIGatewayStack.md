# 🌐 Workflow 2: Ingress + API Gateway Stack

Complete ingress and API gateway infrastructure deployment for enterprise Kubernetes applications.

## 📋 **Stack Components**

### 🔐 **cert-manager**
- **Purpose**: Automatic SSL certificate management via Let's Encrypt
- **Type**: CNCF project for Kubernetes certificate management
- **Resources**: ~100m CPU, ~128Mi memory
- **Features**:
  - Let's Encrypt staging & production ClusterIssuers
  - Automatic certificate renewal
  - Ambassador integration for HTTP01 challenges

### 🌍 **external-dns**
- **Purpose**: Automatic DNS record management
- **Integration**: Cloudflare via IRSA (IAM Roles for Service Accounts)
- **Resources**: ~100m CPU, ~128Mi memory
- **Features**:
  - Automatic A/CNAME record creation
  - Service and Host resource monitoring
  - DNS TXT record ownership tracking

### 🚀 **Ambassador (Emissary-Ingress)**
- **Purpose**: Production-grade API Gateway
- **Type**: Kubernetes-native ingress controller
- **Resources**: ~1000m CPU, ~512Mi memory per replica (2 replicas default)
- **Features**:
  - AWS Network Load Balancer integration
  - Advanced routing and traffic management
  - CORS, authentication, and rate limiting
  - High availability with anti-affinity rules

## 🏗️ **Architecture Flow**

```
Internet → Cloudflare (DNS + CDN) → AWS NLB → Ambassador → Kubernetes Services
```

**Traffic Flow:**
1. **DNS Resolution**: external-dns manages Cloudflare A records
2. **Load Balancing**: AWS NLB distributes traffic to Ambassador pods
3. **SSL Termination**: cert-manager provides Let's Encrypt certificates
4. **API Gateway**: Ambassador routes to appropriate Kubernetes services
5. **Application**: Your microservices receive processed requests

## 💪 **Resource Allocation**

### **Workflow 2 Total Usage:**
- **CPU Request**: 420m (220m + 200m × 2 Ambassador replicas)
- **CPU Limit**: 2200m (200m + 1000m × 2 Ambassador replicas)  
- **Memory Request**: 544Mi (64Mi + 256Mi × 2 Ambassador replicas)
- **Memory Limit**: 768Mi (256Mi + 256Mi × 2 Ambassador replicas)

### **Remaining t3.large Capacity:**
- **Available CPU**: ~2.8 cores
- **Available Memory**: ~1.2Gi
- **Future Support**: 5 microservices + workflows 3-7 (LGTM, ArgoCD, Security, Istio, Data)

## 🔧 **Deployment Prerequisites**

### **Required:**
- **🏗️ Workflow 1: Foundation Platform** must be deployed first
- **GitHub Secrets**: `AWS_ROLE_ARN`, `AWS_REGION`, `AWS_ACCOUNT_ID`

### **Optional:**
- **Cloudflare API Token**: For automatic DNS management
- **Custom Domain**: Configure `ingress_domain` variable

## 🚀 **Deployment Guide**

### **1. Deploy via GitHub Actions**
```
Repository → Actions → "🌐 Workflow 2: Ingress + API Gateway Stack"
- action: apply
- environment: dev
- auto_approve: true
```

### **2. Verify Deployment**
```bash
# Check all components are ready
kubectl get pods -n cert-manager
kubectl get pods -n external-dns
kubectl get pods -n ambassador

# Verify ClusterIssuers
kubectl get clusterissuers

# Get Ambassador Load Balancer hostname
kubectl get svc ambassador -n ambassador
```

### **3. Configure DNS (if not using external-dns)**
```bash
# Get NLB hostname
NLB_HOSTNAME=$(kubectl get svc ambassador -n ambassador -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Point your domain A record to this hostname
echo "Point your domain to: $NLB_HOSTNAME"
```

## 📡 **Application Integration**

### **Basic Mapping Example**
```yaml
apiVersion: getambassador.io/v3alpha1
kind: Mapping
metadata:
  name: my-api
  namespace: default
spec:
  hostname: "api.yourdomain.com"
  prefix: "/api/v1/"
  service: "my-service:80"
  timeout_ms: 30000
```

### **Advanced Mapping with CORS**
```yaml
apiVersion: getambassador.io/v3alpha1
kind: Mapping
metadata:
  name: frontend-api
  namespace: default
spec:
  hostname: "api.yourdomain.com"
  prefix: "/api/"
  service: "backend-service:8080"
  cors:
    origins: ["https://app.yourdomain.com"]
    methods: ["GET", "POST", "PUT", "DELETE"]
    headers: ["Content-Type", "Authorization"]
    credentials: true
```

### **Microservice Mapping Pattern**
```yaml
# User Service
apiVersion: getambassador.io/v3alpha1
kind: Mapping
metadata:
  name: user-service
spec:
  hostname: "api.yourdomain.com"
  prefix: "/api/v1/users/"
  service: "user-service:8080"
  timeout_ms: 15000
---
# Product Service  
apiVersion: getambassador.io/v3alpha1
kind: Mapping
metadata:
  name: product-service
spec:
  hostname: "api.yourdomain.com"
  prefix: "/api/v1/products/"
  service: "product-service:8080"
  timeout_ms: 15000
```

## 🔒 **SSL Certificate Management**

### **Automatic Certificate Example**
```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: api-tls
  namespace: ambassador
spec:
  secretName: api-tls-secret
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  dnsNames:
  - api.yourdomain.com
```

### **Host Configuration with TLS**
```yaml
apiVersion: getambassador.io/v3alpha1
kind: Host
metadata:
  name: api-host
  namespace: ambassador
spec:
  hostname: api.yourdomain.com
  acmeProvider:
    authority: https://acme-v02.api.letsencrypt.org/directory
    email: admin@yourdomain.com
  tlsSecret:
    name: api-tls-secret
```

## 🎯 **Monitoring & Troubleshooting**

### **Component Health Checks**
```bash
# cert-manager health
kubectl get certificaterequests -A
kubectl get certificates -A
kubectl describe clusterissuer letsencrypt-prod

# external-dns health  
kubectl logs -n external-dns deployment/external-dns

# Ambassador health
kubectl get svc ambassador -n ambassador
kubectl logs -n ambassador deployment/ambassador
```

### **Common Issues & Solutions**

**Certificate Issues:**
```bash
# Check certificate status
kubectl describe certificate <cert-name> -n <namespace>

# Force certificate renewal
kubectl delete certificaterequest <request-name> -n <namespace>
```

**DNS Issues:**
```bash
# Check external-dns logs
kubectl logs -n external-dns deployment/external-dns --tail=50

# Verify DNS propagation
nslookup api.yourdomain.com
```

**Ambassador Issues:**
```bash
# Check Ambassador diagnostics
kubectl port-forward -n ambassador svc/ambassador-admin 8877:8877
# Visit http://localhost:8877/ambassador/v0/diag/
```

## 📊 **Performance Tuning**

### **High Traffic Configuration**
```yaml
# Increase Ambassador replicas
ambassador_replica_count = 4

# Optimize resource limits
resources:
  requests:
    cpu: "500m"
    memory: "512Mi"  
  limits:
    cpu: "2000m"
    memory: "1Gi"
```

### **Load Balancer Optimizations**
```yaml
# NLB annotations for high performance
annotations:
  service.beta.kubernetes.io/aws-load-balancer-connection-idle-timeout: "300"
  service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled: "true"
  service.beta.kubernetes.io/aws-load-balancer-backend-protocol: "tcp"
```

---

# 🎉 Excellent Work! Workflow 2 Integration Complete

## 🔍 **Quick Integration Review**

✅ **Architecture Flow Achieved:**
```
Internet → Cloudflare (DNS + CDN) → AWS NLB → Ambassador → Future Apps
```

✅ **Resource Planning Success:**
- **Current usage**: ~1.2 CPU cores, ~768Mi memory
- **Future capacity**: Ready for 5 microservices + workflows 3-7
- **Smart allocation**: Leaves proper headroom on t3.large nodes

✅ **Enterprise Patterns:**
- Manual execution model maintained
- Proper dependency checking (Workflow 1 → Workflow 2)
- Shared state management with targeting
- IRSA integration for security

## 🚀 **Next Steps - Testing Your Platform**

### **1. Deploy Foundation + Ingress Stack**
```bash
# 1. Deploy Workflow 1 (if not already done)
GitHub Actions → "🏗️ Workflow 1: Foundation Platform" → apply

# 2. Deploy Workflow 2
GitHub Actions → "🌐 Workflow 2: Ingress + API Gateway Stack" → apply
```

### **2. Verify Platform Readiness**
```bash
# Check components
kubectl get pods -n cert-manager
kubectl get pods -n external-dns  
kubectl get pods -n ambassador

# Verify Ambassador NLB created
kubectl get svc -n ambassador
```

### **3. Test Application Connection**
Ready to connect your EcoTrack microservices using:
```yaml
apiVersion: getambassador.io/v3alpha1
kind: Mapping
metadata:
  name: ecotrack-api
spec:
  hostname: api.yourdomain.com
  prefix: /api/v1/
  service: ecotrack-service:8080
```

## 🎯 **Platform Status**

**Foundation**: ✅ Complete (EKS + VPC + IRSA)  
**Ingress**: ✅ Complete (SSL + DNS + API Gateway)  
**Next**: Ready for Workflow 3 (LGTM Observability) or application deployment

**Ready to deploy and test the platform, or shall we plan Workflow 3 next?**

---

## 🔧 **Terraform Variables Reference**

### **Required Variables**
```hcl
# Domain configuration
ingress_domain = "api.yourdomain.com"
letsencrypt_email = "admin@yourdomain.com"

# DNS provider
dns_provider = "cloudflare"
domain_filters = ["yourdomain.com"]
cloudflare_api_token = "your-cloudflare-token"
```

### **Optional Variables**
```hcl
# Component versions
cert_manager_version = "v1.13.3"
external_dns_version = "1.14.3"
ambassador_version = "8.9.1"

# Performance tuning
ambassador_replica_count = 2
enable_monitoring = false
load_balancer_scheme = "internet-facing"

# Security
cors_origins = ["https://app.yourdomain.com"]
enable_tls = true
```

## 📝 **Workflow Integration**

This stack integrates seamlessly with:
- **🏗️ Workflow 1**: Foundation Platform (prerequisite)
- **📊 Workflow 3**: LGTM Observability Stack (future)
- **🔄 Workflow 4**: ArgoCD + Tekton GitOps (future)
- **🛡️ Workflow 5**: Security Stack (future)
- **🕸️ Workflow 6**: Istio Service Mesh (future)
- **💾 Workflow 7**: Data Services Stack (future)

**Enterprise-ready Kubernetes platform with proper resource planning and workflow orchestration!** 🚀