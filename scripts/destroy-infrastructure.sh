#!/bin/bash
set -e

# ============================================================================
# Complete Infrastructure Teardown Script
# ============================================================================
# This script safely destroys all AWS EKS infrastructure and cleans up state
# Usage: ./destroy-infrastructure.sh [environment] [scope]
# Examples:
#   ./destroy-infrastructure.sh dev all
#   ./destroy-infrastructure.sh dev lgtm
#   ./destroy-infrastructure.sh dev "3,4,5"
# ============================================================================

# Parse arguments
ENVIRONMENT="${1:-dev}"
SCOPE="${2:-all}"

echo "🚨 WARNING: This will destroy infrastructure!"
echo "=============================================="
echo "Environment: $ENVIRONMENT"
echo "Scope: $SCOPE"
echo ""
read -p "Type 'DESTROY' to confirm: " confirmation

if [[ "$confirmation" != "DESTROY" ]]; then
    echo "❌ Destruction cancelled"
    exit 1
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TERRAFORM_DIR="${BASE_DIR}/terraform/environments/${ENVIRONMENT}"
AWS_REGION="${AWS_REGION:-us-east-1}"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "011921741593")

echo -e "${YELLOW}Starting infrastructure destruction process...${NC}"

# ============================================================================
# Step 1: Clean up Helm releases manually (if cluster exists)
# ============================================================================
echo -e "\n${YELLOW}Step 1: Cleaning up Helm releases...${NC}"

# Check if cluster exists and is accessible
if aws eks describe-cluster --name eks-platform-${ENVIRONMENT} --region ${AWS_REGION} 2>/dev/null; then
    echo "Cluster found. Updating kubeconfig..."
    aws eks update-kubeconfig --name eks-platform-${ENVIRONMENT} --region ${AWS_REGION} || true
    
    # Remove Helm releases to avoid stuck finalizers
    echo "Removing Helm releases..."
    helm list -A --no-headers | awk '{print $1, $2}' | while read name namespace; do
        echo "  Uninstalling: $name from namespace: $namespace"
        helm uninstall "$name" -n "$namespace" --wait --timeout 300s || true
    done
    
    # Delete namespaces that might have stuck resources
    for ns in observability ingress gitops security service-mesh data-services; do
        echo "  Deleting namespace: $ns"
        kubectl delete namespace "$ns" --ignore-not-found=true --timeout=60s || true
    done
else
    echo "Cluster not found or not accessible. Skipping Helm cleanup."
fi

# ============================================================================
# Step 2: Terraform Destroy (in reverse order of creation)
# ============================================================================
echo -e "\n${YELLOW}Step 2: Destroying Terraform resources...${NC}"

cd "${TERRAFORM_DIR}"

# Initialize Terraform with backend config
echo "Initializing Terraform..."
terraform init -backend-config="key=eks-platform/${ENVIRONMENT}/terraform.tfstate" -reconfigure

# Determine which workflows to destroy based on scope
if [[ "$SCOPE" == "all" ]]; then
    WORKFLOWS=(
        "module.data_services"
        "module.service_mesh"
        "module.security"
        "module.gitops"
        "module.lgtm_observability"
        "module.ingress"
        "module.foundation"
    )
elif [[ "$SCOPE" == "lgtm" ]]; then
    WORKFLOWS=("module.lgtm_observability")
elif [[ "$SCOPE" == "gitops" ]]; then
    WORKFLOWS=("module.gitops")
elif [[ "$SCOPE" == "ingress" ]]; then
    WORKFLOWS=("module.ingress")
elif [[ "$SCOPE" == "security" ]]; then
    WORKFLOWS=("module.security")
elif [[ "$SCOPE" == "service-mesh" ]]; then
    WORKFLOWS=("module.service_mesh")
elif [[ "$SCOPE" == "data-services" ]]; then
    WORKFLOWS=("module.data_services")
elif [[ "$SCOPE" == "foundation" ]]; then
    WORKFLOWS=("module.foundation")
