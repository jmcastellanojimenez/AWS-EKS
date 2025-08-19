# MCP Integration Testing Procedures

## Overview

This document provides comprehensive testing procedures for Model Context Protocol (MCP) integrations within the Kiro Infrastructure Platform Management system. It covers testing methodologies for external tool connectivity, auto-approval configurations, safety controls, and cross-system integration scenarios.

## MCP Integration Architecture Testing

### Integration Components

```yaml
MCP Server Integrations:
  AWS Integration:
    server: awslabs.aws-documentation-mcp-server
    capabilities: AWS service documentation and guidance
    auto_approval: describe-*, list-*, get-* operations
    
  Kubernetes Integration:
    server: kubernetes-mcp-server
    capabilities: Kubernetes cluster management
    auto_approval: get, describe, logs operations
    
  Monitoring Integration:
    server: prometheus-mcp-server
    capabilities: Metrics querying and analysis
    auto_approval: query, query_range operations
    
  GitHub Actions Integration:
    server: github-actions-mcp-server
    capabilities: CI/CD pipeline assistance
    auto_approval: workflow status queries
```

## External Tool Connectivity Testing

### AWS MCP Integration Testing

#### Test Script 1: AWS Service Documentation Access
```bash
#!/bin/bash
# AWS MCP Integration Connectivity Test

echo "=== AWS MCP Integration Testing ==="

# Test 1: Basic connectivity
echo "Testing AWS MCP server connectivity..."
curl -X POST http://localhost:3000/mcp/aws/health \
  -H "Content-Type: application/json" \
  -d '{"method": "ping"}' || echo "FAIL: AWS MCP server not responding"

# Test 2: Service documentation retrieval
echo "Testing AWS service documentation access..."
curl -X POST http://localhost:3000/mcp/aws/docs \
  -H "Content-Type: application/json" \
  -d '{
    "method": "get_documentation",
    "params": {
      "service": "eks",
      "operation": "describe-cluster"
    }
  }' | jq '.result' || echo "FAIL: AWS documentation not accessible"

# Test 3: Auto-approval validation
echo "Testing auto-approved operations..."
APPROVED_OPS=("describe-cluster" "list-clusters" "get-cluster-status")
for op in "${APPROVED_OPS[@]}"; do
  echo "Testing auto-approval for: $op"
  curl -X POST http://localhost:3000/mcp/aws/execute \
    -H "Content-Type: application/json" \
    -d "{
      \"method\": \"execute_operation\",
      \"params\": {
        \"operation\": \"$op\",
        \"auto_approve\": true
      }
    }" | jq '.approved' || echo "FAIL: Auto-approval not working for $op"
done

# Test 4: Restricted operation validation
echo "Testing restricted operations..."
RESTRICTED_OPS=("delete-cluster" "create-cluster" "modify-cluster")
for op in "${RESTRICTED_OPS[@]}"; do
  echo "Testing restriction for: $op"
  response=$(curl -s -X POST http://localhost:3000/mcp/aws/execute \
    -H "Content-Type: application/json" \
    -d "{
      \"method\": \"execute_operation\",
      \"params\": {
        \"operation\": \"$op\",
        \"auto_approve\": true
      }
    }")
  
  if echo "$response" | jq -e '.approved == false' > /dev/null; then
    echo "PASS: $op correctly restricted"
  else
    echo "FAIL: $op should be restricted but was approved"
  fi
done

echo "AWS MCP integration testing complete."
```

