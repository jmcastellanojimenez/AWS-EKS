#!/bin/bash

# 🔄 Workflow 4: GitOps & Deployment Automation
# Deployment script for ArgoCD and Tekton GitOps platform
# Integrates with existing EKS infrastructure and LGTM observability

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Default configuration
DEFAULT_DOMAIN="gitops.local"
DEFAULT_GITHUB_ORG="your-org"
DEFAULT_ENVIRONMENT="dev"
DEFAULT_ENABLE_MONITORING="true"
DEFAULT_ENABLE_NOTIFICATIONS="false"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

log_header() {
    echo -e "${PURPLE}🔄 $1${NC}"
}

# Help function
show_help() {
    cat << EOF
🔄 Workflow 4: GitOps & Deployment Automation Deployment Script

USAGE:
    $0 [OPTIONS]

OPTIONS:
    -d, --domain DOMAIN           Domain for GitOps services (default: ${DEFAULT_DOMAIN})
    -o, --github-org ORG          GitHub organization name (default: ${DEFAULT_GITHUB_ORG})
    -e, --environment ENV         Environment (dev/staging/prod) (default: ${DEFAULT_ENVIRONMENT})
    -m, --enable-monitoring       Enable monitoring integration (default: ${DEFAULT_ENABLE_MONITORING})
    -n, --enable-notifications    Enable notifications (default: ${DEFAULT_ENABLE_NOTIFICATIONS})
    --dry-run                     Show what would be deployed without executing
    --skip-terraform              Skip Terraform deployment (use existing infrastructure)
    --skip-argocd                 Skip ArgoCD deployment
    --skip-tekton                 Skip Tekton deployment
    --uninstall                   Uninstall GitOps platform
    -h, --help                    Show this help message

EXAMPLES:
    # Deploy with custom domain
    $0 --domain gitops.example.com --github-org myorg

    # Deploy to staging environment
    $0 --environment staging --enable-monitoring

    # Dry run to see what would be deployed
    $0 --dry-run

    # Uninstall the platform
    $0 --uninstall

PREREQUISITES:
    - kubectl configured for target EKS cluster
    - terraform installed and configured
    - helm installed
    - AWS CLI configured with appropriate permissions
    - GitHub token configured (for GitOps repository access)

EOF
}

# Parse command line arguments
parse_arguments() {
    DOMAIN="${DEFAULT_DOMAIN}"
    GITHUB_ORG="${DEFAULT_GITHUB_ORG}"
    ENVIRONMENT="${DEFAULT_ENVIRONMENT}"
    ENABLE_MONITORING="${DEFAULT_ENABLE_MONITORING}"
    ENABLE_NOTIFICATIONS="${DEFAULT_ENABLE_NOTIFICATIONS}"
    DRY_RUN="false"
    SKIP_TERRAFORM="false"
    SKIP_ARGOCD="false"
    SKIP_TEKTON="false"
    UNINSTALL="false"

    while [[ $# -gt 0 ]]; do
        case $1 in
            -d|--domain)
                DOMAIN="$2"
                shift 2
                ;;
            -o|--github-org)
                GITHUB_ORG="$2"
                shift 2
                ;;
            -e|--environment)
                ENVIRONMENT="$2"
                shift 2
                ;;
            -m|--enable-monitoring)
                ENABLE_MONITORING="true"
                shift
                ;;
            -n|--enable-notifications)
                ENABLE_NOTIFICATIONS="true"
                shift
                ;;
            --dry-run)
                DRY_RUN="true"
                shift
                ;;
            --skip-terraform)
                SKIP_TERRAFORM="true"
                shift
                ;;
            --skip-argocd)
                SKIP_ARGOCD="true"
                shift
                ;;
            --skip-tekton)
                SKIP_TEKTON="true"
                shift
                ;;
            --uninstall)
                UNINSTALL="true"
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# Validate prerequisites
validate_prerequisites() {
    log_header "Validating Prerequisites"

    # Check required tools
    local required_tools=("kubectl" "terraform" "helm" "aws")
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            log_error "$tool is not installed or not in PATH"
            exit 1
        fi
        log_success "$tool is available"
    done

    # Check kubectl context
    if ! kubectl cluster-info &> /dev/null; then
        log_error "kubectl is not configured or cluster is not accessible"
        exit 1
    fi
    
    local cluster_name=$(kubectl config current-context)
    log_success "Connected to cluster: $cluster_name"

    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS credentials are not configured"
        exit 1
    fi
    
    local aws_account=$(aws sts get-caller-identity --query Account --output text)
    log_success "AWS Account: $aws_account"

    # Validate Terraform configuration
    if [[ "$SKIP_TERRAFORM" != "true" ]]; then
        if [[ ! -f "${PROJECT_ROOT}/terraform/main.tf" ]]; then
            log_error "Terraform configuration not found at ${PROJECT_ROOT}/terraform/"
            exit 1
        fi
        log_success "Terraform configuration found"
    fi

    # Check if required namespaces exist
    local required_namespaces=("kube-system")
    for ns in "${required_namespaces[@]}"; do
        if ! kubectl get namespace "$ns" &> /dev/null; then
            log_error "Required namespace '$ns' not found"
            exit 1
        fi
    done
    log_success "Required namespaces exist"
}