else
    # Handle comma-separated workflow numbers
    IFS=',' read -ra NUMS <<< "$SCOPE"
    WORKFLOWS=()
    for num in "${NUMS[@]}"; do
        case "$num" in
            1) WORKFLOWS+=("module.foundation") ;;
            2) WORKFLOWS+=("module.ingress") ;;
            3) WORKFLOWS+=("module.lgtm_observability") ;;
            4) WORKFLOWS+=("module.gitops") ;;
            5) WORKFLOWS+=("module.security") ;;
            6) WORKFLOWS+=("module.service_mesh") ;;
            7) WORKFLOWS+=("module.data_services") ;;
        esac
    done
    # Reverse the array to destroy in correct order
    for ((i=${#WORKFLOWS[@]}-1; i>=0; i--)); do
        reversed+=("${WORKFLOWS[i]}")
    done
    WORKFLOWS=("${reversed[@]}")
fi

for module in "${WORKFLOWS[@]}"; do
    if terraform state list | grep -q "$module"; then
        echo -e "\n${YELLOW}Destroying $module...${NC}"
        terraform destroy -target="$module" -auto-approve || {
            echo -e "${RED}Failed to destroy $module. Continuing...${NC}"
        }
    fi
done

# Final destroy to catch any remaining resources
echo -e "\n${YELLOW}Final infrastructure cleanup...${NC}"
terraform destroy -auto-approve || true

# ============================================================================
# Step 3: Clean up Terraform State
# ============================================================================
echo -e "\n${YELLOW}Step 3: Cleaning up Terraform state...${NC}"

# List all resources in state
echo "Current state resources:"
terraform state list || true

# Remove any stuck resources
STUCK_RESOURCES=$(terraform state list 2>/dev/null | grep -E "(helm_release|kubernetes_)" || true)
if [[ -n "$STUCK_RESOURCES" ]]; then
    echo "Removing stuck resources from state:"
    echo "$STUCK_RESOURCES" | while read resource; do
        echo "  Removing: $resource"
        terraform state rm "$resource" || true
    done
fi

# ============================================================================
# Step 4: Clean up S3 backend and DynamoDB
# ============================================================================
echo -e "\n${YELLOW}Step 4: Cleaning up backend resources...${NC}"

# Get S3 bucket name and DynamoDB table from backend config
S3_BUCKET="eks-learning-lab-terraform-state-011921741593"
DYNAMODB_TABLE="eks-learning-lab-terraform-lock"

# Clean up S3 state files (but keep the bucket)
echo "Cleaning up S3 state files..."
aws s3 rm "s3://${S3_BUCKET}/eks-platform/${ENVIRONMENT}/" --recursive || true
aws s3 rm "s3://${S3_BUCKET}/${ENVIRONMENT}/" --recursive || true

# Clean up DynamoDB lock entries
echo "Cleaning up DynamoDB locks..."
aws dynamodb delete-item \
    --table-name "${DYNAMODB_TABLE}" \
    --key '{"LockID": {"S": "'${S3_BUCKET}'/dev/terraform.tfstate-md5"}}' \
    2>/dev/null || true

aws dynamodb delete-item \
    --table-name "${DYNAMODB_TABLE}" \
    --key '{"LockID": {"S": "'${S3_BUCKET}'/eks-platform/dev/terraform.tfstate-md5"}}' \
    2>/dev/null || true

# ============================================================================
# Step 5: Manual AWS Resource Cleanup
# ============================================================================
echo -e "\n${YELLOW}Step 5: Cleaning up remaining AWS resources...${NC}"

# Clean up any remaining Load Balancers
echo "Checking for remaining Load Balancers..."
aws elb describe-load-balancers --region us-east-1 --query 'LoadBalancerDescriptions[?Tags[?Key==`kubernetes.io/cluster/eks-platform-dev`]].[LoadBalancerName]' --output text | while read lb; do
    echo "  Deleting ELB: $lb"
    aws elb delete-load-balancer --load-balancer-name "$lb" --region us-east-1 || true
done

aws elbv2 describe-load-balancers --region us-east-1 --query 'LoadBalancers[?Tags[?Key==`kubernetes.io/cluster/eks-platform-dev`]].[LoadBalancerArn]' --output text | while read lb; do
    echo "  Deleting ALB/NLB: $lb"
    aws elbv2 delete-load-balancer --load-balancer-arn "$lb" --region us-east-1 || true
done

# Clean up any remaining Security Groups
echo "Checking for remaining Security Groups..."
aws ec2 describe-security-groups --region us-east-1 --filters "Name=tag:kubernetes.io/cluster/eks-platform-dev,Values=owned" --query 'SecurityGroups[].GroupId' --output text | while read sg; do
    echo "  Deleting Security Group: $sg"
    aws ec2 delete-security-group --group-id "$sg" --region us-east-1 || true
done

# Clean up any S3 buckets created by the LGTM stack
for bucket in dev-lgtm-mimir dev-lgtm-loki dev-lgtm-tempo; do
    if aws s3api head-bucket --bucket "${bucket}-011921741593" 2>/dev/null; then
        echo "  Deleting S3 bucket: ${bucket}-011921741593"
        aws s3 rm "s3://${bucket}-011921741593" --recursive || true
        aws s3api delete-bucket --bucket "${bucket}-011921741593" --region us-east-1 || true
    fi
done

# ============================================================================
# Step 6: Verification
# ============================================================================
echo -e "\n${YELLOW}Step 6: Verification...${NC}"

echo "Checking remaining resources..."
echo "  EKS Clusters:"
aws eks list-clusters --region us-east-1 --query 'clusters[?contains(@, `eks-platform-dev`)]' || true

echo "  VPCs:"
aws ec2 describe-vpcs --region us-east-1 --filters "Name=tag:Name,Values=*eks-platform-dev*" --query 'Vpcs[].VpcId' || true

echo -e "\n${GREEN}✅ Infrastructure destruction complete!${NC}"
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Review any remaining resources listed above"
echo "2. Run 'terraform init' to reinitialize the backend"
echo "3. Run 'terraform plan' to verify clean state"
echo "4. Use the init-infrastructure.sh script to redeploy"