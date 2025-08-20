# 📈 LGTM Observability Stack - Enterprise-Grade Monitoring

Complete observability infrastructure for enterprise Kubernetes applications using the LGTM stack (Loki, Grafana, Tempo, Mimir) with Prometheus.

## 🎯 **Problem Analysis: Current Observability Gaps**

### ❌ **Current Issues Solved:**
- **No Metrics Collection**: Limited insight into application performance → Comprehensive metrics with Prometheus + Mimir
- **Log Aggregation Missing**: Scattered logs across pods → Centralized logging with Loki
- **No Distributed Tracing**: Can't track requests across microservices → End-to-end tracing with Tempo
- **Manual Monitoring**: No proactive alerting → Automated alerts with Grafana + Slack
- **Short-term Storage**: Local metrics only → Unlimited S3 storage with lifecycle management

---

## 🚀 **LGTM Stack Architecture: Complete Observability**

### **Data Flow Pipeline**
```
EcoTrack Microservices → [Collection Layer] → [Storage Layer] → [Visualization Layer]
                      ↓                    ↓                  ↓
               Metrics: /actuator/prometheus → Prometheus → Mimir → S3
                 Logs: Container logs → Promtail → Loki → S3
               Traces: OpenTelemetry → Tempo → S3
                      ↓                    ↓                  ↓
                              Grafana Dashboards & Alerts
```

### **Component Integration Model**
```yaml
name: lgtm-observability-stack
purpose: Complete observability for microservices
dependencies: Workflow 1 (Foundation Platform)
storage: S3 backend for unlimited retention
```

**What it provides:**
- ✅ **Real-time metrics** collection and visualization
- ✅ **Centralized logging** with structured search
- ✅ **Distributed tracing** across microservices
- ✅ **Unified dashboards** for all data sources
- ✅ **Proactive alerting** with Slack integration
- ✅ **Unlimited storage** via S3 with lifecycle policies

---

## 🏗️ **Stack Components Deep Dive**

### **📊 Prometheus - Metrics Foundation**
```yaml
name: prometheus-server
purpose: Real-time metrics collection and alerting
version: 25.8.0 (Helm chart)
dependencies: None (standalone scraping)
```

**Core Features:**
- ✅ **Kubernetes Service Discovery**: Auto-discovers EcoTrack services
- ✅ **Spring Boot Integration**: `/actuator/prometheus` endpoint scraping  
- ✅ **AlertManager**: Built-in alerting rules and routing
- ✅ **High Availability**: Multi-replica setup with shared storage
- ✅ **Resource Efficient**: 400m CPU, 1024Mi memory baseline

**Automatic Discovery:**
```yaml
# EcoTrack services automatically discovered via annotations
annotations:
  prometheus.io/scrape: "true"
  prometheus.io/path: "/actuator/prometheus"
  prometheus.io/port: "8080"
```

---

### **💾 Mimir - Long-term Metrics Storage**
```yaml
name: mimir-distributed
purpose: Unlimited metrics storage and querying
version: 5.1.4 (Helm chart)
dependencies: S3 bucket + IRSA permissions
```

**Enterprise Features:**
- ✅ **S3 Backend**: Unlimited retention with cost-effective storage
- ✅ **Multi-tenancy**: Isolated metrics per environment/team
- ✅ **Query Performance**: Optimized for high-cardinality metrics
- ✅ **Prometheus Compatible**: Drop-in replacement for long-term storage
- ✅ **Auto-scaling**: Handles growing metric volumes automatically

**Storage Architecture:**
```yaml
retention_policy:
  prometheus_local: "7 days"    # Fast local queries
  mimir_s3: "365 days"         # Long-term analysis
  s3_lifecycle:
    - standard: "30 days"
    - ia: "90 days"
    - glacier: "365 days"
```

---

### **📝 Loki - Structured Log Aggregation**
```yaml
name: loki-distributed
purpose: Structured log storage and querying
version: 5.36.2 (Helm chart)
dependencies: S3 bucket + Promtail agents
```

**Advanced Capabilities:**
- ✅ **LogQL**: Powerful query language for log analysis
- ✅ **Label-based Indexing**: Efficient log storage and retrieval
- ✅ **Multi-tenant**: Namespace isolation for security
- ✅ **Stream Processing**: Real-time log ingestion and processing
- ✅ **Cost Effective**: Only indexes metadata, not log content

**Log Processing Pipeline:**
```yaml
kubernetes_logs → promtail → loki → s3_storage
              ↓           ↓       ↓
         label_extraction → indexing → query_interface
```

---

### **🔍 Tempo - Distributed Tracing**
```yaml
name: tempo-distributed
purpose: Request tracing across microservices
version: 1.7.1 (Helm chart)
dependencies: OpenTelemetry instrumentation
```

**Tracing Excellence:**
- ✅ **OpenTelemetry Native**: Standard OTLP ingestion
- ✅ **S3-only Storage**: No database dependencies
- ✅ **Trace Correlation**: Links traces with logs and metrics
- ✅ **Multi-protocol**: Jaeger, Zipkin, OTLP support
- ✅ **Sampling Strategies**: Intelligent trace sampling for scale

**Integration Pattern:**
```yaml
microservice_request → otel_instrumentation → tempo_ingestion → s3_storage
                    ↓                      ↓               ↓
               trace_spans → correlation_ids → grafana_visualization
```