# Deploy Terraform infrastructure
deploy_terraform() {
    if [[ "$SKIP_TERRAFORM" == "true" ]]; then
        log_info "Skipping Terraform deployment"
        return 0
    fi

    log_header "Deploying Terraform Infrastructure"

    cd "${PROJECT_ROOT}/terraform"

    # Initialize Terraform
    log_info "Initializing Terraform..."
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would run: terraform init"
    else
        terraform init
    fi

    # Plan Terraform changes
    log_info "Planning Terraform changes..."
    local tf_vars=(
        "-var=enable_gitops_irsa=true"
        "-var=argocd_namespace=argocd"
        "-var=tekton_namespace=tekton-pipelines"
    )

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would run: terraform plan ${tf_vars[*]}"
    else
        terraform plan "${tf_vars[@]}"
    fi

    # Apply Terraform changes
    log_info "Applying Terraform changes..."
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would run: terraform apply -auto-approve ${tf_vars[*]}"
    else
        terraform apply -auto-approve "${tf_vars[@]}"
    fi

    log_success "Terraform infrastructure deployed"
    cd - > /dev/null
}

# Deploy ArgoCD
deploy_argocd() {
    if [[ "$SKIP_ARGOCD" == "true" ]]; then
        log_info "Skipping ArgoCD deployment"
        return 0
    fi

    log_header "Deploying ArgoCD"

    # Create ArgoCD namespace
    log_info "Creating ArgoCD namespace..."
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would create namespace: argocd"
    else
        kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
    fi

    # Get IRSA role ARN from Terraform output
    local argocd_role_arn=""
    if [[ "$SKIP_TERRAFORM" != "true" && "$DRY_RUN" != "true" ]]; then
        cd "${PROJECT_ROOT}/terraform"
        argocd_role_arn=$(terraform output -raw argocd_server_role_arn 2>/dev/null || echo "")
        cd - > /dev/null
    fi

    # Deploy ArgoCD using Terraform module
    log_info "Deploying ArgoCD using Terraform module..."
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would deploy ArgoCD module with domain: $DOMAIN"
    else
        cd "${PROJECT_ROOT}/terraform"
        
        # Create ArgoCD module configuration
        cat > argocd_deployment.tf << EOF
module "argocd" {
  source = "./modules/argocd"

  project_name = var.project_name
  environment  = "$ENVIRONMENT"
  
  hostname    = "argocd.$DOMAIN"
  enable_tls  = true
  
  enable_monitoring     = $ENABLE_MONITORING
  enable_notifications  = $ENABLE_NOTIFICATIONS
  
  service_account_annotations = {
    "eks.amazonaws.com/role-arn" = "$argocd_role_arn"
  }
  
  additional_labels = {
    "app.kubernetes.io/part-of" = "gitops-platform"
    "environment" = "$ENVIRONMENT"
  }
}
EOF

        terraform apply -auto-approve
        cd - > /dev/null
    fi

    # Apply ArgoCD projects and applications
    log_info "Applying ArgoCD projects and applications..."
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would apply ArgoCD configurations from argocd/"
    else
        # Wait for ArgoCD to be ready
        kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s

        # Apply ArgoCD project
        envsubst < "${PROJECT_ROOT}/argocd/projects/ecotrack-project.yaml" | kubectl apply -f -
        
        # Apply ArgoCD applications
        envsubst < "${PROJECT_ROOT}/argocd/applications/ecotrack-app-of-apps.yaml" | kubectl apply -f -
    fi

    log_success "ArgoCD deployed successfully"
}

