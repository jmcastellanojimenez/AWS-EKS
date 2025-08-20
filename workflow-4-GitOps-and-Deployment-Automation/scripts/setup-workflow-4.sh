#!/bin/bash

# =============================================================================
# EcoTrack Workflow 4: GitOps with ArgoCD and Tekton Setup Script
# =============================================================================
# This script deploys a complete GitOps workflow using ArgoCD and Tekton
# for the EcoTrack microservices platform on AWS EKS.

set -euo pipefail

# =============================================================================
# Configuration and Variables
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TERRAFORM_DIR="$PROJECT_ROOT/terraform/environments/dev"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default configuration
AWS_REGION="${AWS_REGION:-us-east-1}"
CLUSTER_NAME="${CLUSTER_NAME:-eks-learning-lab-dev}"
PROJECT_NAME="${PROJECT_NAME:-eks-learning-lab}"
ENVIRONMENT="${ENVIRONMENT:-dev}"
DOMAIN="${DOMAIN:-}"
GITHUB_ORG="${GITHUB_ORG:-your-org}"
SLACK_WEBHOOK="${SLACK_WEBHOOK:-}"
ENABLE_TLS="${ENABLE_TLS:-true}"
ENABLE_MONITORING="${ENABLE_MONITORING:-true}"

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

check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check if running on macOS or Linux
    if [[ "$OSTYPE" != "darwin"* ]] && [[ "$OSTYPE" != "linux-gnu"* ]]; then
        error "This script requires macOS or Linux"
    fi
    
    # Required tools
    local required_tools=("kubectl" "terraform" "helm" "aws" "jq" "yq")
    
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            error "Required tool '$tool' is not installed"
        fi
    done
    
    # Check AWS CLI configuration
    if ! aws sts get-caller-identity &> /dev/null; then
        error "AWS CLI is not configured or credentials are invalid"
    fi
    
    # Check kubectl context
    if ! kubectl cluster-info &> /dev/null; then
        error "kubectl is not configured or cluster is not accessible"
    fi
    
    log "Prerequisites check completed successfully"
}

validate_configuration() {
    log "Validating configuration..."
    
    # Validate required environment variables
    if [[ -z "$AWS_REGION" ]]; then
        error "AWS_REGION environment variable is required"
    fi
    
    if [[ -z "$CLUSTER_NAME" ]]; then
        error "CLUSTER_NAME environment variable is required"
    fi
    
    # Get AWS Account ID
    AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    if [[ -z "$AWS_ACCOUNT_ID" ]]; then
        error "Failed to get AWS Account ID"
    fi
    
    log "Configuration validated successfully"
    info "AWS Account ID: $AWS_ACCOUNT_ID"
    info "AWS Region: $AWS_REGION"
    info "Cluster Name: $CLUSTER_NAME"
    info "Environment: $ENVIRONMENT"
}

setup_terraform_backend() {
    log "Setting up Terraform backend..."
    
    # Check if backend configuration exists
    local backend_config="$TERRAFORM_DIR/backend.tfvars"
    if [[ ! -f "$backend_config" ]]; then
        warn "Backend configuration not found, creating default configuration"
        cat > "$backend_config" <<EOF
bucket = "${PROJECT_NAME}-terraform-state"
region = "${AWS_REGION}"
EOF
    fi
    
    # Initialize Terraform
    cd "$TERRAFORM_DIR"
    terraform init -backend-config="$backend_config"
    
    log "Terraform backend setup completed"
}

deploy_terraform_infrastructure() {
    log "Deploying Terraform infrastructure..."
    
    cd "$TERRAFORM_DIR"
    
    # Create terraform.tfvars if it doesn't exist
    local tfvars="$TERRAFORM_DIR/terraform.tfvars"
    if [[ ! -f "$tfvars" ]]; then
        warn "terraform.tfvars not found, creating default configuration"
        cat > "$tfvars" <<EOF
project_name = "${PROJECT_NAME}"
aws_region = "${AWS_REGION}"
environment = "${ENVIRONMENT}"
cluster_name = "${CLUSTER_NAME}"

# GitOps configuration
enable_argocd = true
enable_tekton = true
enable_monitoring = ${ENABLE_MONITORING}

# Domain configuration
ingress_domain = "${DOMAIN}"
enable_tls = ${ENABLE_TLS}

# Slack integration
slack_webhook_url = "${SLACK_WEBHOOK}"

# GitHub integration
github_org = "${GITHUB_ORG}"
EOF
    fi
    
    # Plan and apply
    terraform plan -var-file="$tfvars"
    terraform apply -var-file="$tfvars" -auto-approve
    
    log "Terraform infrastructure deployment completed"
}

