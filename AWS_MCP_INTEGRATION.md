# AWS MCP Integration for Kiro Infrastructure Platform Management

## Overview

This document provides detailed configuration and testing procedures for AWS MCP integration, enabling Kiro to provide intelligent assistance with AWS services, infrastructure management, and troubleshooting.

## AWS MCP Server Configuration

### Basic Configuration

Add the following to your `.kiro/settings/mcp.json`:

```json
{
  "mcpServers": {
    "aws-docs": {
      "command": "uvx",
      "args": ["awslabs.aws-documentation-mcp-server@latest"],
      "env": {
        "FASTMCP_LOG_LEVEL": "ERROR",
        "AWS_REGION": "us-east-1",
        "AWS_DEFAULT_REGION": "us-east-1"
      },
      "disabled": false,
      "autoApprove": [
        "describe-*",
        "list-*",
        "get-*",
        "show-*",
        "explain-*"
      ]
    }
  }
}
```

### Environment-Specific Configuration

For different environments, adjust the AWS region and add environment-specific settings:

```json
{
  "mcpServers": {
    "aws-docs": {
      "command": "uvx",
      "args": ["awslabs.aws-documentation-mcp-server@latest"],
      "env": {
        "FASTMCP_LOG_LEVEL": "ERROR",
        "AWS_REGION": "us-east-1",
        "AWS_DEFAULT_REGION": "us-east-1",
        "AWS_PROFILE": "eks-learning-lab-dev"
      },
      "disabled": false,
      "autoApprove": [
        "describe-*",
        "list-*",
        "get-*",
        "show-*",
        "explain-*",
        "help"
      ]
    }
  }
}
```

## Auto-Approved Operations

The following AWS CLI operations are automatically approved for safe, read-only access:

### EC2 Operations
- `describe-instances`
- `describe-security-groups`
- `describe-vpcs`
- `describe-subnets`
- `describe-volumes`
- `describe-snapshots`
- `describe-images`
- `describe-key-pairs`

### EKS Operations
- `describe-cluster`
- `describe-nodegroup`
- `list-clusters`
- `list-nodegroups`
- `describe-addon`
- `list-addons`

### IAM Operations
- `list-roles`
- `list-policies`
- `get-role`
- `get-policy`
- `list-attached-role-policies`
- `list-role-policies`

### S3 Operations
- `list-buckets`
- `list-objects-v2`
- `get-bucket-location`
- `get-bucket-lifecycle-configuration`
- `get-bucket-policy`

### CloudWatch Operations
- `describe-alarms`
- `list-metrics`
- `get-metric-statistics`
- `describe-log-groups`

## Testing AWS MCP Integration

### Prerequisites

1. **Install uv and uvx**:
   ```bash
   # Install uv (Python package manager)
   curl -LsSf https://astral.sh/uv/install.sh | sh
   
   # Verify installation
   uv --version
   uvx --version
   ```

2. **Configure AWS Credentials**:
   ```bash
   # Configure AWS CLI
   aws configure
   
   # Or use environment variables
   export AWS_ACCESS_KEY_ID=your_access_key
   export AWS_SECRET_ACCESS_KEY=your_secret_key
   export AWS_DEFAULT_REGION=us-east-1
   ```

3. **Verify AWS Access**:
   ```bash
   # Test basic AWS access
   aws sts get-caller-identity
   aws eks list-clusters --region us-east-1
   ```

### Test Scenarios

#### Test 1: EKS Cluster Information
Ask Kiro to help with EKS cluster management:

**Test Query**: "Can you help me understand the current status of my EKS cluster and provide guidance on node group management?"

**Expected Behavior**: 
- Kiro should use AWS MCP to query cluster information
- Provide detailed cluster status and recommendations
- Offer troubleshooting guidance for common EKS issues

#### Test 2: Infrastructure Cost Analysis
Ask Kiro about AWS cost optimization:

**Test Query**: "Help me analyze my AWS infrastructure costs and suggest optimization opportunities for my EKS platform."

**Expected Behavior**:
- Query AWS Cost Explorer data (if available)
- Analyze EC2, EBS, and S3 usage patterns
- Provide specific cost optimization recommendations

#### Test 3: Security Configuration Review
Ask Kiro to review security configurations:

**Test Query**: "Review my AWS security configurations for the EKS platform and identify potential security improvements."

**Expected Behavior**:
- Analyze IAM roles and policies
- Review security group configurations
- Check encryption settings and compliance

#### Test 4: Troubleshooting Assistance
Simulate a common infrastructure issue:

**Test Query**: "My EKS nodes are not joining the cluster. Can you help me troubleshoot this issue?"

**Expected Behavior**:
- Guide through systematic troubleshooting steps
- Check IAM roles, security groups, and networking
- Provide specific AWS CLI commands for diagnosis

### Validation Commands

Use these commands to verify AWS MCP integration is working:

