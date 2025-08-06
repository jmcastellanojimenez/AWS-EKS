#!/bin/bash
set -euo pipefail

# Observability Tools Installation Script
# Installs Prometheus, Grafana, Jaeger, OpenTelemetry, and logging stack

ENVIRONMENT=${1:-dev}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/tmp/install-observability-${ENVIRONMENT}.log"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}" | tee -a "$LOG_FILE"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}" | tee -a "$LOG_FILE"
}

info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1${NC}" | tee -a "$LOG_FILE"
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    if ! command -v kubectl &> /dev/null; then
        error "kubectl is not installed"
        exit 1
    fi
    
    if ! command -v helm &> /dev/null; then
        error "helm is not installed"
        exit 1
    fi
    
    if ! kubectl cluster-info &> /dev/null; then
        error "Cannot access Kubernetes cluster"
        exit 1
    fi
    
    log "Prerequisites check passed"
}

# Install Prometheus Stack (Prometheus + Grafana + AlertManager)
install_prometheus_stack() {
    log "Installing Prometheus Stack..."
    
    # Add Prometheus community Helm repository
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo update
    
    # Create monitoring namespace
    kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
    
    # Install kube-prometheus-stack
    helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
        --namespace monitoring \
        --set prometheus.prometheusSpec.retention=7d \
        --set prometheus.prometheusSpec.resources.requests.cpu=100m \
        --set prometheus.prometheusSpec.resources.requests.memory=512Mi \
        --set prometheus.prometheusSpec.resources.limits.cpu=500m \
        --set prometheus.prometheusSpec.resources.limits.memory=1Gi \
        --set alertmanager.alertmanagerSpec.resources.requests.cpu=50m \
        --set alertmanager.alertmanagerSpec.resources.requests.memory=64Mi \
        --set alertmanager.alertmanagerSpec.resources.limits.cpu=100m \
        --set alertmanager.alertmanagerSpec.resources.limits.memory=128Mi \
        --set grafana.resources.requests.cpu=100m \
        --set grafana.resources.requests.memory=128Mi \
        --set grafana.resources.limits.cpu=200m \
        --set grafana.resources.limits.memory=256Mi \
        --set grafana.adminPassword=admin123 \
        --set grafana.persistence.enabled=false \
        --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage=10Gi \
        --wait --timeout=600s
    
    # Wait for all components to be ready
    kubectl wait --for=condition=available --timeout=300s deployment/prometheus-grafana -n monitoring
    kubectl wait --for=condition=available --timeout=300s deployment/prometheus-kube-prometheus-operator -n monitoring
    
    log "Prometheus Stack installed successfully"
}

# Install Jaeger for distributed tracing
install_jaeger() {
    log "Installing Jaeger..."
    
    # Add Jaeger Helm repository
    helm repo add jaegertracing https://jaegertracing.github.io/helm-charts
    helm repo update
    
    # Create tracing namespace
    kubectl create namespace tracing --dry-run=client -o yaml | kubectl apply -f -
    
    # Install Jaeger
    helm upgrade --install jaeger jaegertracing/jaeger \
        --namespace tracing \
        --set provisionDataStore.cassandra=false \
        --set provisionDataStore.elasticsearch=false \
        --set allInOne.enabled=true \
        --set storage.type=memory \
        --set allInOne.resources.requests.cpu=100m \
        --set allInOne.resources.requests.memory=256Mi \
        --set allInOne.resources.limits.cpu=500m \
        --set allInOne.resources.limits.memory=512Mi \
        --set agent.resources.requests.cpu=50m \
        --set agent.resources.requests.memory=64Mi \
        --set agent.resources.limits.cpu=100m \
        --set agent.resources.limits.memory=128Mi \
        --wait --timeout=300s
    
    # Wait for Jaeger to be ready
    kubectl wait --for=condition=available --timeout=300s deployment/jaeger -n tracing
    
    log "Jaeger installed successfully"
}