#### Test Script 2: AWS CLI Assistance Validation
```python
#!/usr/bin/env python3
"""
AWS MCP Integration Functional Testing
Tests AWS CLI assistance and service operation guidance
"""

import json
import requests
import subprocess
from typing import Dict, List, Any

class AWSMCPTester:
    def __init__(self, mcp_endpoint: str = "http://localhost:3000/mcp/aws"):
        self.endpoint = mcp_endpoint
        self.test_results = []
    
    def test_aws_cli_assistance(self) -> Dict[str, Any]:
        """Test AWS CLI command assistance"""
        test_cases = [
            {
                "query": "How do I describe an EKS cluster?",
                "expected_command": "aws eks describe-cluster",
                "expected_params": ["--name", "--region"]
            },
            {
                "query": "List all EKS clusters in us-east-1",
                "expected_command": "aws eks list-clusters",
                "expected_params": ["--region us-east-1"]
            },
            {
                "query": "Get EKS cluster status",
                "expected_command": "aws eks describe-cluster",
                "expected_params": ["--name", "--region"]
            }
        ]
        
        results = []
        for test_case in test_cases:
            response = self.query_mcp_server({
                "method": "get_cli_assistance",
                "params": {"query": test_case["query"]}
            })
            
            # Validate response contains expected command
            command_found = test_case["expected_command"] in response.get("command", "")
            params_found = all(
                param in response.get("command", "") 
                for param in test_case["expected_params"]
            )
            
            result = {
                "test_case": test_case["query"],
                "command_found": command_found,
                "params_found": params_found,
                "response": response,
                "passed": command_found and params_found
            }
            results.append(result)
        
        return {"test_type": "aws_cli_assistance", "results": results}
    
    def test_service_operation_guidance(self) -> Dict[str, Any]:
        """Test AWS service operation guidance"""
        test_cases = [
            {
                "service": "eks",
                "operation": "cluster_management",
                "expected_guidance": ["create-cluster", "describe-cluster", "update-cluster"]
            },
            {
                "service": "ec2",
                "operation": "instance_management",
                "expected_guidance": ["describe-instances", "start-instances", "stop-instances"]
            },
            {
                "service": "s3",
                "operation": "bucket_management",
                "expected_guidance": ["list-buckets", "create-bucket", "put-object"]
            }
        ]
        
        results = []
        for test_case in test_cases:
            response = self.query_mcp_server({
                "method": "get_service_guidance",
                "params": {
                    "service": test_case["service"],
                    "operation": test_case["operation"]
                }
            })
            
            # Validate guidance contains expected operations
            guidance_complete = all(
                op in response.get("guidance", "")
                for op in test_case["expected_guidance"]
            )
            
            result = {
                "test_case": f"{test_case['service']}-{test_case['operation']}",
                "guidance_complete": guidance_complete,
                "response": response,
                "passed": guidance_complete
            }
            results.append(result)
        
        return {"test_type": "service_operation_guidance", "results": results}
    
    def query_mcp_server(self, payload: Dict[str, Any]) -> Dict[str, Any]:
        """Query MCP server with payload"""
        try:
            response = requests.post(
                self.endpoint,
                json=payload,
                headers={"Content-Type": "application/json"},
                timeout=30
            )
            return response.json()
        except Exception as e:
            return {"error": str(e)}
    
    def run_all_tests(self) -> Dict[str, Any]:
        """Run all AWS MCP integration tests"""
        return {
            "aws_mcp_tests": [
                self.test_aws_cli_assistance(),
                self.test_service_operation_guidance()
            ]
        }

if __name__ == "__main__":
    tester = AWSMCPTester()
    results = tester.run_all_tests()
    
    with open("aws-mcp-test-results.json", "w") as f:
        json.dump(results, f, indent=2)
    
    print("AWS MCP integration testing complete.")
```

### Kubernetes MCP Integration Testing

#### Test Script 3: Kubernetes Management Validation
```bash
#!/bin/bash
# Kubernetes MCP Integration Testing

echo "=== Kubernetes MCP Integration Testing ==="

# Test 1: Basic connectivity
echo "Testing Kubernetes MCP server connectivity..."
curl -X POST http://localhost:3000/mcp/kubernetes/health \
  -H "Content-Type: application/json" \
  -d '{"method": "ping"}' || echo "FAIL: Kubernetes MCP server not responding"

# Test 2: Cluster information retrieval
echo "Testing cluster information access..."
curl -X POST http://localhost:3000/mcp/kubernetes/cluster \
  -H "Content-Type: application/json" \
  -d '{
    "method": "get_cluster_info",
    "params": {}
  }' | jq '.result.cluster_name' || echo "FAIL: Cluster info not accessible"

# Test 3: Auto-approved operations
echo "Testing auto-approved kubectl operations..."
APPROVED_OPS=("get pods" "describe nodes" "logs")
for op in "${APPROVED_OPS[@]}"; do
  echo "Testing auto-approval for: kubectl $op"
  curl -X POST http://localhost:3000/mcp/kubernetes/execute \
    -H "Content-Type: application/json" \
    -d "{
      \"method\": \"execute_kubectl\",
      \"params\": {
        \"command\": \"$op\",
        \"auto_approve\": true
      }
    }" | jq '.approved' || echo "FAIL: Auto-approval not working for kubectl $op"
done

# Test 4: Restricted operations
echo "Testing restricted kubectl operations..."
RESTRICTED_OPS=("delete pod" "apply -f" "create deployment")
for op in "${RESTRICTED_OPS[@]}"; do
  echo "Testing restriction for: kubectl $op"
  response=$(curl -s -X POST http://localhost:3000/mcp/kubernetes/execute \
    -H "Content-Type: application/json" \
    -d "{
      \"method\": \"execute_kubectl\",
      \"params\": {
        \"command\": \"$op\",
        \"auto_approve\": true
      }
    }")
  
  if echo "$response" | jq -e '.approved == false' > /dev/null; then
    echo "PASS: kubectl $op correctly restricted"
  else
    echo "FAIL: kubectl $op should be restricted but was approved"
  fi
done

# Test 5: Troubleshooting guidance
echo "Testing Kubernetes troubleshooting guidance..."
curl -X POST http://localhost:3000/mcp/kubernetes/troubleshoot \
  -H "Content-Type: application/json" \
  -d '{
    "method": "get_troubleshooting_guidance",
    "params": {
      "issue": "pod_not_starting",
      "namespace": "ecotrack"
    }
  }' | jq '.guidance' || echo "FAIL: Troubleshooting guidance not available"

echo "Kubernetes MCP integration testing complete."
```

