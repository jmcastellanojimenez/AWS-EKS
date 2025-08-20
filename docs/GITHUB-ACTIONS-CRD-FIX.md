# GitHub Actions GitOps CRD Fix

## Problem Description

The **🔄 GitOps & Deployment Automation** GitHub Actions workflow was failing with CRD-related errors during the Terraform plan phase:

```
Error: API did not recognize GroupVersionKind from manifest (CRD may not be installed)
│ no matches for kind "Application" in group "argoproj.io"
│ no matches for kind "Pipeline" in group "tekton.dev"
│ no matches for kind "Task" in group "tekton.dev"
```

## Root Cause in CI/CD Context

The issue occurs because GitHub Actions workflows run in isolated environments where:

1. ✅ **Foundation Platform** exists (prerequisite check passes)
2. ❌ **GitOps module** fails during `terraform plan -target=module.gitops`
3. 🔍 **CRDs don't exist** because Helm charts haven't been applied yet
4. 💥 **Terraform validation** fails during plan phase, not apply phase

## Solution: Staged Deployment in GitHub Actions

### Overview

The fix implements a **two-stage deployment approach** specifically designed for CI/CD environments:

1. **Stage 1**: Deploy Helm charts only (to install CRDs)
2. **Wait Period**: Verify CRDs are established 
3. **Stage 2**: Deploy full GitOps module (manifests can now validate)

### Implementation Details

#### Stage 1: Helm Charts Deployment
```yaml
- name: 📊 Terraform Plan (Helm Charts First)
  run: |
    terraform plan -out=tfplan-helm \
      -target=module.gitops.kubernetes_namespace.gitops \
      -target=module.gitops.helm_release.argocd \
      -target=module.gitops.helm_release.tekton_pipelines \
      -target=module.gitops.helm_release.tekton_triggers
```

#### Stage 2: CRD Verification
```bash
# Wait for ArgoCD CRDs
timeout 300 bash -c '
  while ! kubectl get crd applications.argoproj.io >/dev/null 2>&1; do
    echo "Waiting for ArgoCD Application CRD..."
    sleep 10
  done'

# Wait for Tekton CRDs  
timeout 300 bash -c '
  while ! kubectl get crd pipelines.tekton.dev >/dev/null 2>&1; do
    echo "Waiting for Tekton Pipeline CRD..."
    sleep 10
  done'
```

#### Stage 3: Full Deployment
```yaml
- name: 📊 Terraform Plan (Full GitOps)
  run: |
    terraform plan -out=tfplan-full -target=module.gitops
```

## Updated Workflow Features

### Enhanced Error Handling
- ✅ **Timeout Protection**: 5-minute timeout for CRD establishment
- ✅ **Retry Logic**: Robust waiting with proper error messages
- ✅ **kubectl Configuration**: Automatic cluster connection setup
- ✅ **Progress Indicators**: Clear stage-by-stage progress reporting

### Comprehensive Verification
```yaml
# Check GitOps namespace
kubectl get namespace gitops
kubectl get pods -n gitops

# Check ArgoCD components  
kubectl get deployments -n gitops -l app.kubernetes.io/part-of=argocd

# Check Tekton components
kubectl get deployments -n gitops -l app.kubernetes.io/part-of=tekton-pipelines

# Check CRDs are available
kubectl get crd | grep -E "(argoproj|tekton)"

# Check ArgoCD Applications
kubectl get applications -n gitops
```

### Corrected Resource References
- ✅ **Namespace**: Changed from `argocd` to `gitops` 
- ✅ **Port Forwarding**: Updated to `svc/argocd-server 8080:80`
- ✅ **Secret Location**: `kubectl get secret -n gitops argocd-initial-admin-secret`

## Usage in GitHub Actions

### Manual Trigger
1. Go to **Actions** tab in GitHub repository
2. Select **🔄 GitOps & Deployment Automation** workflow
3. Click **Run workflow**
4. Configure inputs:
   - **Action**: `apply`
   - **Environment**: `dev` 
   - **Auto-approve**: `true`
5. Click **Run workflow**

### Expected Workflow Output
```
🚀 Stage 1: Deploying Helm charts to install CRDs...
⏳ Waiting for CRDs to be established...
🔄 Waiting for ArgoCD CRDs...
🏗️ Waiting for Tekton CRDs...  
✅ All CRDs are now available!
🚀 Stage 2: Deploying full GitOps stack...
✅ GitOps deployment completed successfully!
```

## Key Differences from Local Fix

### GitHub Actions Specific
- **Two-stage Terraform plans**: Separate plan files for each stage
- **Integrated kubectl setup**: Automatic cluster configuration
- **CI/CD optimized waits**: Shorter sleep intervals, better logging
- **Workflow-specific verification**: GitHub Actions compatible resource checks

### Production Ready Features
- **Timeout handling**: 5-minute maximum wait for CRDs
- **Proper cleanup**: Handles failed deployments gracefully  
- **Status reporting**: Clear success/failure indicators
- **Secret handling**: Secure AWS credential management

## Troubleshooting

### If Workflow Still Fails

1. **Check Prerequisites**: Ensure Foundation Platform (Workflow 1) is deployed
2. **Verify Permissions**: Check AWS IAM role has EKS access
3. **Resource Limits**: Ensure cluster has sufficient capacity
4. **Manual Recovery**: Run workflow again with `auto_approve: true`

### Common Issues

#### CRD Timeout
```
Error: timeout waiting for CRDs
```
**Solution**: Increase timeout or check cluster resources

#### kubectl Connection
```
Error: unable to connect to cluster
```
**Solution**: Verify cluster name output and AWS credentials

#### Resource Conflicts
```
Error: resource already exists
```
**Solution**: Run with `action: destroy` first, then redeploy

## Verification Commands

After successful deployment:

```bash
# Check overall status
kubectl get all -n gitops

# Get ArgoCD password
kubectl get secret -n gitops argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d

# Port forward to ArgoCD
kubectl port-forward -n gitops svc/argocd-server 8080:80

# Access ArgoCD UI
open http://localhost:8080
```

## Next Steps

1. ✅ **GitOps Ready**: ArgoCD and Tekton are now operational
2. 🔄 **Configure Applications**: Create ArgoCD applications for your services
3. 🏗️ **Setup Pipelines**: Configure Tekton pipelines for CI/CD
4. 🚀 **Deploy Services**: Use GitOps workflow to deploy applications
5. 📊 **Monitor**: Access ArgoCD UI for deployment monitoring

This fix ensures reliable GitOps deployment in GitHub Actions CI/CD environments, providing a robust foundation for enterprise-grade automated deployments.