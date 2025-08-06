#!/bin/bash
set -euo pipefail

# Security Tools Installation Script
# Installs Vault, OPA Gatekeeper, Kyverno, Falco, and other security tools

ENVIRONMENT=${1:-dev}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/tmp/install-security-${ENVIRONMENT}.log"

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

# Install HashiCorp Vault
install_vault() {
    log "Installing HashiCorp Vault..."
    
    # Add HashiCorp Helm repository
    helm repo add hashicorp https://helm.releases.hashicorp.com
    helm repo update
    
    # Create namespace
    kubectl create namespace vault --dry-run=client -o yaml | kubectl apply -f -
    
    # Install Vault in development mode for learning
    helm upgrade --install vault hashicorp/vault \
        --namespace vault \
        --set server.dev.enabled=true \
        --set server.dev.devRootToken="root-token" \
        --set injector.enabled=true \
        --set server.dataStorage.enabled=false \
        --set server.resources.requests.memory=128Mi \
        --set server.resources.requests.cpu=50m \
        --set server.resources.limits.memory=256Mi \
        --set server.resources.limits.cpu=100m \
        --set injector.resources.requests.memory=64Mi \
        --set injector.resources.requests.cpu=50m \
        --set injector.resources.limits.memory=128Mi \
        --set injector.resources.limits.cpu=100m \
        --wait --timeout=900s
    
    # Wait for Vault to be ready
    kubectl wait --for=condition=ready --timeout=600s pod/vault-0 -n vault
    
    # Configure Vault for Kubernetes authentication
    kubectl exec -n vault vault-0 -- vault auth enable kubernetes
    kubectl exec -n vault vault-0 -- vault write auth/kubernetes/config \
        token_reviewer_jwt="$(kubectl get secret vault-token-reviewer -n vault -o jsonpath='{.data.token}' | base64 -d)" \
        kubernetes_host="https://kubernetes.default.svc:443" \
        kubernetes_ca_cert="$(kubectl exec -n vault vault-0 -- cat /var/run/secrets/kubernetes.io/serviceaccount/ca.crt)"
    
    log "Vault installed successfully"
}

# Install OPA Gatekeeper
install_opa_gatekeeper() {
    log "Installing OPA Gatekeeper..."
    
    # Add Gatekeeper Helm repository
    helm repo add gatekeeper https://open-policy-agent.github.io/gatekeeper/charts
    helm repo update
    
    # Install Gatekeeper
    helm upgrade --install gatekeeper gatekeeper/gatekeeper \
        --namespace gatekeeper-system \
        --create-namespace \
        --set resources.requests.cpu=100m \
        --set resources.requests.memory=256Mi \
        --set resources.limits.cpu=500m \
        --set resources.limits.memory=512Mi \
        --set audit.resources.requests.cpu=100m \
        --set audit.resources.requests.memory=256Mi \
        --set audit.resources.limits.cpu=500m \
        --set audit.resources.limits.memory=512Mi \
        --wait --timeout=900s
    
    # Wait for Gatekeeper to be ready
    kubectl wait --for=condition=available --timeout=600s deployment/gatekeeper-controller-manager -n gatekeeper-system
    
    # Create sample constraint templates and constraints
    kubectl apply -f - <<EOF
apiVersion: templates.gatekeeper.sh/v1beta1
kind: ConstraintTemplate
metadata:
  name: k8srequiredlabels
spec:
  crd:
    spec:
      names:
        kind: K8sRequiredLabels
      validation:
        openAPIV3Schema:
          type: object
          properties:
            labels:
              type: array
              items:
                type: string
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8srequiredlabels

        violation[{"msg": msg}] {
          required := input.parameters.labels
          provided := input.review.object.metadata.labels
          missing := required[_]
          not provided[missing]
          msg := sprintf("You must provide labels: %v", [missing])
        }
---
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sRequiredLabels
metadata:
  name: must-have-environment
spec:
  match:
    kinds:
      - apiGroups: ["apps"]
        kinds: ["Deployment"]
    namespaces: ["default", "sample-apps"]
  parameters:
    labels: ["environment"]
EOF
    
    log "OPA Gatekeeper installed successfully"
}

