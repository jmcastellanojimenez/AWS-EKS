# GitHub Actions MCP Integration for Kiro Infrastructure Platform Management

## Overview

This document provides comprehensive configuration and testing procedures for GitHub Actions MCP integration, enabling Kiro to provide intelligent assistance with CI/CD pipeline management, workflow automation, deployment guidance, and troubleshooting.

## GitHub Actions MCP Server Configuration

### Basic Configuration

Add the following to your `.kiro/settings/mcp.json`:

```json
{
  "mcpServers": {
    "github-actions": {
      "command": "uvx",
      "args": ["github-actions-mcp-server@latest"],
      "env": {
        "GITHUB_TOKEN": "${GITHUB_TOKEN}",
        "GITHUB_REPOSITORY": "your-org/eks-learning-lab",
        "FASTMCP_LOG_LEVEL": "ERROR"
      },
      "disabled": false,
      "autoApprove": [
        "list-*",
        "get-*",
        "describe-*",
        "show-*",
        "search-*"
      ]
    }
  }
}
```

### Advanced Configuration with Multiple Repositories

For managing multiple repositories and organizations:

```json
{
  "mcpServers": {
    "github-actions": {
      "command": "uvx",
      "args": ["github-actions-mcp-server@latest"],
      "env": {
        "GITHUB_TOKEN": "${GITHUB_TOKEN}",
        "GITHUB_REPOSITORY": "your-org/eks-learning-lab",
        "GITHUB_ORG": "your-org",
        "FASTMCP_LOG_LEVEL": "ERROR"
      },
      "disabled": false,
      "autoApprove": [
        "list-workflows",
        "list-runs",
        "get-workflow",
        "get-run",
        "describe-workflow",
        "show-logs",
        "search-workflows",
        "list-artifacts",
        "get-artifact"
      ]
    }
  }
}
```

## Auto-Approved Operations

The following GitHub Actions operations are automatically approved for safe, read-only access:

### Workflow Management
- `list-workflows` - List repository workflows
- `get-workflow` - Get workflow details
- `describe-workflow` - Describe workflow configuration
- `search-workflows` - Search workflows by name or trigger

### Workflow Runs
- `list-runs` - List workflow runs
- `get-run` - Get specific run details
- `show-logs` - Display run logs
- `list-jobs` - List jobs in a run
- `get-job` - Get job details

### Artifacts and Deployments
- `list-artifacts` - List workflow artifacts
- `get-artifact` - Download artifact metadata
- `list-deployments` - List repository deployments
- `get-deployment` - Get deployment details

### Repository Information
- `get-repo` - Get repository information
- `list-branches` - List repository branches
- `list-tags` - List repository tags
- `get-commit` - Get commit details

## Testing GitHub Actions MCP Integration

### Prerequisites

1. **Create GitHub Personal Access Token**:
   ```bash
   # Go to GitHub Settings > Developer settings > Personal access tokens
   # Create token with the following scopes:
   # - repo (Full control of private repositories)
   # - workflow (Update GitHub Action workflows)
   # - read:org (Read org and team membership)
   
   # Set environment variable
   export GITHUB_TOKEN="ghp_your_token_here"
   ```

2. **Verify GitHub CLI access** (optional):
   ```bash
   # Install GitHub CLI
   brew install gh
   
   # Authenticate
   gh auth login
   
   # Test access
   gh repo list
   gh workflow list
   ```

3. **Install uv and uvx** (if not already installed):
   ```bash
   curl -LsSf https://astral.sh/uv/install.sh | sh
   uv --version
   uvx --version
   ```

### Test Scenarios

#### Test 1: Workflow Analysis and Optimization
Ask Kiro to analyze CI/CD workflows:

**Test Query**: "Analyze my GitHub Actions workflows and suggest optimizations for faster deployment times and better resource usage."

**Expected Behavior**:
- List all workflows in the repository
- Analyze workflow configurations and triggers
- Identify bottlenecks and optimization opportunities
- Suggest improvements for caching, parallelization, and resource usage

#### Test 2: Deployment Troubleshooting
Simulate deployment issues:

**Test Query**: "My Terraform deployment workflow is failing. Can you help me troubleshoot the issue and identify the root cause?"

**Expected Behavior**:
- Retrieve recent workflow runs and their status
- Analyze failed job logs
- Identify common failure patterns
- Provide step-by-step troubleshooting guidance

#### Test 3: Workflow Security Review
Ask about security best practices:

**Test Query**: "Review my GitHub Actions workflows for security vulnerabilities and suggest improvements to follow security best practices."

**Expected Behavior**:
- Analyze workflow files for security issues
- Check for hardcoded secrets or credentials
- Review permissions and access controls
- Suggest security improvements and best practices

#### Test 4: CI/CD Pipeline Optimization
Ask for pipeline improvements:

**Test Query**: "Help me optimize my CI/CD pipeline for the EKS platform deployment to reduce deployment time and improve reliability."

**Expected Behavior**:
- Analyze current pipeline structure
- Suggest parallelization opportunities
- Recommend caching strategies
- Provide deployment reliability improvements

