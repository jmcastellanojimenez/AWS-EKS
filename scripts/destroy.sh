#!/bin/bash
set -e

# EKS Platform Destruction Script
ENVIRONMENT=${1:-dev}
CONFIRM=${2:-false}

echo "🔥 EKS Platform Destruction Script"
echo "=================================="
echo "Environment: $ENVIRONMENT"
echo ""

RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[DANGER]${NC} $1"
}

if [[ "$CONFIRM" != "DESTROY" ]]; then
    print_error "This will DESTROY all resources in $ENVIRONMENT environment!"
    print_warning "To confirm, run: $0 $ENVIRONMENT DESTROY"
    exit 1
fi

cd "terraform/environments/$ENVIRONMENT"

print_warning "Destroying infrastructure..."
terraform destroy -var-file="terraform.tfvars" -auto-approve

echo "🔥 Environment $ENVIRONMENT destroyed!"