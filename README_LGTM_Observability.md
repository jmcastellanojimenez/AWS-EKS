# 📈 Workflow 3: LGTM Observability Stack

Complete observability infrastructure for enterprise Kubernetes applications using the LGTM stack (Loki, Grafana, Tempo, Mimir) with Prometheus.

## 📋 **Stack Overview**

The LGTM Observability Stack provides comprehensive monitoring, logging, and tracing capabilities for your EKS cluster and EcoTrack microservices. Built on proven CNCF technologies with enterprise-grade S3 storage backends.

### 🔄 **Data Flow Architecture**

```
EcoTrack Microservices → [Collection Layer] → [Storage Layer] → [Visualization Layer]
                      ↓                    ↓                  ↓
               Metrics: /actuator/prometheus → Prometheus → Mimir → S3
                 Logs: Container logs → Promtail → Loki → S3
               Traces: OpenTelemetry → Tempo → S3
                      ↓                    ↓                  ↓
                              Grafana Dashboards & Alerts
```

## 🏗️ **Stack Components**

### 📊 **Prometheus - Metrics Collection**
- **Purpose**: Real-time metrics collection and short-term storage
- **Version**: 25.8.0 (Helm chart)
- **Resources**: 400m CPU, 1024Mi memory (requests)
- **Features**:
  - Kubernetes service discovery
  - EcoTrack microservices auto-discovery via annotations
  - AlertManager integration
  - 7-day local retention (configurable)

### 💾 **Mimir - Long-term Metrics Storage**
- **Purpose**: Unlimited metrics storage and querying
- **Version**: 5.1.4 (Helm chart)
- **Resources**: 300m CPU, 512Mi memory (requests)
- **Features**:
  - S3 backend for unlimited retention
  - Multi-tenancy support
  - Compatible with Prometheus APIs
  - Automatic compaction and lifecycle management

### 📝 **Loki - Log Aggregation**
- **Purpose**: Structured log storage and querying
- **Version**: 5.36.2 (Helm chart)
- **Resources**: 200m CPU, 512Mi memory (requests)
- **Features**:
  - LogQL query language
  - S3 storage backend
  - Automatic log discovery via Promtail
  - Label-based indexing for efficiency

### 🔍 **Tempo - Distributed Tracing**
- **Purpose**: Request tracing across microservices
- **Version**: 1.7.1 (Helm chart)
- **Resources**: 150m CPU, 256Mi memory (requests)
- **Features**:
  - OpenTelemetry-compatible
  - S3-only storage (no database required)
  - Trace correlation with logs and metrics
  - Jaeger and Zipkin protocol support

### 📈 **Grafana - Unified Dashboards**
- **Purpose**: Visualization, alerting, and observability hub
- **Version**: 7.0.11 (Helm chart)
- **Resources**: 100m CPU, 256Mi memory (requests)
- **Features**:
  - Pre-configured data sources
  - Built-in dashboards for Kubernetes and Spring Boot
  - Unified alerting with Slack integration
  - RBAC and multi-user support

### 📄 **Promtail - Log Collection**
- **Purpose**: Log shipping from Kubernetes to Loki
- **Included**: Part of Loki stack
- **Resources**: 50m CPU, 128Mi memory per node
- **Features**:
  - Automatic Kubernetes log discovery
  - Label extraction and processing
  - Multiple output targets

## 💪 **Resource Planning**

### **Total Stack Usage (per t3.large node):**
- **CPU Requests**: 1,250m (1.25 cores)
- **Memory Requests**: 2,688Mi (~2.6Gi)
- **CPU Limits**: 2,600m (2.6 cores)  
- **Memory Limits**: 5,248Mi (~5.1Gi)

### **Remaining Capacity (3-5 node cluster):**
- **Available CPU**: ~4.75 cores per node
- **Available Memory**: ~2.4Gi per node
- **Future Support**: Sufficient for all remaining workflows + 5 EcoTrack microservices

