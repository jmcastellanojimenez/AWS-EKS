#!/bin/bash

# =============================================================================
# EcoTrack Workflow 4: GitOps & Deployment Automation Setup Script
# =============================================================================
# This script deploys a complete GitOps platform using ArgoCD and Tekton
# for the EcoTrack microservices platform on any Kubernetes cluster.
#
# Features:
# - Cloud-agnostic deployment
# - Production-ready configuration
# - LGTM observability integration
# - Ambassador ingress integration
# - Complete RBAC setup
# - Security scanning integration
# =============================================================================

set -euo pipefail

# =============================================================================
# Configuration and Variables
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly YELLOW='\033[1;33m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# Default configuration
CLUSTER_NAME="${CLUSTER_NAME:-}"
CONTAINER_REGISTRY="${CONTAINER_REGISTRY:-}"
GITHUB_ORG="${GITHUB_ORG:-}"
GITHUB_TOKEN="${GITHUB_TOKEN:-}"
GITHUB_USERNAME="${GITHUB_USERNAME:-}"
DOMAIN="${DOMAIN:-}"
SLACK_WEBHOOK_URL="${SLACK_WEBHOOK_URL:-}"
DRY_RUN="${DRY_RUN:-false}"
SKIP_PREREQUISITES="${SKIP_PREREQUISITES:-false}"
ENABLE_MONITORING="${ENABLE_MONITORING:-true}"
ENABLE_SECURITY="${ENABLE_SECURITY:-true}"

# Internal variables
ARGOCD_NAMESPACE="argocd"
TEKTON_NAMESPACE="tekton-pipelines"
ECOTRACK_NAMESPACE="ecotrack-dev"
TEMP_DIR=""

# =============================================================================
# Helper Functions
# =============================================================================

log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
    exit 1
}

info() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')] INFO: $1${NC}"
}

success() {
    echo -e "${CYAN}[$(date '+%Y-%m-%d %H:%M:%S')] SUCCESS: $1${NC}"
}

header() {
    echo -e "${PURPLE}"
    echo "============================================================================="
    echo "  $1"
    echo "============================================================================="
    echo -e "${NC}"
}