---

### **📈 Grafana - Unified Observability Hub**
```yaml
name: grafana-enterprise
purpose: Visualization, alerting, and observability hub
version: 7.0.11 (Helm chart)
dependencies: All data sources (Prometheus, Loki, Tempo, Mimir)
```

**Comprehensive Dashboards:**
- ✅ **Pre-configured Data Sources**: All components auto-connected
- ✅ **Built-in Dashboards**: Kubernetes, Spring Boot, Ambassador
- ✅ **Custom EcoTrack Views**: Business metrics and KPIs
- ✅ **Unified Alerting**: Single pane for all alert rules
- ✅ **RBAC Support**: Multi-user access with role-based permissions

---

## 💪 **Resource Planning & Capacity**

### **LGTM Stack Resource Usage (per t3.large node):**
```yaml
cpu_requests: "1,250m (1.25 cores)"
memory_requests: "2,688Mi (~2.6Gi)"
cpu_limits: "2,600m (2.6 cores)"  
memory_limits: "5,248Mi (~5.1Gi)"

# Per-component breakdown:
prometheus: "400m CPU, 1024Mi memory"
mimir: "300m CPU, 512Mi memory"
loki: "200m CPU, 512Mi memory"
tempo: "150m CPU, 256Mi memory"
grafana: "100m CPU, 256Mi memory"
promtail: "50m CPU, 128Mi memory per node"
```

### **Remaining Cluster Capacity (3-5 node setup):**
```yaml
available_per_node:
  cpu: "~4.75 cores"
  memory: "~2.4Gi"
  
future_workload_support:
  workflows_4_7: "ArgoCD, Security, Istio, Data services"
  microservices: "5 EcoTrack services with 3 replicas each"
  overhead: "20% buffer for scaling and updates"
```

### **S3 Storage Economics:**
```yaml
estimated_monthly_costs:
  data_volume: "~10GB/month (5 microservices)"
  s3_cost: "$0.25/month with lifecycle policies"
  retention_strategy:
    hot_data: "7 days (Standard S3)"
    warm_data: "30 days (IA)"
    cold_data: "365 days (Glacier)"
    expiration: "automatic cleanup"
```

---

## 🔧 **Deployment Prerequisites**

### **Required Infrastructure:**
- ✅ **Workflow 1: Foundation Platform** - IRSA OIDC provider and EBS CSI driver
- ✅ **S3 Bucket Access** - Automated via IRSA (no access keys)
- ✅ **Persistent Volumes** - EBS volumes for Prometheus and Grafana
- ✅ **Network Policies** - Secure inter-component communication

### **Optional Integrations:**
- **Workflow 2: Ingress + API Gateway** - Ambassador metrics collection
- **External DNS** - Custom Grafana domain setup
- **Slack Integration** - Alert notifications and team collaboration

### **GitHub Secrets (Pre-configured):**
```yaml
required_secrets:
  AWS_ROLE_ARN: "IAM role for GitHub Actions deployment"
  AWS_REGION: "Target AWS region (us-east-1)"
  AWS_ACCOUNT_ID: "AWS account for S3 bucket naming"

optional_secrets:
  SLACK_WEBHOOK_URL: "Grafana alert notifications"
  GRAFANA_ADMIN_PASSWORD: "Custom admin password (auto-generated if not set)"
```

---

## 🚀 **Deployment Guide**

### **1. Deploy via GitHub Actions**
```yaml
repository: "Navigate to Actions tab"
workflow: "📈 Workflow 3: LGTM Observability Stack"
configuration:
  action: "apply"
  environment: "dev"
  auto_approve: "true"
  
deployment_time: "~8-12 minutes"
verification: "Automatic health checks included"
```

### **2. Comprehensive Deployment Verification**
```bash
# Verify all observability namespaces and pods
kubectl get pods -n observability --watch

# Check component-specific health
kubectl get pods -n observability -l app=prometheus-server
kubectl get pods -n observability -l app.kubernetes.io/name=grafana
kubectl get pods -n observability -l app=loki
kubectl get pods -n observability -l app.kubernetes.io/name=tempo
kubectl get pods -n observability -l app.kubernetes.io/name=mimir

# Verify services and ingress points
kubectl get svc -n observability
kubectl get pvc -n observability

# Check data source connectivity
kubectl get configmap -n observability -l grafana_datasource=true
```

### **3. Access Grafana Dashboard**
```bash
# Retrieve admin credentials
GRAFANA_PASSWORD=$(kubectl get secret -n observability grafana-credentials -o jsonpath='{.data.admin-password}' | base64 -d)
echo "Grafana Admin Password: $GRAFANA_PASSWORD"

# Secure local access
kubectl port-forward -n observability svc/grafana 3000:80 &
echo "Grafana URL: http://localhost:3000"
echo "Login: admin / $GRAFANA_PASSWORD"

# Alternative: Direct service access (if ingress configured)
kubectl get ingress -n observability grafana-ingress
```

