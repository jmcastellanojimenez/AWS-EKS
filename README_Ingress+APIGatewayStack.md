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

## 🔧 **Environment Configuration**

### **Environment-Specific Settings**
Configure different settings per environment for proper deployment lifecycle:

```yaml
# Development Environment
dev:
  ingress_domain: "dev-api.yourdomain.com"
  certificate_issuer: "letsencrypt-staging"  # Use staging for testing
  ambassador_replica_count: 1               # Single replica for dev
  enable_monitoring: false                  # Reduced overhead
  log_level: "debug"                       # Verbose logging
  cors_origins: ["*"]                      # Permissive CORS for development

# Production Environment  
prod:
  ingress_domain: "api.yourdomain.com"
  certificate_issuer: "letsencrypt-prod"   # Production certificates
  ambassador_replica_count: 3              # High availability
  enable_monitoring: true                  # Full observability
  log_level: "info"                       # Production logging
  cors_origins: ["https://app.yourdomain.com"]  # Restricted CORS

# Staging Environment
staging:
  ingress_domain: "staging-api.yourdomain.com"
  certificate_issuer: "letsencrypt-staging"
  ambassador_replica_count: 2
  enable_monitoring: true
  log_level: "info"
  cors_origins: ["https://staging-app.yourdomain.com"]
```

### **Terraform Variable Examples**
```hcl
# terraform.tfvars for dev
ingress_domain = "dev-api.yourdomain.com"
enable_letsencrypt = true
letsencrypt_email = "admin@yourdomain.com"
ambassador_replica_count = 1
enable_monitoring = false
dns_provider = "cloudflare"
domain_filters = ["yourdomain.com"]

# terraform.tfvars for prod
ingress_domain = "api.yourdomain.com"
enable_letsencrypt = true
letsencrypt_email = "admin@yourdomain.com"
ambassador_replica_count = 3
enable_monitoring = true
load_balancer_scheme = "internet-facing"
cors_origins = ["https://app.yourdomain.com"]
```

---

## 🛡️ **Security Best Practices**

### **Rate Limiting Configuration**
Implement proper rate limiting to protect your APIs:

```yaml
# Basic Rate Limiting Mapping
apiVersion: getambassador.io/v3alpha1
kind: RateLimitService
metadata:
  name: basic-rate-limit
  namespace: ambassador
spec:
  service: "ratelimit:5000"
---
apiVersion: getambassador.io/v3alpha1
kind: Mapping
metadata:
  name: api-with-rate-limit
spec:
  hostname: "api.yourdomain.com"
  prefix: "/api/v1/"
  service: "backend-service:8080"
  rate_limits:
  - descriptor:
    - key: "generic_key"
      value: "basic"
    rate_limit:
      unit: "minute"
      requests_per_unit: 100  # 100 requests/minute per IP
```

### **Advanced Rate Limiting Examples**
```yaml
# Authenticated User Rate Limiting
apiVersion: getambassador.io/v3alpha1
kind: Mapping
metadata:
  name: authenticated-api
spec:
  hostname: "api.yourdomain.com"
  prefix: "/api/v1/user/"
  service: "user-service:8080"
  rate_limits:
  - descriptor:
    - key: "user_id"
      value: "authenticated"
    rate_limit:
      unit: "minute"
      requests_per_unit: 1000  # 1000 requests/minute per authenticated user

---
# Admin Endpoints - Stricter Limits
apiVersion: getambassador.io/v3alpha1
kind: Mapping
metadata:
  name: admin-api
spec:
  hostname: "api.yourdomain.com"
  prefix: "/api/v1/admin/"
  service: "admin-service:8080"
  rate_limits:
  - descriptor:
    - key: "remote_address"
      value: "admin"
    rate_limit:
      unit: "minute"
      requests_per_unit: 10    # 10 requests/minute per IP for admin
```

### **Security Headers**
```yaml
# Security Headers via Ambassador
apiVersion: getambassador.io/v3alpha1
kind: Mapping
metadata:
  name: secure-api
spec:
  hostname: "api.yourdomain.com"
  prefix: "/api/"
  service: "backend-service:8080"
  add_response_headers:
    X-Content-Type-Options: "nosniff"
    X-Frame-Options: "DENY"
    X-XSS-Protection: "1; mode=block"
    Strict-Transport-Security: "max-age=31536000; includeSubDomains"
    Content-Security-Policy: "default-src 'self'"
```

### **IP Allowlisting**
```yaml
# Restrict access to specific IPs
apiVersion: getambassador.io/v3alpha1
kind: Mapping
metadata:
  name: restricted-api
spec:
  hostname: "api.yourdomain.com"
  prefix: "/api/v1/internal/"
  service: "internal-service:8080"
  bypass_auth: true
  modules:
  - name: "ip-allow"
    config:
      ip_allow:
      - "10.0.0.0/8"      # Private networks
      - "192.168.0.0/16"  # Private networks
      - "172.16.0.0/12"   # Private networks
      ip_deny: ["0.0.0.0/0"]  # Deny all others
```

---

## 🔗 **Integration with Future Workflows**

### **Forward Compatibility Planning**

#### **🏗️ Workflow 3 (LGTM Observability Stack)**
Ambassador automatically exposes metrics for monitoring integration:

```yaml
# Automatic Prometheus metrics exposure
# Metrics available at: http://ambassador-admin:8877/metrics
# Future LGTM stack will automatically discover and scrape these

# Key metrics exposed:
- envoy_http_downstream_rq_total
- envoy_cluster_upstream_rq_retry  
- envoy_cluster_upstream_rq_pending
- ambassador_edge_stack_go_*
```