### Monitoring MCP Integration Testing

#### Test Script 4: Prometheus Metrics Integration
```python
#!/usr/bin/env python3
"""
Monitoring MCP Integration Testing
Tests Prometheus metrics server integration
"""

import json
import requests
import time
from typing import Dict, List, Any

class MonitoringMCPTester:
    def __init__(self, mcp_endpoint: str = "http://localhost:3000/mcp/monitoring"):
        self.endpoint = mcp_endpoint
        self.test_results = []
    
    def test_prometheus_connectivity(self) -> Dict[str, Any]:
        """Test Prometheus server connectivity"""
        response = self.query_mcp_server({
            "method": "check_prometheus_health",
            "params": {}
        })
        
        return {
            "test_type": "prometheus_connectivity",
            "healthy": response.get("status") == "healthy",
            "response": response
        }
    
    def test_metrics_querying(self) -> Dict[str, Any]:
        """Test metrics querying capabilities"""
        test_queries = [
            {
                "name": "cpu_usage",
                "query": "rate(cpu_usage_seconds_total[5m])",
                "expected_metric": "cpu_usage_seconds_total"
            },
            {
                "name": "memory_usage",
                "query": "container_memory_usage_bytes",
                "expected_metric": "container_memory_usage_bytes"
            },
            {
                "name": "http_requests",
                "query": "rate(http_requests_total[5m])",
                "expected_metric": "http_requests_total"
            }
        ]
        
        results = []
        for test_query in test_queries:
            response = self.query_mcp_server({
                "method": "query_metrics",
                "params": {
                    "query": test_query["query"],
                    "auto_approve": True
                }
            })
            
            # Check if query was executed and returned data
            has_data = "data" in response and len(response.get("data", [])) > 0
            correct_metric = test_query["expected_metric"] in str(response)
            
            result = {
                "query_name": test_query["name"],
                "query": test_query["query"],
                "has_data": has_data,
                "correct_metric": correct_metric,
                "response": response,
                "passed": has_data and correct_metric
            }
            results.append(result)
        
        return {"test_type": "metrics_querying", "results": results}
    
    def test_alerting_integration(self) -> Dict[str, Any]:
        """Test alerting system integration"""
        response = self.query_mcp_server({
            "method": "get_active_alerts",
            "params": {"auto_approve": True}
        })
        
        # Validate alert structure
        alerts_valid = isinstance(response.get("alerts", []), list)
        
        return {
            "test_type": "alerting_integration",
            "alerts_accessible": alerts_valid,
            "alert_count": len(response.get("alerts", [])),
            "response": response
        }
    
    def test_dashboard_integration(self) -> Dict[str, Any]:
        """Test Grafana dashboard integration"""
        response = self.query_mcp_server({
            "method": "get_dashboard_list",
            "params": {"auto_approve": True}
        })
        
        # Check for expected dashboards
        expected_dashboards = [
            "Kubernetes Cluster Overview",
            "EcoTrack Application Metrics",
            "Infrastructure Monitoring"
        ]
        
        dashboards = response.get("dashboards", [])
        dashboard_names = [d.get("title", "") for d in dashboards]
        
        found_dashboards = [
            name for name in expected_dashboards 
            if any(name in dashboard_name for dashboard_name in dashboard_names)
        ]
        
        return {
            "test_type": "dashboard_integration",
            "expected_dashboards": len(expected_dashboards),
            "found_dashboards": len(found_dashboards),
            "coverage": len(found_dashboards) / len(expected_dashboards),
            "response": response
        }
    
    def query_mcp_server(self, payload: Dict[str, Any]) -> Dict[str, Any]:
        """Query MCP server with payload"""
        try:
            response = requests.post(
                self.endpoint,
                json=payload,
                headers={"Content-Type": "application/json"},
                timeout=30
            )
            return response.json()
        except Exception as e:
            return {"error": str(e)}
    
    def run_all_tests(self) -> Dict[str, Any]:
        """Run all monitoring MCP integration tests"""
        return {
            "monitoring_mcp_tests": [
                self.test_prometheus_connectivity(),
                self.test_metrics_querying(),
                self.test_alerting_integration(),
                self.test_dashboard_integration()
            ]
        }

if __name__ == "__main__":
    tester = MonitoringMCPTester()
    results = tester.run_all_tests()
    
    with open("monitoring-mcp-test-results.json", "w") as f:
        json.dump(results, f, indent=2)
    
    print("Monitoring MCP integration testing complete.")
```

## Auto-Approval Configuration Testing