### **4. Validate S3 Storage Integration**
```bash
# Verify S3 buckets creation and access
aws s3 ls | grep lgtm-observability

# Check component-specific buckets
aws s3 ls dev-lgtm-prometheus-${AWS_ACCOUNT_ID}/ --recursive
aws s3 ls dev-lgtm-loki-${AWS_ACCOUNT_ID}/ --recursive  
aws s3 ls dev-lgtm-tempo-${AWS_ACCOUNT_ID}/ --recursive

# Verify IRSA permissions
kubectl get serviceaccounts -n observability -o yaml | grep eks.amazonaws.com/role-arn

# Test S3 connectivity from pods
kubectl exec -n observability deployment/loki -- aws s3 ls s3://dev-lgtm-loki-${AWS_ACCOUNT_ID}/
```

---

## 📡 **EcoTrack Microservices Integration**

### **Spring Boot Application Configuration**

#### **1. Actuator Metrics Exposure**
```yaml
# application.yml for all EcoTrack microservices
management:
  endpoints:
    web:
      exposure:
        include: "health,info,prometheus,metrics"
      base-path: "/actuator"
  endpoint:
    health:
      show-details: "always"
      probes:
        enabled: true
    metrics:
      enabled: true
  metrics:
    export:
      prometheus:
        enabled: true
        descriptions: true
    distribution:
      percentiles-histogram:
        http.server.requests: true
      percentiles:
        http.server.requests: 0.5, 0.95, 0.99
```

#### **2. OpenTelemetry Tracing Setup**
```xml
<!-- pom.xml dependencies for distributed tracing -->
<dependencies>
    <dependency>
        <groupId>io.opentelemetry.instrumentation</groupId>
        <artifactId>opentelemetry-spring-boot-starter</artifactId>
        <version>1.32.0-alpha</version>
    </dependency>
    <dependency>
        <groupId>io.opentelemetry</groupId>
        <artifactId>opentelemetry-exporter-otlp</artifactId>
    </dependency>
</dependencies>
```

#### **3. Kubernetes Deployment Integration**
```yaml
# Complete EcoTrack microservice deployment template
apiVersion: apps/v1
kind: Deployment
metadata:
  name: user-service
  namespace: ecotrack
  labels:
    app.kubernetes.io/name: user-service
    app.kubernetes.io/part-of: ecotrack
    app.kubernetes.io/version: "1.0.0"
    app.kubernetes.io/component: backend
spec:
  replicas: 3
  selector:
    matchLabels:
      app.kubernetes.io/name: user-service
  template:
    metadata:
      annotations:
        # Prometheus metrics discovery
        prometheus.io/scrape: "true"
        prometheus.io/path: "/actuator/prometheus"
        prometheus.io/port: "8080"
        # Force pod restart on config changes
        kubectl.kubernetes.io/restartedAt: "2024-01-15T10:30:00Z"
      labels:
        app.kubernetes.io/name: user-service
        app.kubernetes.io/part-of: ecotrack
        version: "v1.0.0"
    spec:
      containers:
      - name: user-service
        image: ecotrack/user-service:1.0.0
        ports:
        - containerPort: 8080
          name: http
          protocol: TCP
        env:
        # OpenTelemetry configuration
        - name: OTEL_EXPORTER_OTLP_ENDPOINT
          value: "http://tempo.observability.svc.cluster.local:4317"
        - name: OTEL_SERVICE_NAME
          value: "user-service"
        - name: OTEL_SERVICE_VERSION
          value: "1.0.0"
        - name: OTEL_RESOURCE_ATTRIBUTES
          value: "service.namespace=ecotrack,service.instance.id=$(HOSTNAME)"
        - name: OTEL_EXPORTER_OTLP_PROTOCOL
          value: "grpc"
        - name: OTEL_TRACES_SAMPLER
          value: "traceidratio"
        - name: OTEL_TRACES_SAMPLER_ARG
          value: "0.1"  # Sample 10% of traces
        # Application-specific environment
        - name: SPRING_PROFILES_ACTIVE
          value: "kubernetes,observability"
        - name: MANAGEMENT_ENDPOINTS_WEB_EXPOSURE_INCLUDE
          value: "health,info,prometheus"
        resources:
          requests:
            cpu: 200m
            memory: 512Mi
          limits:
            cpu: 500m
            memory: 1Gi
        livenessProbe:
          httpGet:
            path: /actuator/health/liveness
            port: 8080
          initialDelaySeconds: 60
          periodSeconds: 30
          timeoutSeconds: 5
          failureThreshold: 3
        readinessProbe:
          httpGet:
            path: /actuator/health/readiness
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
        startupProbe:
          httpGet:
            path: /actuator/health
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 5
          timeoutSeconds: 3
          failureThreshold: 20
---
# Service for the deployment
apiVersion: v1
kind: Service
metadata:
  name: user-service
  namespace: ecotrack
  labels:
    app.kubernetes.io/name: user-service
    app.kubernetes.io/part-of: ecotrack
spec:
  type: ClusterIP
  ports:
  - port: 80
    targetPort: 8080
    protocol: TCP
    name: http
  selector:
    app.kubernetes.io/name: user-service
```