# Install Kyverno
install_kyverno() {
    log "Installing Kyverno..."
    
    # Add Kyverno Helm repository
    helm repo add kyverno https://kyverno.github.io/kyverno/
    helm repo update
    
    # Install Kyverno
    helm upgrade --install kyverno kyverno/kyverno \
        --namespace kyverno \
        --create-namespace \
        --set resources.requests.memory=128Mi \
        --set resources.requests.cpu=100m \
        --set resources.limits.memory=512Mi \
        --set resources.limits.cpu=500m \
        --set initContainer.resources.requests.memory=64Mi \
        --set initContainer.resources.requests.cpu=50m \
        --set initContainer.resources.limits.memory=128Mi \
        --set initContainer.resources.limits.cpu=100m \
        --wait --timeout=900s
    
    # Wait for Kyverno to be ready
    kubectl wait --for=condition=available --timeout=600s deployment/kyverno-admission-controller -n kyverno
    
    # Create sample Kyverno policies
    kubectl apply -f - <<EOF
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: add-default-resources
spec:
  background: false
  rules:
  - name: add-default-requests
    match:
      any:
      - resources:
          kinds:
          - Deployment
    mutate:
      patchStrategicMerge:
        spec:
          template:
            spec:
              containers:
              - (name): "*"
                resources:
                  requests:
                    +(memory): "64Mi"
                    +(cpu): "50m"
                  limits:
                    +(memory): "128Mi"
                    +(cpu): "100m"
---
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: disallow-privileged-containers
spec:
  background: true
  validationFailureAction: enforce
  rules:
  - name: check-privileged
    match:
      any:
      - resources:
          kinds:
          - Pod
          - Deployment
    validate:
      message: "Privileged containers are not allowed"
      pattern:
        spec:
          =(securityContext):
            =(privileged): "false"
          containers:
          - name: "*"
            =(securityContext):
              =(privileged): "false"
EOF
    
    log "Kyverno installed successfully"
}

# Install Falco
install_falco() {
    log "Installing Falco..."
    
    # Add Falco Helm repository
    helm repo add falcosecurity https://falcosecurity.github.io/charts
    helm repo update
    
    # Install Falco
    helm upgrade --install falco falcosecurity/falco \
        --namespace falco \
        --create-namespace \
        --set driver.kind=ebpf \
        --set collectors.enabled=false \
        --set falcosidekick.enabled=true \
        --set falcosidekick.webui.enabled=true \
        --set resources.requests.cpu=100m \
        --set resources.requests.memory=128Mi \
        --set resources.limits.cpu=200m \
        --set resources.limits.memory=256Mi \
        --wait --timeout=900s
    
    # Wait for Falco to be ready
    kubectl wait --for=condition=ready --timeout=300s pod -l app.kubernetes.io/name=falco -n falco
    
    log "Falco installed successfully"
}

# Install Trivy Operator
install_trivy_operator() {
    log "Installing Trivy Operator..."
    
    # Add Aqua Helm repository
    helm repo add aqua https://aquasecurity.github.io/helm-charts/
    helm repo update
    
    # Install Trivy Operator
    helm upgrade --install trivy-operator aqua/trivy-operator \
        --namespace trivy-system \
        --create-namespace \
        --set operator.resources.requests.cpu=50m \
        --set operator.resources.requests.memory=64Mi \
        --set operator.resources.limits.cpu=100m \
        --set operator.resources.limits.memory=128Mi \
        --wait --timeout=900s
    
    # Wait for Trivy Operator to be ready
    kubectl wait --for=condition=available --timeout=600s deployment/trivy-operator -n trivy-system
    
    log "Trivy Operator installed successfully"
}

