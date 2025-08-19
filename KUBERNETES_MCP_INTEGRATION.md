# Kubernetes MCP Integration for Kiro Infrastructure Platform Management

## Overview

This document provides comprehensive configuration and testing procedures for Kubernetes MCP integration, enabling Kiro to provide intelligent assistance with Kubernetes cluster management, troubleshooting, and operational tasks.

## Kubernetes MCP Server Configuration

### Basic Configuration

Add the following to your `.kiro/settings/mcp.json`:

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
        "explain",
        "api-resources",
        "api-versions"
      ]
    }
  }
}
```

### Multi-Environment Configuration

For managing multiple Kubernetes clusters (dev/staging/prod):

```json
{
  "mcpServers": {
    "kubernetes-mgmt": {
      "command": "uvx",
      "args": ["kubernetes-mcp-server@latest"],
      "env": {
        "KUBECONFIG": "~/.kube/config",
        "FASTMCP_LOG_LEVEL": "ERROR",
        "KUBECTL_CONTEXT": "eks-learning-lab-dev-cluster"
      },
      "disabled": false,
      "autoApprove": [
        "get",
        "describe",
        "logs",
        "top",
        "explain",
        "api-resources",
        "api-versions",
        "config",
        "cluster-info"
      ]
    }
  }
}
```

## Auto-Approved Operations

The following kubectl operations are automatically approved for safe, read-only cluster access:

### Resource Information
- `get pods`
- `get services`
- `get deployments`
- `get nodes`
- `get namespaces`
- `get configmaps`
- `get secrets` (metadata only)
- `get persistentvolumes`
- `get persistentvolumeclaims`

### Detailed Resource Description
- `describe pod`
- `describe service`
- `describe deployment`
- `describe node`
- `describe namespace`
- `describe ingress`
- `describe hpa`

### Logs and Monitoring
- `logs <pod-name>`
- `logs -f <pod-name>` (follow logs)
- `top nodes`
- `top pods`

### Cluster Information
- `cluster-info`
- `api-resources`
- `api-versions`
- `explain <resource>`
- `config view`
- `config get-contexts`

## Testing Kubernetes MCP Integration

### Prerequisites

1. **Install kubectl**:
   ```bash
   # Install kubectl
   curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/darwin/amd64/kubectl"
   chmod +x kubectl
   sudo mv kubectl /usr/local/bin/
   
   # Verify installation
   kubectl version --client
   ```

2. **Configure kubeconfig**:
   ```bash
   # Get EKS cluster credentials
   aws eks update-kubeconfig --region us-east-1 --name eks-learning-lab-dev-cluster
   
   # Verify cluster access
   kubectl cluster-info
   kubectl get nodes
   ```

3. **Install uv and uvx** (if not already installed):
   ```bash
   curl -LsSf https://astral.sh/uv/install.sh | sh
   uv --version
   uvx --version
   ```

### Test Scenarios

#### Test 1: Cluster Health Assessment
Ask Kiro to assess cluster health:

**Test Query**: "Can you check the health of my EKS cluster and identify any issues with nodes or pods?"

**Expected Behavior**:
- Query node status and resource usage
- Check system pods in kube-system namespace
- Identify unhealthy pods or resource constraints
- Provide troubleshooting recommendations

#### Test 2: Application Troubleshooting
Simulate application issues:

**Test Query**: "My microservices in the ecotrack namespace are having connectivity issues. Can you help me troubleshoot?"

**Expected Behavior**:
- Check pod status in ecotrack namespace
- Analyze service configurations
- Review network policies and ingress
- Provide step-by-step troubleshooting guide

#### Test 3: Resource Usage Analysis
Ask about resource optimization:

**Test Query**: "Analyze the resource usage of my Kubernetes cluster and suggest optimization opportunities."

**Expected Behavior**:
- Query node and pod resource usage
- Identify over/under-provisioned resources
- Suggest HPA and VPA configurations
- Recommend resource limit adjustments

#### Test 4: Observability Stack Health
Check observability components:

**Test Query**: "Check the health of my LGTM observability stack and help me troubleshoot any issues."

**Expected Behavior**:
- Check pods in observability namespace
- Verify Prometheus, Loki, Grafana, Tempo status
- Analyze resource usage and performance
- Provide configuration recommendations

### Validation Commands

Use these commands to verify Kubernetes MCP integration:

```bash
# 1. Verify kubectl access
kubectl cluster-info
kubectl get nodes
kubectl get namespaces

# 2. Check system components
kubectl get pods -n kube-system
kubectl get pods -n observability
kubectl get pods -n ambassador

# 3. Test resource queries
kubectl top nodes
kubectl top pods -A --sort-by=memory

# 4. Verify service connectivity
kubectl get services -A
kubectl get ingress -A

# 5. Check persistent storage
kubectl get pv
kubectl get pvc -A
```

## Kubernetes Service Integration Patterns

### EKS Cluster Management
```yaml
Cluster Operations:
  - Node health and capacity monitoring
  - Add-on status and configuration
  - Network connectivity troubleshooting
  - Resource quota and limit management
  
Kiro Assistance:
  - Automated health checks
  - Capacity planning recommendations
  - Performance optimization guidance
  - Security configuration review
```

### Application Lifecycle Management
```yaml
Deployment Operations:
  - Pod status and health monitoring
  - Service discovery and connectivity
  - ConfigMap and Secret management
  - Rolling update and rollback guidance
  
Troubleshooting Support:
  - Pod startup and crash analysis
  - Network connectivity issues
  - Resource constraint identification
  - Configuration validation
```

### Observability Integration
```yaml
Monitoring Operations:
  - Metrics collection verification
  - Log aggregation troubleshooting
  - Distributed tracing analysis
  - Alert configuration guidance
  