### **Custom Business Metrics**
```java
// Spring Boot custom metrics for EcoTrack business logic
@RestController
@Timed(name = "user_service_requests", description = "User service request timing")
public class UserController {
    
    private final Counter userRegistrations = Counter.builder("ecotrack_users_registered_total")
            .description("Total number of user registrations")
            .tag("service", "user-service")
            .register(Metrics.globalRegistry);
    
    private final Timer paymentProcessingTime = Timer.builder("ecotrack_payment_duration_seconds")
            .description("Payment processing duration")
            .tag("service", "payment-service")
            .register(Metrics.globalRegistry);
    
    @PostMapping("/users")
    @Counted(name = "user_creation_attempts", description = "User creation attempts")
    public ResponseEntity<User> createUser(@RequestBody UserRequest request) {
        Timer.Sample sample = Timer.start(Metrics.globalRegistry);
        try {
            User user = userService.createUser(request);
            userRegistrations.increment("success");
            return ResponseEntity.ok(user);
        } catch (Exception e) {
            userRegistrations.increment("error");
            throw e;
        } finally {
            sample.stop(Timer.builder("user_creation_duration")
                    .description("User creation processing time")
                    .register(Metrics.globalRegistry));
        }
    }
}
```

---

## 📊 **Pre-configured Dashboard Library**

### **1. Kubernetes Cluster Overview (Dashboard ID: 7249)**
```yaml
dashboard_purpose: "Complete cluster health and resource utilization"
key_metrics:
  - "Node CPU, memory, disk usage across all nodes"
  - "Pod resource consumption and limits"
  - "Network I/O and cluster networking policies"
  - "Persistent volume usage and storage classes"
  - "Kubernetes events and cluster-level alerts"
access_path: "Grafana → Dashboards → Browse → Kubernetes Cluster"
update_frequency: "Real-time (30-second refresh)"
```

### **2. Kubernetes Pods Monitoring (Dashboard ID: 6336)**
```yaml
dashboard_purpose: "Detailed pod-level monitoring and troubleshooting"
key_metrics:
  - "Pod CPU and memory usage per namespace"
  - "Container restart counts and crash loops"
  - "Resource requests vs actual usage"
  - "Pod readiness and liveness probe status"
  - "Container image pull status and errors"
access_path: "Grafana → Dashboards → Browse → Kubernetes Pods"
drill_down: "Pod-specific views with log correlation"
```

### **3. Spring Boot Applications (Dashboard ID: 12900)**
```yaml
dashboard_purpose: "Comprehensive Spring Boot microservice monitoring"
jvm_metrics:
  - "Heap memory usage and garbage collection performance"
  - "Thread pool utilization and deadlock detection"
  - "Class loading statistics and method execution time"
application_metrics:
  - "HTTP request rates, response times, and error rates"
  - "Database connection pool health and query performance"
  - "Cache hit rates and custom business metrics"
database_integration:
  - "HikariCP connection pool monitoring"
  - "Query execution time distribution"
  - "Database transaction success/failure rates"
business_metrics:
  - "EcoTrack-specific KPIs and user journey metrics"
access_path: "Grafana → Dashboards → Browse → Spring Boot Statistics"
```

### **4. Ambassador API Gateway (Dashboard ID: 13758)** *(if Workflow 2 deployed)*
```yaml
dashboard_purpose: "API Gateway performance and traffic analysis"
traffic_metrics:
  - "Request volume by service and endpoint"
  - "Latency percentiles (P50, P95, P99)"
  - "Throughput and concurrent connections"
error_analysis:
  - "4xx/5xx error rates by service"
  - "Upstream service failures and timeouts"
  - "Circuit breaker status and retry attempts"
load_balancing:
  - "Backend service health and weight distribution"
  - "Connection pool utilization"
  - "SSL certificate status and expiration"
access_path: "Grafana → Dashboards → Browse → Ambassador Edge Stack"
```

### **5. LGTM Stack Health (Custom Dashboard)**
```yaml
dashboard_purpose: "Monitor the monitoring stack itself"
prometheus_health:
  - "Scrape target health and discovery status"
  - "Cardinality growth and ingestion rate"
  - "Query performance and resource usage"
loki_health:
  - "Log ingestion rate and index health"
  - "Query performance and storage utilization"
  - "Promtail agent status across all nodes"
tempo_health:
  - "Trace ingestion rate and storage performance"
  - "Query latency and sampling rate effectiveness"
  - "OpenTelemetry exporter connectivity"
grafana_health:
  - "Dashboard usage statistics and performance"
  - "Alert rule evaluation and notification delivery"
  - "Data source connectivity and query response times"
s3_integration:
  - "Bucket storage utilization and costs"
  - "Upload/download success rates"
  - "Lifecycle policy effectiveness"
```

---

## 🔔 **Advanced Alerting Framework**

### **Critical Infrastructure Alerts**
```yaml
# Node resource exhaustion
alert: NodeCPUUsage
expr: 100 - (avg(rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 85
for: 10m
severity: critical
description: "Node CPU usage is above 85% for 10 minutes"

alert: NodeMemoryUsage
expr: (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100 > 85
for: 5m
severity: critical
description: "Node memory usage is above 85%"

alert: NodeDiskUsage
expr: (1 - (node_filesystem_avail_bytes{fstype!="tmpfs"} / node_filesystem_size_bytes{fstype!="tmpfs"})) * 100 > 85
for: 5m
severity: warning
description: "Node disk usage is above 85%"

# Kubernetes pod health
alert: PodCrashLoop
expr: rate(kube_pod_container_status_restarts_total[15m]) > 0
for: 5m
severity: critical
description: "Pod {{ $labels.pod }} in namespace {{ $labels.namespace }} is crash looping"

alert: PodMemoryUsage
expr: (container_memory_working_set_bytes{container!="POD"} / container_spec_memory_limit_bytes{container!="POD"}) * 100 > 80
for: 5m
severity: warning
description: "Pod {{ $labels.pod }} memory usage is above 80% of limit"
```