# Deploy Tekton
deploy_tekton() {
    if [[ "$SKIP_TEKTON" == "true" ]]; then
        log_info "Skipping Tekton deployment"
        return 0
    fi

    log_header "Deploying Tekton"

    # Get IRSA role ARN from Terraform output
    local tekton_role_arn=""
    if [[ "$SKIP_TERRAFORM" != "true" && "$DRY_RUN" != "true" ]]; then
        cd "${PROJECT_ROOT}/terraform"
        tekton_role_arn=$(terraform output -raw tekton_pipeline_role_arn 2>/dev/null || echo "")
        cd - > /dev/null
    fi

    # Deploy Tekton using Terraform module
    log_info "Deploying Tekton using Terraform module..."
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would deploy Tekton module"
    else
        cd "${PROJECT_ROOT}/terraform"
        
        # Create Tekton module configuration
        cat > tekton_deployment.tf << EOF
module "tekton" {
  source = "./modules/tekton"

  project_name = var.project_name
  environment  = "$ENVIRONMENT"
  
  enable_dashboard = true
  enable_triggers  = true
  enable_monitoring = $ENABLE_MONITORING
  
  dashboard_hostname = "tekton.$DOMAIN"
  
  container_registry = {
    url      = data.aws_caller_identity.current.account_id + ".dkr.ecr." + data.aws_region.current.name + ".amazonaws.com"
    username = ""
    password = ""
    region   = data.aws_region.current.name
  }
  
  github_config = {
    webhook_secret = var.github_webhook_secret
    token          = var.github_token
  }
  
  service_account_annotations = {
    "eks.amazonaws.com/role-arn" = "$tekton_role_arn"
  }
  
  additional_labels = {
    "app.kubernetes.io/part-of" = "gitops-platform"
    "environment" = "$ENVIRONMENT"
  }
}
EOF

        terraform apply -auto-approve
        cd - > /dev/null
    fi

    # Apply Tekton pipelines and tasks
    log_info "Applying Tekton pipelines and tasks..."
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would apply Tekton configurations from tekton/"
    else
        # Wait for Tekton to be ready
        kubectl wait --for=condition=ready pod -l app.kubernetes.io/part-of=tekton-pipelines -n tekton-pipelines --timeout=300s

        # Apply Tekton pipeline
        kubectl apply -f "${PROJECT_ROOT}/tekton/pipelines/java-microservice-pipeline.yaml"
    fi

    log_success "Tekton deployed successfully"
}

# Configure monitoring integration
configure_monitoring() {
    if [[ "$ENABLE_MONITORING" != "true" ]]; then
        log_info "Monitoring integration disabled"
        return 0
    fi

    log_header "Configuring Monitoring Integration"

    log_info "Verifying LGTM observability stack..."
    if ! kubectl get namespace observability &> /dev/null; then
        log_warning "Observability namespace not found. Please deploy LGTM stack first."
        return 0
    fi

    # ServiceMonitors should be created by the Terraform modules
    log_info "Monitoring integration configured via Terraform modules"
    log_success "Monitoring integration completed"
}

