# EKS Platform Makefile
.PHONY: help init plan apply destroy clean validate fmt security-scan

# Default environment
ENV ?= dev

# Colors for output
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[1;33m
RED := \033[0;31m
NC := \033[0m # No Color

help: ## Show this help message
	@echo "$(BLUE)EKS Platform Management$(NC)"
	@echo "======================="
	@echo ""
	@echo "$(YELLOW)Available commands:$(NC)"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  $(GREEN)%-15s$(NC) %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo ""
	@echo "$(YELLOW)Usage:$(NC)"
	@echo "  make <command> ENV=<environment>"
	@echo ""
	@echo "$(YELLOW)Examples:$(NC)"
	@echo "  make plan ENV=dev"
	@echo "  make apply ENV=prod"
	@echo "  make destroy ENV=dev"

init: ## Initialize Terraform
	@echo "$(BLUE)Initializing Terraform for $(ENV) environment...$(NC)"
	cd terraform/environments/$(ENV) && terraform init

validate: ## Validate Terraform configuration
	@echo "$(BLUE)Validating Terraform configuration...$(NC)"
	cd terraform/environments/$(ENV) && terraform validate

fmt: ## Format Terraform files
	@echo "$(BLUE)Formatting Terraform files...$(NC)"
	terraform fmt -recursive

plan: init validate ## Plan Terraform deployment
	@echo "$(BLUE)Planning deployment for $(ENV) environment...$(NC)"
	cd terraform/environments/$(ENV) && terraform plan -var-file="terraform.tfvars"

apply: init validate ## Apply Terraform deployment
	@echo "$(YELLOW)Deploying to $(ENV) environment...$(NC)"
	@echo "$(RED)This will create/modify infrastructure. Continue? [y/N]$(NC)" && read ans && [ $${ans:-N} = y ]
	cd terraform/environments/$(ENV) && terraform apply -var-file="terraform.tfvars"
	@$(MAKE) kubeconfig ENV=$(ENV)
	@$(MAKE) verify ENV=$(ENV)

destroy: ## Destroy Terraform deployment
	@echo "$(RED)WARNING: This will destroy all resources in $(ENV) environment!$(NC)"
	@echo "$(RED)Type 'yes' to confirm:$(NC)" && read ans && [ "$$ans" = "yes" ]
	cd terraform/environments/$(ENV) && terraform destroy -var-file="terraform.tfvars"

kubeconfig: ## Update kubeconfig for the cluster
	@echo "$(BLUE)Updating kubeconfig...$(NC)"
	$(eval CLUSTER_NAME := $(shell cd terraform/environments/$(ENV) && terraform output -raw cluster_name 2>/dev/null || echo ""))
	$(eval AWS_REGION := $(shell cd terraform/environments/$(ENV) && terraform output -raw aws_region 2>/dev/null || echo "us-east-1"))
	@if [ -n "$(CLUSTER_NAME)" ]; then \
		aws eks update-kubeconfig --region $(AWS_REGION) --name $(CLUSTER_NAME); \
		echo "$(GREEN)Kubeconfig updated for cluster: $(CLUSTER_NAME)$(NC)"; \
	else \
		echo "$(RED)Could not determine cluster name$(NC)"; \
	fi

verify: ## Verify deployment
	@echo "$(BLUE)Verifying deployment...$(NC)"
	@echo "$(YELLOW)Checking nodes:$(NC)"
	kubectl get nodes
	@echo ""
	@echo "$(YELLOW)Checking system pods:$(NC)"
	kubectl get pods -n kube-system
	@echo ""
	@echo "$(YELLOW)Checking ingress components:$(NC)"
	kubectl get pods -n ingress-system
	@echo ""
	@echo "$(YELLOW)Checking observability stack:$(NC)"
	kubectl get pods -n observability
	@echo ""
	@echo "$(YELLOW)Checking GitOps components:$(NC)"
	kubectl get pods -n gitops

status: ## Show cluster status
	@echo "$(BLUE)Cluster Status$(NC)"
	@echo "=============="
	kubectl cluster-info
	@echo ""
	@echo "$(YELLOW)Node Status:$(NC)"
	kubectl get nodes -o wide
	@echo ""
	@echo "$(YELLOW)Resource Usage:$(NC)"
	kubectl top nodes 2>/dev/null || echo "Metrics server not available"

logs: ## Show logs for a component
	@echo "$(BLUE)Available components:$(NC)"
	@echo "  aws-load-balancer-controller (kube-system)"
	@echo "  cert-manager (ingress-system)"
	@echo "  external-dns (ingress-system)"
	@echo "  ambassador (ingress-system)"
	@echo "  prometheus (observability)"
	@echo "  grafana (observability)"
	@echo "  argocd-server (gitops)"
	@echo ""
	@echo "$(YELLOW)Usage: make logs COMPONENT=<component> NAMESPACE=<namespace>$(NC)"
	@if [ -n "$(COMPONENT)" ] && [ -n "$(NAMESPACE)" ]; then \
		kubectl logs -l app.kubernetes.io/name=$(COMPONENT) -n $(NAMESPACE) --tail=100 -f; \
	fi

port-forward: ## Port forward to services
	@echo "$(BLUE)Available services:$(NC)"
	@echo "  grafana (3000:80)"
	@echo "  argocd (8080:80)"
	@echo "  prometheus (9090:9090)"
	@echo ""
	@echo "$(YELLOW)Usage: make port-forward SERVICE=<service>$(NC)"
	@case "$(SERVICE)" in \
		grafana) kubectl port-forward -n observability svc/grafana 3000:80 ;; \
		argocd) kubectl port-forward -n gitops svc/argocd-server 8080:80 ;; \
		prometheus) kubectl port-forward -n observability svc/prometheus-kube-prometheus-prometheus 9090:9090 ;; \
		*) echo "$(RED)Unknown service: $(SERVICE)$(NC)" ;; \
	esac

