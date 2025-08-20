#!/bin/bash
set -euo pipefail

# Ultra-Minimal Tools Installation Script
# Only installs the absolute essentials for learning

ENVIRONMENT=${1:-dev}
LOG_FILE="/tmp/install-minimal-${ENVIRONMENT}.log"

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date +'%H:%M:%S')] $1${NC}" | tee -a "$LOG_FILE"; }
warn() { echo -e "${YELLOW}[$(date +'%H:%M:%S')] WARNING: $1${NC}" | tee -a "$LOG_FILE"; }
error() { echo -e "${RED}[$(date +'%H:%M:%S')] ERROR: $1${NC}" | tee -a "$LOG_FILE"; }

# Check cluster resources
check_resources() {
    log "Checking cluster resources..."
    
    # Get node capacity
    available_pods=$(kubectl get nodes -o jsonpath='{.items[0].status.allocatable.pods}' 2>/dev/null || echo "110")
    current_pods=$(kubectl get pods --all-namespaces --no-headers 2>/dev/null | wc -l || echo "0")
    
    log "Current pods: $current_pods/$available_pods"
    
    if [ "$current_pods" -gt $((available_pods - 5)) ]; then
        error "Cluster is at pod capacity! Cannot install more tools."
        error "Current: $current_pods, Available: $available_pods"
        error "Consider using larger nodes (t3.medium) or fewer tools."
        exit 1
    fi
    
    # Check memory pressure
    kubectl top nodes 2>/dev/null | grep -q "%" && {
        log "Node resource usage:"
        kubectl top nodes 2>/dev/null || true
    }
}

# Install only the most basic observability
install_minimal_monitoring() {
    log "Installing minimal monitoring (Metrics Server only)..."
    
    # Metrics Server (if not already installed by core tools)
    if ! kubectl get deployment metrics-server -n kube-system &>/dev/null; then
        kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
        kubectl wait --for=condition=available --timeout=600s deployment/metrics-server -n kube-system || warn "Metrics server not ready"
    fi
    
    log "Basic monitoring installed"
}

# Install minimal ingress
install_minimal_ingress() {
    log "Installing minimal ingress (NGINX Ingress Controller)..."
    
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/aws/deploy.yaml
    
    # Wait briefly
    sleep 30
    kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=600s || warn "NGINX ingress not ready"
    
    log "Minimal ingress installed"
}

# Create simple demo application
create_demo_app() {
    log "Creating simple demo application..."
    
    kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hello-kubernetes
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: hello-kubernetes
  template:
    metadata:
      labels:
        app: hello-kubernetes
    spec:
      containers:
      - name: hello-kubernetes
        image: paulbouwer/hello-kubernetes:1.10
        ports:
        - containerPort: 8080
        resources:
          requests:
            cpu: 5m
            memory: 8Mi
          limits:
            cpu: 50m
            memory: 64Mi
        env:
        - name: MESSAGE
          value: "Hello from EKS Learning Lab!"
---
apiVersion: v1
kind: Service
metadata:
  name: hello-kubernetes
  namespace: default
spec:
  selector:
    app: hello-kubernetes
  ports:
  - port: 80
    targetPort: 8080
  type: LoadBalancer
EOF

    log "Demo application created"
}