# Install OpenTelemetry Operator
install_opentelemetry() {
    log "Installing OpenTelemetry Operator..."
    
    # Install cert-manager (required for OpenTelemetry Operator)
    helm repo add jetstack https://charts.jetstack.io
    helm repo update
    
    helm upgrade --install cert-manager jetstack/cert-manager \
        --namespace cert-manager \
        --create-namespace \
        --set installCRDs=true \
        --set resources.requests.cpu=50m \
        --set resources.requests.memory=64Mi \
        --set resources.limits.cpu=100m \
        --set resources.limits.memory=128Mi \
        --wait --timeout=300s
    
    # Install OpenTelemetry Operator
    kubectl apply -f https://github.com/open-telemetry/opentelemetry-operator/releases/latest/download/opentelemetry-operator.yaml
    
    # Wait for OpenTelemetry Operator to be ready
    kubectl wait --for=condition=available --timeout=300s deployment/opentelemetry-operator-controller-manager -n opentelemetry-operator-system
    
    # Create OpenTelemetry Collector
    kubectl apply -f - <<EOF
apiVersion: opentelemetry.io/v1alpha1
kind: OpenTelemetryCollector
metadata:
  name: otel-collector
  namespace: monitoring
spec:
  mode: deployment
  replicas: 1
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      cpu: 200m
      memory: 256Mi
  config: |
    receivers:
      otlp:
        protocols:
          grpc:
            endpoint: 0.0.0.0:4317
          http:
            endpoint: 0.0.0.0:4318
      prometheus:
        config:
          scrape_configs:
            - job_name: 'k8s-pods'
              kubernetes_sd_configs:
                - role: pod
    
    processors:
      batch:
      memory_limiter:
        limit_mib: 200
    
    exporters:
      prometheus:
        endpoint: "0.0.0.0:8889"
      jaeger:
        endpoint: jaeger-collector.tracing.svc.cluster.local:14250
        tls:
          insecure: true
      logging:
        loglevel: info
    
    service:
      pipelines:
        traces:
          receivers: [otlp]
          processors: [memory_limiter, batch]
          exporters: [jaeger, logging]
        metrics:
          receivers: [otlp, prometheus]
          processors: [memory_limiter, batch]
          exporters: [prometheus, logging]
        logs:
          receivers: [otlp]
          processors: [memory_limiter, batch]
          exporters: [logging]
EOF
    
    log "OpenTelemetry installed successfully"
}

# Install Elasticsearch and Kibana for logging
install_elk_stack() {
    log "Installing ELK Stack (Elasticsearch + Kibana + Filebeat)..."
    
    # Add Elastic Helm repository
    helm repo add elastic https://helm.elastic.co
    helm repo update
    
    # Create logging namespace
    kubectl create namespace logging --dry-run=client -o yaml | kubectl apply -f -
    
    # Install Elasticsearch (single node for learning)
    helm upgrade --install elasticsearch elastic/elasticsearch \
        --namespace logging \
        --set replicas=1 \
        --set minimumMasterNodes=1 \
        --set resources.requests.cpu=500m \
        --set resources.requests.memory=1Gi \
        --set resources.limits.cpu=1000m \
        --set resources.limits.memory=2Gi \
        --set volumeClaimTemplate.resources.requests.storage=10Gi \
        --set esConfig."elasticsearch\.yml"="cluster.name: \"docker-cluster\"\nnetwork.host: 0.0.0.0\ndiscovery.type: single-node\nxpack.security.enabled: false" \
        --wait --timeout=600s
    
    # Install Kibana
    helm upgrade --install kibana elastic/kibana \
        --namespace logging \
        --set resources.requests.cpu=100m \
        --set resources.requests.memory=512Mi \
        --set resources.limits.cpu=500m \
        --set resources.limits.memory=1Gi \
        --set service.type=ClusterIP \
        --wait --timeout=300s
    
    # Install Filebeat
    helm upgrade --install filebeat elastic/filebeat \
        --namespace logging \
        --set resources.requests.cpu=100m \
        --set resources.requests.memory=128Mi \
        --set resources.limits.cpu=200m \
        --set resources.limits.memory=256Mi \
        --wait --timeout=300s
    
    log "ELK Stack installed successfully"
}

# Install Stern for log streaming
install_stern() {
    log "Installing Stern..."
    
    if ! command -v stern &> /dev/null; then
        log "Downloading Stern CLI..."
        STERN_VERSION="1.25.0"
        curl -L "https://github.com/stern/stern/releases/download/v${STERN_VERSION}/stern_${STERN_VERSION}_linux_amd64.tar.gz" | tar xz
        sudo mv stern /usr/local/bin/
        rm -f LICENSE
    fi
    
    log "Stern installed successfully"
}