### Safety Control Validation

#### Test Script 5: Auto-Approval Boundary Testing
```bash
#!/bin/bash
# Auto-Approval Configuration Testing

echo "=== Auto-Approval Configuration Testing ==="

# Test 1: Read-only operations auto-approval
echo "Testing read-only operations auto-approval..."
READONLY_OPS=(
  "aws eks describe-cluster"
  "kubectl get pods"
  "prometheus query"
  "grafana dashboard list"
)

for op in "${READONLY_OPS[@]}"; do
  echo "Testing auto-approval for: $op"
  # Simulate MCP call with auto-approval
  response=$(curl -s -X POST http://localhost:3000/mcp/test \
    -H "Content-Type: application/json" \
    -d "{
      \"method\": \"test_auto_approval\",
      \"params\": {
        \"operation\": \"$op\",
        \"type\": \"readonly\"
      }
    }")
  
  if echo "$response" | jq -e '.auto_approved == true' > /dev/null; then
    echo "PASS: $op auto-approved correctly"
  else
    echo "FAIL: $op should be auto-approved"
  fi
done

# Test 2: Write operations require approval
echo "Testing write operations require manual approval..."
WRITE_OPS=(
  "aws eks create-cluster"
  "kubectl apply -f deployment.yaml"
  "terraform apply"
  "helm install"
)

for op in "${WRITE_OPS[@]}"; do
  echo "Testing manual approval requirement for: $op"
  response=$(curl -s -X POST http://localhost:3000/mcp/test \
    -H "Content-Type: application/json" \
    -d "{
      \"method\": \"test_auto_approval\",
      \"params\": {
        \"operation\": \"$op\",
        \"type\": \"write\"
      }
    }")
  
  if echo "$response" | jq -e '.auto_approved == false' > /dev/null; then
    echo "PASS: $op correctly requires manual approval"
  else
    echo "FAIL: $op should require manual approval"
  fi
done

# Test 3: Dangerous operations blocked
echo "Testing dangerous operations are blocked..."
DANGEROUS_OPS=(
  "aws eks delete-cluster"
  "kubectl delete namespace"
  "rm -rf /"
  "terraform destroy"
)

for op in "${DANGEROUS_OPS[@]}"; do
  echo "Testing blocking for: $op"
  response=$(curl -s -X POST http://localhost:3000/mcp/test \
    -H "Content-Type: application/json" \
    -d "{
      \"method\": \"test_auto_approval\",
      \"params\": {
        \"operation\": \"$op\",
        \"type\": \"dangerous\"
      }
    }")
  
  if echo "$response" | jq -e '.blocked == true' > /dev/null; then
    echo "PASS: $op correctly blocked"
  else
    echo "FAIL: $op should be blocked"
  fi
done

echo "Auto-approval configuration testing complete."
```

### Safety Control Integration Testing

