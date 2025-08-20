#!/bin/bash

# GitOps CRD Fix Deployment Script
# Addresses the CRD installation timing issue by deploying in proper sequence

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Environment (default to dev)
ENV="${1:-dev}"

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo -e "${BLUE}🚀 GitOps CRD Fix Deployment Script${NC}"
echo -e "${YELLOW}Environment: ${ENV}${NC}"
echo ""

# Change to terraform environment directory
cd "${PROJECT_DIR}/terraform/environments/${ENV}"

echo -e "${BLUE}Step 1: Initialize Terraform${NC}"
terraform init

echo -e "${BLUE}Step 2: Deploy Helm Charts First (to install CRDs)${NC}"
echo -e "${YELLOW}Deploying GitOps namespace and Helm charts...${NC}"

# Deploy just the Helm charts to install CRDs first
terraform apply -auto-approve \
  -target=module.gitops.kubernetes_namespace.gitops \
  -target=module.gitops.helm_release.argocd \
  -target=module.gitops.helm_release.tekton_pipelines \
  -target=module.gitops.helm_release.tekton_triggers

echo -e "${GREEN}✅ Helm charts deployed successfully${NC}"

echo -e "${BLUE}Step 3: Wait for CRDs to be established${NC}"

# Wait for ArgoCD CRDs
echo -e "${YELLOW}Waiting for ArgoCD CRDs...${NC}"
timeout 300 bash -c '
  while ! kubectl get crd applications.argoproj.io >/dev/null 2>&1; do
    echo "Waiting for ArgoCD Application CRD..."
    sleep 5
  done
  while ! kubectl get crd applicationsets.argoproj.io >/dev/null 2>&1; do
    echo "Waiting for ArgoCD ApplicationSet CRD..."
    sleep 5
  done
'

# Wait for Tekton CRDs
echo -e "${YELLOW}Waiting for Tekton CRDs...${NC}"
timeout 300 bash -c '
  while ! kubectl get crd pipelines.tekton.dev >/dev/null 2>&1; do
    echo "Waiting for Tekton Pipeline CRD..."
    sleep 5
  done
  while ! kubectl get crd tasks.tekton.dev >/dev/null 2>&1; do
    echo "Waiting for Tekton Task CRD..."
    sleep 5
  done
  while ! kubectl get crd eventlisteners.triggers.tekton.dev >/dev/null 2>&1; do
    echo "Waiting for Tekton EventListener CRD..."
    sleep 5
  done
'

echo -e "${GREEN}✅ All CRDs are now available${NC}"

echo -e "${BLUE}Step 4: Deploy time_sleep resources${NC}"
terraform apply -auto-approve \
  -target=module.gitops.time_sleep.wait_for_argocd_crds \
  -target=module.gitops.time_sleep.wait_for_tekton_crds

echo -e "${BLUE}Step 5: Deploy remaining GitOps manifests${NC}"
echo -e "${YELLOW}Deploying ArgoCD and Tekton manifests...${NC}"

# Now deploy the manifests that depend on CRDs
terraform apply -auto-approve \
  -target=module.gitops.kubernetes_manifest.app_of_apps \
  -target=module.gitops.kubernetes_manifest.build_pipeline \
  -target=module.gitops.kubernetes_manifest.trivy_task \
  -target=module.gitops.kubernetes_manifest.github_eventlistener

echo -e "${GREEN}✅ GitOps manifests deployed successfully${NC}"

echo -e "${BLUE}Step 6: Complete GitOps module deployment${NC}"
terraform apply -auto-approve -target=module.gitops

echo -e "${GREEN}✅ GitOps module deployment completed successfully!${NC}"

echo -e "${BLUE}Step 7: Verification${NC}"
echo -e "${YELLOW}Checking deployed resources...${NC}"

# Verify ArgoCD
echo "ArgoCD pods:"
kubectl get pods -n gitops -l app.kubernetes.io/name=argocd-server

# Verify Tekton
echo ""
echo "Tekton pods:"
kubectl get pods -n gitops -l app.kubernetes.io/part-of=tekton-pipelines

# Verify CRDs
echo ""
echo "CRDs:"
kubectl get crd | grep -E "(argoproj|tekton)" | head -5

# Verify manifests
echo ""
echo "ArgoCD Applications:"
kubectl get applications -n gitops 2>/dev/null || echo "No applications found (this is normal for initial deployment)"

echo ""
echo "Tekton Pipelines:"
kubectl get pipelines -n gitops 2>/dev/null || echo "No pipelines found"

echo ""
echo "Tekton Tasks:"
kubectl get tasks -n gitops 2>/dev/null || echo "No tasks found"

echo ""
echo -e "${GREEN}🎉 GitOps CRD fix deployment completed successfully!${NC}"
echo -e "${YELLOW}Next steps:${NC}"
echo -e "  1. Configure your GitOps repository URL in terraform.tfvars"
echo -e "  2. Create Application manifests in your GitOps repository"
echo -e "  3. Access ArgoCD UI at https://${DOMAIN_NAME:-your-domain.com}/argocd"
echo -e "  4. Continue with remaining workflow deployments"