setup_namespaces() {
    log "Setting up Kubernetes namespaces..."
    
    # Create namespaces
    kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: argocd
  labels:
    name: argocd
    managed-by: terraform
---
apiVersion: v1
kind: Namespace
metadata:
  name: tekton-pipelines
  labels:
    name: tekton-pipelines
    managed-by: terraform
---
apiVersion: v1
kind: Namespace
metadata:
  name: ecotrack-dev
  labels:
    name: ecotrack-dev
    environment: development
    project: ecotrack
EOF
    
    log "Namespaces setup completed"
}

install_argocd() {
    log "Installing ArgoCD..."
    
    # Add ArgoCD Helm repository
    helm repo add argo https://argoproj.github.io/argo-helm
    helm repo update
    
    # Prepare values file
    local values_file="$PROJECT_ROOT/helm-values/argocd-values.yaml"
    
    # Replace placeholders in values file
    sed -i.bak "s/your-domain.com/${DOMAIN}/g" "$values_file"
    sed -i.bak "s/ACCOUNT_ID/${AWS_ACCOUNT_ID}/g" "$values_file"
    
    # Install ArgoCD
    helm upgrade --install argocd argo/argo-cd \
        --namespace argocd \
        --values "$values_file" \
        --wait \
        --timeout 600s
    
    # Wait for ArgoCD to be ready
    kubectl wait --namespace argocd \
        --for=condition=ready pod \
        --selector=app.kubernetes.io/name=argocd-server \
        --timeout=600s
    
    log "ArgoCD installation completed"
}

install_tekton() {
    log "Installing Tekton..."
    
    # Add Tekton Helm repository
    helm repo add cdf https://cdfoundation.github.io/tekton-helm-chart
    helm repo update
    
    # Install Tekton Pipelines
    helm upgrade --install tekton-pipelines cdf/tekton-pipelines \
        --namespace tekton-pipelines \
        --wait \
        --timeout 600s
    
    # Install Tekton Triggers
    helm upgrade --install tekton-triggers cdf/tekton-triggers \
        --namespace tekton-pipelines \
        --wait \
        --timeout 600s
    
    # Install Tekton Dashboard
    helm upgrade --install tekton-dashboard cdf/tekton-dashboard \
        --namespace tekton-pipelines \
        --wait \
        --timeout 600s
    
    log "Tekton installation completed"
}

apply_tekton_configurations() {
    log "Applying Tekton configurations..."
    
    # Update account ID in RBAC configuration
    sed "s/ACCOUNT_ID/${AWS_ACCOUNT_ID}/g" "$PROJECT_ROOT/tekton/rbac/pipeline-rbac.yaml" | \
        kubectl apply -f -
    
    # Apply tasks
    kubectl apply -f "$PROJECT_ROOT/tekton/tasks/"
    
    # Apply pipelines
    kubectl apply -f "$PROJECT_ROOT/tekton/pipelines/"
    
    # Apply triggers
    kubectl apply -f "$PROJECT_ROOT/tekton/triggers/"
    
    log "Tekton configurations applied successfully"
}

apply_argocd_configurations() {
    log "Applying ArgoCD configurations..."
    
    # Apply projects
    kubectl apply -f "$PROJECT_ROOT/argocd/projects/"
    
    # Apply applications
    kubectl apply -f "$PROJECT_ROOT/argocd/applications/"
    
    # Apply ApplicationSets if they exist
    if [[ -d "$PROJECT_ROOT/argocd/applicationsets" ]]; then
        kubectl apply -f "$PROJECT_ROOT/argocd/applicationsets/"
    fi
    
    log "ArgoCD configurations applied successfully"
}

setup_github_secrets() {
    log "Setting up GitHub integration secrets..."
    
    # Create GitHub webhook secret
    if [[ -n "${GITHUB_WEBHOOK_SECRET:-}" ]]; then
        kubectl create secret generic github-webhook-secret \
            --namespace tekton-pipelines \
            --from-literal=secretToken="$GITHUB_WEBHOOK_SECRET" \
            --dry-run=client -o yaml | kubectl apply -f -
    fi
    
    # Create GitHub token secret
    if [[ -n "${GITHUB_TOKEN:-}" ]]; then
        kubectl create secret generic github-token-secret \
            --namespace tekton-pipelines \
            --from-literal=token="$GITHUB_TOKEN" \
            --from-literal=username="${GITHUB_USERNAME:-tekton}" \
            --dry-run=client -o yaml | kubectl apply -f -
    fi
    
    log "GitHub secrets setup completed"
}