### **EcoTrack Application Alerts**
```yaml
# High error rate across microservices
alert: HighErrorRate
expr: |
  (
    rate(http_requests_total{job=~".*ecotrack.*",status=~"5.."}[5m]) /
    rate(http_requests_total{job=~".*ecotrack.*"}[5m])
  ) * 100 > 5
for: 3m
severity: critical
description: "{{ $labels.job }} has error rate above 5% for 3 minutes"

# High response time
alert: HighLatency
expr: |
  histogram_quantile(0.95, 
    rate(http_request_duration_seconds_bucket{job=~".*ecotrack.*"}[5m])
  ) > 2
for: 5m
severity: warning
description: "{{ $labels.job }} 95th percentile latency is above 2 seconds"

# Service unavailable
alert: ServiceDown
expr: up{job=~".*ecotrack.*"} == 0
for: 1m
severity: critical
description: "EcoTrack service {{ $labels.job }} is down"

# Database connection issues
alert: DatabaseConnectionPool
expr: hikaricp_connections_active{job=~".*ecotrack.*"} / hikaricp_connections_max{job=~".*ecotrack.*"} > 0.8
for: 5m
severity: warning
description: "{{ $labels.job }} database connection pool is above 80% utilization"

# Custom business metric alerts
alert: LowUserRegistrations
expr: rate(ecotrack_users_registered_total[30m]) < 0.1
for: 30m
severity: info
description: "User registration rate is below normal (< 6 per hour)"

alert: PaymentProcessingDelay
expr: histogram_quantile(0.95, rate(ecotrack_payment_duration_seconds_bucket[10m])) > 30
for: 10m
severity: critical
description: "Payment processing time is above 30 seconds for 95% of requests"
```

### **LGTM Stack Self-Monitoring**
```yaml
# Prometheus health
alert: PrometheusTargetDown
expr: up{job="prometheus"} == 0
for: 1m
severity: critical
description: "Prometheus server is down"

alert: PrometheusHighCardinality
expr: prometheus_tsdb_symbol_table_size_bytes > 16777216  # 16MB
for: 15m
severity: warning
description: "Prometheus cardinality is growing too high"

# Grafana connectivity
alert: GrafanaDown
expr: up{job="grafana"} == 0
for: 2m
severity: critical
description: "Grafana is unavailable"

# Loki ingestion health
alert: LokiIngestionRate
expr: rate(loki_ingester_samples_received_total[5m]) < 1
for: 10m
severity: warning
description: "Loki is not receiving log samples"
```

### **Slack Integration Configuration**
```yaml
# Grafana notification channel configuration
notification_channels:
  - name: "ecotrack-critical"
    type: "slack"
    settings:
      url: "$SLACK_WEBHOOK_URL"
      channel: "#ecotrack-alerts"
      username: "Grafana"
      iconEmoji: ":exclamation:"
      title: "🚨 EcoTrack Critical Alert"
      text: |
        **Alert:** {{ range .Alerts }}{{ .Annotations.summary }}{{ end }}
        **Severity:** {{ range .Alerts }}{{ .Labels.severity }}{{ end }}
        **Time:** {{ range .Alerts }}{{ .StartsAt.Format "2006-01-02 15:04:05" }}{{ end }}
        **Description:** {{ range .Alerts }}{{ .Annotations.description }}{{ end }}
        
  - name: "ecotrack-warnings"
    type: "slack"
    settings:
      url: "$SLACK_WEBHOOK_URL"
      channel: "#ecotrack-monitoring"
      username: "Grafana"
      iconEmoji: ":warning:"
      title: "⚠️ EcoTrack Warning"
      text: |
        **Alert:** {{ range .Alerts }}{{ .Annotations.summary }}{{ end }}
        **Service:** {{ range .Alerts }}{{ .Labels.job }}{{ end }}
        **Time:** {{ range .Alerts }}{{ .StartsAt.Format "15:04:05" }}{{ end }}
```

---

## 🎯 **Key Monitoring Queries for EcoTrack**

### **Business Intelligence Metrics**
```promql
# User activity and engagement
rate(ecotrack_users_registered_total[1h])  # Hourly user registration rate
rate(ecotrack_user_logins_total[5m])       # Login activity
rate(ecotrack_product_views_total[5m])     # Product catalog engagement

# E-commerce performance
rate(ecotrack_orders_total[5m])                    # Order creation rate
rate(ecotrack_orders_completed_total[5m]) /        # Order success rate
rate(ecotrack_orders_total[5m])
sum(ecotrack_order_value_total) by (product_category)  # Revenue by category

# Payment processing
histogram_quantile(0.95, rate(ecotrack_payment_duration_seconds_bucket[5m]))  # Payment latency
rate(ecotrack_payments_failed_total[5m])  # Payment failure rate
sum(rate(ecotrack_payment_amount_total[1h])) by (payment_method)  # Revenue by payment type
```

