# Monitoring MCP Integration for Kiro Infrastructure Platform Management

## Overview

This document provides comprehensive configuration and testing procedures for monitoring system MCP integration, enabling Kiro to provide intelligent assistance with observability data analysis, alerting, and performance optimization using the LGTM stack (Loki, Grafana, Tempo, Mimir/Prometheus).

## Monitoring MCP Server Configuration

### Prometheus Metrics Server Configuration

Add the following to your `.kiro/settings/mcp.json`:

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
        "labels",
        "label_values",
        "targets",
        "rules",
        "alerts"
      ]
    }
  }
}
```

### Multi-Component Monitoring Configuration

For comprehensive LGTM stack integration:

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
        "labels",
        "label_values",
        "targets",
        "rules",
        "alerts"
      ]
    },
    "loki-logs": {
      "command": "uvx",
      "args": ["loki-mcp-server@latest"],
      "env": {
        "LOKI_URL": "http://localhost:3100",
        "FASTMCP_LOG_LEVEL": "ERROR"
      },
      "disabled": false,
      "autoApprove": [
        "query",
        "query_range",
        "labels",
        "label_values",
        "series"
      ]
    },
    "grafana-dashboards": {
      "command": "uvx",
      "args": ["grafana-mcp-server@latest"],
      "env": {
        "GRAFANA_URL": "http://localhost:3000",
        "GRAFANA_API_KEY": "${GRAFANA_API_KEY}",
        "FASTMCP_LOG_LEVEL": "ERROR"
      },
      "disabled": false,
      "autoApprove": [
        "get-*",
        "list-*",
        "search-*"
      ]
    }
  }
}
```

## Auto-Approved Operations

The following monitoring operations are automatically approved for safe, read-only access:

### Prometheus Operations
- `query` - Execute PromQL queries
- `query_range` - Execute range queries
- `series` - Get time series metadata
- `labels` - Get available labels
- `label_values` - Get label values
- `targets` - Get scrape targets
- `rules` - Get recording/alerting rules
- `alerts` - Get active alerts

### Loki Operations
- `query` - Execute LogQL queries
- `query_range` - Execute log range queries
- `labels` - Get available log labels
- `label_values` - Get log label values
- `series` - Get log series metadata

### Grafana Operations
- `get-dashboard` - Retrieve dashboard configurations
- `list-dashboards` - List available dashboards
- `search-dashboards` - Search dashboards
- `get-datasource` - Get data source configurations
- `list-datasources` - List data sources

## Testing Monitoring MCP Integration

### Prerequisites

1. **Set up port forwarding for observability stack**:
   ```bash
   # Prometheus
   kubectl port-forward -n observability svc/prometheus-server 9090:80 &
   
   # Loki
   kubectl port-forward -n observability svc/loki-query-frontend 3100:3100 &
   
   # Grafana
   kubectl port-forward -n observability svc/grafana 3000:80 &
   
   # Tempo (optional)
   kubectl port-forward -n observability svc/tempo-query-frontend 3200:3200 &
   ```

2. **Verify observability stack access**:
   ```bash
   # Test Prometheus
   curl -s http://localhost:9090/api/v1/query?query=up | jq .
   
   # Test Loki
   curl -s http://localhost:3100/ready
   
   # Test Grafana
   curl -s http://localhost:3000/api/health
   ```

3. **Get Grafana credentials**:
   ```bash
   # Get admin password
   kubectl get secret -n observability grafana-credentials -o jsonpath='{.data.admin-password}' | base64 -d
   ```

### Test Scenarios

#### Test 1: Infrastructure Metrics Analysis
Ask Kiro to analyze infrastructure performance:

**Test Query**: "Analyze the CPU and memory usage of my EKS cluster nodes and identify any performance bottlenecks."

**Expected Behavior**:
- Query node CPU and memory metrics
- Analyze resource utilization trends
- Identify nodes with high resource usage
- Provide optimization recommendations

**Sample Metrics to Query**:
```promql
# Node CPU usage
100 - (avg by (instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Node memory usage
(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100

# Pod CPU usage
rate(container_cpu_usage_seconds_total[5m]) * 100

# Pod memory usage
container_memory_working_set_bytes / container_spec_memory_limit_bytes * 100
```

#### Test 2: Application Performance Monitoring
Ask about microservices performance:

**Test Query**: "Check the performance of my EcoTrack microservices and identify any services with high error rates or slow response times."

**Expected Behavior**:
- Query HTTP request metrics for each service
- Analyze error rates and response times
- Identify performance bottlenecks
- Suggest optimization strategies