# Install K9s for cluster management
install_k9s() {
    log "Installing K9s..."
    
    if ! command -v k9s &> /dev/null; then
        log "Downloading K9s..."
        K9S_VERSION="v0.27.4"
        curl -L "https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/k9s_Linux_amd64.tar.gz" | tar xz
        sudo mv k9s /usr/local/bin/
        rm -f LICENSE README.md
    fi
    
    log "K9s installed successfully"
}

# Create observability dashboards
create_dashboards() {
    log "Creating custom Grafana dashboards..."
    
    # Create custom dashboard ConfigMap
    kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: custom-dashboards
  namespace: monitoring
  labels:
    grafana_dashboard: "1"
data:
  eks-cluster-overview.json: |
    {
      "dashboard": {
        "id": null,
        "title": "EKS Cluster Overview",
        "tags": ["kubernetes", "eks"],
        "style": "dark",
        "timezone": "browser",
        "panels": [
          {
            "id": 1,
            "title": "Cluster CPU Usage",
            "type": "graph",
            "targets": [
              {
                "expr": "sum(rate(container_cpu_usage_seconds_total[5m])) by (node)",
                "legendFormat": "{{node}}"
              }
            ],
            "gridPos": {"h": 8, "w": 12, "x": 0, "y": 0}
          },
          {
            "id": 2,
            "title": "Cluster Memory Usage",
            "type": "graph",
            "targets": [
              {
                "expr": "sum(container_memory_usage_bytes) by (node)",
                "legendFormat": "{{node}}"
              }
            ],
            "gridPos": {"h": 8, "w": 12, "x": 12, "y": 0}
          },
          {
            "id": 3,
            "title": "Pod Count by Namespace",
            "type": "graph",
            "targets": [
              {
                "expr": "sum(kube_pod_info) by (namespace)",
                "legendFormat": "{{namespace}}"
              }
            ],
            "gridPos": {"h": 8, "w": 24, "x": 0, "y": 8}
          }
        ],
        "time": {"from": "now-1h", "to": "now"},
        "refresh": "30s"
      }
    }
EOF
    
    log "Custom dashboards created successfully"
}

# Deploy sample applications with observability
deploy_sample_apps() {
    log "Deploying sample applications with observability..."
    
    # Create sample app with metrics endpoint
    kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sample-metrics-app
  namespace: default
  labels:
    app: sample-metrics-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: sample-metrics-app
  template:
    metadata:
      labels:
        app: sample-metrics-app
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "8080"
        prometheus.io/path: "/metrics"
    spec:
      containers:
      - name: app
        image: nginx:alpine
        ports:
        - containerPort: 80
        - containerPort: 8080
        resources:
          requests:
            cpu: 50m
            memory: 64Mi
          limits:
            cpu: 100m
            memory: 128Mi
        lifecycle:
          postStart:
            exec:
              command:
              - /bin/sh
              - -c
              - |
                cat > /tmp/metrics.sh << 'EOF'
                #!/bin/sh
                while true; do
                  echo "# HELP http_requests_total Total HTTP requests"
                  echo "# TYPE http_requests_total counter"
                  echo "http_requests_total{method=\"GET\",status=\"200\"} \$((\$RANDOM % 1000))"
                  echo "# HELP app_memory_usage Memory usage in bytes"
                  echo "# TYPE app_memory_usage gauge"
                  echo "app_memory_usage \$((\$RANDOM % 100000000))"
                  sleep 10
                done > /tmp/metrics.txt &
                EOF
                chmod +x /tmp/metrics.sh
                /tmp/metrics.sh &
                while true; do nc -l -p 8080 < /tmp/metrics.txt; done &
---
apiVersion: v1
kind: Service
metadata:
  name: sample-metrics-app
  namespace: default
  labels:
    app: sample-metrics-app
spec:
  selector:
    app: sample-metrics-app
  ports:
  - name: http
    port: 80
    targetPort: 80
  - name: metrics
    port: 8080
    targetPort: 8080
---
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: sample-metrics-app
  namespace: default
  labels:
    app: sample-metrics-app
spec:
  selector:
    matchLabels:
      app: sample-metrics-app
  endpoints:
  - port: metrics
    path: /metrics
    interval: 30s
EOF
    
    log "Sample applications deployed successfully"
}