# Install Pod Security Standards
install_pod_security_standards() {
    log "Configuring Pod Security Standards..."
    
    # Label namespaces with Pod Security Standards
    kubectl label namespace default pod-security.kubernetes.io/enforce=baseline
    kubectl label namespace default pod-security.kubernetes.io/audit=restricted
    kubectl label namespace default pod-security.kubernetes.io/warn=restricted
    
    kubectl label namespace kube-system pod-security.kubernetes.io/enforce=privileged
    kubectl label namespace kube-system pod-security.kubernetes.io/audit=privileged
    kubectl label namespace kube-system pod-security.kubernetes.io/warn=privileged
    
    # Create a restricted namespace for testing
    kubectl create namespace secure-apps --dry-run=client -o yaml | kubectl apply -f -
    kubectl label namespace secure-apps pod-security.kubernetes.io/enforce=restricted
    kubectl label namespace secure-apps pod-security.kubernetes.io/audit=restricted
    kubectl label namespace secure-apps pod-security.kubernetes.io/warn=restricted
    
    log "Pod Security Standards configured successfully"
}

# Install Network Policies
install_network_policies() {
    log "Installing sample Network Policies..."
    
    # Create network policies for different scenarios
    kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all-ingress
  namespace: secure-apps
spec:
  podSelector: {}
  policyTypes:
  - Ingress
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns-egress
  namespace: secure-apps
spec:
  podSelector: {}
  policyTypes:
  - Egress
  egress:
  - to: []
    ports:
    - protocol: UDP
      port: 53
    - protocol: TCP
      port: 53
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-monitoring-ingress
  namespace: default
spec:
  podSelector:
    matchLabels:
      monitoring: "true"
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: monitoring
    ports:
    - protocol: TCP
      port: 8080
EOF
    
    log "Network Policies installed successfully"
}