### Validation Commands

Use these commands to verify GitHub Actions MCP integration:

```bash
# 1. Test GitHub API access
curl -H "Authorization: token $GITHUB_TOKEN" \
  https://api.github.com/repos/your-org/eks-learning-lab/actions/workflows

# 2. List workflow runs
curl -H "Authorization: token $GITHUB_TOKEN" \
  https://api.github.com/repos/your-org/eks-learning-lab/actions/runs

# 3. Get specific workflow details
curl -H "Authorization: token $GITHUB_TOKEN" \
  https://api.github.com/repos/your-org/eks-learning-lab/actions/workflows/terraform-deploy.yml

# 4. Check repository information
curl -H "Authorization: token $GITHUB_TOKEN" \
  https://api.github.com/repos/your-org/eks-learning-lab

# 5. List recent commits
curl -H "Authorization: token $GITHUB_TOKEN" \
  https://api.github.com/repos/your-org/eks-learning-lab/commits
```

## GitHub Actions Integration Patterns

### Infrastructure Deployment Workflows
```yaml
Terraform Workflows:
  - Plan and apply automation
  - Multi-environment deployment
  - State management and locking
  - Drift detection and remediation
  
Kubernetes Workflows:
  - Manifest validation and deployment
  - Helm chart management
  - Configuration updates
  - Health checks and rollbacks
  
Kiro Assistance:
  - Workflow optimization recommendations
  - Error analysis and troubleshooting
  - Security best practices enforcement
  - Performance monitoring and alerts
```

### Application Deployment Pipelines
```yaml
Microservices Deployment:
  - Container image building
  - Security scanning and testing
  - Multi-stage deployments
  - Canary and blue-green deployments
  
Quality Assurance:
  - Automated testing pipelines
  - Code quality checks
  - Security vulnerability scanning
  - Performance testing automation
  
Monitoring Integration:
  - Deployment success tracking
  - Performance impact analysis
  - Rollback automation
  - Alert integration
```

### GitOps Integration
```yaml
GitOps Workflows:
  - ArgoCD synchronization
  - Configuration drift detection
  - Automated remediation
  - Policy enforcement
  
Compliance and Governance:
  - Policy as code validation
  - Compliance reporting
  - Audit trail maintenance
  - Change approval workflows
```

## Advanced GitHub Actions Operations

### Workflow Analysis and Optimization
```yaml
Performance Metrics:
  - Workflow execution time
  - Job parallelization efficiency
  - Resource utilization patterns
  - Cache hit rates
  
Optimization Strategies:
  - Dependency caching
  - Matrix build optimization
  - Conditional job execution
  - Resource allocation tuning
  
Cost Optimization:
  - Runner usage analysis
  - Workflow frequency optimization
  - Resource right-sizing
  - Spot runner utilization
```

### Security and Compliance
```yaml
Security Scanning:
  - Secret detection and prevention
  - Dependency vulnerability scanning
  - Container image security analysis
  - Infrastructure security validation
  
Compliance Automation:
  - Policy enforcement workflows
  - Audit log generation
  - Compliance reporting
  - Change management integration
```

### Monitoring and Alerting
```yaml
Workflow Monitoring:
  - Success/failure rate tracking
  - Performance trend analysis
  - Resource usage monitoring
  - Cost tracking and optimization
  
Alert Integration:
  - Slack/Teams notifications
  - Email alerts for failures
  - PagerDuty integration
  - Custom webhook notifications
```

## EKS Platform Specific Workflows

### Foundation Platform Deployment
```yaml
Workflow: terraform-foundation.yml
Purpose: Deploy EKS cluster and core infrastructure
Triggers:
  - Manual dispatch
  - Pull request to main (plan only)
  - Push to main (apply)
  
Jobs:
  - terraform-validate
  - terraform-plan
  - terraform-apply
  - post-deployment-tests
  
Kiro Assistance:
  - Validate Terraform syntax
  - Analyze resource dependencies
  - Suggest optimization opportunities
  - Troubleshoot deployment failures
```

### Observability Stack Deployment
```yaml
Workflow: terraform-observability.yml
Purpose: Deploy LGTM observability stack
Dependencies: Foundation platform
Triggers:
  - Manual dispatch
  - Dependency on foundation completion
  
Jobs:
  - validate-prerequisites
  - deploy-prometheus
  - deploy-loki
  - deploy-grafana
  - deploy-tempo
  - integration-tests
  
Kiro Assistance:
  - Verify prerequisite dependencies
  - Monitor deployment progress
  - Validate observability integration
  - Troubleshoot component failures
```

### Microservices Deployment
```yaml
Workflow: deploy-microservices.yml
Purpose: Deploy EcoTrack application services
Dependencies: All platform workflows
Triggers:
  - Manual dispatch
  - Application code changes
  
Jobs:
  - build-images
  - security-scan
  - deploy-to-staging
  - integration-tests
  - deploy-to-production
  - health-checks
  
Kiro Assistance:
  - Optimize build processes
  - Analyze test results
  - Monitor deployment health
  - Suggest rollback strategies
```