Performance Analysis:
  - Resource usage optimization
  - Scaling recommendations
  - Bottleneck identification
  - Cost optimization suggestions
```

### Security and Compliance
```yaml
Security Operations:
  - RBAC configuration review
  - Network policy validation
  - Secret management audit
  - Pod security standard compliance
  
Compliance Checks:
  - Resource limit enforcement
  - Security context validation
  - Image security scanning
  - Policy violation detection
```

## Advanced Kubernetes Operations

### Multi-Namespace Management
```yaml
Namespace Operations:
  - Cross-namespace communication
  - Resource quota management
  - Network policy configuration
  - Service mesh integration
  
Best Practices:
  - Namespace isolation strategies
  - Resource allocation patterns
  - Security boundary enforcement
  - Monitoring and alerting setup
```

### Storage Management
```yaml
Persistent Volume Operations:
  - PV/PVC status monitoring
  - Storage class optimization
  - Backup and recovery procedures
  - Performance troubleshooting
  
Database Integration:
  - PostgreSQL cluster management
  - Redis cluster monitoring
  - Data persistence strategies
  - Backup automation
```

### Service Mesh Integration
```yaml
Istio Operations:
  - Sidecar injection verification
  - Traffic management configuration
  - Security policy enforcement
  - Observability data collection
  
Troubleshooting:
  - mTLS connectivity issues
  - Traffic routing problems
  - Policy enforcement failures
  - Performance optimization
```

## Troubleshooting Kubernetes MCP Integration

### Common Issues

#### 1. kubeconfig Not Found
```bash
# Check kubeconfig location
echo $KUBECONFIG
ls -la ~/.kube/config

# Set kubeconfig explicitly
export KUBECONFIG=~/.kube/config

# Update EKS credentials
aws eks update-kubeconfig --region us-east-1 --name eks-learning-lab-dev-cluster
```

#### 2. Cluster Access Denied
```bash
# Verify AWS credentials
aws sts get-caller-identity

# Check IAM permissions for EKS
aws iam list-attached-user-policies --user-name your-username

# Test cluster access
kubectl auth can-i get pods --all-namespaces
```

#### 3. MCP Server Connection Issues
```bash
# Test uvx installation
uvx --version

# Test Kubernetes MCP server manually
uvx kubernetes-mcp-server@latest

# Check kubectl connectivity
kubectl cluster-info
kubectl get nodes
```

#### 4. Context Configuration Problems
```bash
# List available contexts
kubectl config get-contexts

# Switch to correct context
kubectl config use-context eks-learning-lab-dev-cluster

# Verify current context
kubectl config current-context
```

### Debug Commands

```bash
# 1. Cluster connectivity
kubectl cluster-info dump --output-directory=/tmp/cluster-info

# 2. Node diagnostics
kubectl describe nodes
kubectl get events --sort-by='.lastTimestamp'

# 3. Pod troubleshooting
kubectl get pods -A -o wide
kubectl describe pod <pod-name> -n <namespace>
kubectl logs <pod-name> -n <namespace> --previous

# 4. Service connectivity
kubectl get endpoints -A
kubectl get services -A -o wide

# 5. Resource usage
kubectl top nodes
kubectl top pods -A --sort-by=memory
```

## Security Considerations

### RBAC Configuration
The Kubernetes MCP integration requires appropriate RBAC permissions:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: kiro-mcp-reader
rules:
- apiGroups: [""]
  resources: ["*"]
  verbs: ["get", "list", "describe"]
- apiGroups: ["apps"]
  resources: ["*"]
  verbs: ["get", "list", "describe"]
- apiGroups: ["networking.k8s.io"]
  resources: ["*"]
  verbs: ["get", "list", "describe"]
- apiGroups: ["metrics.k8s.io"]
  resources: ["*"]
  verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: kiro-mcp-reader-binding
subjects:
- kind: User
  name: kiro-user
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: kiro-mcp-reader
  apiGroup: rbac.authorization.k8s.io
```

### Best Practices
1. **Read-Only Access**: Auto-approve only read operations
2. **Namespace Isolation**: Limit access to specific namespaces when possible
3. **Audit Logging**: Enable Kubernetes audit logging
4. **Context Switching**: Use appropriate contexts for different environments
5. **Secret Protection**: Never auto-approve secret content access

## Integration with Platform Components

### Foundation Platform (Workflow 1)
```yaml
EKS Cluster Management:
  - Node group health monitoring
  - Add-on status verification
  - CNI configuration troubleshooting
  - IAM role validation
```

### Ingress Stack (Workflow 2)
```yaml
Ambassador Integration:
  - Ingress controller health
  - Certificate management status
  - DNS configuration verification
  - Load balancer connectivity
```

### Observability Stack (Workflow 3)
```yaml
LGTM Stack Monitoring:
  - Prometheus target discovery
  - Loki log ingestion status
  - Grafana dashboard access
  - Tempo trace collection
```

### Microservices Platform
```yaml
EcoTrack Application Support:
  - Service health monitoring
  - Database connectivity checks
  - Inter-service communication
  - Performance optimization
```

## Requirements Compliance

This Kubernetes MCP integration addresses the following requirements:

- **Requirement 9.2**: Kubernetes integration for cluster operations
- **Requirement 2.2**: Kubernetes management assistance
- **Requirement 5.2**: Proactive monitoring and alerting support

## Next Steps

1. **Apply Configuration**: Add Kubernetes MCP server to `.kiro/settings/mcp.json`
2. **Configure kubectl**: Ensure proper kubeconfig setup
3. **Test Integration**: Run through all test scenarios
4. **Set Up RBAC**: Configure appropriate cluster permissions
5. **Monitor Performance**: Track MCP server health and response times
6. **Document Procedures**: Create runbooks for common operations