### **Technical Performance Metrics**
```promql
# Service health across microservices
rate(http_requests_total{job=~".*ecotrack.*"}[5m])                    # Request rate per service
rate(http_requests_total{job=~".*ecotrack.*",status=~"5.."}[5m])     # Error rate per service
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket{job=~".*ecotrack.*"}[5m]))  # Response time

# JVM and resource monitoring
jvm_memory_used_bytes{job=~".*ecotrack.*",area="heap"} /              # JVM heap utilization
jvm_memory_max_bytes{job=~".*ecotrack.*",area="heap"}
rate(jvm_gc_collection_seconds_sum{job=~".*ecotrack.*"}[5m])         # GC impact
jvm_threads_current{job=~".*ecotrack.*"}                             # Thread usage

# Database performance
hikaricp_connections_active{job=~".*ecotrack.*"}                      # DB connection usage
rate(hikaricp_connections_created_total{job=~".*ecotrack.*"}[5m])     # Connection churn
histogram_quantile(0.95, rate(hikaricp_connections_usage_seconds_bucket[5m]))  # Connection time
```

### **Infrastructure Monitoring**
```promql
# Kubernetes resource utilization
rate(container_cpu_usage_seconds_total{namespace="ecotrack"}[5m])     # CPU usage per pod
container_memory_working_set_bytes{namespace="ecotrack"}              # Memory usage per pod
rate(container_network_receive_bytes_total{namespace="ecotrack"}[5m]) # Network ingress
rate(container_network_transmit_bytes_total{namespace="ecotrack"}[5m]) # Network egress

# Node-level health
100 - (avg(rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)      # Node CPU usage
(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100  # Node memory usage
rate(node_disk_io_time_seconds_total[5m])                             # Disk I/O utilization
```

### **Log Analysis Queries (LogQL)**
```logql
# Error tracking and troubleshooting
{namespace="ecotrack"} |= "ERROR" | json | line_format "{{.timestamp}} {{.level}} {{.message}}"

# Payment processing monitoring
{namespace="ecotrack",app="payment-service"} |= "payment" | json | 
  line_format "{{.timestamp}} Payment {{.payment_id}} Status: {{.status}}"

# Database connection issues
{namespace="ecotrack"} |~ "(?i)connection.*timeout|timeout.*connection|connection.*refused" | 
  json | line_format "{{.timestamp}} DB Error: {{.message}}"

# Performance issue detection
{namespace="ecotrack"} |~ "slow.*query|query.*slow|timeout|performance" | 
  json | duration > 1s | line_format "{{.timestamp}} SLOW: {{.message}}"

# User activity tracking
{namespace="ecotrack",app="user-service"} |= "user" |= "login" | 
  json | line_format "{{.timestamp}} User Activity: {{.user_id}} {{.action}}"

# API rate limiting and abuse detection
{namespace="ecotrack"} |~ "rate.*limit|too.*many.*requests|429" | 
  json | line_format "{{.timestamp}} Rate Limit: {{.client_ip}} {{.endpoint}}"
```

---

## 🛠️ **Troubleshooting Playbook**

### **Component Health Diagnostics**

#### **1. Prometheus Issues**
```bash
# Check Prometheus server status
kubectl get pods -n observability -l app=prometheus-server
kubectl logs -n observability -l app=prometheus-server --tail=100

# Verify target discovery
kubectl port-forward -n observability svc/prometheus-server 9090:80 &
curl -s "http://localhost:9090/api/v1/targets" | jq '.data.activeTargets[] | select(.health != "up")'

# Check configuration reload
kubectl get configmap -n observability prometheus-server -o yaml
kubectl rollout restart -n observability deployment/prometheus-server

# Verify EcoTrack service discovery
curl -s "http://localhost:9090/api/v1/label/__name__/values" | jq '.data[]' | grep ecotrack

# Check scrape performance
curl -s "http://localhost:9090/api/v1/query?query=up{job=~'.*ecotrack.*'}"
```

#### **2. Grafana Connectivity Issues**
```bash
# Grafana pod health
kubectl get pods -n observability -l app.kubernetes.io/name=grafana
kubectl logs -n observability -l app.kubernetes.io/name=grafana --tail=100

# Test data source connectivity
kubectl exec -n observability deployment/grafana -- curl -s http://prometheus-server/api/v1/label/__name__/values
kubectl exec -n observability deployment/grafana -- curl -s http://loki:3100/loki/api/v1/labels

# Verify Grafana configuration
kubectl get configmap -n observability grafana-datasources -o yaml
kubectl get secret -n observability grafana-credentials -o yaml

# Reset admin password
kubectl patch secret -n observability grafana-credentials -p '{"data":{"admin-password":"'$(echo -n "newpassword" | base64)'"}}'
kubectl rollout restart -n observability deployment/grafana
```

