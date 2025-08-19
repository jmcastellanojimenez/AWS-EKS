#!/bin/bash
set -e

# EKS Platform Deployment Script
# This script deploys the complete EKS platform in the correct order

ENVIRONMENT=${1:-dev}
SKIP_CONFIRMATION=${2:-false}

echo "🚀 EKS Platform Deployment Script"
echo "=================================="
echo "Environment: $ENVIRONMENT"
echo ""

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check if required tools are installed
    local tools=("terraform" "kubectl" "helm" "aws")
    for tool in "${tools[@]}"; do
        if ! command -v $tool &> /dev/null; then
            print_error "$tool is not installed or not in PATH"
            exit 1
        fi
    done
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS credentials not configured or invalid"
        exit 1
    fi
    
    # Check if terraform.tfvars exists
    if [[ ! -f "terraform/environments/$ENVIRONMENT/terraform.tfvars" ]]; then
        print_error "terraform.tfvars not found for environment: $ENVIRONMENT"
        print_status "Please copy terraform.tfvars.example to terraform.tfvars and update with your values"
        exit 1
    fi
    
    print_success "Prerequisites check passed"
}

# Function to deploy infrastructure
deploy_infrastructure() {
    print_status "Deploying infrastructure for environment: $ENVIRONMENT"
    
    cd "terraform/environments/$ENVIRONMENT"
    
    # Initialize Terraform
    print_status "Initializing Terraform..."
    terraform init
    
    # Plan deployment
    print_status "Planning deployment..."
    terraform plan -var-file="terraform.tfvars" -out=tfplan
    
    # Confirm deployment
    if [[ "$SKIP_CONFIRMATION" != "true" ]]; then
        echo ""
        print_warning "Review the plan above. Do you want to proceed with deployment? (yes/no)"
        read -r response
        if [[ "$response" != "yes" ]]; then
            print_status "Deployment cancelled"
            exit 0
        fi
    fi
    
    # Apply deployment
    print_status "Applying deployment..."
    terraform apply tfplan
    
    # Get cluster information
    CLUSTER_NAME=$(terraform output -raw cluster_name)
    AWS_REGION=$(terraform output -raw aws_region || echo "us-east-1")
    
    print_success "Infrastructure deployment completed"
    print_status "Cluster Name: $CLUSTER_NAME"
    print_status "AWS Region: $AWS_REGION"
    
    cd - > /dev/null
}

# Function to configure kubectl
configure_kubectl() {
    print_status "Configuring kubectl..."
    
    # Update kubeconfig
    aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME"
    
    # Verify connection
    if kubectl get nodes &> /dev/null; then
        print_success "kubectl configured successfully"
        kubectl get nodes
    else
        print_error "Failed to connect to cluster"
        exit 1
    fi
}

# Function to wait for components to be ready
wait_for_components() {
    print_status "Waiting for components to be ready..."
    
    # Wait for system components
    print_status "Waiting for system components..."
    kubectl wait --for=condition=Ready pods -l app.kubernetes.io/name=aws-load-balancer-controller -n kube-system --timeout=300s
    kubectl wait --for=condition=Ready pods -l app.kubernetes.io/name=cluster-autoscaler -n kube-system --timeout=300s
    
    # Wait for ingress components
    print_status "Waiting for ingress components..."
    kubectl wait --for=condition=Ready pods -l app.kubernetes.io/name=cert-manager -n ingress-system --timeout=300s
    kubectl wait --for=condition=Ready pods -l app.kubernetes.io/name=external-dns -n ingress-system --timeout=300s
    kubectl wait --for=condition=Ready pods -l app.kubernetes.io/name=emissary-ingress -n ingress-system --timeout=300s
    
    # Wait for observability components
    print_status "Waiting for observability components..."
    kubectl wait --for=condition=Ready pods -l app.kubernetes.io/name=prometheus -n observability --timeout=600s
    kubectl wait --for=condition=Ready pods -l app.kubernetes.io/name=grafana -n observability --timeout=300s
    
    print_success "All components are ready"
}

# Function to display access information
display_access_info() {
    print_success "🎉 Deployment completed successfully!"
    echo ""
    echo "📊 Access Information:"
    echo "====================="
    
    # Get domain from terraform output
    cd "terraform/environments/$ENVIRONMENT"
    DOMAIN_NAME=$(terraform output -raw domain_name 2>/dev/null || echo "your-domain.dev")
    GRAFANA_PASSWORD=$(terraform output -raw grafana_admin_password 2>/dev/null || echo "Check terraform.tfvars")
    cd - > /dev/null
    
    echo "🌐 Grafana Dashboard: https://$DOMAIN_NAME/grafana"
    echo "   Username: admin"
    echo "   Password: $GRAFANA_PASSWORD"
    echo ""
    echo "🔄 ArgoCD Dashboard: https://$DOMAIN_NAME/argocd"
    echo "   Username: admin"
    echo "   Password: Run 'kubectl get secret argocd-initial-admin-secret -n gitops -o jsonpath=\"{.data.password}\" | base64 -d'"
    echo ""
    echo "🔧 Useful Commands:"
    echo "==================="
    echo "# Update kubeconfig"
    echo "aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME"
    echo ""
    echo "# Check cluster status"
    echo "kubectl get nodes"
    echo "kubectl get pods -A"
    echo ""
    echo "# Port forward to services (for local access)"
    echo "kubectl port-forward -n observability svc/grafana 3000:80"
    echo "kubectl port-forward -n gitops svc/argocd-server 8080:80"
    echo ""
    echo "📚 Next Steps:"
    echo "=============="
    echo "1. Configure your applications in the GitOps repository"
    echo "2. Deploy your microservices using ArgoCD"
    echo "3. Set up monitoring dashboards in Grafana"
    echo "4. Configure alerting rules in Prometheus"
}

# Function to handle cleanup on error
cleanup_on_error() {
    print_error "Deployment failed. Check the logs above for details."
    print_status "You may need to manually clean up resources."
    exit 1
}

# Main deployment function
main() {
    # Set up error handling
    trap cleanup_on_error ERR
    
    echo "Starting deployment process..."
    echo ""
    
    # Run deployment steps
    check_prerequisites
    deploy_infrastructure
    configure_kubectl
    wait_for_components
    display_access_info
    
    print_success "🚀 EKS Platform deployment completed successfully!"
}

# Show usage if no arguments provided
if [[ $# -eq 0 ]]; then
    echo "Usage: $0 <environment> [skip-confirmation]"
    echo ""
    echo "Environments: dev, staging, prod"
    echo "skip-confirmation: true to skip confirmation prompts"
    echo ""
    echo "Example: $0 dev"
    echo "Example: $0 prod true"
    exit 1
fi

# Run main function
main