# Uninstall GitOps platform
uninstall_platform() {
    log_header "Uninstalling GitOps Platform"

    log_warning "This will remove ArgoCD, Tekton, and all related resources"
    read -p "Are you sure you want to continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Uninstall cancelled"
        exit 0
    fi

    # Remove ArgoCD applications first
    log_info "Removing ArgoCD applications..."
    kubectl delete applications --all -n argocd --ignore-not-found=true

    # Remove ArgoCD projects
    log_info "Removing ArgoCD projects..."
    kubectl delete appprojects --all -n argocd --ignore-not-found=true

    # Remove Tekton pipelines
    log_info "Removing Tekton pipelines..."
    kubectl delete pipelines --all -n tekton-pipelines --ignore-not-found=true

    # Destroy Terraform resources
    log_info "Destroying Terraform resources..."
    cd "${PROJECT_ROOT}/terraform"
    
    # Remove deployment files
    rm -f argocd_deployment.tf tekton_deployment.tf
    
    terraform destroy -auto-approve
    cd - > /dev/null

    log_success "GitOps platform uninstalled"
}

# Display deployment summary
show_deployment_summary() {
    log_header "Deployment Summary"

    echo
    echo "🎉 GitOps & Deployment Automation Platform Deployed Successfully!"
    echo
    echo "📋 Configuration:"
    echo "  🌐 Domain: $DOMAIN"
    echo "  🏢 GitHub Org: $GITHUB_ORG"
    echo "  🏷️  Environment: $ENVIRONMENT"
    echo "  📊 Monitoring: $ENABLE_MONITORING"
    echo "  🔔 Notifications: $ENABLE_NOTIFICATIONS"
    echo
    echo "🔗 Access URLs:"
    if [[ "$SKIP_ARGOCD" != "true" ]]; then
        echo "  🔄 ArgoCD UI: https://argocd.$DOMAIN"
        echo "  📋 ArgoCD CLI: argocd login argocd.$DOMAIN"
    fi
    if [[ "$SKIP_TEKTON" != "true" ]]; then
        echo "  🔧 Tekton Dashboard: https://tekton.$DOMAIN"
        echo "  📋 Tekton CLI: tkn pipeline list -n tekton-pipelines"
    fi
    echo
    echo "📋 GitOps Repository:"
    echo "  📂 Expected Repository: https://github.com/$GITHUB_ORG/ecotrack-manifests"
    echo "  📁 Structure: See argocd/ and tekton/ directories for examples"
    echo
    if [[ "$ENABLE_MONITORING" == "true" ]]; then
        echo "📊 Monitoring:"
        echo "  📈 Grafana: Access via LGTM observability stack"
        echo "  🔍 Prometheus: ServiceMonitors configured for ArgoCD and Tekton"
        echo
    fi
    echo "🚀 Next Steps:"
    echo "1. 📂 Create GitOps repository:"
    echo "   git clone https://github.com/$GITHUB_ORG/ecotrack-manifests"
    echo "   # Or create a new repository with the structure from:"
    echo "   # argocd/ and tekton/ directories"
    echo
    echo "2. 🔗 Configure GitHub webhooks for your microservice repositories:"
    echo "   - Webhook URL: https://tekton.$DOMAIN/webhooks/github"
    echo "   - Content Type: application/json"
    echo "   - Events: push, pull_request"
    echo
    if [[ "$ENABLE_NOTIFICATIONS" == "true" ]]; then
        echo "3. 🔔 Configure notifications:"
        echo "   - Update ArgoCD notification configuration"
        echo "   - Configure Slack/email webhooks"
        echo
    fi
    echo
    echo "📚 Documentation: See GitOpsAndDeploymentAutomation.md"
    echo
}

# Main execution function
main() {
    log_header "GitOps & Deployment Automation Platform Deployment"
    
    parse_arguments "$@"
    
    if [[ "$UNINSTALL" == "true" ]]; then
        uninstall_platform
        exit 0
    fi
    
    validate_prerequisites
    
    # Export environment variables for envsubst
    export DOMAIN GITHUB_ORG ENVIRONMENT ENABLE_MONITORING ENABLE_NOTIFICATIONS
    
    deploy_terraform
    deploy_argocd
    deploy_tekton
    configure_monitoring
    
    if [[ "$DRY_RUN" != "true" ]]; then
        show_deployment_summary
    else
        log_info "Dry run completed. No changes were made."
    fi
}

# Execute main function with all arguments
main "$@"