setup_monitoring_integration() {
    if [[ "$ENABLE_MONITORING" == "true" ]]; then
        log "Setting up monitoring integration..."
        
        # Create service monitors for ArgoCD
        kubectl apply -f - <<EOF
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: argocd-metrics
  namespace: observability
  labels:
    app.kubernetes.io/name: argocd
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: argocd-server-metrics
  endpoints:
  - port: metrics
    interval: 30s
    path: /metrics
---
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: tekton-metrics
  namespace: observability
  labels:
    app.kubernetes.io/name: tekton-pipelines
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: tekton-pipelines-controller
  endpoints:
  - port: http-metrics
    interval: 30s
    path: /metrics
EOF
        
        log "Monitoring integration setup completed"
    fi
}

get_access_information() {
    log "Retrieving access information..."
    
    # Get ArgoCD admin password
    local argocd_password
    argocd_password=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
    
    # Get service URLs
    local argocd_url="http://localhost:8080"
    local tekton_url="http://localhost:9097"
    
    if [[ -n "$DOMAIN" ]]; then
        argocd_url="https://argocd.${DOMAIN}"
        tekton_url="https://tekton.${DOMAIN}"
    fi
    
    echo
    echo "============================================================================="
    echo "                          ACCESS INFORMATION"
    echo "============================================================================="
    echo
    echo "ArgoCD:"
    echo "  URL: $argocd_url"
    echo "  Username: admin"
    echo "  Password: $argocd_password"
    echo
    echo "Tekton Dashboard:"
    echo "  URL: $tekton_url"
    echo
    
    if [[ -z "$DOMAIN" ]]; then
        echo "To access the services locally, run:"
        echo "  kubectl port-forward -n argocd service/argocd-server 8080:80"
        echo "  kubectl port-forward -n tekton-pipelines service/tekton-dashboard 9097:9097"
        echo
    fi
    
    echo "GitHub Webhook URL (replace with your domain):"
    echo "  https://${DOMAIN:-your-domain.com}/webhooks/"
    echo
    echo "============================================================================="
}

verify_deployment() {
    log "Verifying deployment..."
    
    # Check ArgoCD pods
    kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server
    
    # Check Tekton pods
    kubectl get pods -n tekton-pipelines
    
    # Check ArgoCD applications
    kubectl get applications -n argocd
    
    log "Deployment verification completed"
}

cleanup_on_error() {
    error "Script failed. Check the logs above for details."
    warn "You may need to manually clean up resources"
}

# =============================================================================
# Main Execution
# =============================================================================

main() {
    log "Starting EcoTrack Workflow 4 (GitOps) deployment..."
    
    # Set up error handling
    trap cleanup_on_error ERR
    
    # Execute deployment steps
    check_prerequisites
    validate_configuration
    setup_terraform_backend
    deploy_terraform_infrastructure
    setup_namespaces
    install_argocd
    install_tekton
    apply_tekton_configurations
    apply_argocd_configurations
    setup_github_secrets
    setup_monitoring_integration
    verify_deployment
    get_access_information
    
    log "EcoTrack Workflow 4 (GitOps) deployment completed successfully!"
    info "Your GitOps platform is now ready for the EcoTrack microservices"
}

# =============================================================================
# Script Entry Point
# =============================================================================

# Check if script is being sourced or executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --domain)
                DOMAIN="$2"
                shift 2
                ;;
            --github-org)
                GITHUB_ORG="$2"
                shift 2
                ;;
            --slack-webhook)
                SLACK_WEBHOOK="$2"
                shift 2
                ;;
            --disable-tls)
                ENABLE_TLS="false"
                shift
                ;;
            --disable-monitoring)
                ENABLE_MONITORING="false"
                shift
                ;;
            --help)
                echo "Usage: $0 [options]"
                echo
                echo "Options:"
                echo "  --domain DOMAIN          Set the domain for ingress"
                echo "  --github-org ORG         Set the GitHub organization"
                echo "  --slack-webhook URL      Set the Slack webhook URL"
                echo "  --disable-tls            Disable TLS"
                echo "  --disable-monitoring     Disable monitoring integration"
                echo "  --help                   Show this help message"
                exit 0
                ;;
            *)
                error "Unknown option: $1"
                ;;
        esac
    done
    
    # Run main function
    main "$@"
fi