### **S3 Storage Costs (estimated):**
- **Data Volume**: ~10GB/month for 5 microservices
- **Cost**: ~$0.25/month with lifecycle policies
- **Retention**: 7 days Standard → IA → Glacier → 365 days expiration

## 🔧 **Prerequisites**

### **Required Infrastructure:**
- ✅ **Workflow 1: Foundation Platform** - Must be deployed first
- ✅ **IRSA OIDC Provider** - For S3 access without keys
- ✅ **EBS CSI Driver** - For persistent volumes

### **Optional Integration:**
- **Workflow 2: Ingress + API Gateway** - For Ambassador metrics
- **Cloudflare/Route53** - For custom Grafana domains

### **GitHub Secrets (Existing):**
- `AWS_ROLE_ARN` - IAM role for GitHub Actions
- `AWS_REGION` - Target AWS region (us-east-1)
- `AWS_ACCOUNT_ID` - AWS account ID for S3 buckets

### **Optional Secrets:**
- `SLACK_WEBHOOK_URL` - For Grafana alerting

## 🚀 **Deployment Guide**

### **1. Deploy via GitHub Actions**
```
Repository → Actions → "📈 Workflow 3: LGTM Observability Stack"
Input Configuration:
- action: apply
- environment: dev
- auto_approve: true
```

### **2. Verify Deployment**
```bash
# Check all observability pods
kubectl get pods -n observability

# Verify component health
kubectl get pods -n observability -l app=prometheus-server
kubectl get pods -n observability -l app.kubernetes.io/name=grafana
kubectl get pods -n observability -l app=loki
kubectl get pods -n observability -l app.kubernetes.io/name=tempo
kubectl get pods -n observability -l app.kubernetes.io/name=mimir

# Check services
kubectl get svc -n observability
```

### **3. Access Grafana Dashboard**
```bash
# Get admin password
kubectl get secret -n observability grafana-credentials -o jsonpath='{.data.admin-password}' | base64 -d

# Port-forward to access locally
kubectl port-forward -n observability svc/grafana 3000:80

# Access: http://localhost:3000
# Login: admin / <password-from-above>
```

### **4. Verify S3 Storage**
```bash
# List LGTM S3 buckets
aws s3 ls | grep lgtm

# Check bucket contents (after some data flows in)
aws s3 ls dev-lgtm-prometheus-$AWS_ACCOUNT_ID/
aws s3 ls dev-lgtm-loki-$AWS_ACCOUNT_ID/
aws s3 ls dev-lgtm-tempo-$AWS_ACCOUNT_ID/
```

## 📡 **EcoTrack Integration**

### **Microservices Configuration**

#### **1. Prometheus Metrics**
Add these annotations to your EcoTrack deployment manifests:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: user-service
spec:
  template:
    metadata:
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/path: "/actuator/prometheus"
        prometheus.io/port: "8080"
    spec:
      containers:
      - name: user-service
        ports:
        - containerPort: 8080
          name: http
```

#### **2. Spring Boot Actuator**
Ensure your `application.yml` includes:
```yaml
management:
  endpoints:
    web:
      exposure:
        include: health,info,prometheus
  endpoint:
    health:
      show-details: always
  metrics:
    export:
      prometheus:
        enabled: true
```

#### **3. OpenTelemetry Tracing**
Add to your Spring Boot applications:
```xml
<!-- pom.xml -->
<dependency>
    <groupId>io.opentelemetry.instrumentation</groupId>
    <artifactId>opentelemetry-spring-boot-starter</artifactId>
</dependency>
```

Environment variables for trace export:
```yaml
env:
- name: OTEL_EXPORTER_OTLP_ENDPOINT
  value: "http://tempo.observability.svc.cluster.local:4317"
- name: OTEL_SERVICE_NAME
  value: "user-service"
- name: OTEL_RESOURCE_ATTRIBUTES
  value: "service.namespace=ecotrack,service.version=1.0.0"
