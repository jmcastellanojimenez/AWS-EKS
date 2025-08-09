#!/bin/bash

# 🚀 Kubernetes Ingress Workshop - Setup Script
# This script sets up the prerequisites for the ingress workshop

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
ENVIRONMENT="${1:-dev}"
AWS_REGION="${AWS_REGION:-us-east-1}"

echo -e "${BLUE}🚀 Kubernetes Ingress Workshop Setup${NC}"
echo -e "${BLUE}Environment: ${ENVIRONMENT}${NC}"
echo -e "${BLUE}AWS Region: ${AWS_REGION}${NC}"
echo ""

# Function to print status
print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check prerequisites
echo -e "${BLUE}🔍 Checking Prerequisites...${NC}"

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    print_error "AWS CLI is not installed. Please install it first."
    exit 1
fi
print_status "AWS CLI is installed"

# Check AWS credentials
if ! aws sts get-caller-identity &> /dev/null; then
    print_error "AWS credentials not configured or invalid"
    exit 1
fi
print_status "AWS credentials are configured"

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed. Please install it first."
    exit 1
fi
print_status "kubectl is installed"

# Check if helm is installed
if ! command -v helm &> /dev/null; then
    print_error "helm is not installed. Please install it first."
    exit 1
fi
print_status "Helm is installed"

# Check if terraform is installed
if ! command -v terraform &> /dev/null; then
    print_error "Terraform is not installed. Please install it first."
    exit 1
fi
print_status "Terraform is installed"

echo ""

# Check EKS cluster
echo -e "${BLUE}🔍 Checking EKS Cluster...${NC}"
CLUSTER_NAME="eks-learning-lab-${ENVIRONMENT}"

if ! aws eks describe-cluster --name "${CLUSTER_NAME}" --region "${AWS_REGION}" &> /dev/null; then
    print_error "EKS cluster '${CLUSTER_NAME}' not found in region '${AWS_REGION}'"
    echo -e "${YELLOW}Please deploy the EKS cluster first using the main infrastructure workflow${NC}"
    exit 1
fi
print_status "EKS cluster '${CLUSTER_NAME}' is available"

# Update kubeconfig
echo -e "${BLUE}🔧 Updating kubeconfig...${NC}"
aws eks update-kubeconfig --region "${AWS_REGION}" --name "${CLUSTER_NAME}"
print_status "kubeconfig updated for cluster '${CLUSTER_NAME}'"

# Test cluster connectivity
echo -e "${BLUE}🧪 Testing cluster connectivity...${NC}"
if kubectl cluster-info &> /dev/null; then
    print_status "Successfully connected to EKS cluster"
else
    print_error "Failed to connect to EKS cluster"
    exit 1
fi

# Check cluster nodes
NODE_COUNT=$(kubectl get nodes --no-headers | wc -l)
if [ "${NODE_COUNT}" -eq 0 ]; then
    print_error "No worker nodes found in the cluster"
    exit 1
fi
print_status "Found ${NODE_COUNT} worker node(s) in the cluster"

echo ""

# Verify Terraform backend
echo -e "${BLUE}🗄️ Verifying Terraform Backend...${NC}"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
BUCKET_NAME="eks-learning-lab-terraform-state-${AWS_ACCOUNT_ID}"

if aws s3api head-bucket --bucket "${BUCKET_NAME}" &> /dev/null; then
    print_status "Terraform state bucket '${BUCKET_NAME}' is accessible"
else
    print_error "Terraform state bucket '${BUCKET_NAME}' is not accessible"
    print_warning "This bucket should have been created by the main infrastructure deployment"
    exit 1
fi

echo ""

# Display next steps
echo -e "${GREEN}🎉 Setup Complete!${NC}"
echo ""
echo -e "${BLUE}Next Steps:${NC}"
echo -e "1. Run the ${YELLOW}🚀 Deploy Kubernetes Ingress Patterns${NC} workflow from GitHub Actions"
echo -e "2. Choose either ${YELLOW}'alb'${NC} or ${YELLOW}'nginx'${NC} pattern"
echo -e "3. Enable demo apps deployment for testing"
echo ""
echo -e "${BLUE}Manual Deployment (if preferred):${NC}"
echo -e "1. Deploy shared infrastructure:"
echo -e "   ${YELLOW}cd terraform/shared && terraform init && terraform plan && terraform apply${NC}"
echo -e "2. Deploy pattern infrastructure:"
echo -e "   ${YELLOW}cd terraform/alb-pattern && terraform init && terraform plan && terraform apply${NC}"
echo -e "   ${YELLOW}# OR${NC}"
echo -e "   ${YELLOW}cd terraform/nginx-pattern && terraform init && terraform plan && terraform apply${NC}"
echo -e "3. Deploy Kubernetes controllers and manifests"
echo ""
echo -e "${BLUE}Cost Information:${NC}"
echo -e "• ${YELLOW}ALB Pattern:${NC} ~\$16/month (ALB) + \$0.50/month (Route53)"
echo -e "• ${YELLOW}NGINX Pattern:${NC} ~\$16/month (NLB) + \$0.50/month (Route53)"
echo -e "• ${YELLOW}Both patterns:${NC} Use existing EKS cluster (~\$88/month with 2 nodes)"
echo ""
print_status "Ready to deploy ingress patterns!"