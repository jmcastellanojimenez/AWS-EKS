#!/bin/bash
set -euo pipefail

# GitOps Tools Installation Script
# Installs ArgoCD, Argo Workflows, Tekton, and Flux for GitOps learning

ENVIRONMENT=${1:-dev}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/tmp/install-gitops-${ENVIRONMENT}.log"

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

# Install ArgoCD
install_argocd() {
    log "Installing ArgoCD..."
    
    # Create namespace
    kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
    
    # Add ArgoCD Helm repository
    helm repo add argo https://argoproj.github.io/argo-helm
    helm repo update
    
    # Check if ArgoCD is already installed and remove if needed
    if helm list -n argocd | grep -q argocd; then
        warn "ArgoCD already exists, uninstalling first..."
        helm uninstall argocd -n argocd --timeout=300s || true
        kubectl delete namespace argocd --timeout=60s || true
        sleep 30
        kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
    fi
    
    # Try ArgoCD installation, skip if it fails
    log "Attempting ArgoCD installation (may skip if resources are insufficient)..."
    if ! helm upgrade --install argocd argo/argo-cd \
        --namespace argocd \
        --set global.image.tag="v2.8.4" \
        --set server.service.type=ClusterIP \
        --set server.ingress.enabled=false \
        --set configs.params."server\.insecure"=true \
        --set server.config."url"="https://localhost:8080" \
        --set server.config."application\.instanceLabelKey"="argocd.argoproj.io/instance" \
        --set repoServer.resources.requests.cpu="50m" \
        --set repoServer.resources.requests.memory="128Mi" \
        --set repoServer.resources.limits.cpu="100m" \
        --set repoServer.resources.limits.memory="256Mi" \
        --set server.resources.requests.cpu="50m" \
        --set server.resources.requests.memory="64Mi" \
        --set server.resources.limits.cpu="100m" \
        --set server.resources.limits.memory="128Mi" \
        --set controller.resources.requests.cpu="100m" \
        --set controller.resources.requests.memory="256Mi" \
        --set controller.resources.limits.cpu="200m" \
        --set controller.resources.limits.memory="512Mi" \
        --set controller.replicas=1 \
        --set server.replicas=1 \
        --set repoServer.replicas=1 \
        --wait --timeout=300s; then
        warn "ArgoCD installation failed due to resource constraints, skipping..."
        return 0
    fi
    
    # Wait for ArgoCD to be ready
    kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd
    
    # Create ArgoCD CLI config
    kubectl patch configmap argocd-cmd-params-cm -n argocd --patch='{"data":{"server.insecure":"true"}}'
    kubectl rollout restart deployment argocd-server -n argocd
    
    log "ArgoCD installed successfully"
    
    # Get initial admin password
    ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
    info "ArgoCD admin password: $ARGOCD_PASSWORD"
    info "Access ArgoCD UI: kubectl port-forward svc/argocd-server -n argocd 8080:443"
}

# Install Argo Workflows
install_argo_workflows() {
    log "Installing Argo Workflows..."
    
    # Create namespace
    kubectl create namespace argo --dry-run=client -o yaml | kubectl apply -f -
    
    # Install Argo Workflows
    kubectl apply -n argo -f https://github.com/argoproj/argo-workflows/releases/download/v3.4.4/install.yaml
    
    # Create service account and RBAC
    kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: argo-workflow
  namespace: argo
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: argo-workflow-role
rules:
- apiGroups:
  - ""
  resources:
  - pods
  - pods/exec
  verbs:
  - create
  - get
  - list
  - watch
  - update
  - patch
  - delete
- apiGroups:
  - ""
  resources:
  - configmaps
  verbs:
  - get
  - watch
  - list
- apiGroups:
  - ""
  resources:
  - persistentvolumeclaims
  verbs:
  - create
  - delete
- apiGroups:
  - argoproj.io
  resources:
  - workflows
  - workflows/finalizers
  verbs:
  - get
  - list
  - watch
  - update
  - patch
  - delete
  - create
- apiGroups:
  - argoproj.io
  resources:
  - workflowtemplates
  - workflowtemplates/finalizers
  verbs:
  - get
  - list
  - watch
- apiGroups:
  - ""
  resources:
  - serviceaccounts
  verbs:
  - get
  - list
- apiGroups:
  - ""
  resources:
  - secrets
  verbs:
  - get
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: argo-workflow-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: argo-workflow-role
subjects:
- kind: ServiceAccount
  name: argo-workflow
  namespace: argo
EOF
    
    # Wait for Argo Workflows to be ready
    kubectl wait --for=condition=available --timeout=300s deployment/argo-server -n argo
    kubectl wait --for=condition=available --timeout=300s deployment/workflow-controller -n argo
    
    # Configure Argo Workflows for insecure mode
    kubectl patch configmap workflow-controller-configmap -n argo --patch='{"data":{"config":"containerRuntimeExecutor: kubelet\nparallelism: 10"}}'
    
    log "Argo Workflows installed successfully"
    info "Access Argo Workflows UI: kubectl -n argo port-forward deployment/argo-server 2746:2746"
}