clean: ## Clean up local files
	@echo "$(BLUE)Cleaning up local files...$(NC)"
	find . -name "*.tfplan" -delete
	find . -name ".terraform.lock.hcl" -delete
	find . -type d -name ".terraform" -exec rm -rf {} + 2>/dev/null || true

security-scan: ## Run security scans
	@echo "$(BLUE)Running security scans...$(NC)"
	@echo "$(YELLOW)Scanning Terraform files...$(NC)"
	@if command -v tfsec >/dev/null 2>&1; then \
		tfsec terraform/; \
	else \
		echo "$(YELLOW)tfsec not installed. Install with: brew install tfsec$(NC)"; \
	fi
	@echo ""
	@echo "$(YELLOW)Scanning Kubernetes manifests...$(NC)"
	@if command -v kubesec >/dev/null 2>&1; then \
		find k8s-manifests/ -name "*.yaml" -exec kubesec scan {} \; ; \
	else \
		echo "$(YELLOW)kubesec not installed. Install with: brew install kubesec$(NC)"; \
	fi

update: ## Update dependencies
	@echo "$(BLUE)Updating dependencies...$(NC)"
	@echo "$(YELLOW)Updating Terraform providers...$(NC)"
	cd terraform/environments/$(ENV) && terraform init -upgrade
	@echo "$(YELLOW)Updating Helm repositories...$(NC)"
	helm repo update

backup: ## Backup cluster configuration
	@echo "$(BLUE)Backing up cluster configuration...$(NC)"
	@mkdir -p backups/$(ENV)
	kubectl get all -A -o yaml > backups/$(ENV)/all-resources-$(shell date +%Y%m%d-%H%M%S).yaml
	@echo "$(GREEN)Backup saved to backups/$(ENV)/$(NC)"