#### **3. Loki Log Ingestion Problems**
```bash
# Promtail agents status
kubectl get pods -n observability -l app=promtail
kubectl logs -n observability -l app=promtail --tail=50

# Loki ingestion health
kubectl port-forward -n observability svc/loki 3100:3100 &
curl -s "http://localhost:3100/loki/api/v1/label/app/values" | jq

# Verify log flow from EcoTrack
curl -s "http://localhost:3100/loki/api/v1/query_range?query={namespace=\"ecotrack\"}&start=$(date -d '1 hour ago' +%s)000000000&end=$(date +%s)000000000"

# Check S3 backend connectivity
kubectl exec -n observability deployment/loki -- aws s3 ls s3://dev-lgtm-loki-${AWS_ACCOUNT_ID}/
kubectl logs -n observability deployment/loki | grep -i s3

# Promtail configuration verification
kubectl get configmap -n observability loki-promtail -o yaml
```

#### **4. Tempo Tracing Debugging**
```bash
# Tempo service health
kubectl get pods -n observability -l app.kubernetes.io/name=tempo
kubectl logs -n observability -l app.kubernetes.io/name=tempo --tail=100

# Verify trace ingestion
kubectl port-forward -n observability svc/tempo 3100:3100 &
curl -s "http://localhost:3100/api/search?tags=service.name=user-service"

# Test OpenTelemetry connectivity from EcoTrack
kubectl exec -n ecotrack deployment/user-service -- curl -v http://tempo.observability.svc.cluster.local:4317

# Check trace sampling configuration
kubectl get configmap -n observability tempo -o yaml | grep -A 10 sampling

# Verify S3 storage
kubectl exec -n observability deployment/tempo -- aws s3 ls s3://dev-lgtm-tempo-${AWS_ACCOUNT_ID}/
```

#### **5. Mimir Long-term Storage**
```bash
# Mimir distributed components
kubectl get pods -n observability -l app.kubernetes.io/name=mimir
kubectl logs -n observability -l app.kubernetes.io/component=ingester --tail=50

# Verify remote write from Prometheus
kubectl logs -n observability deployment/prometheus-server | grep -i mimir
curl -s "http://prometheus-server:9090/api/v1/query?query=prometheus_remote_storage_samples_total"

# Check S3 backend for Mimir
kubectl exec -n observability deployment/mimir-query-frontend -- aws s3 ls s3://dev-lgtm-mimir-${AWS_ACCOUNT_ID}/

# Query Mimir directly
kubectl port-forward -n observability svc/mimir-query-frontend 8080:8080 &
curl -s "http://localhost:8080/prometheus/api/v1/label/__name__/values"
```

### **Performance Optimization Strategies**

#### **High-Traffic Environment Tuning**
```yaml
# Scale Prometheus for high cardinality
prometheus_server:
  resources:
    requests:
      cpu: "1000m"
      memory: "4Gi"
    limits:
      cpu: "2000m"
      memory: "8Gi"
  retention: "7d"
  
# Optimize Grafana for multiple users
grafana:
  replicas: 3
  resources:
    requests:
      cpu: "200m"
      memory: "512Mi"
    limits:
      cpu: "500m"
      memory: "1Gi"

# Scale Loki for log volume
loki:
  ingester:
    replicas: 3
  distributor:
    replicas: 3
  query_frontend:
    replicas: 2
```

#### **Development Environment Resource Reduction**
```yaml
# Minimal LGTM stack for development
development_mode:
  disable_mimir: true          # Use only Prometheus local storage
  disable_tempo: true          # Skip distributed tracing
  reduce_retention: true       # 3-day retention only
  
prometheus_dev:
  resources:
    requests:
      cpu: "200m"
      memory: "1Gi"
  retention: "3d"

grafana_dev:
  resources:
    requests:
      cpu: "100m"
      memory: "256Mi"
```

### **Cost Optimization for S3 Storage**
```bash
# Monitor S3 storage costs
aws s3api list-objects-v2 --bucket dev-lgtm-prometheus-${AWS_ACCOUNT_ID} --query 'Contents[].{Key:Key,Size:Size}' --output table

# Verify lifecycle policies
aws s3api get-bucket-lifecycle-configuration --bucket dev-lgtm-loki-${AWS_ACCOUNT_ID}

# Set up cost monitoring
aws ce get-cost-and-usage --time-period Start=2024-01-01,End=2024-01-31 --granularity MONTHLY --metrics BlendedCost --group-by Type=DIMENSION,Key=SERVICE
```

---

## 🔗 **Integration Roadmap with Future Workflows**

### **Workflow 4: GitOps + CI/CD (ArgoCD + Tekton)**
```yaml
integration_benefits:
  - "ArgoCD application health monitoring via Prometheus metrics"
  - "Tekton pipeline execution tracing through OpenTelemetry"
  - "Git repository changes correlated with deployment metrics"
  - "Automated rollback triggers based on error rate thresholds"
  
observability_enhancements:
  prometheus_targets:
    - "argocd-metrics:8082"
    - "tekton-pipelines-controller:9090"
  custom_dashboards:
    - "GitOps Health Dashboard"
    - "CI/CD Pipeline Performance"
    - "Deployment Success Rate Tracking"
  automated_alerts:
    - "Failed ArgoCD sync operations"
    - "Tekton pipeline failures"
    - "Deployment rollback events"
```

### **Workflow 5: Security & Compliance Stack**
```yaml
security_monitoring:
  log_analysis:
    - "Falco security alerts in Loki"
    - "Kubernetes audit logs analysis"
    - "Network policy violation tracking"
  metrics_integration:
    - "Security scan results as Prometheus metrics"
    - "Compliance score tracking"
    - "Vulnerability count trends"
  alerting_enhancements:
    - "Critical security incident notifications"
    - "Compliance threshold breaches"
    - "Anomalous activity detection"
```