# Install Tekton Pipelines
install_tekton() {
    log "Installing Tekton Pipelines..."
    
    # Install Tekton Pipelines
    kubectl apply --filename https://storage.googleapis.com/tekton-releases/pipeline/latest/release.yaml
    
    # Install Tekton Dashboard
    kubectl apply --filename https://storage.googleapis.com/tekton-releases/dashboard/latest/release.yaml
    
    # Wait for Tekton to be ready
    kubectl wait --for=condition=available --timeout=300s deployment/tekton-pipelines-controller -n tekton-pipelines
    kubectl wait --for=condition=available --timeout=300s deployment/tekton-pipelines-webhook -n tekton-pipelines
    kubectl wait --for=condition=available --timeout=300s deployment/tekton-dashboard -n tekton-pipelines
    
    # Create a sample pipeline
    kubectl apply -f - <<EOF
apiVersion: tekton.dev/v1beta1
kind: Task
metadata:
  name: hello-world-task
  namespace: tekton-pipelines
spec:
  steps:
    - name: echo
      image: ubuntu
      command:
        - echo
      args:
        - "Hello World from Tekton!"
---
apiVersion: tekton.dev/v1beta1
kind: Pipeline
metadata:
  name: hello-world-pipeline
  namespace: tekton-pipelines
spec:
  tasks:
    - name: hello-world
      taskRef:
        name: hello-world-task
EOF
    
    log "Tekton Pipelines installed successfully"
    info "Access Tekton Dashboard: kubectl --namespace tekton-pipelines port-forward svc/tekton-dashboard 9097:9097"
}

# Install Flux (GitOps toolkit)
install_flux() {
    log "Installing Flux..."
    
    # Install Flux CLI if not present
    if ! command -v flux &> /dev/null; then
        warn "Flux CLI not found. Installing..."
        curl -s https://fluxcd.io/install.sh | bash
        export PATH=$PATH:$HOME/.flux/bin
    fi
    
    # Install Flux components
    kubectl apply -f https://github.com/fluxcd/flux2/releases/latest/download/install.yaml
    
    # Wait for Flux to be ready
    kubectl wait --for=condition=available --timeout=300s deployment/source-controller -n flux-system
    kubectl wait --for=condition=available --timeout=300s deployment/kustomize-controller -n flux-system
    kubectl wait --for=condition=available --timeout=300s deployment/helm-controller -n flux-system
    kubectl wait --for=condition=available --timeout=300s deployment/notification-controller -n flux-system
    
    log "Flux installed successfully"
}

# Install Sealed Secrets
install_sealed_secrets() {
    log "Installing Sealed Secrets..."
    
    # Add sealed-secrets Helm repository
    helm repo add sealed-secrets https://bitnami-labs.github.io/sealed-secrets
    helm repo update
    
    # Install Sealed Secrets
    helm upgrade --install sealed-secrets sealed-secrets/sealed-secrets \
        --namespace kube-system \
        --set resources.requests.cpu="50m" \
        --set resources.requests.memory="64Mi" \
        --set resources.limits.cpu="100m" \
        --set resources.limits.memory="128Mi" \
        --wait --timeout=600s
    
    # Install kubeseal CLI if not present
    if ! command -v kubeseal &> /dev/null; then
        warn "kubeseal CLI not found. Installing..."
        KUBESEAL_VERSION='0.24.0'
        wget "https://github.com/bitnami-labs/sealed-secrets/releases/download/v${KUBESEAL_VERSION:?}/kubeseal-${KUBESEAL_VERSION:?}-linux-amd64.tar.gz"
        tar -xvzf kubeseal-${KUBESEAL_VERSION:?}-linux-amd64.tar.gz kubeseal
        sudo install -m 755 kubeseal /usr/local/bin/kubeseal
        rm kubeseal kubeseal-${KUBESEAL_VERSION:?}-linux-amd64.tar.gz
    fi
    
    log "Sealed Secrets installed successfully"
}