install-tools: ## Install required tools (macOS)
	@echo "$(BLUE)Installing required tools...$(NC)"
	@if command -v brew >/dev/null 2>&1; then \
		brew install terraform kubectl helm awscli tfsec kubesec; \
		echo "$(GREEN)Tools installed successfully$(NC)"; \
	else \
		echo "$(RED)Homebrew not found. Please install Homebrew first.$(NC)"; \
	fi

# Development helpers
dev-deploy: ## Quick deploy to dev environment
	@$(MAKE) apply ENV=dev

dev-destroy: ## Quick destroy dev environment
	@$(MAKE) destroy ENV=dev

dev-status: ## Show dev environment status
	@$(MAKE) status ENV=dev

# GitOps helpers
gitops-fix: ## Fix GitOps CRD installation issues
	@echo "$(BLUE)Deploying GitOps with CRD fix...$(NC)"
	./scripts/deploy-gitops-fix.sh $(ENV)

deploy-gitops: ## Deploy GitOps module with proper CRD handling
	@$(MAKE) gitops-fix ENV=$(ENV)

# Production helpers
prod-plan: ## Plan production deployment
	@$(MAKE) plan ENV=prod

prod-apply: ## Apply production deployment (with extra confirmation)
	@echo "$(RED)PRODUCTION DEPLOYMENT$(NC)"
	@echo "$(RED)This will deploy to PRODUCTION environment!$(NC)"
	@echo "$(RED)Type 'DEPLOY_TO_PRODUCTION' to confirm:$(NC)" && read ans && [ "$$ans" = "DEPLOY_TO_PRODUCTION" ]
	@$(MAKE) apply ENV=prod

# Destruction targets for specific modules
destroy-all: ## Destroy ALL infrastructure (DANGEROUS!)
	@echo "$(RED)🚨 WARNING: This will destroy ALL infrastructure!$(NC)"
	@./scripts/destroy-infrastructure.sh $(ENV) all

destroy-lgtm: ## Destroy LGTM Observability stack only
	@echo "$(YELLOW)Destroying LGTM Observability stack...$(NC)"
	@./scripts/destroy-infrastructure.sh $(ENV) lgtm

destroy-gitops: ## Destroy GitOps infrastructure only
	@echo "$(YELLOW)Destroying GitOps infrastructure...$(NC)"
	@./scripts/destroy-infrastructure.sh $(ENV) gitops

destroy-ingress: ## Destroy Ingress infrastructure only
	@echo "$(YELLOW)Destroying Ingress infrastructure...$(NC)"
	@./scripts/destroy-infrastructure.sh $(ENV) ingress

destroy-security: ## Destroy Security infrastructure only
	@echo "$(YELLOW)Destroying Security infrastructure...$(NC)"
	@./scripts/destroy-infrastructure.sh $(ENV) security

destroy-mesh: ## Destroy Service Mesh only
	@echo "$(YELLOW)Destroying Service Mesh...$(NC)"
	@./scripts/destroy-infrastructure.sh $(ENV) service-mesh

destroy-data: ## Destroy Data Services only
	@echo "$(YELLOW)Destroying Data Services...$(NC)"
	@./scripts/destroy-infrastructure.sh $(ENV) data-services

destroy-foundation: ## Destroy Foundation (EKS cluster) - DANGEROUS!
	@echo "$(RED)🚨 WARNING: This will destroy the EKS cluster and ALL resources!$(NC)"
	@./scripts/destroy-infrastructure.sh $(ENV) foundation

destroy-workflow: ## Destroy specific workflow(s) - Usage: make destroy-workflow WORKFLOWS=3,4,5
	@echo "$(YELLOW)Destroying workflows: $(WORKFLOWS)$(NC)"
	@./scripts/destroy-infrastructure.sh $(ENV) $(WORKFLOWS)

destroy-check: ## Check what would be destroyed without actually destroying
	@echo "$(BLUE)Checking deployed resources...$(NC)"
	cd terraform/environments/$(ENV) && terraform state list | grep module