# Cleanup function
cleanup() {
    if [[ -n "$TEMP_DIR" && -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR"
    fi
}

# Set up cleanup on exit
trap cleanup EXIT

# =============================================================================
# Validation Functions
# =============================================================================

validate_prerequisites() {
    if [[ "$SKIP_PREREQUISITES" == "true" ]]; then
        warn "Skipping prerequisite validation"
        return 0
    fi

    header "Validating Prerequisites"
    
    # Check operating system
    if [[ "$OSTYPE" != "darwin"* ]] && [[ "$OSTYPE" != "linux-gnu"* ]]; then
        error "This script requires macOS or Linux"
    fi
    
    # Required tools
    local required_tools=("kubectl" "helm" "jq" "yq" "curl" "git")
    
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            error "Required tool '$tool' is not installed. Please install it and try again."
        fi
        info "✓ $tool is available"
    done
    
    # Check kubectl context
    if ! kubectl cluster-info &> /dev/null; then
        error "kubectl is not configured or cluster is not accessible"
    fi
    
    local context=$(kubectl config current-context)
    info "✓ Connected to Kubernetes cluster: $context"
    
    # Check cluster version
    local k8s_version=$(kubectl version --output=json | jq -r '.serverVersion.gitVersion')
    info "✓ Kubernetes version: $k8s_version"
    
    # Validate Kubernetes version
    local min_version="v1.24.0"
    if ! version_compare "$k8s_version" "$min_version"; then
        error "Kubernetes version $k8s_version is not supported. Minimum version: $min_version"
    fi
    
    success "Prerequisites validation completed"
}

# Version comparison function
version_compare() {
    local version1=$1
    local version2=$2
    
    # Remove 'v' prefix if present
    version1=${version1#v}
    version2=${version2#v}
    
    if [[ "$(printf '%s\n' "$version1" "$version2" | sort -V | head -n1)" == "$version2" ]]; then
        return 0
    else
        return 1
    fi
}

validate_configuration() {
    header "Validating Configuration"
    
    # Validate required environment variables
    if [[ -z "$CLUSTER_NAME" ]]; then
        error "CLUSTER_NAME environment variable is required"
    fi
    
    if [[ -z "$CONTAINER_REGISTRY" ]]; then
        error "CONTAINER_REGISTRY environment variable is required"
    fi
    
    if [[ -z "$GITHUB_ORG" ]]; then
        error "GITHUB_ORG environment variable is required"
    fi
    
    if [[ -z "$GITHUB_TOKEN" ]]; then
        error "GITHUB_TOKEN environment variable is required"
    fi
    
    # Validate GitHub token
    if ! curl -s -H "Authorization: token $GITHUB_TOKEN" \
         "https://api.github.com/user" | jq -r '.login' &> /dev/null; then
        error "Invalid GitHub token or API access failed"
    fi
    
    # Set defaults for optional variables
    GITHUB_USERNAME="${GITHUB_USERNAME:-$(curl -s -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/user | jq -r '.login')}"
    DOMAIN="${DOMAIN:-cluster.local}"
    
    info "✓ Cluster Name: $CLUSTER_NAME"
    info "✓ Container Registry: $CONTAINER_REGISTRY"
    info "✓ GitHub Organization: $GITHUB_ORG"
    info "✓ GitHub Username: $GITHUB_USERNAME"
    info "✓ Domain: $DOMAIN"
    info "✓ Monitoring Enabled: $ENABLE_MONITORING"
    info "✓ Security Features: $ENABLE_SECURITY"
    
    success "Configuration validation completed"
}

# =============================================================================
# Installation Functions
# =============================================================================

setup_namespaces() {
    header "Setting Up Namespaces"
    
    local namespaces=("$ARGOCD_NAMESPACE" "$TEKTON_NAMESPACE" "$ECOTRACK_NAMESPACE")
    
    for namespace in "${namespaces[@]}"; do
        if kubectl get namespace "$namespace" &> /dev/null; then
            warn "Namespace $namespace already exists"
        else
            info "Creating namespace: $namespace"
            if [[ "$DRY_RUN" != "true" ]]; then
                kubectl create namespace "$namespace"
                kubectl label namespace "$namespace" \
                    app.kubernetes.io/managed-by=gitops-platform \
                    monitoring=lgtm-stack
            fi
        fi
    done
    
    success "Namespaces setup completed"
}

install_argocd() {
    header "Installing ArgoCD"
    
    # Add ArgoCD Helm repository
    info "Adding ArgoCD Helm repository..."
    if [[ "$DRY_RUN" != "true" ]]; then
        helm repo add argo https://argoproj.github.io/argo-helm
        helm repo update
    fi
    
    # Prepare values file with variable substitution
    local values_file="$PROJECT_ROOT/helm-values/argocd-values.yaml"
    local temp_values_file="$TEMP_DIR/argocd-values.yaml"
    
    info "Preparing ArgoCD configuration..."
    substitute_variables "$values_file" "$temp_values_file"
    
    # Install ArgoCD
    info "Installing ArgoCD..."
    if [[ "$DRY_RUN" != "true" ]]; then
        helm upgrade --install argocd argo/argo-cd \
            --namespace "$ARGOCD_NAMESPACE" \
            --values "$temp_values_file" \
            --wait \
            --timeout 600s \
            --create-namespace
        
        # Wait for ArgoCD to be ready
        info "Waiting for ArgoCD to be ready..."
        kubectl wait --namespace "$ARGOCD_NAMESPACE" \
            --for=condition=ready pod \
            --selector=app.kubernetes.io/name=argocd-server \
            --timeout=600s
    fi
    
    success "ArgoCD installation completed"
}

install_tekton() {
    header "Installing Tekton"
    
    # Install Tekton Pipelines
    info "Installing Tekton Pipelines..."
    if [[ "$DRY_RUN" != "true" ]]; then
        kubectl apply -f https://storage.googleapis.com/tekton-releases/pipeline/latest/release.yaml
        
        # Wait for Tekton Pipelines to be ready
        kubectl wait --namespace tekton-pipelines \
            --for=condition=ready pod \
            --selector=app.kubernetes.io/name=tekton-pipelines-controller \
            --timeout=300s
    fi
    
    # Install Tekton Triggers
    info "Installing Tekton Triggers..."
    if [[ "$DRY_RUN" != "true" ]]; then
        kubectl apply -f https://storage.googleapis.com/tekton-releases/triggers/latest/release.yaml
        kubectl apply -f https://storage.googleapis.com/tekton-releases/triggers/latest/interceptors.yaml
        
        # Wait for Tekton Triggers to be ready
        kubectl wait --namespace tekton-pipelines \
            --for=condition=ready pod \
            --selector=app.kubernetes.io/name=tekton-triggers-controller \
            --timeout=300s
    fi
    
    # Install Tekton Dashboard
    info "Installing Tekton Dashboard..."
    if [[ "$DRY_RUN" != "true" ]]; then
        kubectl apply -f https://storage.googleapis.com/tekton-releases/dashboard/latest/release.yaml
        
        # Wait for Dashboard to be ready
        kubectl wait --namespace tekton-pipelines \
            --for=condition=ready pod \
            --selector=app.kubernetes.io/name=tekton-dashboard \
            --timeout=300s
    fi
    
    success "Tekton installation completed"
}

setup_rbac() {
    header "Setting Up RBAC"
    
    local rbac_file="$PROJECT_ROOT/tekton/rbac/tekton-rbac.yaml"
    local temp_rbac_file="$TEMP_DIR/tekton-rbac.yaml"
    
    info "Applying RBAC configuration..."
    substitute_variables "$rbac_file" "$temp_rbac_file"
    
    if [[ "$DRY_RUN" != "true" ]]; then
        kubectl apply -f "$temp_rbac_file"
    fi
    
    success "RBAC setup completed"
}

setup_secrets() {
    header "Setting Up Secrets"
    
    # Create Git credentials secret
    info "Creating Git credentials secret..."
    if [[ "$DRY_RUN" != "true" ]]; then
        kubectl create secret generic git-credentials \
            --namespace "$TEKTON_NAMESPACE" \
            --from-literal=username="$GITHUB_USERNAME" \
            --from-literal=password="$GITHUB_TOKEN" \
            --from-literal=token="$GITHUB_TOKEN" \
            --dry-run=client -o yaml | kubectl apply -f -
    fi
    
    # Create GitHub webhook secret
    info "Creating GitHub webhook secret..."
    local webhook_secret=$(openssl rand -hex 20)
    if [[ "$DRY_RUN" != "true" ]]; then
        kubectl create secret generic github-webhook-secret \
            --namespace "$TEKTON_NAMESPACE" \
            --from-literal=secretToken="$webhook_secret" \
            --dry-run=client -o yaml | kubectl apply -f -
    fi
    
    # Create Slack webhook secret (if provided)
    if [[ -n "$SLACK_WEBHOOK_URL" ]]; then
        info "Creating Slack webhook secret..."
        if [[ "$DRY_RUN" != "true" ]]; then
            kubectl create secret generic slack-webhook-secret \
                --namespace "$TEKTON_NAMESPACE" \
                --from-literal=webhook-url="$SLACK_WEBHOOK_URL" \
                --dry-run=client -o yaml | kubectl apply -f -
        fi
    fi
    
    success "Secrets setup completed"
}

apply_tekton_configurations() {
    header "Applying Tekton Configurations"
    
    # Apply custom tasks
    info "Applying Tekton tasks..."
    local task_files=(
        "$PROJECT_ROOT/tekton/tasks/maven-build.yaml"
        "$PROJECT_ROOT/tekton/tasks/container-build.yaml"
        "$PROJECT_ROOT/tekton/tasks/security-scan.yaml"
        "$PROJECT_ROOT/tekton/tasks/gitops-update.yaml"
    )
    
    for task_file in "${task_files[@]}"; do
        local temp_task_file="$TEMP_DIR/$(basename "$task_file")"
        substitute_variables "$task_file" "$temp_task_file"
        
        if [[ "$DRY_RUN" != "true" ]]; then
            kubectl apply -f "$temp_task_file"
        fi
    done
    
    # Apply pipelines
    info "Applying Tekton pipelines..."
    local pipeline_file="$PROJECT_ROOT/tekton/pipelines/java-microservice-pipeline.yaml"
    local temp_pipeline_file="$TEMP_DIR/java-microservice-pipeline.yaml"
    substitute_variables "$pipeline_file" "$temp_pipeline_file"
    
    if [[ "$DRY_RUN" != "true" ]]; then
        kubectl apply -f "$temp_pipeline_file"
    fi
    
    # Apply triggers
    info "Applying Tekton triggers..."
    local trigger_file="$PROJECT_ROOT/tekton/triggers/github-webhook.yaml"
    local temp_trigger_file="$TEMP_DIR/github-webhook.yaml"
    substitute_variables "$trigger_file" "$temp_trigger_file"
    
    if [[ "$DRY_RUN" != "true" ]]; then
        kubectl apply -f "$temp_trigger_file"
    fi
    
    success "Tekton configurations applied"
}

apply_argocd_configurations() {
    header "Applying ArgoCD Configurations"
    
    # Apply project
    info "Applying ArgoCD project..."
    local project_file="$PROJECT_ROOT/argocd/projects/ecotrack-project.yaml"
    local temp_project_file="$TEMP_DIR/ecotrack-project.yaml"
    substitute_variables "$project_file" "$temp_project_file"
    
    if [[ "$DRY_RUN" != "true" ]]; then
        kubectl apply -f "$temp_project_file"
    fi
    
    # Apply applications
    info "Applying ArgoCD applications..."
    local app_file="$PROJECT_ROOT/argocd/applications/app-of-apps.yaml"
    local temp_app_file="$TEMP_DIR/app-of-apps.yaml"
    substitute_variables "$app_file" "$temp_app_file"
    
    if [[ "$DRY_RUN" != "true" ]]; then
        kubectl apply -f "$temp_app_file"
    fi
    
    success "ArgoCD configurations applied"
}

# =============================================================================
# Utility Functions
# =============================================================================

substitute_variables() {
    local source_file="$1"
    local target_file="$2"
    
    # Create temp directory if it doesn't exist
    if [[ -z "$TEMP_DIR" ]]; then
        TEMP_DIR=$(mktemp -d)
    fi
    
    # Substitute variables in the file
    envsubst '
        $CLUSTER_NAME
        $CONTAINER_REGISTRY
        $GITHUB_ORG
        $GITHUB_USERNAME
        $GITHUB_TOKEN
        $DOMAIN
        $ARGOCD_DOMAIN
        $TEKTON_DOMAIN
        $GRAFANA_DOMAIN
    ' < "$source_file" > "$target_file"
}

setup_ingress_configuration() {
    if [[ "$DOMAIN" == "cluster.local" ]]; then
        info "Using cluster.local domain - skipping ingress setup"
        return 0
    fi
    
    header "Setting Up Ingress Configuration"
    
    # Set domain-specific variables
    export ARGOCD_DOMAIN="argocd.$DOMAIN"
    export TEKTON_DOMAIN="tekton.$DOMAIN"
    export GRAFANA_DOMAIN="grafana.$DOMAIN"
    
    info "ArgoCD will be available at: https://$ARGOCD_DOMAIN"
    info "Tekton Dashboard will be available at: https://$TEKTON_DOMAIN"
    
    success "Ingress configuration completed"
}

verify_deployment() {
    header "Verifying Deployment"
    
    # Check ArgoCD pods
    info "Checking ArgoCD pods..."
    if [[ "$DRY_RUN" != "true" ]]; then
        kubectl get pods -n "$ARGOCD_NAMESPACE" -l app.kubernetes.io/name=argocd-server
    fi
    
    # Check Tekton pods
    info "Checking Tekton pods..."
    if [[ "$DRY_RUN" != "true" ]]; then
        kubectl get pods -n "$TEKTON_NAMESPACE"
    fi
    
    # Check if ArgoCD is responsive
    if [[ "$DRY_RUN" != "true" ]]; then
        info "Testing ArgoCD server responsiveness..."
        kubectl wait --namespace "$ARGOCD_NAMESPACE" \
            --for=condition=ready pod \
            --selector=app.kubernetes.io/name=argocd-server \
            --timeout=60s
    fi
    
    success "Deployment verification completed"
}

get_access_information() {
    header "Access Information"
    
    # Get ArgoCD admin password
    local argocd_password=""
    if [[ "$DRY_RUN" != "true" ]]; then
        argocd_password=$(kubectl -n "$ARGOCD_NAMESPACE" get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d 2>/dev/null || echo "Password not available yet")
    else
        argocd_password="<dry-run-mode>"
    fi
    
    # Get webhook secret
    local webhook_secret=""
    if [[ "$DRY_RUN" != "true" ]]; then
        webhook_secret=$(kubectl -n "$TEKTON_NAMESPACE" get secret github-webhook-secret -o jsonpath="{.data.secretToken}" | base64 -d 2>/dev/null || echo "Secret not available")
    else
        webhook_secret="<dry-run-mode>"
    fi
    
    echo
    echo "============================================================================="
    echo "                          🚀 ACCESS INFORMATION"
    echo "============================================================================="
    echo
    echo "📋 ArgoCD:"
    if [[ "$DOMAIN" != "cluster.local" ]]; then
        echo "  🌐 URL: https://argocd.$DOMAIN"
    else
        echo "  🌐 URL: http://localhost:8080 (use port-forward)"
        echo "     Port-forward command: kubectl port-forward -n $ARGOCD_NAMESPACE service/argocd-server 8080:80"
    fi
    echo "  👤 Username: admin"
    echo "  🔑 Password: $argocd_password"
    echo
    echo "📋 Tekton Dashboard:"
    if [[ "$DOMAIN" != "cluster.local" ]]; then
        echo "  🌐 URL: https://tekton.$DOMAIN"
    else
        echo "  🌐 URL: http://localhost:9097 (use port-forward)"
        echo "     Port-forward command: kubectl port-forward -n $TEKTON_NAMESPACE service/tekton-dashboard 9097:9097"
    fi
    echo
    echo "📋 GitHub Webhook Configuration:"
    echo "  🔗 Webhook URL: https://$DOMAIN/tekton-webhooks/"
    echo "  🔑 Secret Token: $webhook_secret"
    echo "  📦 Content Type: application/json"
    echo "  📝 Events: Push, Pull Request, Release"
    echo
    echo "📋 Container Registry:"
    echo "  🏪 Registry URL: $CONTAINER_REGISTRY"
    echo "  📦 Image Pattern: $CONTAINER_REGISTRY/ecotrack/{service-name}:{tag}"
    echo
    echo "📋 GitOps Repository:"
    echo "  📂 Expected Repository: https://github.com/$GITHUB_ORG/ecotrack-manifests"
    echo "  📁 Structure: See 04-gitops-deployment-automation/manifests/ for examples"
    echo
    if [[ "$ENABLE_MONITORING" == "true" ]]; then
        echo "📋 Observability:"
        if [[ "$DOMAIN" != "cluster.local" ]]; then
            echo "  📊 Grafana: https://grafana.$DOMAIN"
            echo "  📈 Prometheus: https://prometheus.$DOMAIN"
        else
            echo "  📊 Use existing LGTM stack port-forwards"
        fi
        echo
    fi
    echo "============================================================================="
    echo
}

show_next_steps() {
    header "Next Steps"
    
    echo "🎯 To complete the GitOps setup:"
    echo
    echo "1. 📂 Create the GitOps manifest repository:"
    echo "   git clone https://github.com/$GITHUB_ORG/ecotrack-manifests"
    echo "   # Or create a new repository with the structure from:"
    echo "   # 04-gitops-deployment-automation/manifests/"
    echo
    echo "2. 🔗 Configure GitHub webhooks for your microservice repositories:"
    echo "   - Go to each repository settings → Webhooks"
    echo "   - Add webhook: https://$DOMAIN/tekton-webhooks/"
    echo "   - Content type: application/json"
    echo "   - Secret: $webhook_secret"
    echo "   - Events: Push, Pull Request, Release"
    echo
    echo "3. 🏗️ Set up your Java microservices with Dockerfile:"
    echo "   # Example Dockerfile structure is in the README"
    echo
    echo "4. 🧪 Test the pipeline:"
    echo "   - Push code to a microservice repository"
    echo "   - Watch the pipeline in Tekton Dashboard"
    echo "   - Monitor deployment in ArgoCD"
    echo
    echo "5. 📊 Access monitoring dashboards:"
    if [[ "$DOMAIN" != "cluster.local" ]]; then
        echo "   - ArgoCD: https://argocd.$DOMAIN"
        echo "   - Tekton: https://tekton.$DOMAIN"
        echo "   - Grafana: https://grafana.$DOMAIN"
    else
        echo "   - Use kubectl port-forward commands shown above"
    fi
    echo
    echo "📚 Documentation: See 04-gitops-deployment-automation/README.md"
    echo
}

# =============================================================================
# Main Execution
# =============================================================================

show_banner() {
    echo -e "${PURPLE}"
    cat << 'EOF'
    ███████╗ ██████╗ ██████╗ ████████╗██████╗  █████╗  ██████╗██╗  ██╗
    ██╔════╝██╔════╝██╔═══██╗╚══██╔══╝██╔══██╗██╔══██╗██╔════╝██║ ██╔╝
    █████╗  ██║     ██║   ██║   ██║   ██████╔╝███████║██║     █████╔╝ 
    ██╔══╝  ██║     ██║   ██║   ██║   ██╔══██╗██╔══██║██║     ██╔═██╗ 
    ███████╗╚██████╗╚██████╔╝   ██║   ██║  ██║██║  ██║╚██████╗██║  ██╗
    ╚══════╝ ╚═════╝ ╚═════╝    ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝
    
    🚀 Workflow 4: GitOps & Deployment Automation
    ⚡ ArgoCD + Tekton + Java Microservices Platform
    🌟 Production-Ready | Cloud-Agnostic | LGTM Integrated
EOF
    echo -e "${NC}"
}

main() {
    show_banner
    
    # Set up error handling
    set -E
    trap 'error "Script failed on line $LINENO"' ERR
    
    # Create temp directory
    TEMP_DIR=$(mktemp -d)
    
    log "Starting EcoTrack GitOps Platform deployment..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        warn "Running in DRY-RUN mode - no changes will be made"
    fi
    
    # Execute deployment steps
    validate_prerequisites
    validate_configuration
    setup_ingress_configuration
    setup_namespaces
    install_argocd
    install_tekton
    setup_rbac
    setup_secrets
    apply_tekton_configurations
    apply_argocd_configurations
    
    if [[ "$DRY_RUN" != "true" ]]; then
        verify_deployment
    fi
    
    get_access_information
    show_next_steps
    
    success "🎉 EcoTrack GitOps Platform deployment completed successfully!"
    info "🚀 Your GitOps platform is now ready for the EcoTrack microservices"
}

# =============================================================================
# Script Entry Point
# =============================================================================

# Print usage information
usage() {
    cat << EOF
Usage: $0 [options]

Deploy EcoTrack GitOps Platform with ArgoCD and Tekton

Required Environment Variables:
  CLUSTER_NAME         Kubernetes cluster name
  CONTAINER_REGISTRY   Container registry URL (e.g., your-registry.com)
  GITHUB_ORG          GitHub organization name
  GITHUB_TOKEN        GitHub personal access token

Optional Environment Variables:
  GITHUB_USERNAME     GitHub username (auto-detected if not provided)
  DOMAIN              Custom domain for ingress (default: cluster.local)
  SLACK_WEBHOOK_URL   Slack webhook URL for notifications
  DRY_RUN             Set to 'true' for dry-run mode (default: false)
  SKIP_PREREQUISITES  Set to 'true' to skip prerequisite checks (default: false)
  ENABLE_MONITORING   Enable LGTM integration (default: true)
  ENABLE_SECURITY     Enable security features (default: true)

Options:
  --dry-run           Run in dry-run mode (no changes made)
  --skip-prereqs      Skip prerequisite validation
  --no-monitoring     Disable monitoring integration
  --no-security       Disable security features
  --help              Show this help message

Examples:
  # Basic deployment
  export CLUSTER_NAME="my-cluster"
  export CONTAINER_REGISTRY="my-registry.com"
  export GITHUB_ORG="my-org"
  export GITHUB_TOKEN="ghp_xxxxxxxxxxxx"
  $0

  # With custom domain and Slack
  export DOMAIN="ecotrack.example.com"
  export SLACK_WEBHOOK_URL="https://hooks.slack.com/services/..."
  $0

  # Dry-run mode
  $0 --dry-run

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN="true"
            shift
            ;;
        --skip-prereqs)
            SKIP_PREREQUISITES="true"
            shift
            ;;
        --no-monitoring)
            ENABLE_MONITORING="false"
            shift
            ;;
        --no-security)
            ENABLE_SECURITY="false"
            shift
            ;;
        --help)
            usage
            exit 0
            ;;
        *)
            error "Unknown option: $1"
            ;;
    esac
done

# Check if script is being sourced or executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Run main function
    main "$@"
fi