```

### **Microservice Deployment Example**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: user-service
  namespace: ecotrack
  labels:
    app.kubernetes.io/name: user-service
    app.kubernetes.io/part-of: ecotrack
spec:
  replicas: 3
  selector:
    matchLabels:
      app.kubernetes.io/name: user-service
  template:
    metadata:
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/path: "/actuator/prometheus"
        prometheus.io/port: "8080"
      labels:
        app.kubernetes.io/name: user-service
        app.kubernetes.io/part-of: ecotrack
    spec:
      containers:
      - name: user-service
        image: ecotrack/user-service:1.0.0
        ports:
        - containerPort: 8080
          name: http
        env:
        - name: OTEL_EXPORTER_OTLP_ENDPOINT
          value: "http://tempo.observability.svc.cluster.local:4317"
        - name: OTEL_SERVICE_NAME
          value: "user-service"
        - name: OTEL_RESOURCE_ATTRIBUTES
          value: "service.namespace=ecotrack,service.version=1.0.0"
        resources:
          requests:
            cpu: 100m
            memory: 256Mi
          limits:
            cpu: 300m
            memory: 512Mi
        livenessProbe:
          httpGet:
            path: /actuator/health
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /actuator/health/readiness
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5
```

## 📊 **Pre-configured Dashboards**

### **1. Kubernetes Cluster Overview (ID: 7249)**
- **Metrics**: Node CPU, memory, disk usage
- **Network**: Pod network I/O, cluster network policy
- **Resources**: Resource quotas, limit ranges
- **Access**: Grafana → Dashboards → Kubernetes Cluster

### **2. Kubernetes Pods Monitoring (ID: 6336)**
- **Pod Metrics**: CPU, memory, restart count
- **Resource Usage**: Requests vs limits
- **Health**: Readiness and liveness probe status
- **Access**: Grafana → Dashboards → Kubernetes Pods

### **3. Spring Boot Applications (ID: 12900)**
- **JVM Metrics**: Heap usage, GC performance, thread count
- **HTTP Metrics**: Request rate, response time, error rate
- **Database**: Connection pool, query performance
- **Custom Metrics**: Business logic metrics from EcoTrack
- **Access**: Grafana → Dashboards → Spring Boot Statistics

### **4. Ambassador API Gateway (ID: 13758)** *(if Workflow 2 deployed)*
- **Traffic Metrics**: Request volume, latency percentiles
- **Error Rates**: 4xx/5xx responses, upstream failures
- **Load Balancing**: Backend health, connection pools
- **Access**: Grafana → Dashboards → Ambassador Edge Stack

### **5. LGTM Stack Health** *(custom dashboard)*
- **Prometheus**: Scrape health, cardinality, ingestion rate
- **Loki**: Log ingestion rate, query performance
- **Tempo**: Trace ingestion, query latency
- **Grafana**: Dashboard usage, alert status

## 🔔 **Alerting Configuration**

### **Critical Alerts (Pre-configured)**

#### **Infrastructure Alerts:**
```yaml
# High CPU Usage
alert: NodeCPUUsage
expr: 100 - (avg(rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
for: 5m

# High Memory Usage  
alert: NodeMemoryUsage
expr: (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100 > 80
for: 5m

# Pod Restart Loop
alert: PodCrashLoop
expr: rate(kube_pod_container_status_restarts_total[15m]) > 0
for: 5m
```

#### **Application Alerts:**
```yaml
# High Error Rate
alert: HighErrorRate
expr: rate(http_requests_total{status=~"5.."}[5m]) / rate(http_requests_total[5m]) > 0.1
for: 2m

# High Response Time
alert: HighLatency
expr: histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m])) > 1
for: 5m

# Service Down
alert: ServiceDown
expr: up{job=~".*ecotrack.*"} == 0
for: 1m
```

