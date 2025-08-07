#!/bin/bash
set -euo pipefail

# Service Mesh Installation Script
# Installs Istio, Linkerd, and Cilium for service mesh learning

ENVIRONMENT=${1:-dev}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/tmp/install-servicemesh-${ENVIRONMENT}.log"

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

# Install minimal Istio (lightweight)
install_lightweight_istio() {
    log "Attempting minimal Istio installation..."
    
    # Download and install Istio CLI if needed
    if ! command -v istioctl &> /dev/null; then
        log "Downloading Istio CLI..."
        curl -L https://istio.io/downloadIstio | ISTIO_VERSION=1.19.3 sh -
        sudo mv istio-*/bin/istioctl /usr/local/bin/
        rm -rf istio-*
    fi
    
    # Try minimal Istio installation
    if timeout 300 istioctl install \
        --set values.pilot.resources.requests.cpu=25m \
        --set values.pilot.resources.requests.memory=32Mi \
        --set values.pilot.resources.limits.cpu=100m \
        --set values.pilot.resources.limits.memory=128Mi \
        --set values.pilot.env.EXTERNAL_ISTIOD=false \
        --set values.gateways.istio-ingressgateway.enabled=false \
        --set values.gateways.istio-egressgateway.enabled=false \
        --readiness-timeout=5m -y; then
        log "Minimal Istio installed successfully"
        return 0
    else
        warn "Minimal Istio installation failed"
        return 1
    fi
}

# Install minimal Linkerd (lightweight)
install_lightweight_linkerd() {
    log "Attempting minimal Linkerd installation..."
    
    # Download Linkerd CLI if needed
    if ! command -v linkerd &> /dev/null; then
        log "Downloading Linkerd CLI..."
        curl -sL https://run.linkerd.io/install-edge | sh
        sudo mv ~/.linkerd2/bin/linkerd /usr/local/bin/
    fi
    
    # Install Gateway API CRDs (required)
    kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.1/standard-install.yaml || true
    
    # Try minimal Linkerd installation
    if linkerd install --crds | kubectl apply -f - && \
       linkerd install \
         --proxy-cpu-request=5m \
         --proxy-memory-request=8Mi \
         --proxy-cpu-limit=50m \
         --proxy-memory-limit=64Mi | kubectl apply -f -; then
        log "Minimal Linkerd installed successfully"
        return 0
    else
        warn "Minimal Linkerd installation failed"
        return 1
    fi
}

# Legacy Istio function (kept for compatibility)
install_istio() {
    log "Installing Istio..."
    
    # Download and install Istio CLI
    if ! command -v istioctl &> /dev/null; then
        log "Downloading Istio CLI..."
        curl -L https://istio.io/downloadIstio | ISTIO_VERSION=1.19.3 sh -
        sudo mv istio-*/bin/istioctl /usr/local/bin/
        rm -rf istio-*
    fi
    
    # Try minimal Istio installation, skip if it fails
    log "Attempting Istio installation (may skip if resources are insufficient)..."
    if ! timeout 600 istioctl install \
        --set values.defaultRevision=default \
        --set values.pilot.resources.requests.cpu=50m \
        --set values.pilot.resources.requests.memory=64Mi \
        --set values.pilot.resources.limits.cpu=200m \
        --set values.pilot.resources.limits.memory=256Mi \
        --set values.pilot.env.PILOT_ENABLE_WORKLOAD_ENTRY_AUTO_REGISTRATION=true \
        --readiness-timeout=10m -y; then
        warn "Istio installation failed due to resource constraints, skipping..."
        return 0
    fi
    
    # Enable sidecar injection for default namespace
    kubectl label namespace default istio-injection=enabled --overwrite
    
    # Install Istio addons
    kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.19/samples/addons/grafana.yaml
    kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.19/samples/addons/jaeger.yaml
    kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.19/samples/addons/kiali.yaml
    kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.19/samples/addons/prometheus.yaml
    
    # Wait for Istio components to be ready - increased timeouts
    kubectl wait --for=condition=available --timeout=600s deployment/istiod -n istio-system
    kubectl wait --for=condition=available --timeout=600s deployment/grafana -n istio-system || warn "Grafana not ready"
    kubectl wait --for=condition=available --timeout=600s deployment/kiali -n istio-system || warn "Kiali not ready"
    
    log "Istio installed successfully"
}