# Deploy security monitoring tools
deploy_security_monitoring() {
    log "Deploying security monitoring components..."
    
    # Create a simple security monitoring dashboard
    kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: security-dashboard
  namespace: default
data:
  index.html: |
    <!DOCTYPE html>
    <html>
    <head>
        <title>EKS Security Dashboard</title>
        <style>
            body { font-family: Arial, sans-serif; margin: 20px; }
            .card { border: 1px solid #ddd; padding: 20px; margin: 10px 0; border-radius: 5px; }
            .header { background: #2196F3; color: white; padding: 10px; margin: -20px -20px 20px -20px; }
        </style>
    </head>
    <body>
        <h1>EKS Learning Lab - Security Dashboard</h1>
        
        <div class="card">
            <div class="header">Security Tools Status</div>
            <ul>
                <li>HashiCorp Vault - Secret Management</li>
                <li>OPA Gatekeeper - Policy Enforcement</li>
                <li>Kyverno - Policy Management</li>
                <li>Falco - Runtime Security</li>
                <li>Trivy Operator - Vulnerability Scanning</li>
                <li>Pod Security Standards - Built-in Security</li>
            </ul>
        </div>
        
        <div class="card">
            <div class="header">Access Commands</div>
            <pre>
    # Vault UI
    kubectl port-forward svc/vault-ui -n vault 8200:8200
    
    # Falco Sidekick UI
    kubectl port-forward svc/falco-falcosidekick-ui -n falco 2802:2802
    
    # Check Gatekeeper violations
    kubectl get constraints
    
    # Check Kyverno policies
    kubectl get cpol
    
    # View security reports
    kubectl get vulnerabilityreports -A
            </pre>
        </div>
    </body>
    </html>
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: security-dashboard
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: security-dashboard
  template:
    metadata:
      labels:
        app: security-dashboard
        monitoring: "true"
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 80
        volumeMounts:
        - name: dashboard
          mountPath: /usr/share/nginx/html
        resources:
          requests:
            cpu: 10m
            memory: 16Mi
          limits:
            cpu: 50m
            memory: 64Mi
      volumes:
      - name: dashboard
        configMap:
          name: security-dashboard
---
apiVersion: v1
kind: Service
metadata:
  name: security-dashboard
  namespace: default
spec:
  selector:
    app: security-dashboard
  ports:
  - port: 80
    targetPort: 80
EOF
    
    log "Security monitoring components deployed successfully"
}

# Verify installations
verify_installations() {
    log "Verifying security tool installations..."
    
    local failed=0
    
    # Check Vault
    if kubectl get pod -n vault vault-0 &> /dev/null; then
        log "✅ HashiCorp Vault: Running"
    else
        error "❌ HashiCorp Vault: Failed"
        failed=1
    fi
    
    # Check OPA Gatekeeper
    if kubectl get deployment -n gatekeeper-system gatekeeper-controller-manager &> /dev/null; then
        log "✅ OPA Gatekeeper: Running"
    else
        error "❌ OPA Gatekeeper: Failed"
        failed=1
    fi
    
    # Check Kyverno
    if kubectl get deployment -n kyverno kyverno-admission-controller &> /dev/null; then
        log "✅ Kyverno: Running"
    else
        error "❌ Kyverno: Failed"
        failed=1
    fi
    
    # Check Falco
    if kubectl get daemonset -n falco falco &> /dev/null; then
        log "✅ Falco: Running"
    else
        error "❌ Falco: Failed"
        failed=1
    fi
    
    # Check Trivy Operator
    if kubectl get deployment -n trivy-system trivy-operator &> /dev/null; then
        log "✅ Trivy Operator: Running"
    else
        error "❌ Trivy Operator: Failed"
        failed=1
    fi
    
    return $failed
}

# Print summary
print_summary() {
    log "Security tools installation completed!"
    info ""
    info "Installed security tools:"
    info "  • HashiCorp Vault - Secret management and encryption"
    info "  • OPA Gatekeeper - Policy enforcement with OPA"
    info "  • Kyverno - Kubernetes native policy management"
    info "  • Falco - Runtime security monitoring"
    info "  • Trivy Operator - Vulnerability scanning"
    info "  • Pod Security Standards - Built-in Kubernetes security"
    info "  • Network Policies - Network segmentation"
    info ""
    info "Access URLs:"
    info "  • Vault UI: kubectl port-forward svc/vault -n vault 8200:8200"
    info "  • Falco Sidekick UI: kubectl port-forward svc/falco-falcosidekick-ui -n falco 2802:2802"
    info "  • Security Dashboard: kubectl port-forward svc/security-dashboard 8080:80"
    info ""
    info "Vault credentials (dev mode):"
    info "  • Root token: root-token"
    info "  • Vault address: http://localhost:8200"
    info ""
    info "Useful commands:"
    info "  • Check policy violations: kubectl get constraints"
    info "  • View Kyverno policies: kubectl get cpol"
    info "  • Check security reports: kubectl get vulnerabilityreports -A"
    info "  • View Falco alerts: kubectl logs -n falco -l app.kubernetes.io/name=falco"
    info ""
    info "Next steps:"
    info "  1. Explore policy enforcement with sample violations"
    info "  2. Set up Vault secrets for your applications"
    info "  3. Review security reports and fix vulnerabilities"
    info "  4. Install observability tools: ./install-observability.sh $ENVIRONMENT"
    info ""
    info "Log file: $LOG_FILE"
}

# Main execution
main() {
    log "Starting security tools installation for environment: $ENVIRONMENT"
    
    check_prerequisites
    install_vault
    install_opa_gatekeeper
    install_kyverno
    install_falco
    install_trivy_operator
    install_pod_security_standards
    install_network_policies
    deploy_security_monitoring
    
    if verify_installations; then
        print_summary
        log "All security tools installed successfully! ✅"
        exit 0
    else
        error "Some installations failed. Check the log file: $LOG_FILE"
        exit 1
    fi
}

# Run main function
main "$@"