### **Slack Integration**
Configure via GitHub secret `SLACK_WEBHOOK_URL`:
```yaml
# Grafana Alert Notification Channel
name: "EcoTrack Alerts"
type: "slack"
settings:
  url: "$SLACK_WEBHOOK_URL"
  channel: "#ecotrack-alerts"
  title: "EcoTrack Alert"
  text: "{{ range .Alerts }}{{ .Annotations.summary }}{{ end }}"
```

## 🎯 **Monitoring Queries**

### **Key Metrics for EcoTrack**

#### **Business Metrics:**
```promql
# User Registration Rate
rate(ecotrack_users_registered_total[5m])

# Product Views
rate(ecotrack_product_views_total[5m])

# Order Success Rate
rate(ecotrack_orders_completed_total[5m]) / rate(ecotrack_orders_total[5m])

# Payment Processing Time
histogram_quantile(0.95, rate(ecotrack_payment_duration_seconds_bucket[5m]))
```

#### **Technical Metrics:**
```promql
# Request Rate per Service
rate(http_requests_total{job=~".*ecotrack.*"}[5m])

# Error Rate per Service
rate(http_requests_total{job=~".*ecotrack.*",status=~"5.."}[5m])

# Database Connection Pool
hikaricp_connections_active{job=~".*ecotrack.*"}

# JVM Memory Usage
jvm_memory_used_bytes{job=~".*ecotrack.*",area="heap"} / jvm_memory_max_bytes{job=~".*ecotrack.*",area="heap"}
```

#### **Log Queries (LogQL):**
```logql
# Error Logs from All EcoTrack Services
{namespace="ecotrack"} |= "ERROR"

# Database Connection Errors
{namespace="ecotrack"} |= "Connection" |= "timeout" or "refused"

# Payment Service Specific Logs
{namespace="ecotrack",app="payment-service"} |= "payment"

# Slow Query Detection
{namespace="ecotrack"} |~ "slow.*query|query.*slow" | logfmt | duration > 1s
```

## 🛠️ **Troubleshooting Guide**

### **Common Issues & Solutions**

#### **1. Prometheus Not Scraping Metrics**
```bash
# Check Prometheus targets
kubectl port-forward -n observability svc/prometheus-server 9090:80
# Visit: http://localhost:9090/targets

# Verify service annotations
kubectl get pods -n ecotrack -o yaml | grep -A 5 annotations

# Check service discovery
kubectl logs -n observability deployment/prometheus-server
```

#### **2. Grafana Data Source Connection**
```bash
# Test Prometheus connectivity
kubectl exec -n observability deployment/grafana -- curl -s http://prometheus-server/api/v1/label/__name__/values

# Check Grafana logs
kubectl logs -n observability deployment/grafana

# Verify data source configuration
kubectl get configmap -n observability grafana-datasources -o yaml
```

#### **3. Loki Not Receiving Logs**
```bash
# Check Promtail status
kubectl get pods -n observability -l app=promtail

# Verify log ingestion
kubectl port-forward -n observability svc/loki 3100:3100
curl -s "http://localhost:3100/loki/api/v1/label/app/values"

# Check Promtail configuration
kubectl logs -n observability daemonset/loki-promtail
```

#### **4. Tempo Tracing Issues**
```bash
# Verify trace ingestion
kubectl port-forward -n observability svc/tempo 3100:3100
curl -s "http://localhost:3100/api/search"

# Check OpenTelemetry configuration in apps
kubectl get pods -n ecotrack -o yaml | grep -A 5 OTEL_

# Test trace connectivity
kubectl exec -n ecotrack deployment/user-service -- curl -s http://tempo.observability.svc.cluster.local:4317
```

#### **5. S3 Storage Access Issues**
```bash
# Check IRSA roles
kubectl get serviceaccounts -n observability -o yaml | grep eks.amazonaws.com/role-arn

# Verify S3 bucket access
kubectl exec -n observability deployment/loki -- aws s3 ls s3://dev-lgtm-loki-$AWS_ACCOUNT_ID/

# Check IAM policies
aws iam get-role --role-name eks-learning-lab-dev-loki-role
```