# Verify installations
verify_installations() {
    log "Verifying observability tool installations..."
    
    local failed=0
    
    # Check Prometheus
    if kubectl get deployment -n monitoring prometheus-kube-prometheus-operator &> /dev/null; then
        log "✅ Prometheus Stack: Running"
    else
        error "❌ Prometheus Stack: Failed"
        failed=1
    fi
    
    # Check Jaeger
    if kubectl get deployment -n tracing jaeger &> /dev/null; then
        log "✅ Jaeger: Running"
    else
        error "❌ Jaeger: Failed"
        failed=1
    fi
    
    # Check OpenTelemetry
    if kubectl get deployment -n opentelemetry-operator-system opentelemetry-operator-controller-manager &> /dev/null; then
        log "✅ OpenTelemetry Operator: Running"
    else
        error "❌ OpenTelemetry Operator: Failed"
        failed=1
    fi
    
    # Check Elasticsearch
    if kubectl get statefulset -n logging elasticsearch-master &> /dev/null; then
        log "✅ Elasticsearch: Running"
    else
        error "❌ Elasticsearch: Failed"
        failed=1
    fi
    
    # Check Kibana
    if kubectl get deployment -n logging kibana-kibana &> /dev/null; then
        log "✅ Kibana: Running"
    else
        error "❌ Kibana: Failed"
        failed=1
    fi
    
    # Check CLI tools
    if command -v stern &> /dev/null; then
        log "✅ Stern CLI: Installed"
    else
        warn "⚠️ Stern CLI: Not found"
    fi
    
    if command -v k9s &> /dev/null; then
        log "✅ K9s CLI: Installed"
    else
        warn "⚠️ K9s CLI: Not found"
    fi
    
    return $failed
}

# Print summary
print_summary() {
    log "Observability tools installation completed!"
    info ""
    info "Installed observability tools:"
    info "  • Prometheus Stack - Metrics collection and alerting"
    info "  • Grafana - Metrics visualization and dashboards"
    info "  • Jaeger - Distributed tracing"
    info "  • OpenTelemetry - Observability data collection"
    info "  • Elasticsearch - Log storage and search"
    info "  • Kibana - Log visualization and analysis"
    info "  • Filebeat - Log shipping"
    info "  • Stern - Multi-pod log streaming"
    info "  • K9s - Terminal-based cluster management"
    info ""
    info "Access URLs:"
    info "  • Grafana: kubectl port-forward svc/prometheus-grafana -n monitoring 3000:80"
    info "  • Prometheus: kubectl port-forward svc/prometheus-kube-prometheus-prometheus -n monitoring 9090:9090"
    info "  • AlertManager: kubectl port-forward svc/prometheus-kube-prometheus-alertmanager -n monitoring 9093:9093"
    info "  • Jaeger UI: kubectl port-forward svc/jaeger-query -n tracing 16686:16686"
    info "  • Kibana: kubectl port-forward svc/kibana-kibana -n logging 5601:5601"
    info ""
    info "Credentials:"
    info "  • Grafana - Username: admin, Password: admin123"
    info ""
    info "Useful commands:"
    info "  • Stream logs: stern <pod-pattern> -n <namespace>"
    info "  • Cluster overview: k9s"
    info "  • Check metrics: curl http://localhost:3000/api/health"
    info "  • View traces: Open Jaeger UI and explore sample traces"
    info ""
    info "Sample metrics endpoint:"
    info "  • App metrics: kubectl port-forward svc/sample-metrics-app 8080:8080"
    info "  • Check metrics: curl http://localhost:8080/metrics"
    info ""
    info "Next steps:"
    info "  1. Explore Grafana dashboards and create custom ones"
    info "  2. Set up alerts in AlertManager"
    info "  3. Generate traces and analyze them in Jaeger"
    info "  4. Use Kibana to search and analyze logs"
    info "  5. Install storage solutions: ./install-storage.sh $ENVIRONMENT"
    info ""
    info "Log file: $LOG_FILE"
}

# Main execution
main() {
    log "Starting observability tools installation for environment: $ENVIRONMENT"
    
    check_prerequisites
    install_prometheus_stack
    install_jaeger
    install_opentelemetry
    install_elk_stack
    install_stern
    install_k9s
    create_dashboards
    deploy_sample_apps
    
    if verify_installations; then
        print_summary
        log "All observability tools installed successfully! ✅"
        exit 0
    else
        error "Some installations failed. Check the log file: $LOG_FILE"
        exit 1
    fi
}

# Run main function
main "$@"