# Install Linkerd
install_linkerd() {
    log "Installing Linkerd..."
    
    # Download and install Linkerd CLI
    if ! command -v linkerd &> /dev/null; then
        log "Downloading Linkerd CLI..."
        curl -sL https://run.linkerd.io/install | sh
        sudo mv ~/.linkerd2/bin/linkerd /usr/local/bin/
    fi
    
    # Install Gateway API CRDs first (required by Linkerd)
    kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.1/standard-install.yaml || warn "Gateway API already installed"
    
    # Check cluster compatibility
    linkerd check --pre || warn "Linkerd pre-check failed"
    
    # Install Linkerd CRDs
    linkerd install --crds | kubectl apply -f -
    
    # Install Linkerd control plane
    linkerd install --set proxy.resources.cpu.request=10m --set proxy.resources.memory.request=10Mi --set proxy.resources.cpu.limit=100m --set proxy.resources.memory.limit=128Mi | kubectl apply -f -
    
    # Wait for Linkerd to be ready
    linkerd check
    
    # Install Linkerd Viz extension
    linkerd viz install | kubectl apply -f -
    
    # Wait for Viz to be ready
    linkerd check --addon viz
    
    log "Linkerd installed successfully"
}

# Install Cilium (as CNI replacement - optional)
install_cilium_cli() {
    log "Installing Cilium CLI and Hubble..."
    
    # Install Cilium CLI
    if ! command -v cilium &> /dev/null; then
        log "Downloading Cilium CLI..."
        CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/master/stable.txt)
        CLI_ARCH=amd64
        curl -L --fail --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}
        sha256sum --check cilium-linux-${CLI_ARCH}.tar.gz.sha256sum
        sudo tar xzvfC cilium-linux-${CLI_ARCH}.tar.gz /usr/local/bin
        rm cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}
    fi
    
    # Install Hubble CLI
    if ! command -v hubble &> /dev/null; then
        log "Downloading Hubble CLI..."
        HUBBLE_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/hubble/master/stable.txt)
        HUBBLE_ARCH=amd64
        curl -L --fail --remote-name-all https://github.com/cilium/hubble/releases/download/$HUBBLE_VERSION/hubble-linux-${HUBBLE_ARCH}.tar.gz{,.sha256sum}
        sha256sum --check hubble-linux-${HUBBLE_ARCH}.tar.gz.sha256sum
        sudo tar xzvfC hubble-linux-${HUBBLE_ARCH}.tar.gz /usr/local/bin
        rm hubble-linux-${HUBBLE_ARCH}.tar.gz{,.sha256sum}
    fi
    
    # Enable Hubble UI (observability for Cilium)
    helm repo add cilium https://helm.cilium.io/
    helm repo update
    
    # Install Hubble UI
    helm upgrade --install hubble-ui cilium/hubble-ui \
        --namespace kube-system \
        --set hubble.enabled=true \
        --set hubble.ui.enabled=true \
        --set hubble.relay.enabled=true \
        --set hubble.ui.ingress.enabled=false \
        --wait --timeout=600s
    
    log "Cilium CLI and Hubble installed successfully"
}

