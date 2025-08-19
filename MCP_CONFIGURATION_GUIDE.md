# MCP Configuration Guide for Kiro Infrastructure Platform Management

## Overview

This guide provides the Model Context Protocol (MCP) configuration patterns for the EKS Foundation Platform. The MCP integrations enable Kiro to seamlessly interact with AWS, Kubernetes, monitoring systems, and CI/CD pipelines.

## Base Configuration Structure

The MCP configuration should be placed in `.kiro/settings/mcp.json`. If this file doesn't exist, create it with the following base structure:

```json
{
  "mcpServers": {}
}
```

## MCP Server Configuration Patterns

### 1. AWS Documentation Server

**Purpose**: Provides AWS service documentation and best practices guidance
**Auto-approval**: Read-only operations for safe AWS CLI assistance

```json
{
  "mcpServers": {
    "aws-docs": {
      "command": "uvx",
      "args": ["awslabs.aws-documentation-mcp-server@latest"],
      "env": {
        "FASTMCP_LOG_LEVEL": "ERROR",
        "AWS_REGION": "us-east-1"
      },
      "disabled": false,
      "autoApprove": [
        "describe-*",
        "list-*",
        "get-*",
        "show-*"
      ]
    }
  }
}
```

### 2. Kubernetes Management Server

**Purpose**: Kubernetes cluster management and troubleshooting assistance
**Auto-approval**: Safe kubectl operations that don't modify cluster state

```json
{
  "mcpServers": {
    "kubernetes-mgmt": {
      "command": "uvx",
      "args": ["kubernetes-mcp-server@latest"],
      "env": {
        "KUBECONFIG": "~/.kube/config",
        "FASTMCP_LOG_LEVEL": "ERROR"
      },
      "disabled": false,
      "autoApprove": [
        "get",
        "describe",
        "logs",
        "top",
        "explain"
      ]
    }
  }
}
```

### 3. Prometheus Metrics Server

**Purpose**: Observability data access and monitoring system integration
**Auto-approval**: Query operations for metrics analysis

```json
{
  "mcpServers": {
    "prometheus-metrics": {
      "command": "uvx",
      "args": ["prometheus-mcp-server@latest"],
      "env": {
        "PROMETHEUS_URL": "http://localhost:9090",
        "FASTMCP_LOG_LEVEL": "ERROR"
      },
      "disabled": false,
      "autoApprove": [
        "query",
        "query_range",
        "series",
        "labels"
      ]
    }
  }
}
```

### 4. GitHub Actions Server

**Purpose**: CI/CD pipeline assistance and workflow automation
**Auto-approval**: Read operations for workflow analysis

```json
{
  "mcpServers": {
    "github-actions": {
      "command": "uvx",
      "args": ["github-actions-mcp-server@latest"],
      "env": {
        "GITHUB_TOKEN": "${GITHUB_TOKEN}",
        "FASTMCP_LOG_LEVEL": "ERROR"
      },
      "disabled": false,
      "autoApprove": [
        "list-*",
        "get-*",
        "describe-*"
      ]
    }
  }
}
```

## Complete Configuration Example

Here's the complete MCP configuration combining all servers:

```json
{
  "mcpServers": {
    "aws-docs": {
      "command": "uvx",
      "args": ["awslabs.aws-documentation-mcp-server@latest"],
      "env": {
        "FASTMCP_LOG_LEVEL": "ERROR",
        "AWS_REGION": "us-east-1"
      },
      "disabled": false,
      "autoApprove": [
        "describe-*",
        "list-*",
        "get-*",
        "show-*"
      ]
    },
    "kubernetes-mgmt": {
      "command": "uvx",
      "args": ["kubernetes-mcp-server@latest"],
      "env": {
        "KUBECONFIG": "~/.kube/config",
        "FASTMCP_LOG_LEVEL": "ERROR"
      },
      "disabled": false,
      "autoApprove": [
        "get",
        "describe",
        "logs",
        "top",
        "explain"
      ]
    },
    "prometheus-metrics": {
      "command": "uvx",
      "args": ["prometheus-mcp-server@latest"],
      "env": {
        "PROMETHEUS_URL": "http://localhost:9090",
        "FASTMCP_LOG_LEVEL": "ERROR"
      },
      "disabled": false,
      "autoApprove": [
        "query",
        "query_range",
        "series",
        "labels"
      ]
    },
    "github-actions": {
      "command": "uvx",
      "args": ["github-actions-mcp-server@latest"],
      "env": {
        "GITHUB_TOKEN": "${GITHUB_TOKEN}",
        "FASTMCP_LOG_LEVEL": "ERROR"
      },
      "disabled": false,
      "autoApprove": [
        "list-*",
        "get-*",
        "describe-*"
      ]
    }
  }
}
```

## Configuration Guidelines

### Security Best Practices

1. **Auto-approval Scope**: Only approve read-only operations that don't modify infrastructure
2. **Environment Variables**: Use environment variables for sensitive data like tokens
3. **Log Levels**: Set appropriate log levels to avoid verbose output
4. **Disabled Flag**: Use the disabled flag to temporarily disable servers during troubleshooting

### Platform-Specific Considerations

1. **AWS Integration**: Configure AWS region and credentials appropriately
2. **Kubernetes Access**: Ensure kubeconfig is properly configured for cluster access
3. **Monitoring Access**: Configure Prometheus URL based on port-forwarding or ingress setup
4. **GitHub Integration**: Requires GitHub token with appropriate repository permissions

### Testing and Validation

After configuring MCP servers, test each integration:

1. **AWS**: Test AWS service documentation queries
2. **Kubernetes**: Test cluster status and pod information queries
3. **Prometheus**: Test metrics queries and alerting guidance
4. **GitHub Actions**: Test workflow analysis and troubleshooting

## Troubleshooting

### Common Issues

1. **Server Connection Failures**: Check network connectivity and credentials
2. **Auto-approval Not Working**: Verify command patterns match exactly
3. **Environment Variables**: Ensure all required environment variables are set
4. **uvx Installation**: Ensure uv and uvx are installed and available in PATH

### Debugging Steps

1. Check MCP server logs for connection issues
2. Verify environment variables are properly set
3. Test individual MCP servers in isolation
4. Use Kiro's MCP Server view to monitor connection status

## Requirements Mapping

This configuration addresses the following requirements:

- **Requirement 9.1**: AWS integration for infrastructure management
- **Requirement 9.2**: Kubernetes integration for cluster operations
- **Requirement 9.3**: Monitoring system integration for observability
- **Requirement 9.4**: GitHub Actions integration for CI/CD assistance
- **Requirement 9.5**: Comprehensive external tool connectivity

## Next Steps

1. Apply the MCP configuration to `.kiro/settings/mcp.json`
2. Install required dependencies (uv, uvx)
3. Test each MCP server integration
4. Configure environment-specific settings
5. Set up monitoring for MCP server health