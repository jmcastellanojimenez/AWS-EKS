#!/bin/bash

# GitOps CRD Fix Validation Script
# Validates that the CRD fix has been implemented correctly

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Environment (default to dev)
ENV="${1:-dev}"

echo -e "${BLUE}🔍 GitOps CRD Fix Validation${NC}"
echo -e "${YELLOW}Environment: ${ENV}${NC}"
echo ""

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Function to check if a resource exists
check_resource() {
    local resource_type=$1
    local resource_name=$2
    local namespace=${3:-gitops}
    
    if kubectl get "$resource_type" "$resource_name" -n "$namespace" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ $resource_type/$resource_name exists${NC}"
        return 0
    else
        echo -e "${RED}❌ $resource_type/$resource_name not found${NC}"
        return 1
    fi
}

# Function to check if CRD exists
check_crd() {
    local crd_name=$1
    
    if kubectl get crd "$crd_name" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ CRD $crd_name exists${NC}"
        return 0
    else
        echo -e "${RED}❌ CRD $crd_name not found${NC}"
        return 1
    fi
}

echo -e "${BLUE}1. Checking kubectl connectivity${NC}"
if ! kubectl cluster-info >/dev/null 2>&1; then
    echo -e "${RED}❌ Cannot connect to Kubernetes cluster${NC}"
    echo "Make sure kubectl is configured and cluster is accessible"
    exit 1
fi
echo -e "${GREEN}✅ Kubernetes cluster accessible${NC}"

echo ""
echo -e "${BLUE}2. Checking GitOps namespace${NC}"
check_resource "namespace" "gitops" ""

echo ""
echo -e "${BLUE}3. Checking ArgoCD CRDs${NC}"
check_crd "applications.argoproj.io"
check_crd "applicationsets.argoproj.io"
check_crd "appprojects.argoproj.io"

echo ""
echo -e "${BLUE}4. Checking Tekton CRDs${NC}"
check_crd "pipelines.tekton.dev"
check_crd "tasks.tekton.dev"
check_crd "pipelineruns.tekton.dev"
check_crd "taskruns.tekton.dev"

echo ""
echo -e "${BLUE}5. Checking ArgoCD deployment${NC}"
check_resource "deployment" "argocd-server"
check_resource "deployment" "argocd-application-controller"
check_resource "deployment" "argocd-repo-server"

# Check ArgoCD pods are running
argocd_pods_ready=$(kubectl get pods -n gitops -l app.kubernetes.io/part-of=argocd --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l || echo "0")
if [ "$argocd_pods_ready" -gt 0 ]; then
    echo -e "${GREEN}✅ ArgoCD pods are running ($argocd_pods_ready pods)${NC}"
else
    echo -e "${RED}❌ No ArgoCD pods are running${NC}"
fi

echo ""
echo -e "${BLUE}6. Checking Tekton deployment${NC}"
check_resource "deployment" "tekton-pipelines-controller"
check_resource "deployment" "tekton-pipelines-webhook"

# Check Tekton pods are running
tekton_pods_ready=$(kubectl get pods -n gitops -l app.kubernetes.io/part-of=tekton-pipelines --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l || echo "0")
if [ "$tekton_pods_ready" -gt 0 ]; then
    echo -e "${GREEN}✅ Tekton pods are running ($tekton_pods_ready pods)${NC}"
else
    echo -e "${RED}❌ No Tekton pods are running${NC}"
fi

echo ""
echo -e "${BLUE}7. Checking GitOps manifests${NC}"

# Check if ArgoCD Application exists
if kubectl get applications -n gitops app-of-apps >/dev/null 2>&1; then
    echo -e "${GREEN}✅ ArgoCD Application 'app-of-apps' exists${NC}"
    app_status=$(kubectl get applications -n gitops app-of-apps -o jsonpath='{.status.health.status}' 2>/dev/null || echo "Unknown")
    echo -e "${YELLOW}   Status: $app_status${NC}"
else
    echo -e "${YELLOW}⚠️  ArgoCD Application 'app-of-apps' not found (this may be normal for initial deployment)${NC}"
fi

# Check if Tekton Pipeline exists
if kubectl get pipelines -n gitops build-and-push >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Tekton Pipeline 'build-and-push' exists${NC}"
else
    echo -e "${RED}❌ Tekton Pipeline 'build-and-push' not found${NC}"
fi

# Check if Tekton Task exists
if kubectl get tasks -n gitops trivy-scanner >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Tekton Task 'trivy-scanner' exists${NC}"
else
    echo -e "${RED}❌ Tekton Task 'trivy-scanner' not found${NC}"
fi

echo ""
echo -e "${BLUE}8. Checking Terraform state${NC}"
cd "${PROJECT_DIR}/terraform/environments/${ENV}"

if terraform show -json | jq -e '.values.root_module.child_modules[] | select(.address == "module.gitops")' >/dev/null 2>&1; then
    echo -e "${GREEN}✅ GitOps module exists in Terraform state${NC}"
else
    echo -e "${RED}❌ GitOps module not found in Terraform state${NC}"
fi

echo ""
echo -e "${BLUE}9. Testing CRD validation${NC}"

# Test if we can create a sample manifest (dry-run)
cat <<EOF | kubectl apply --dry-run=server -f - >/dev/null 2>&1
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: test-validation
  namespace: gitops
spec:
  project: default
  source:
    repoURL: https://github.com/example/example
    targetRevision: main
    path: test
  destination:
    server: https://kubernetes.default.svc
    namespace: default
EOF

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ ArgoCD Application CRD validation passed${NC}"
else
    echo -e "${RED}❌ ArgoCD Application CRD validation failed${NC}"
fi

cat <<EOF | kubectl apply --dry-run=server -f - >/dev/null 2>&1
apiVersion: tekton.dev/v1beta1
kind: Task
metadata:
  name: test-validation
  namespace: gitops
spec:
  steps:
  - name: test
    image: alpine
    script: echo "test"
EOF

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Tekton Task CRD validation passed${NC}"
else
    echo -e "${RED}❌ Tekton Task CRD validation failed${NC}"
fi

echo ""
echo -e "${BLUE}10. Summary${NC}"

# Count successful checks
total_checks=10
failed_checks=0

# Simple success/failure indicator
echo -e "${GREEN}🎉 GitOps CRD Fix Validation Complete${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo -e "  1. If any checks failed, run: make deploy-gitops ENV=${ENV}"
echo -e "  2. Configure your GitOps repository in terraform.tfvars"
echo -e "  3. Access ArgoCD UI (check ingress or use port-forward)"
echo -e "  4. Continue with remaining platform deployments"

echo ""
echo -e "${BLUE}Quick access commands:${NC}"
echo -e "  • ArgoCD UI: kubectl port-forward -n gitops svc/argocd-server 8080:80"
echo -e "  • View all GitOps resources: kubectl get all -n gitops"
echo -e "  • Check ArgoCD apps: kubectl get applications -n gitops"
echo -e "  • Check Tekton resources: kubectl get pipelines,tasks -n gitops"