#### Test Script 6: Safety Control Validation
```python
#!/usr/bin/env python3
"""
Safety Control Integration Testing
Tests safety controls and escalation procedures
"""

import json
import requests
import time
from typing import Dict, List, Any

class SafetyControlTester:
    def __init__(self, mcp_endpoint: str = "http://localhost:3000/mcp"):
        self.endpoint = mcp_endpoint
        self.test_results = []
    
    def test_rate_limiting(self) -> Dict[str, Any]:
        """Test rate limiting for MCP operations"""
        # Send rapid requests to test rate limiting
        start_time = time.time()
        responses = []
        
        for i in range(20):  # Send 20 rapid requests
            response = self.query_mcp_server({
                "method": "test_operation",
                "params": {"operation_id": i}
            })
            responses.append(response)
            time.sleep(0.1)  # 100ms between requests
        
        # Check for rate limiting responses
        rate_limited = sum(1 for r in responses if r.get("rate_limited", False))
        
        return {
            "test_type": "rate_limiting",
            "total_requests": len(responses),
            "rate_limited_requests": rate_limited,
            "rate_limiting_active": rate_limited > 0,
            "test_duration": time.time() - start_time
        }
    
    def test_resource_limits(self) -> Dict[str, Any]:
        """Test resource limit enforcement"""
        test_cases = [
            {
                "operation": "scale_deployment",
                "params": {"replicas": 100},  # Excessive scaling
                "should_block": True
            },
            {
                "operation": "allocate_storage",
                "params": {"size": "10TB"},  # Excessive storage
                "should_block": True
            },
            {
                "operation": "scale_deployment",
                "params": {"replicas": 5},  # Reasonable scaling
                "should_block": False
            }
        ]
        
        results = []
        for test_case in test_cases:
            response = self.query_mcp_server({
                "method": "test_resource_limits",
                "params": test_case["params"]
            })
            
            blocked = response.get("blocked", False)
            correct_behavior = blocked == test_case["should_block"]
            
            result = {
                "operation": test_case["operation"],
                "params": test_case["params"],
                "should_block": test_case["should_block"],
                "was_blocked": blocked,
                "correct_behavior": correct_behavior
            }
            results.append(result)
        
        return {"test_type": "resource_limits", "results": results}
    
    def test_escalation_triggers(self) -> Dict[str, Any]:
        """Test escalation trigger mechanisms"""
        escalation_scenarios = [
            {
                "scenario": "high_error_rate",
                "params": {"error_rate": 0.15},  # 15% error rate
                "should_escalate": True
            },
            {
                "scenario": "resource_exhaustion",
                "params": {"cpu_usage": 0.95},  # 95% CPU usage
                "should_escalate": True
            },
            {
                "scenario": "normal_operation",
                "params": {"error_rate": 0.01, "cpu_usage": 0.60},
                "should_escalate": False
            }
        ]
        
        results = []
        for scenario in escalation_scenarios:
            response = self.query_mcp_server({
                "method": "test_escalation",
                "params": scenario["params"]
            })
            
            escalated = response.get("escalated", False)
            correct_escalation = escalated == scenario["should_escalate"]
            
            result = {
                "scenario": scenario["scenario"],
                "params": scenario["params"],
                "should_escalate": scenario["should_escalate"],
                "was_escalated": escalated,
                "correct_escalation": correct_escalation
            }
            results.append(result)
        
        return {"test_type": "escalation_triggers", "results": results}
    
    def query_mcp_server(self, payload: Dict[str, Any]) -> Dict[str, Any]:
        """Query MCP server with payload"""
        try:
            response = requests.post(
                f"{self.endpoint}/safety",
                json=payload,
                headers={"Content-Type": "application/json"},
                timeout=30
            )
            return response.json()
        except Exception as e:
            return {"error": str(e)}
    
    def run_all_tests(self) -> Dict[str, Any]:
        """Run all safety control tests"""
        return {
            "safety_control_tests": [
                self.test_rate_limiting(),
                self.test_resource_limits(),
                self.test_escalation_triggers()
            ]
        }

if __name__ == "__main__":
    tester = SafetyControlTester()
    results = tester.run_all_tests()
    
    with open("safety-control-test-results.json", "w") as f:
        json.dump(results, f, indent=2)
    
    print("Safety control testing complete.")
```

## Cross-System Integration Testing

### End-to-End Integration Scenarios