**Sample Metrics to Query**:
```promql
# HTTP request rate
rate(http_requests_total[5m])

# HTTP error rate
rate(http_requests_total{status=~"5.."}[5m]) / rate(http_requests_total[5m])

# HTTP response time
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))

# JVM memory usage
jvm_memory_used_bytes / jvm_memory_max_bytes * 100
```

#### Test 3: Log Analysis and Troubleshooting
Ask Kiro to analyze application logs:

**Test Query**: "Analyze the logs from my user-service for the last hour and identify any errors or unusual patterns."

**Expected Behavior**:
- Query Loki for user-service logs
- Filter for error-level logs
- Identify patterns and anomalies
- Provide troubleshooting guidance

**Sample LogQL Queries**:
```logql
# Error logs from user-service
{namespace="ecotrack", app="user-service"} |= "ERROR"

# Database connection errors
{namespace="ecotrack"} |= "database" |= "connection" |= "error"

# High response time logs
{namespace="ecotrack"} | json | duration > 2s
```

#### Test 4: Alert Analysis and Incident Response
Ask about active alerts:

**Test Query**: "Show me all active alerts in my cluster and help me prioritize which ones need immediate attention."

**Expected Behavior**:
- Query Prometheus for active alerts
- Categorize alerts by severity
- Provide context for each alert
- Suggest remediation steps

### Validation Commands

Use these commands to verify monitoring MCP integration:

```bash
# 1. Test Prometheus connectivity
curl -s http://localhost:9090/api/v1/query?query=up | jq '.data.result | length'

# 2. Verify metrics collection
curl -s "http://localhost:9090/api/v1/query?query=kubernetes_build_info" | jq .

# 3. Test Loki connectivity
curl -s "http://localhost:3100/loki/api/v1/query?query={namespace=\"ecotrack\"}" | jq .

# 4. Check Grafana API
curl -s -H "Authorization: Bearer $GRAFANA_API_KEY" http://localhost:3000/api/dashboards/home | jq .

# 5. Verify alert rules
curl -s http://localhost:9090/api/v1/rules | jq '.data.groups[].rules[] | select(.type=="alerting")'
```

## Monitoring Integration Patterns

### Infrastructure Monitoring
```yaml
Key Metrics:
  - Node resource utilization (CPU, memory, disk)
  - Pod resource consumption and limits
  - Network traffic and connectivity
  - Storage usage and performance
  
Alerting Rules:
  - High CPU usage (>80% for 5 minutes)
  - High memory usage (>85% for 5 minutes)
  - Disk space low (<10% free)
  - Pod restart frequency (>5 restarts/hour)
  
Kiro Assistance:
  - Automated metric analysis
  - Trend identification and forecasting
  - Capacity planning recommendations
  - Performance optimization guidance
```

### Application Performance Monitoring
```yaml
Microservices Metrics:
  - HTTP request rate and latency
  - Error rates and status codes
  - Database connection pool usage
  - JVM memory and garbage collection
  
Business Metrics:
  - User registration rate
  - Order processing time
  - Payment success rate
  - Notification delivery rate
  
Observability:
  - Distributed tracing analysis
  - Log correlation and analysis
  - Custom business metric tracking
  - SLA/SLO monitoring
```

### Cost and Resource Optimization
```yaml
Cost Metrics:
  - Resource usage vs allocation
  - Spot instance interruption rate
  - Storage usage and lifecycle
  - Network data transfer costs
  
Optimization Opportunities:
  - Right-sizing recommendations
  - Unused resource identification
  - Scaling pattern analysis
  - Cost anomaly detection
```

## Advanced Monitoring Queries

### Infrastructure Health Queries
```promql
# Cluster resource utilization
(
  sum(rate(container_cpu_usage_seconds_total{container!="POD",container!=""}[5m])) by (node) /
  sum(machine_cpu_cores) by (node)
) * 100

# Memory pressure
(
  sum(container_memory_working_set_bytes{container!="POD",container!=""}) by (node) /
  sum(machine_memory_bytes) by (node)
) * 100

# Pod restart rate
increase(kube_pod_container_status_restarts_total[1h])

# Persistent volume usage
(
  kubelet_volume_stats_used_bytes /
  kubelet_volume_stats_capacity_bytes
) * 100
```

### Application Performance Queries
```promql
# Service error rate
(
  sum(rate(http_requests_total{status=~"5.."}[5m])) by (service) /
  sum(rate(http_requests_total[5m])) by (service)
) * 100

# 95th percentile response time
histogram_quantile(0.95,
  sum(rate(http_request_duration_seconds_bucket[5m])) by (service, le)
)

# Database connection pool utilization
(
  hikaricp_connections_active /
  hikaricp_connections_max
) * 100

# JVM heap usage
(
  jvm_memory_used_bytes{area="heap"} /
  jvm_memory_max_bytes{area="heap"}
) * 100
```