#### **🔄 Workflow 4 (ArgoCD + Tekton GitOps)**
Ambassador Mappings integrate seamlessly with GitOps:

```yaml
# GitOps-ready Mapping structure
apiVersion: getambassador.io/v3alpha1
kind: Mapping
metadata:
  name: gitops-managed-service
  namespace: production
  labels:
    app.kubernetes.io/managed-by: "argocd"
    app.kubernetes.io/part-of: "microservices-platform"
spec:
  hostname: "api.yourdomain.com"
  prefix: "/api/v1/orders/"
  service: "orders-service:8080"
  # ArgoCD will manage updates to this mapping
```

#### **🛡️ Workflow 5 (Security Stack)**
Ambassador integrates with security tools:

```yaml
# External Auth Integration (future)
apiVersion: getambassador.io/v3alpha1
kind: Mapping
metadata:
  name: auth-protected-api
spec:
  hostname: "api.yourdomain.com"
  prefix: "/api/v1/protected/"
  service: "protected-service:8080"
  # Future: Integration with OAuth2-Proxy, Keycloak, etc.
  auth_service: "oauth2-proxy.security:4180"
```

#### **🕸️ Workflow 6 (Istio Service Mesh)**
Ambassador + Istio integration patterns:

```yaml
# Istio Integration Mode
# Ambassador handles north-south traffic (ingress)
# Istio handles east-west traffic (service-to-service)

# Edge routing via Ambassador
apiVersion: getambassador.io/v3alpha1
kind: Mapping
metadata:
  name: istio-mesh-entry
spec:
  hostname: "api.yourdomain.com"
  prefix: "/api/"
  service: "istio-proxy.istio-system:80"  # Route to Istio Gateway
  
# Istio takes over internal routing
# Benefits: mTLS, circuit breaking, retries, observability
```

#### **💾 Workflow 7 (Data Services Stack)**
Database and cache service exposure:

```yaml
# Database Admin Interfaces (secured)
apiVersion: getambassador.io/v3alpha1
kind: Mapping
metadata:
  name: pgadmin-interface
spec:
  hostname: "admin.yourdomain.com"
  prefix: "/pgadmin/"
  service: "pgadmin:80"
  # Future: Integration with database authentication
  
# API endpoints for data services
apiVersion: getambassador.io/v3alpha1
kind: Mapping
metadata:
  name: data-api
spec:
  hostname: "api.yourdomain.com"
  prefix: "/api/v1/data/"
  service: "data-service:8080"
  timeout_ms: 60000  # Longer timeout for data operations
```

### **Microservices Integration Patterns**

#### **Multi-Service Routing**
```yaml
# Pattern for 5 planned microservices
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

---
# Order Service
apiVersion: getambassador.io/v3alpha1
kind: Mapping
metadata:
  name: order-service
spec:
  hostname: "api.yourdomain.com"
  prefix: "/api/v1/orders/"
  service: "order-service:8080"
  timeout_ms: 30000  # Orders may take longer

---
# Payment Service
apiVersion: getambassador.io/v3alpha1
kind: Mapping
metadata:
  name: payment-service
spec:
  hostname: "api.yourdomain.com"
  prefix: "/api/v1/payments/"
  service: "payment-service:8080"
  timeout_ms: 45000  # Payment processing timeout

---
# Notification Service
apiVersion: getambassador.io/v3alpha1
kind: Mapping
metadata:
  name: notification-service
spec:
  hostname: "api.yourdomain.com"
  prefix: "/api/v1/notifications/"
  service: "notification-service:8080"
  timeout_ms: 10000  # Fast notifications
```

### **Resource Planning for Future Workflows**

#### **Current Platform Capacity (t3.large nodes):**
```yaml
# Total cluster capacity: ~6 CPU cores, ~7.5Gi memory per node (3-5 nodes)
# Workflow 1 (Foundation): ~0.5 CPU cores, ~1Gi memory
# Workflow 2 (Ingress): ~1.2 CPU cores, ~768Mi memory
# Remaining: ~2.8 CPU cores, ~1.2Gi memory per node

# Future workflow allocations:
Workflow_3_LGTM:
  prometheus: "500m CPU, 512Mi memory"
  grafana: "100m CPU, 128Mi memory"
  loki: "300m CPU, 256Mi memory"
  
Workflow_4_GitOps:
  argocd: "200m CPU, 256Mi memory"
  tekton: "300m CPU, 512Mi memory"
  
Workflow_5_Security:
  falco: "100m CPU, 128Mi memory"
  oauth2_proxy: "50m CPU, 64Mi memory"
  
Workflow_6_Istio:
  istiod: "500m CPU, 512Mi memory"
  istio_proxy: "100m CPU, 128Mi memory per service"
  
Workflow_7_Data:
  postgresql: "200m CPU, 512Mi memory"
  redis: "100m CPU, 128Mi memory"
  
Microservices_5x:
  each_service: "300m CPU, 512Mi memory (3 replicas)"
  total: "4.5 CPU, 7.5Gi memory"

# Total future needs: ~7 CPU cores, ~11Gi memory
# Platform auto-scaling: 3-5 nodes provides ~18-30 CPU cores, ~22-37Gi memory
# Conclusion: Platform can handle all planned workloads with headroom
```

**🚀 The Ingress + API Gateway Stack is future-ready for all planned workflows and microservices!**