# Create simple dashboard
create_simple_dashboard() {
    log "Creating simple cluster dashboard..."
    
    kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: cluster-dashboard
  namespace: default
data:
  index.html: |
    <!DOCTYPE html>
    <html>
    <head>
        <title>EKS Learning Lab - Simple Dashboard</title>
        <meta http-equiv="refresh" content="30">
        <style>
            body { font-family: Arial, sans-serif; margin: 20px; background: #f5f5f5; }
            .card { background: white; padding: 20px; margin: 10px 0; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
            .header { color: #2196F3; border-bottom: 1px solid #eee; padding-bottom: 10px; }
            .status-ok { color: #4CAF50; }
            .status-warn { color: #FF9800; }
            pre { background: #f8f8f8; padding: 10px; border-radius: 4px; overflow-x: auto; }
        </style>
    </head>
    <body>
        <div class="card">
            <h1 class="header">🚀 EKS Learning Lab Dashboard</h1>
            <p>Lightweight cluster monitoring for learning purposes</p>
            <p><strong>Environment:</strong> Development</p>
            <p><strong>Cost Optimization:</strong> Enabled (Spot instances, Auto-shutdown)</p>
        </div>
        
        <div class="card">
            <h2 class="header">📊 Quick Stats</h2>
            <div id="stats">
                <p>• <span class="status-ok">✓</span> Cluster: Running</p>
                <p>• <span class="status-ok">✓</span> Nodes: 2 (t3.medium spot)</p>
                <p>• <span class="status-warn">⚠</span> Resources: Limited (Learning optimized)</p>
            </div>
        </div>
        
        <div class="card">
            <h2 class="header">🛠️ Available Tools</h2>
            <ul>
                <li><strong>Kubernetes Dashboard:</strong> kubectl port-forward -n kubernetes-dashboard svc/kubernetes-dashboard-kong-proxy 8443:443</li>
                <li><strong>Demo App:</strong> kubectl get svc hello-kubernetes</li>
                <li><strong>Metrics:</strong> kubectl top nodes, kubectl top pods</li>
            </ul>
        </div>
        
        <div class="card">
            <h2 class="header">💰 Cost Information</h2>
            <p><strong>Estimated Cost (24/7):</strong> ~$127/month</p>
            <p><strong>With Scheduled Shutdown:</strong> ~$30-40/month</p>
            <p><strong>Current Mode:</strong> Manual control (no auto-shutdown)</p>
        </div>
        
        <div class="card">
            <h2 class="header">🔧 Useful Commands</h2>
            <pre>
# View cluster resources
kubectl top nodes
kubectl get pods --all-namespaces

# Access demo app
kubectl port-forward svc/hello-kubernetes 8080:80

# Check cluster status
kubectl cluster-info
kubectl get nodes -o wide

# Cost control
# Use GitHub Actions: "Manual Cost Control" workflow
            </pre>
        </div>
    </body>
    </html>
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cluster-dashboard
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: cluster-dashboard
  template:
    metadata:
      labels:
        app: cluster-dashboard
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 80
        resources:
          requests:
            cpu: 5m
            memory: 8Mi
          limits:
            cpu: 20m
            memory: 32Mi
        volumeMounts:
        - name: dashboard
          mountPath: /usr/share/nginx/html
      volumes:
      - name: dashboard
        configMap:
          name: cluster-dashboard
---
apiVersion: v1
kind: Service
metadata:
  name: cluster-dashboard
  namespace: default
spec:
  selector:
    app: cluster-dashboard
  ports:
  - port: 80
    targetPort: 80
EOF

    log "Simple dashboard created"
}

# Main execution
main() {
    log "🚀 Starting ultra-minimal tools installation for EKS Learning Lab"
    
    check_resources
    install_minimal_monitoring
    install_minimal_ingress
    create_demo_app
    create_simple_dashboard
    
    log ""
    log "✅ Minimal installation completed!"
    log ""
    log "📊 Access your tools:"
    log "  • Simple Dashboard: kubectl port-forward svc/cluster-dashboard 8080:80"
    log "  • Demo App: kubectl port-forward svc/hello-kubernetes 8090:80"
    log "  • Kubernetes Dashboard: (from core tools)"
    log ""
    log "🎯 Next steps:"
    log "  1. Access the simple dashboard to see cluster status"
    log "  2. Try the demo application"
    log "  3. Use 'kubectl top nodes' to monitor resources"
    log "  4. Consider t3.medium nodes for more advanced tools"
    log ""
    log "💰 Remember: This cluster costs ~$4/day when running"
    log "📝 Log file: $LOG_FILE"
}

# Run main function
main "$@"