#### Test Script 7: Complete Workflow Integration
```python
#!/usr/bin/env python3
"""
Cross-System Integration Testing
Tests complete workflows across all MCP integrations
"""

import json
import requests
import time
from typing import Dict, List, Any

class CrossSystemIntegrationTester:
    def __init__(self):
        self.endpoints = {
            "aws": "http://localhost:3000/mcp/aws",
            "kubernetes": "http://localhost:3000/mcp/kubernetes",
            "monitoring": "http://localhost:3000/mcp/monitoring",
            "github": "http://localhost:3000/mcp/github"
        }
        self.test_results = []
    
    def test_infrastructure_deployment_workflow(self) -> Dict[str, Any]:
        """Test complete infrastructure deployment workflow"""
        workflow_steps = [
            {
                "step": "validate_aws_resources",
                "system": "aws",
                "operation": "describe_cluster_capacity",
                "expected_result": "capacity_available"
            },
            {
                "step": "deploy_application",
                "system": "kubernetes",
                "operation": "apply_deployment",
                "expected_result": "deployment_successful"
            },
            {
                "step": "verify_monitoring",
                "system": "monitoring",
                "operation": "check_metrics_collection",
                "expected_result": "metrics_available"
            },
            {
                "step": "update_ci_cd",
                "system": "github",
                "operation": "update_workflow_status",
                "expected_result": "workflow_updated"
            }
        ]
        
        results = []
        workflow_success = True
        
        for step in workflow_steps:
            start_time = time.time()
            
            response = self.query_system(
                step["system"],
                step["operation"],
                {"auto_approve": True}
            )
            
            step_duration = time.time() - start_time
            step_success = response.get("status") == step["expected_result"]
            
            if not step_success:
                workflow_success = False
            
            result = {
                "step": step["step"],
                "system": step["system"],
                "operation": step["operation"],
                "duration": step_duration,
                "success": step_success,
                "response": response
            }
            results.append(result)
        
        return {
            "test_type": "infrastructure_deployment_workflow",
            "workflow_success": workflow_success,
            "total_duration": sum(r["duration"] for r in results),
            "steps": results
        }
    
    def test_incident_response_workflow(self) -> Dict[str, Any]:
        """Test incident response across systems"""
        incident_steps = [
            {
                "step": "detect_issue",
                "system": "monitoring",
                "operation": "check_alert_status",
                "expected_result": "alerts_detected"
            },
            {
                "step": "analyze_infrastructure",
                "system": "aws",
                "operation": "analyze_resource_health",
                "expected_result": "analysis_complete"
            },
            {
                "step": "check_application_status",
                "system": "kubernetes",
                "operation": "get_pod_status",
                "expected_result": "status_retrieved"
            },
            {
                "step": "trigger_remediation",
                "system": "github",
                "operation": "trigger_remediation_workflow",
                "expected_result": "workflow_triggered"
            }
        ]
        
        results = []
        incident_response_success = True
        
        for step in incident_steps:
            start_time = time.time()
            
            response = self.query_system(
                step["system"],
                step["operation"],
                {"incident_id": "test-incident-001"}
            )
            
            step_duration = time.time() - start_time
            step_success = response.get("status") == step["expected_result"]
            
            if not step_success:
                incident_response_success = False
            
            result = {
                "step": step["step"],
                "system": step["system"],
                "operation": step["operation"],
                "duration": step_duration,
                "success": step_success,
                "response": response
            }
            results.append(result)
        
        return {
            "test_type": "incident_response_workflow",
            "incident_response_success": incident_response_success,
            "total_response_time": sum(r["duration"] for r in results),
            "steps": results
        }
    
    def test_data_flow_integration(self) -> Dict[str, Any]:
        """Test data flow between systems"""
        data_flow_tests = [
            {
                "source": "kubernetes",
                "destination": "monitoring",
                "data_type": "metrics",
                "operation": "export_pod_metrics"
            },
            {
                "source": "aws",
                "destination": "monitoring",
                "data_type": "infrastructure_metrics",
                "operation": "export_cloudwatch_metrics"
            },
            {
                "source": "monitoring",
                "destination": "github",
                "data_type": "alert_status",
                "operation": "send_alert_webhook"
            }
        ]
        
        results = []
        for test in data_flow_tests:
            # Test data export from source
            export_response = self.query_system(
                test["source"],
                test["operation"],
                {"destination": test["destination"]}
            )
            
            # Verify data received at destination
            time.sleep(2)  # Allow time for data propagation
            
            verify_response = self.query_system(
                test["destination"],
                "verify_data_received",
                {"data_type": test["data_type"], "source": test["source"]}
            )
            
            data_flow_success = (
                export_response.get("exported", False) and
                verify_response.get("received", False)
            )
            
            result = {
                "source": test["source"],
                "destination": test["destination"],
                "data_type": test["data_type"],
                "export_success": export_response.get("exported", False),
                "receive_success": verify_response.get("received", False),
                "data_flow_success": data_flow_success
            }
            results.append(result)
        
        return {"test_type": "data_flow_integration", "results": results}
    
    def query_system(self, system: str, operation: str, params: Dict[str, Any]) -> Dict[str, Any]:
        """Query specific system via MCP"""
        try:
            response = requests.post(
                self.endpoints[system],
                json={
                    "method": operation,
                    "params": params
                },
                headers={"Content-Type": "application/json"},
                timeout=30
            )
            return response.json()
        except Exception as e:
            return {"error": str(e), "status": "error"}
    
    def run_all_tests(self) -> Dict[str, Any]:
        """Run all cross-system integration tests"""
        return {
            "cross_system_integration_tests": [
                self.test_infrastructure_deployment_workflow(),
                self.test_incident_response_workflow(),
                self.test_data_flow_integration()
            ]
        }

if __name__ == "__main__":
    tester = CrossSystemIntegrationTester()
    results = tester.run_all_tests()
    
    with open("cross-system-integration-test-results.json", "w") as f:
        json.dump(results, f, indent=2)
    
    print("Cross-system integration testing complete.")
```

## Test Execution and Validation

### Comprehensive Test Suite

#### Master Test Runner
```bash
#!/bin/bash
# Master MCP Integration Test Runner

echo "=== MCP Integration Comprehensive Testing ==="

# Set up test environment
export MCP_TEST_MODE=true
export MCP_ENDPOINT_BASE="http://localhost:3000/mcp"

# Create test results directory
mkdir -p test-results
cd test-results

echo "Starting MCP integration test suite..."

# Run connectivity tests
echo "1. Running connectivity tests..."
../aws-mcp-connectivity-test.sh > aws-connectivity-results.log 2>&1
../kubernetes-mcp-connectivity-test.sh > k8s-connectivity-results.log 2>&1

# Run functional tests
echo "2. Running functional tests..."
python3 ../aws-mcp-functional-test.py
python3 ../monitoring-mcp-functional-test.py

# Run safety control tests
echo "3. Running safety control tests..."
../auto-approval-test.sh > auto-approval-results.log 2>&1
python3 ../safety-control-test.py

# Run integration tests
echo "4. Running cross-system integration tests..."
python3 ../cross-system-integration-test.py

# Generate comprehensive report
echo "5. Generating test report..."
python3 ../generate-mcp-test-report.py

echo "MCP integration testing complete. Results available in test-results/"
```

### Test Result Analysis

