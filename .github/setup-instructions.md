# GitHub Actions Setup Instructions

## Prerequisites

1. **AWS Account**: Target AWS account where EKS will be deployed
2. **GitHub Repository**: Your AWS-EKS repository
3. **AWS CLI**: Configured with appropriate permissions
4. **GitHub Username**: Required for trust policy setup

## Setup Steps

### 1. Get Your AWS Account ID

```bash
# Get your AWS account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "Your AWS Account ID: $AWS_ACCOUNT_ID"
```

### 2. Create OIDC Provider in AWS

```bash
# Check if OIDC provider already exists
aws iam list-open-id-connect-providers --query 'OpenIDConnectProviderList[?contains(Arn, `token.actions.githubusercontent.com`)]'

# Create OIDC provider if it doesn't exist
aws iam create-open-id-connect-provider \
    --url https://token.actions.githubusercontent.com \
    --client-id-list sts.amazonaws.com \
    --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
```

### 3. Update Configuration Files

```bash
# REQUIRED: Replace with your actual GitHub username
export GITHUB_USERNAME="your-github-username"
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Update the trust policy with your GitHub username
sed -i.bak "s/YOUR_GITHUB_USERNAME/${GITHUB_USERNAME}/g" .github/iam/GitHubActionsRole.json

# Update account ID in trust policy
sed -i.bak "s/503561447988/${AWS_ACCOUNT_ID}/g" .github/iam/GitHubActionsRole.json

# Verify the changes
cat .github/iam/GitHubActionsRole.json
```

### 4. Create IAM Role for GitHub Actions

```bash
# Create the role
aws iam create-role \
    --role-name GitHubActionsRole \
    --assume-role-policy-document file://.github/iam/GitHubActionsRole.json \
    --description "Role for GitHub Actions to deploy EKS clusters"

# Attach policy
aws iam put-role-policy \
    --role-name GitHubActionsRole \
    --policy-name GitHubActionsPolicy \
    --policy-document file://.github/iam/GitHubActionsPolicy.json

# Get the role ARN
aws iam get-role --role-name GitHubActionsRole --query 'Role.Arn' --output text
```

### 5. Create S3 Bucket and DynamoDB Table (if needed)

```bash
# Create S3 bucket for Terraform state
aws s3api create-bucket \
    --bucket tf-bucket-${AWS_ACCOUNT_ID} \
    --region us-east-1

# Enable versioning
aws s3api put-bucket-versioning \
    --bucket tf-bucket-${AWS_ACCOUNT_ID} \
    --versioning-configuration Status=Enabled

# Create DynamoDB table for state locking
aws dynamodb create-table \
    --table-name tf-lock-table \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
    --region us-east-1
```

### 6. Configure GitHub Repository Secrets

Go to your GitHub repository → Settings → Secrets and Variables → Actions

Add the following secret:

- **AWS_ROLE_ARN**: `arn:aws:iam::YOUR_ACCOUNT_ID:role/GitHubActionsRole`

### 7. Update EKS Configuration Files

```bash
# Update account ID in all config files
find cdktf/config -name "*.json" -exec sed -i.bak "s/503561447988/${AWS_ACCOUNT_ID}/g" {} \;

# Verify changes
grep -r "account" cdktf/config/
```

### 5. Usage

#### Manual Deployment
Go to Actions → EKS Cluster Deployment → Run workflow

Fill in:
- **Cluster name**: `np-alpha-eks-01-cheap`
- **Action**: `deploy`
- **AWS Region**: `us-east-1`
- **Environment**: `nonprod`

#### Automatic Deployment
Push changes to `main` branch with modifications in `cdktf/` directory

## Troubleshooting

### Common Issues

1. **OIDC Provider Error**: Make sure the provider exists and thumbprint is correct
2. **Permission Denied**: Verify IAM role has correct permissions
3. **Config File Not Found**: Ensure config file exists in correct path
4. **TypeScript Compilation**: Dependencies are installed automatically

### Debug Steps

1. Check GitHub Actions logs
2. Verify AWS credentials are working
3. Validate config file syntax
4. Check S3 bucket and DynamoDB table exist

## Security Notes

- The IAM policy is broad for EKS deployment needs
- Consider restricting permissions based on your requirements
- Use least privilege principle in production
- Monitor CloudTrail for actions performed by this role