### **Workflow 6: Istio Service Mesh**
```yaml
service_mesh_observability:
  enhanced_metrics:
    - "Service-to-service traffic patterns"
    - "mTLS certificate status monitoring"
    - "Circuit breaker and retry statistics"
  distributed_tracing:
    - "Enhanced trace correlation through sidecar proxies"
    - "Request routing and load balancing visibility"
    - "Cross-cluster service communication"
  dashboards:
    - "Istio Service Topology"
    - "Service Mesh Performance"
    - "Security Policy Enforcement"
```

### **Workflow 7: Data Services & Analytics**
```yaml
data_platform_monitoring:
  database_metrics:
    - "PostgreSQL performance monitoring"
    - "Redis cache hit rates and memory usage"
    - "ETL job success/failure rates"
  data_quality:
    - "Data freshness and completeness metrics"
    - "Schema change impact tracking"
    - "Query performance optimization alerts"
  business_intelligence:
    - "Data pipeline SLA monitoring"
    - "User behavior analytics correlation"
    - "Real-time data quality scoring"
```

---

## 📈 **Success Metrics & KPIs**

### **Operational Excellence Indicators**
```yaml
infrastructure_health:
  target_uptime: "99.9%"
  mean_time_to_detection: "<5 minutes"
  mean_time_to_resolution: "<30 minutes"
  
application_performance:
  p95_response_time: "<500ms"
  error_rate: "<0.1%"
  service_availability: "99.95%"
  
observability_coverage:
  monitored_services: "100%"
  log_retention: "365 days"
  metric_coverage: "All critical business flows"
  
cost_efficiency:
  monthly_s3_cost: "<$5"
  storage_utilization: "Optimized via lifecycle policies"
  query_performance: "Sub-second dashboard loads"
```

### **Business Impact Measurements**
```yaml
user_experience:
  page_load_time: "<2 seconds"
  api_response_time: "<200ms"
  error_free_sessions: ">99%"
  
business_metrics:
  order_completion_rate: ">95%"
  payment_success_rate: ">99.5%"
  user_satisfaction_score: ">4.5/5"
  
operational_efficiency:
  incident_response_time: "<15 minutes"
  false_positive_rate: "<5%"
  automation_coverage: ">80%"
```

---

## 🎯 **Deployment Success Checklist**

- [ ] **All LGTM components deployed** and pods showing `Running` status
- [ ] **S3 buckets created** with proper IRSA permissions and lifecycle policies
- [ ] **Grafana accessible** via port-forward with admin credentials working
- [ ] **All data sources configured** (Prometheus, Loki, Tempo, Mimir) and status `Working`
- [ ] **Pre-built dashboards imported** and displaying data for cluster and applications
- [ ] **Prometheus discovering EcoTrack services** via service annotations automatically
- [ ] **Logs flowing** from all namespaces to Loki via Promtail agents
- [ ] **Traces collecting** from OpenTelemetry-instrumented applications
- [ ] **Alerting rules configured** and Slack notifications tested successfully
- [ ] **Resource usage optimal** (~1.25 CPU cores, ~2.6Gi memory per node)
- [ ] **S3 storage active** with data being written to all component buckets
- [ ] **Custom EcoTrack metrics** visible in Prometheus and Grafana dashboards

---

## 📚 **Learning Resources & Documentation**

### **Official Documentation:**
- [Prometheus Operator Guide](https://prometheus-operator.dev/docs/)
- [Grafana Dashboard Best Practices](https://grafana.com/docs/grafana/latest/best-practices/)
- [Loki LogQL Query Language](https://grafana.com/docs/loki/latest/logql/)
- [Tempo Distributed Tracing](https://grafana.com/docs/tempo/latest/)
- [Mimir Long-term Storage](https://grafana.com/docs/mimir/latest/)

### **Spring Boot Integration:**
- [Spring Boot Actuator Metrics](https://docs.spring.io/spring-boot/docs/current/reference/html/actuator.html)
- [Micrometer Prometheus Integration](https://micrometer.io/docs/registry/prometheus)
- [OpenTelemetry Java Agent](https://opentelemetry.io/docs/instrumentation/java/)

### **Kubernetes Monitoring:**
- [kube-state-metrics](https://github.com/kubernetes/kube-state-metrics)
- [node-exporter](https://github.com/prometheus/node_exporter)
- [Prometheus Service Discovery](https://prometheus.io/docs/prometheus/latest/configuration/configuration/#kubernetes_sd_config)

### **Advanced Topics:**
- [PromQL Query Optimization](https://prometheus.io/docs/prometheus/latest/querying/basics/)
- [Grafana Alert Rule Templates](https://grafana.com/docs/grafana/latest/alerting/)
- [LGTM Stack Architecture Patterns](https://grafana.com/blog/2021/03/03/intro-to-the-lgtm-stack/)

**🚀 The LGTM Observability Stack provides enterprise-grade monitoring, logging, and tracing for your EcoTrack microservices with unlimited S3 storage, pre-configured dashboards, and comprehensive alerting - all ready for production workloads from day one!**