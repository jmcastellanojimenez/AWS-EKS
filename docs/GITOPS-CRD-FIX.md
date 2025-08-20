# GitOps CRD Installation Fix

## Problem Description

When deploying the GitOps module (Workflow 4), Terraform fails during the plan phase with CRD-related errors:

```
Error: API did not recognize GroupVersionKind from manifest (CRD may not be installed)
│ no matches for kind "Application" in group "argoproj.io"
│ no matches for kind "Pipeline" in group "tekton.dev"
│ no matches for kind "Task" in group "tekton.dev"
```

## Root Cause

The issue occurs because Terraform tries to validate Kubernetes manifests during the **plan phase**, but the required Custom Resource Definitions (CRDs) don't exist yet. The CRDs are installed by Helm charts during the **apply phase**.

**Timeline of the problem**:
1. ✅ Foundation, Ingress, and Observability modules deploy successfully
2. ❌ GitOps module fails during `terraform plan` phase
3. 🔍 Helm charts are planned but not yet applied → CRDs not available
4. 💥 `kubernetes_manifest` resources fail validation

## Solution Implementation

### 1. Improved Module Dependencies

Updated `terraform/modules/gitops/main.tf` with:
- Simplified CRD wait logic using `time_sleep` resources
- Proper dependency chains: `helm_release` → `time_sleep` → `kubernetes_manifest`
- Added `computed_fields` for server-side apply compatibility
- Removed complex `null_resource` validations that can fail

### 2. Sequential Deployment Script

Created `scripts/deploy-gitops-fix.sh` that deploys in proper sequence:
1. **Helm Charts First**: Deploy ArgoCD and Tekton Helm charts to install CRDs
2. **Wait for CRDs**: Verify CRDs are established and available
3. **Deploy Manifests**: Apply Kubernetes manifests that depend on CRDs

### 3. Makefile Integration

Added convenient Makefile targets:
```bash
make deploy-gitops ENV=dev    # Deploy with CRD fix
make gitops-fix ENV=dev       # Run the fix script directly
```

## Usage

### Quick Fix (Recommended)
```bash
# Use the automated fix script
make deploy-gitops ENV=dev
```

### Manual Deployment
```bash
# Navigate to environment directory
cd terraform/environments/dev

# 1. Deploy Helm charts first
terraform apply -auto-approve \
  -target=module.gitops.kubernetes_namespace.gitops \
  -target=module.gitops.helm_release.argocd \
  -target=module.gitops.helm_release.tekton_pipelines \
  -target=module.gitops.helm_release.tekton_triggers

# 2. Wait for CRDs (check manually)
kubectl get crd | grep -E "(argoproj|tekton)"

# 3. Deploy time_sleep resources
terraform apply -auto-approve \
  -target=module.gitops.time_sleep.wait_for_argocd_crds \
  -target=module.gitops.time_sleep.wait_for_tekton_crds

# 4. Deploy manifests
terraform apply -auto-approve \
  -target=module.gitops.kubernetes_manifest.app_of_apps \
  -target=module.gitops.kubernetes_manifest.build_pipeline \
  -target=module.gitops.kubernetes_manifest.trivy_task

# 5. Complete deployment
terraform apply -auto-approve -target=module.gitops
```

## Verification

After successful deployment, verify:

```bash
# Check ArgoCD pods
kubectl get pods -n gitops -l app.kubernetes.io/name=argocd-server

# Check Tekton pods
kubectl get pods -n gitops -l app.kubernetes.io/part-of=tekton-pipelines

# Check CRDs are available
kubectl get crd | grep -E "(argoproj|tekton)"

# Check ArgoCD Applications (may be empty initially)
kubectl get applications -n gitops

# Check Tekton resources
kubectl get pipelines -n gitops
kubectl get tasks -n gitops
```

## Key Improvements

1. **Removed Complex Validation**: Eliminated `null_resource` with local-exec that could fail
2. **Simplified Wait Logic**: Using `time_sleep` with proper dependencies
3. **Server-Side Apply**: Added `computed_fields` for better CRD compatibility
4. **Automated Script**: One-command fix for the entire issue
5. **Clear Documentation**: Step-by-step manual process when needed

## Prevention

To prevent this issue in future modules:
1. Always deploy Helm charts before dependent manifests
2. Use `time_sleep` resources with adequate delays (60s+)
3. Add `computed_fields` to `kubernetes_manifest` resources
4. Consider using conditional resource creation for complex cases

## Troubleshooting

### If CRDs still not found:
```bash
# Force Helm chart reinstallation
helm uninstall argocd -n gitops
helm uninstall tekton-pipelines -n gitops
helm uninstall tekton-triggers -n gitops

# Re-run the fix script
make deploy-gitops ENV=dev
```

### If manifests fail to apply:
```bash
# Check CRD status
kubectl get crd applications.argoproj.io -o yaml
kubectl get crd pipelines.tekton.dev -o yaml

# Wait longer for CRDs to be ready
sleep 120

# Retry manifest deployment
terraform apply -target=module.gitops.kubernetes_manifest.app_of_apps
```

### If ArgoCD UI not accessible:
```bash
# Check ingress configuration
kubectl get ingress -n gitops

# Check Ambassador mapping
kubectl get mapping -n gitops

# Port forward for direct access
kubectl port-forward -n gitops svc/argocd-server 8080:80
```

## Next Steps

1. Configure your GitOps repository URL in `terraform.tfvars`
2. Create Application manifests in your GitOps repository
3. Access ArgoCD UI at `https://your-domain.com/argocd`
4. Continue with remaining workflow deployments (Security, Service Mesh, Data Services)

This fix ensures reliable GitOps deployment and provides a foundation for enterprise-grade CI/CD workflows.