### Log Analysis Queries
```logql
# Error rate by service
sum by (app) (rate({namespace="ecotrack"} |= "ERROR" [5m]))

# Database errors
{namespace="ecotrack"} |= "database" |= "error" | json | line_format "{{.timestamp}} {{.level}} {{.message}}"

# Slow queries
{namespace="ecotrack"} | json | duration > 1s | line_format "{{.app}} - {{.duration}} - {{.query}}"

# Authentication failures
{namespace="ecotrack"} |= "authentication" |= "failed" | json | line_format "{{.timestamp}} {{.user}} {{.ip}}"
```

## Troubleshooting Monitoring MCP Integration

### Common Issues

#### 1. Port Forwarding Connection Issues
```bash
# Check if port forwarding is active
ps aux | grep "kubectl port-forward"

# Kill existing port forwards
pkill -f "kubectl port-forward"

# Restart port forwarding
kubectl port-forward -n observability svc/prometheus-server 9090:80 &
kubectl port-forward -n observability svc/loki-query-frontend 3100:3100 &
kubectl port-forward -n observability svc/grafana 3000:80 &
```

#### 2. Prometheus Query Failures
```bash
# Test Prometheus connectivity
curl -s http://localhost:9090/-/healthy

# Check Prometheus targets
curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | select(.health != "up")'

# Verify metrics availability
curl -s "http://localhost:9090/api/v1/label/__name__/values" | jq '.data | length'
```

#### 3. Loki Query Issues
```bash
# Test Loki readiness
curl -s http://localhost:3100/ready

# Check Loki metrics
curl -s http://localhost:3100/metrics | grep loki_ingester

# Test log query
curl -s "http://localhost:3100/loki/api/v1/query?query={namespace=\"observability\"}" | jq .
```

#### 4. Grafana API Access
```bash
# Test Grafana health
curl -s http://localhost:3000/api/health

# Get API key (if needed)
kubectl get secret -n observability grafana-api-key -o jsonpath='{.data.key}' | base64 -d

# Test API access
curl -s -H "Authorization: Bearer $GRAFANA_API_KEY" http://localhost:3000/api/org | jq .
```

### Debug Commands

```bash
# 1. Check observability pod status
kubectl get pods -n observability
kubectl describe pod -n observability -l app=prometheus-server

# 2. Verify service endpoints
kubectl get endpoints -n observability
kubectl get services -n observability

# 3. Check ingress configuration
kubectl get ingress -n observability
kubectl describe ingress -n observability

# 4. Analyze resource usage
kubectl top pods -n observability
kubectl describe node | grep -A 5 "Allocated resources"

# 5. Check persistent volumes
kubectl get pv | grep observability
kubectl get pvc -n observability
```

## Security Considerations

### API Access Control
```yaml
Prometheus Security:
  - Read-only query access
  - No admin API access
  - Rate limiting on queries
  - Network policy restrictions
  
Loki Security:
  - Query-only access
  - No write operations
  - Log data encryption
  - Access logging enabled
  
Grafana Security:
  - API key with viewer permissions
  - Dashboard read-only access
  - No admin operations
  - Session timeout configured
```

### Best Practices
1. **Read-Only Access**: Auto-approve only query operations
2. **Rate Limiting**: Implement query rate limits to prevent abuse
3. **Network Security**: Use network policies to restrict access
4. **Audit Logging**: Enable audit logs for all monitoring access
5. **Data Retention**: Configure appropriate data retention policies

## Integration with Platform Components

### Foundation Platform Monitoring
```yaml
EKS Cluster Metrics:
  - Node health and capacity
  - Control plane metrics
  - Add-on performance
  - Network connectivity
```

### Ingress Stack Monitoring
```yaml
Ambassador Metrics:
  - Request rate and latency
  - SSL certificate status
  - Load balancer health
  - DNS resolution metrics
```

### Microservices Monitoring
```yaml
EcoTrack Application Metrics:
  - Service health and performance
  - Database connectivity
  - Inter-service communication
  - Business KPIs
```

## Requirements Compliance

This monitoring MCP integration addresses the following requirements:

- **Requirement 9.3**: Monitoring system integration for observability
- **Requirement 5.1**: Proactive monitoring and alerting
- **Requirement 5.2**: Performance optimization guidance
- **Requirement 5.4**: Capacity planning and resource analysis

## Next Steps

1. **Apply Configuration**: Add monitoring MCP servers to `.kiro/settings/mcp.json`
2. **Set Up Port Forwarding**: Configure access to observability stack
3. **Test Integration**: Run through all test scenarios
4. **Configure Alerts**: Set up monitoring for MCP server health
5. **Create Dashboards**: Build Grafana dashboards for MCP metrics
6. **Document Procedures**: Create runbooks for monitoring operations