#### Test Report Generator
```python
#!/usr/bin/env python3
"""
MCP Integration Test Report Generator
Analyzes all test results and generates comprehensive report
"""

import json
import glob
import os
from datetime import datetime
from typing import Dict, List, Any

class MCPTestReportGenerator:
    def __init__(self, results_dir: str = "test-results"):
        self.results_dir = results_dir
        self.report_data = {
            "timestamp": datetime.now().isoformat(),
            "test_summary": {},
            "detailed_results": {},
            "recommendations": []
        }
    
    def analyze_test_results(self) -> Dict[str, Any]:
        """Analyze all test result files"""
        # Load JSON test results
        json_files = glob.glob(f"{self.results_dir}/*-test-results.json")
        
        total_tests = 0
        passed_tests = 0
        failed_tests = 0
        
        for json_file in json_files:
            with open(json_file, 'r') as f:
                results = json.load(f)
            
            test_name = os.path.basename(json_file).replace('-test-results.json', '')
            
            # Analyze test results structure
            if isinstance(results, dict):
                test_count, pass_count = self.count_test_results(results)
                total_tests += test_count
                passed_tests += pass_count
                failed_tests += (test_count - pass_count)
                
                self.report_data["detailed_results"][test_name] = {
                    "total_tests": test_count,
                    "passed_tests": pass_count,
                    "failed_tests": test_count - pass_count,
                    "success_rate": pass_count / test_count if test_count > 0 else 0,
                    "results": results
                }
        
        # Generate summary
        self.report_data["test_summary"] = {
            "total_tests": total_tests,
            "passed_tests": passed_tests,
            "failed_tests": failed_tests,
            "overall_success_rate": passed_tests / total_tests if total_tests > 0 else 0,
            "test_categories": len(self.report_data["detailed_results"])
        }
        
        # Generate recommendations
        self.generate_recommendations()
        
        return self.report_data
    
    def count_test_results(self, results: Dict[str, Any]) -> tuple:
        """Recursively count test results"""
        total_count = 0
        pass_count = 0
        
        if isinstance(results, dict):
            if "passed" in results:
                total_count += 1
                if results["passed"]:
                    pass_count += 1
            elif "results" in results and isinstance(results["results"], list):
                for result in results["results"]:
                    sub_total, sub_pass = self.count_test_results(result)
                    total_count += sub_total
                    pass_count += sub_pass
            else:
                for key, value in results.items():
                    if isinstance(value, (dict, list)):
                        sub_total, sub_pass = self.count_test_results(value)
                        total_count += sub_total
                        pass_count += sub_pass
        elif isinstance(results, list):
            for item in results:
                sub_total, sub_pass = self.count_test_results(item)
                total_count += sub_total
                pass_count += sub_pass
        
        return total_count, pass_count
    
    def generate_recommendations(self):
        """Generate recommendations based on test results"""
        recommendations = []
        
        # Check overall success rate
        success_rate = self.report_data["test_summary"]["overall_success_rate"]
        if success_rate < 0.9:
            recommendations.append({
                "priority": "high",
                "category": "overall_performance",
                "issue": f"Overall success rate is {success_rate:.1%}, below 90% threshold",
                "recommendation": "Review failed tests and address underlying issues"
            })
        
        # Check individual test categories
        for test_name, results in self.report_data["detailed_results"].items():
            if results["success_rate"] < 0.8:
                recommendations.append({
                    "priority": "medium",
                    "category": test_name,
                    "issue": f"{test_name} success rate is {results['success_rate']:.1%}",
                    "recommendation": f"Focus on improving {test_name} reliability"
                })
        
        # Check for specific failure patterns
        if "aws-mcp" in self.report_data["detailed_results"]:
            aws_results = self.report_data["detailed_results"]["aws-mcp"]
            if aws_results["failed_tests"] > 0:
                recommendations.append({
                    "priority": "high",
                    "category": "aws_integration",
                    "issue": "AWS MCP integration has failures",
                    "recommendation": "Check AWS credentials and service availability"
                })
        
        self.report_data["recommendations"] = recommendations
    
    def generate_html_report(self) -> str:
        """Generate HTML test report"""
        html_template = """
        <!DOCTYPE html>
        <html>
        <head>
            <title>MCP Integration Test Report</title>
            <style>
                body { font-family: Arial, sans-serif; margin: 20px; }
                .summary { background: #f0f0f0; padding: 15px; border-radius: 5px; }
                .success { color: green; }
                .failure { color: red; }
                .warning { color: orange; }
                table { border-collapse: collapse; width: 100%; margin: 20px 0; }
                th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
                th { background-color: #f2f2f2; }
                .recommendation { background: #fff3cd; padding: 10px; margin: 10px 0; border-radius: 5px; }
            </style>
        </head>
        <body>
            <h1>MCP Integration Test Report</h1>
            <p>Generated: {timestamp}</p>
            
            <div class="summary">
                <h2>Test Summary</h2>
                <p>Total Tests: {total_tests}</p>
                <p>Passed: <span class="success">{passed_tests}</span></p>
                <p>Failed: <span class="failure">{failed_tests}</span></p>
                <p>Success Rate: <span class="{success_class}">{success_rate:.1%}</span></p>
            </div>
            
            <h2>Test Results by Category</h2>
            <table>
                <tr>
                    <th>Category</th>
                    <th>Total Tests</th>
                    <th>Passed</th>
                    <th>Failed</th>
                    <th>Success Rate</th>
                </tr>
                {test_rows}
            </table>
            
            <h2>Recommendations</h2>
            {recommendations_html}
        </body>
        </html>
        """
        
        # Generate test result rows
        test_rows = ""
        for test_name, results in self.report_data["detailed_results"].items():
            success_class = "success" if results["success_rate"] > 0.8 else "failure"
            test_rows += f"""
                <tr>
                    <td>{test_name}</td>
                    <td>{results["total_tests"]}</td>
                    <td class="success">{results["passed_tests"]}</td>
                    <td class="failure">{results["failed_tests"]}</td>
                    <td class="{success_class}">{results["success_rate"]:.1%}</td>
                </tr>
            """
        
        # Generate recommendations HTML
        recommendations_html = ""
        for rec in self.report_data["recommendations"]:
            priority_class = rec["priority"]
            recommendations_html += f"""
                <div class="recommendation {priority_class}">
                    <strong>{rec["priority"].upper()}: {rec["category"]}</strong><br>
                    Issue: {rec["issue"]}<br>
                    Recommendation: {rec["recommendation"]}
                </div>
            """
        
        # Fill template
        success_rate = self.report_data["test_summary"]["overall_success_rate"]
        success_class = "success" if success_rate > 0.8 else "failure"
        
        return html_template.format(
            timestamp=self.report_data["timestamp"],
            total_tests=self.report_data["test_summary"]["total_tests"],
            passed_tests=self.report_data["test_summary"]["passed_tests"],
            failed_tests=self.report_data["test_summary"]["failed_tests"],
            success_rate=success_rate,
            success_class=success_class,
            test_rows=test_rows,
            recommendations_html=recommendations_html
        )
    
    def save_report(self):
        """Save test report in multiple formats"""
        # Save JSON report
        with open(f"{self.results_dir}/mcp-integration-test-report.json", "w") as f:
            json.dump(self.report_data, f, indent=2)
        
        # Save HTML report
        html_report = self.generate_html_report()
        with open(f"{self.results_dir}/mcp-integration-test-report.html", "w") as f:
            f.write(html_report)
        
        print(f"Test reports saved to {self.results_dir}/")
        print(f"Overall success rate: {self.report_data['test_summary']['overall_success_rate']:.1%}")

if __name__ == "__main__":
    generator = MCPTestReportGenerator()
    generator.analyze_test_results()
    generator.save_report()
```