```bash
# 1. Check MCP server status in Kiro
# Navigate to MCP Server view in Kiro feature panel

# 2. Test AWS CLI access
aws eks describe-cluster --name eks-learning-lab-dev-cluster --region us-east-1

# 3. Verify IAM permissions
aws iam list-attached-role-policies --role-name eks-learning-lab-dev-cluster-service-role

# 4. Check S3 buckets for observability
aws s3 ls | grep lgtm

# 5. Verify VPC configuration
aws ec2 describe-vpcs --filters "Name=tag:Name,Values=eks-learning-lab-dev-vpc"
```

## AWS Service Integration Patterns

### EKS Cluster Management
```yaml
Common Operations:
  - Cluster status and health checks
  - Node group scaling and management
  - Add-on configuration and updates
  - Troubleshooting connectivity issues
  
Kiro Assistance:
  - Automated cluster health assessment
  - Node capacity planning recommendations
  - Add-on compatibility guidance
  - Performance optimization suggestions
```

### Infrastructure as Code Support
```yaml
Terraform Integration:
  - AWS provider configuration guidance
  - Resource dependency analysis
  - State file troubleshooting
  - Cost estimation for planned changes
  
Best Practices:
  - Resource naming conventions
  - Tagging strategies
  - Security configurations
  - Multi-environment management
```

### Observability and Monitoring
```yaml
CloudWatch Integration:
  - Metrics analysis and alerting
  - Log aggregation strategies
  - Dashboard creation guidance
  - Cost optimization for monitoring
  
S3 Storage Management:
  - Lifecycle policy optimization
  - Cost analysis and forecasting
  - Data retention strategies
  - Performance optimization
```

## Troubleshooting AWS MCP Integration

### Common Issues

#### 1. MCP Server Connection Failed
```bash
# Check uvx installation
uvx --version

# Test MCP server manually
uvx awslabs.aws-documentation-mcp-server@latest

# Check network connectivity
curl -I https://pypi.org/simple/
```

#### 2. AWS Credentials Not Found
```bash
# Verify AWS credentials
aws sts get-caller-identity

# Check environment variables
echo $AWS_ACCESS_KEY_ID
echo $AWS_DEFAULT_REGION

# Test with specific profile
aws sts get-caller-identity --profile eks-learning-lab-dev
```

#### 3. Auto-Approval Not Working
```yaml
Verification Steps:
  - Check command patterns match exactly
  - Verify autoApprove array syntax
  - Test with manual approval first
  - Check MCP server logs for errors
```

#### 4. Region Configuration Issues
```bash
# Set default region
export AWS_DEFAULT_REGION=us-east-1

# Verify region in AWS config
cat ~/.aws/config

# Test region-specific commands
aws eks list-clusters --region us-east-1
```

### Debug Commands

```bash
# 1. Check MCP server logs
# View logs in Kiro MCP Server panel

# 2. Test AWS CLI directly
aws --version
aws configure list

# 3. Verify permissions
aws iam get-user
aws sts get-caller-identity

# 4. Test specific AWS operations
aws eks describe-cluster --name eks-learning-lab-dev-cluster
aws ec2 describe-instances --max-items 5
aws s3 ls
```

## Security Considerations

### IAM Permissions
The AWS MCP integration requires the following minimum IAM permissions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "eks:DescribeCluster",
        "eks:ListClusters",
        "eks:DescribeNodegroup",
        "eks:ListNodegroups",
        "ec2:DescribeInstances",
        "ec2:DescribeVpcs",
        "ec2:DescribeSubnets",
        "ec2:DescribeSecurityGroups",
        "iam:ListRoles",
        "iam:GetRole",
        "s3:ListAllMyBuckets",
        "s3:ListBucket",
        "cloudwatch:DescribeAlarms",
        "cloudwatch:ListMetrics"
      ],
      "Resource": "*"
    }
  ]
}
```

### Best Practices
1. **Principle of Least Privilege**: Only grant necessary permissions
2. **Read-Only Access**: Auto-approve only read operations
3. **Environment Isolation**: Use separate AWS profiles for different environments
4. **Credential Rotation**: Regularly rotate AWS access keys
5. **Audit Logging**: Enable CloudTrail for API call auditing

## Requirements Compliance

This AWS MCP integration addresses the following requirements:

- **Requirement 9.1**: Integration with external tools and services (AWS)
- **Requirement 2.1**: Intelligent Terraform management with AWS services
- **Requirement 2.4**: AWS service integration understanding

## Next Steps

1. **Apply Configuration**: Add AWS MCP server to `.kiro/settings/mcp.json`
2. **Install Dependencies**: Ensure uv and uvx are installed
3. **Configure Credentials**: Set up AWS credentials and profiles
4. **Test Integration**: Run through all test scenarios
5. **Monitor Performance**: Track MCP server health and response times
6. **Document Issues**: Record any integration issues and solutions