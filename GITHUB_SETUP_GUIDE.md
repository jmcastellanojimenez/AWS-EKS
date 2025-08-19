# 🚀 GitHub Repository Setup Guide

## 📋 Step-by-Step GitHub Configuration

### 1. Create GitHub Repository

```bash
# Create new repository on GitHub
# Repository name: eks-foundation-platform
# Description: Complete Enterprise EKS Platform with 7 Workflows
# Visibility: Private (recommended for infrastructure)
```

### 2. Push Your Code to GitHub

```bash
# Initialize git repository (if not already done)
git init
git add .
git commit -m "Initial commit: Complete EKS Foundation Platform"

# Add GitHub remote
git remote add origin https://github.com/YOUR_USERNAME/eks-foundation-platform.git

# Push to GitHub
git branch -M main
git push -u origin main
```

### 3. Configure GitHub Secrets

Go to your repository → Settings → Secrets and variables → Actions

#### ✅ Repository Secrets Already Configured:

| Secret Name | Status | Purpose |
|-------------|--------|---------|
| `AWS_ACCOUNT_ID` | ✅ Configured | AWS Account ID for backend configuration |
| `AWS_REGION` | ✅ Configured | AWS Region for deployments |
| `AWS_ROLE_ARN` | ✅ Configured | AWS access via OIDC |
| `SLACK_WEBHOOK_URL` | ✅ Configured | Slack notifications for deployments |

#### Additional Secrets Needed:

| Secret Name | Value | Purpose |
|-------------|-------|---------|
| `CLOUDFLARE_API_TOKEN` | Your Cloudflare API token | DNS automation (if using external-dns) |
| `GRAFANA_ADMIN_PASSWORD` | Secure password | Grafana access |
| `POSTGRES_PASSWORD` | Secure database password | PostgreSQL access |

#### Optional Environment-Specific Secrets:

If you want different values per environment, you can add:

**Development Environment:**
- `DEV_CLOUDFLARE_API_TOKEN` (optional)
- `DEV_GRAFANA_ADMIN_PASSWORD` (optional)
- `DEV_POSTGRES_PASSWORD` (optional)

**Staging Environment:**
- `STAGING_CLOUDFLARE_API_TOKEN` (optional)
- `STAGING_GRAFANA_ADMIN_PASSWORD` (optional)
- `STAGING_POSTGRES_PASSWORD` (optional)

**Production Environment:**
- `PROD_CLOUDFLARE_API_TOKEN` (optional)
- `PROD_GRAFANA_ADMIN_PASSWORD` (optional)
- `PROD_POSTGRES_PASSWORD` (optional)

### 4. Configure AWS OIDC Provider

Create an IAM role for GitHub Actions to assume:

```bash
# Create the OIDC provider (one-time setup)
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
```

### 5. Create GitHub Actions IAM Role

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:jmcastellanojimenez/AWS-EKS:*"
        }
      }
    }
  ]
}
```

### 6. Attach Policies to GitHub Actions Role

```bash
# Attach required policies
aws iam attach-role-policy \
  --role-name github-actions-role \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess

# Or create a more restrictive custom policy (recommended)
```

### 7. Configure Repository Environments

Go to Settings → Environments and create:

#### **Development Environment**
- **Protection Rules**: None (for fast iteration)
- **Environment Secrets**: Dev-specific values
- **Reviewers**: Optional

#### **Staging Environment**
- **Protection Rules**: Require reviewers (1 person)
- **Environment Secrets**: Staging-specific values
- **Reviewers**: Platform team members

#### **Production Environment**
- **Protection Rules**: 
  - Require reviewers (2+ people)
  - Wait timer (5 minutes)
  - Restrict to main branch only
- **Environment Secrets**: Production values
- **Reviewers**: Senior engineers + managers

## 🔧 Deployment Workflow Usage

### Manual Deployment via GitHub Actions

1. **Go to Actions tab** in your repository
2. **Select "Terraform Apply"** workflow
3. **Click "Run workflow"**
4. **Select environment** (dev/staging/prod)
5. **Type "yes"** to confirm
6. **Click "Run workflow"**

### Automated Deployment (Optional)

The workflows are configured for manual triggers, but you can enable automatic deployment by modifying the workflow triggers.

## 🎯 Benefits of GitHub Actions Deployment

### **Team Collaboration**
- **Shared deployment process** - everyone uses the same method
- **Visibility** - team can see deployment status and logs
- **Knowledge sharing** - deployment process is documented in code

### **Security & Compliance**
- **No local credentials** - uses OIDC for secure AWS access
- **Audit trail** - complete record of all deployments
- **Approval gates** - required reviews for sensitive environments
- **Consistent environment** - same tools and versions every time

### **Operational Benefits**
- **Rollback capability** - easy to revert to previous versions
- **Deployment history** - see what changed and when
- **Automated testing** - can add validation steps
- **Notifications** - Slack alerts for deployment status

## 🚨 Important Notes

### **Terraform State Management**
- **Backend Configuration**: Update `backend.tf` with your S3 bucket
- **State Locking**: Ensure DynamoDB table exists for state locking
- **State Security**: S3 bucket should be encrypted and access-controlled

### **Secrets Management**
- **Never commit secrets** to the repository
- **Use GitHub Secrets** for sensitive values
- **Rotate secrets regularly**
- **Use environment-specific secrets** for different environments

### **Cost Management**
- **GitHub Actions minutes** - free tier includes 2000 minutes/month
- **Self-hosted runners** - option for unlimited minutes
- **AWS costs** - same regardless of deployment method

This setup gives you a professional, secure, and collaborative deployment process while maintaining the same infrastructure outcomes!