## Troubleshooting GitHub Actions MCP Integration

### Common Issues

#### 1. GitHub Token Authentication
```bash
# Verify token validity
curl -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/user

# Check token scopes
curl -H "Authorization: token $GITHUB_TOKEN" -I https://api.github.com/user | grep -i x-oauth-scopes

# Test repository access
curl -H "Authorization: token $GITHUB_TOKEN" \
  https://api.github.com/repos/your-org/eks-learning-lab
```

#### 2. Repository Access Issues
```bash
# Verify repository exists and is accessible
gh repo view your-org/eks-learning-lab

# Check repository permissions
curl -H "Authorization: token $GITHUB_TOKEN" \
  https://api.github.com/repos/your-org/eks-learning-lab/collaborators/your-username/permission
```

#### 3. Workflow API Limitations
```bash
# Check API rate limits
curl -H "Authorization: token $GITHUB_TOKEN" -I https://api.github.com/user | grep -i x-ratelimit

# Test workflow API access
curl -H "Authorization: token $GITHUB_TOKEN" \
  https://api.github.com/repos/your-org/eks-learning-lab/actions/workflows
```

#### 4. MCP Server Connection Issues
```bash
# Test uvx installation
uvx --version

# Test GitHub Actions MCP server manually
uvx github-actions-mcp-server@latest

# Check environment variables
echo $GITHUB_TOKEN
echo $GITHUB_REPOSITORY
```

### Debug Commands

```bash
# 1. GitHub API connectivity
curl -H "Authorization: token $GITHUB_TOKEN" \
  https://api.github.com/repos/your-org/eks-learning-lab/actions/workflows | jq '.workflows[].name'

# 2. Recent workflow runs
curl -H "Authorization: token $GITHUB_TOKEN" \
  https://api.github.com/repos/your-org/eks-learning-lab/actions/runs?per_page=5 | jq '.workflow_runs[].conclusion'

# 3. Workflow logs (for specific run)
curl -H "Authorization: token $GITHUB_TOKEN" \
  https://api.github.com/repos/your-org/eks-learning-lab/actions/runs/{run_id}/logs

# 4. Repository branches and tags
curl -H "Authorization: token $GITHUB_TOKEN" \
  https://api.github.com/repos/your-org/eks-learning-lab/branches | jq '.[].name'

# 5. Check workflow artifacts
curl -H "Authorization: token $GITHUB_TOKEN" \
  https://api.github.com/repos/your-org/eks-learning-lab/actions/artifacts | jq '.artifacts[].name'
```

## Security Considerations

### GitHub Token Security
```yaml
Token Permissions:
  - repo: Full control of private repositories
  - workflow: Update GitHub Action workflows
  - read:org: Read org and team membership
  - read:packages: Download packages from GitHub Package Registry
  
Security Best Practices:
  - Use fine-grained personal access tokens
  - Limit token scope to minimum required
  - Set token expiration dates
  - Rotate tokens regularly
  - Store tokens securely (environment variables)
```

### Workflow Security
```yaml
Security Scanning:
  - Secret detection in workflows
  - Dependency vulnerability scanning
  - Container image security analysis
  - Infrastructure security validation
  
Access Control:
  - Branch protection rules
  - Required status checks
  - Deployment environment protection
  - Manual approval requirements
```

### Best Practices
1. **Read-Only Access**: Auto-approve only read operations
2. **Token Security**: Use environment variables for tokens
3. **Scope Limitation**: Limit token permissions to minimum required
4. **Audit Logging**: Enable audit logs for all GitHub Actions access
5. **Regular Rotation**: Rotate tokens and credentials regularly

## Integration with Platform Components

### Foundation Platform (Workflow 1)
```yaml
GitHub Actions Integration:
  - Terraform deployment automation
  - Infrastructure validation
  - Resource provisioning
  - Configuration management
```

### Observability Stack (Workflow 3)
```yaml
Monitoring Integration:
  - Deployment success tracking
  - Performance monitoring
  - Alert integration
  - Dashboard automation
```

### GitOps Implementation (Workflow 4)
```yaml
ArgoCD Integration:
  - Application deployment automation
  - Configuration synchronization
  - Rollback automation
  - Policy enforcement
```

### Microservices Platform
```yaml
EcoTrack Deployment:
  - Container image building
  - Multi-environment deployment
  - Health check automation
  - Performance monitoring
```

## Requirements Compliance

This GitHub Actions MCP integration addresses the following requirements:

- **Requirement 9.4**: GitHub Actions integration for CI/CD assistance
- **Requirement 4.1**: Automated development assistance
- **Requirement 8.1**: Knowledge management and documentation

## Next Steps

1. **Apply Configuration**: Add GitHub Actions MCP server to `.kiro/settings/mcp.json`
2. **Configure GitHub Token**: Set up personal access token with appropriate scopes
3. **Test Integration**: Run through all test scenarios
4. **Set Up Workflows**: Configure GitHub Actions workflows for platform deployment
5. **Monitor Performance**: Track MCP server health and GitHub API usage
6. **Document Procedures**: Create runbooks for CI/CD operations