## Continuous Integration Testing

### Automated Test Pipeline

```yaml
# .github/workflows/mcp-integration-tests.yml
name: MCP Integration Tests

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]
  schedule:
    - cron: '0 6 * * *'  # Daily at 6 AM

jobs:
  mcp-integration-tests:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Set up Python
      uses: actions/setup-python@v4
      with:
        python-version: '3.9'
    
    - name: Install dependencies
      run: |
        pip install requests pytest
        
    - name: Start MCP test environment
      run: |
        docker-compose -f docker-compose.test.yml up -d
        sleep 30  # Wait for services to start
        
    - name: Run MCP connectivity tests
      run: |
        chmod +x tests/mcp/aws-mcp-connectivity-test.sh
        chmod +x tests/mcp/kubernetes-mcp-connectivity-test.sh
        ./tests/mcp/aws-mcp-connectivity-test.sh
        ./tests/mcp/kubernetes-mcp-connectivity-test.sh
        
    - name: Run MCP functional tests
      run: |
        python tests/mcp/aws-mcp-functional-test.py
        python tests/mcp/monitoring-mcp-functional-test.py
        python tests/mcp/cross-system-integration-test.py
        
    - name: Run safety control tests
      run: |
        chmod +x tests/mcp/auto-approval-test.sh
        ./tests/mcp/auto-approval-test.sh
        python tests/mcp/safety-control-test.py
        
    - name: Generate test report
      run: |
        python tests/mcp/generate-mcp-test-report.py
        
    - name: Upload test results
      uses: actions/upload-artifact@v3
      with:
        name: mcp-test-results
        path: test-results/
        
    - name: Cleanup test environment
      if: always()
      run: |
        docker-compose -f docker-compose.test.yml down
```

This comprehensive MCP integration testing framework ensures all external tool integrations work correctly, auto-approval configurations are properly enforced, safety controls are effective, and cross-system data flows operate as expected.