# Install Open Service Mesh (OSM)
install_osm() {
    log "Installing Open Service Mesh (OSM)..."
    
    # Download and install OSM CLI
    if ! command -v osm &> /dev/null; then
        log "Downloading OSM CLI..."
        system=$(uname -s | tr '[:upper:]' '[:lower:]')
        arch=$(uname -m | sed 's/x86_64/amd64/g' | sed 's/aarch64/arm64/g')
        release=$(curl -s https://api.github.com/repos/openservicemesh/osm/releases/latest | grep tag_name | cut -d '"' -f 4)
        curl -L https://github.com/openservicemesh/osm/releases/download/$release/osm-$release-$system-$arch.tar.gz | tar -vxzf -
        sudo mv ./$system-$arch/osm /usr/local/bin/
        rm -rf ./$system-$arch
    fi
    
    # Install OSM
    osm install --mesh-name osm --osm-namespace osm-system --set=osm.injector.resource.requests.cpu=100m --set=osm.injector.resource.requests.memory=64Mi --set=osm.injector.resource.limits.cpu=200m --set=osm.injector.resource.limits.memory=128Mi
    
    # Wait for OSM to be ready
    kubectl wait --for=condition=available --timeout=300s deployment/osm-controller -n osm-system
    kubectl wait --for=condition=available --timeout=300s deployment/osm-injector -n osm-system
    
    log "Open Service Mesh installed successfully"
}

# Deploy sample applications
deploy_sample_apps() {
    log "Deploying sample applications for service mesh demonstration..."
    
    # Create namespace for sample apps
    kubectl create namespace sample-apps --dry-run=client -o yaml | kubectl apply -f -
    
    # Label namespace for Istio injection
    kubectl label namespace sample-apps istio-injection=enabled --overwrite
    
    # Deploy BookInfo sample application (Istio)
    kubectl apply -n sample-apps -f https://raw.githubusercontent.com/istio/istio/release-1.19/samples/bookinfo/platform/kube/bookinfo.yaml
    kubectl apply -n sample-apps -f https://raw.githubusercontent.com/istio/istio/release-1.19/samples/bookinfo/networking/bookinfo-gateway.yaml
    
    # Deploy sample app for Linkerd
    kubectl create namespace linkerd-sample --dry-run=client -o yaml | kubectl apply -f -
    kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hello-linkerd
  namespace: linkerd-sample
spec:
  replicas: 1
  selector:
    matchLabels:
      app: hello-linkerd
  template:
    metadata:
      labels:
        app: hello-linkerd
      annotations:
        linkerd.io/inject: enabled
    spec:
      containers:
      - name: hello
        image: buoyantio/bb:v0.0.6
        ports:
        - containerPort: 9898
        env:
        - name: PORT
          value: "9898"
        resources:
          requests:
            cpu: 10m
            memory: 16Mi
          limits:
            cpu: 50m
            memory: 64Mi
---
apiVersion: v1
kind: Service
metadata:
  name: hello-linkerd
  namespace: linkerd-sample
spec:
  selector:
    app: hello-linkerd
  ports:
  - port: 80
    targetPort: 9898
EOF
    
    # Inject Linkerd proxy
    kubectl get deployment hello-linkerd -n linkerd-sample -o yaml | linkerd inject - | kubectl apply -f -
    
    log "Sample applications deployed successfully"
}

# Create network policies
create_network_policies() {
    log "Creating network policies for security..."
    
    # Create a default deny-all network policy
    kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: sample-apps
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-bookinfo-traffic
  namespace: sample-apps
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: istio-system
    - namespaceSelector:
        matchLabels:
          name: sample-apps
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          name: istio-system
    - namespaceSelector:
        matchLabels:
          name: sample-apps
  - to: {}
    ports:
    - protocol: TCP
      port: 53
    - protocol: UDP
      port: 53
    - protocol: TCP
      port: 443
EOF
    
    log "Network policies created successfully"
}

# Verify installations
verify_installations() {
    log "Verifying service mesh installations..."
    
    local failed=0
    
    # Check Istio
    if kubectl get deployment -n istio-system istiod &> /dev/null; then
        log "✅ Istio: Running"
    else
        error "❌ Istio: Failed"
        failed=1
    fi
    
    # Check Linkerd
    if kubectl get deployment -n linkerd linkerd-controller &> /dev/null; then
        log "✅ Linkerd: Running"
    else
        error "❌ Linkerd: Failed"
        failed=1
    fi
    
    # Check OSM
    if kubectl get deployment -n osm-system osm-controller &> /dev/null; then
        log "✅ Open Service Mesh: Running"
    else
        error "❌ Open Service Mesh: Failed"
        failed=1
    fi
    
    # Check Hubble UI
    if kubectl get deployment -n kube-system hubble-ui &> /dev/null; then
        log "✅ Hubble UI: Running"
    else
        warn "⚠️ Hubble UI: Not found (this is okay if Cilium is not the primary CNI)"
    fi
    
    return $failed
}

# Print summary
print_summary() {
    log "Service mesh tools installation completed!"
    info ""
    info "Installed service meshes:"
    info "  • Istio - Complete service mesh solution"
    info "  • Linkerd - Ultralight service mesh"
    info "  • Open Service Mesh (OSM) - SMI-compliant service mesh"
    info "  • Cilium/Hubble CLI - eBPF-based networking and security"
    info ""
    info "Access URLs:"
    info "  • Kiali (Istio): kubectl port-forward svc/kiali -n istio-system 20001:20001"
    info "  • Grafana (Istio): kubectl port-forward svc/grafana -n istio-system 3000:3000"
    info "  • Jaeger (Istio): kubectl port-forward svc/jaeger -n istio-system 16686:16686"
    info "  • Linkerd Viz: linkerd viz dashboard"
    info "  • Hubble UI: kubectl port-forward svc/hubble-ui -n kube-system 12000:80"
    info ""
    info "Sample applications:"
    info "  • BookInfo (Istio): kubectl get pods -n sample-apps"
    info "  • Hello Linkerd: kubectl get pods -n linkerd-sample"
    info ""
    info "Useful commands:"
    info "  • Check Istio proxy status: istioctl proxy-status"
    info "  • Check Linkerd data plane: linkerd check --proxy"
    info "  • Linkerd top command: linkerd viz top pods"
    info "  • OSM mesh status: osm mesh list"
    info ""
    info "Next steps:"
    info "  1. Explore service mesh features with sample applications"
    info "  2. Learn about traffic management, security policies, and observability"
    info "  3. Install security tools: ./install-security.sh $ENVIRONMENT"
    info ""
    info "Log file: $LOG_FILE"
}

# Main execution
main() {
    log "Starting service mesh installation for environment: $ENVIRONMENT"
    
    check_prerequisites
    
    # Check available resources first
    available_pods=$(kubectl get nodes -o jsonpath='{.items[0].status.allocatable.pods}')
    current_pods=$(kubectl get pods --all-namespaces --no-headers | wc -l)
    log "Current pods: $current_pods, Node capacity: $available_pods"
    
    if [ "$current_pods" -gt $((available_pods - 10)) ]; then
        warn "Cluster is near pod capacity ($current_pods/$available_pods). Skipping service mesh installation."
        warn "Consider using larger nodes (t3.medium) for service mesh features."
        return 0
    fi
    
    # Try only one lightweight service mesh
    if ! install_lightweight_istio; then
        warn "Istio failed, trying Linkerd..."
        if ! install_lightweight_linkerd; then
            warn "Both Istio and Linkerd failed due to resource constraints"
            log "Service mesh installation skipped - cluster needs more resources"
            return 0
        fi
    fi
    
    # Skip heavy components
    log "Skipping OSM, Cilium, and sample apps due to resource constraints"
    
    if verify_installations; then
        print_summary
        log "All service mesh tools installed successfully! ✅"
        exit 0
    else
        error "Some installations failed. Check the log file: $LOG_FILE"
        exit 1
    fi
}

# Run main function
main "$@"