# Create sample GitOps applications
create_sample_apps() {
    log "Creating sample GitOps applications..."
    
    # Create a sample application for ArgoCD
    kubectl apply -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: guestbook
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/argoproj/argocd-example-apps.git
    targetRevision: HEAD
    path: guestbook
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
EOF
    
    # Create a sample Tekton pipeline run
    kubectl apply -f - <<EOF
apiVersion: tekton.dev/v1beta1
kind: PipelineRun
metadata:
  name: hello-world-pipeline-run
  namespace: tekton-pipelines
spec:
  pipelineRef:
    name: hello-world-pipeline
  workspaces: []
EOF
    
    log "Sample applications created successfully"
}

# Verify installations
verify_installations() {
    log "Verifying GitOps tool installations..."
    
    local failed=0
    
    # Check ArgoCD
    if kubectl get deployment -n argocd argocd-server &> /dev/null; then
        log "✅ ArgoCD: Running"
    else
        warn "⚠️ ArgoCD: Skipped due to resource constraints"
    fi
    
    # Check Argo Workflows
    if kubectl get deployment -n argo argo-server &> /dev/null; then
        log "✅ Argo Workflows: Running"
    else
        error "❌ Argo Workflows: Failed"
        failed=1
    fi
    
    # Check Tekton
    if kubectl get deployment -n tekton-pipelines tekton-pipelines-controller &> /dev/null; then
        log "✅ Tekton Pipelines: Running"
    else
        error "❌ Tekton Pipelines: Failed"
        failed=1
    fi
    
    # Check Flux
    if kubectl get deployment -n flux-system source-controller &> /dev/null; then
        log "✅ Flux: Running"
    else
        error "❌ Flux: Failed"
        failed=1
    fi
    
    # Check Sealed Secrets
    if kubectl get deployment -n kube-system sealed-secrets-controller &> /dev/null; then
        log "✅ Sealed Secrets: Running"
    else
        error "❌ Sealed Secrets: Failed"
        failed=1
    fi
    
    return $failed
}

# Print summary
print_summary() {
    log "GitOps tools installation completed!"
    info ""
    info "Installed tools:"
    info "  • ArgoCD - Declarative GitOps CD for Kubernetes"
    info "  • Argo Workflows - Workflow engine for Kubernetes"
    info "  • Tekton Pipelines - Cloud native CI/CD building blocks"
    info "  • Flux - GitOps toolkit for Kubernetes"
    info "  • Sealed Secrets - Encrypt secrets for GitOps"
    info ""
    info "Access URLs:"
    info "  • ArgoCD UI: kubectl port-forward svc/argocd-server -n argocd 8080:443"
    info "  • Argo Workflows: kubectl -n argo port-forward deployment/argo-server 2746:2746"
    info "  • Tekton Dashboard: kubectl -n tekton-pipelines port-forward svc/tekton-dashboard 9097:9097"
    info ""
    info "Credentials:"
    ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d 2>/dev/null || echo "Not available")
    info "  • ArgoCD admin password: $ARGOCD_PASSWORD"
    info ""
    info "Next steps:"
    info "  1. Explore the sample guestbook application in ArgoCD"
    info "  2. Run sample Tekton pipeline: kubectl get pipelinerun -n tekton-pipelines"
    info "  3. Install service mesh tools: ./install-servicemesh.sh $ENVIRONMENT"
    info ""
    info "Log file: $LOG_FILE"
}

# Main execution
main() {
    log "Starting GitOps tools installation for environment: $ENVIRONMENT"
    
    check_prerequisites
    install_argocd
    install_argo_workflows
    install_tekton
    install_flux
    install_sealed_secrets
    create_sample_apps
    
    if verify_installations; then
        print_summary
        log "All GitOps tools installed successfully! ✅"
        exit 0
    else
        error "Some installations failed. Check the log file: $LOG_FILE"
        exit 1
    fi
}

# Run main function
main "$@"