#### **6. High Resource Usage**
```bash
# Check resource consumption
kubectl top pods -n observability

# Scale down non-essential components
kubectl patch deployment prometheus-alertmanager -n observability -p '{"spec":{"replicas":0}}'

# Adjust retention policies
kubectl patch configmap prometheus-server -n observability --patch='{"data":{"prometheus.yml":"...(reduce retention)..."}}'
```

### **Performance Optimization**

#### **For High-Traffic Environments:**
```yaml
# Increase Prometheus resources
prometheus_resources:
  requests:
    cpu: "800m"
    memory: "2Gi"
  limits:
    cpu: "1500m" 
    memory: "4Gi"

# Scale Grafana replicas
grafana:
  replicas: 3

# Optimize Mimir for scale
mimir:
  ingester:
    replicas: 3
  distributor:
    replicas: 3
```

#### **For Development Environments:**
```yaml
# Reduce resource usage
prometheus_resources:
  requests:
    cpu: "200m"
    memory: "512Mi"

# Disable non-essential components
enable_mimir: false
enable_tempo: false

# Shorter retention
prometheus_retention: "3d"
```

## 🔗 **Integration with Future Workflows**

### **Workflow 4: GitOps (ArgoCD + Tekton)**
- **Metrics**: ArgoCD application health, sync status
- **Logs**: GitOps pipeline logs and events
- **Traces**: CI/CD pipeline execution traces
- **Dashboards**: Pre-configured ArgoCD dashboards

### **Workflow 5: Security Stack**
- **Metrics**: Security policy violations, Falco alerts
- **Logs**: Audit logs, security events
- **Alerts**: Critical security incidents
- **Integration**: SIEM log forwarding

### **Workflow 6: Istio Service Mesh**
- **Metrics**: Service mesh traffic, latency, error rates
- **Traces**: Enhanced distributed tracing through sidecar proxies
- **Observability**: mTLS certificate status, traffic policies
- **Dashboards**: Istio service topology and performance

### **Workflow 7: Data Services**
- **Metrics**: Database performance, cache hit rates
- **Logs**: Database query logs, data pipeline logs
- **Monitoring**: Data quality metrics, ETL job health
- **Alerts**: Database connection issues, data anomalies

---

## 🎯 **Success Criteria Checklist**

- [ ] **All LGTM components deployed** and pods in Running state
- [ ] **S3 buckets created** with proper lifecycle policies
- [ ] **Grafana accessible** via port-forward with admin credentials
- [ ] **Data sources configured** (Prometheus, Loki, Tempo, Mimir)
- [ ] **Pre-built dashboards** showing cluster and application metrics
- [ ] **Prometheus discovering** EcoTrack microservices automatically
- [ ] **Logs flowing** from applications to Loki via Promtail
- [ ] **Traces collecting** from OpenTelemetry-instrumented services
- [ ] **Alerting functional** with Slack notification testing
- [ ] **Resource usage** within planned capacity (~1.2 CPU, ~2.5Gi memory)

---

## 📚 **Additional Resources**

### **Documentation Links:**
- [Prometheus Operator](https://prometheus-operator.dev/)
- [Grafana Dashboards](https://grafana.com/grafana/dashboards/)
- [Loki LogQL](https://grafana.com/docs/loki/latest/logql/)
- [Tempo Tracing](https://grafana.com/docs/tempo/latest/)
- [Mimir Architecture](https://grafana.com/docs/mimir/latest/)

### **Community Resources:**
- [CNCF Observability Landscape](https://landscape.cncf.io/card-mode?category=observability-and-analysis)
- [OpenTelemetry Instrumentation](https://opentelemetry.io/docs/instrumentation/)
- [Spring Boot Actuator](https://docs.spring.io/spring-boot/docs/current/reference/html/actuator.html)

**🚀 The LGTM Observability Stack provides enterprise-grade monitoring, logging, and tracing for your EcoTrack microservices with unlimited S3 storage and pre-configured dashboards!**