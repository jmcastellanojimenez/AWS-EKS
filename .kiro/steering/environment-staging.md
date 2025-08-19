# Staging Environment Configuration

## Environment Overview

The staging environment mirrors production configuration while allowing for controlled testing and validation of changes before production deployment.

## Environment-Specific Settings

### Resource Allocation
```yaml
Cluster Configuration:
  node_count: 5-8 nodes
  instance_types: ["t3.large", "t3.xlarge"]
  spot_percentage: 70%
  auto_scaling: balanced (moderate scale-up/down)
  
Resource Limits:
  cpu_requests: 100m-300m per service
  memory_requests: 256Mi-768Mi per service
  cpu_limits: 800m-1500m per service
  memory_limits: 1Gi-3Gi per service
  
Storage:
  storage_class: gp3
  volume_sizes: 50-200GB
  backup_frequency: daily
  retention_period: 30 days
```

### Autonomous Operation Boundaries
```yaml
Autopilot Mode Permissions:
  resource_scaling: enabled with approval gates
  configuration_changes: limited scope
  cost_optimization: enabled
  security_updates: enabled with validation
  
Scaling Limits:
  max_replicas: 8 per service
  max_nodes: 12 per cluster
  max_cost_increase: 30% per day
  max_storage_expansion: 50% per operation
  
Operation Frequency:
  max_operations_per_hour: 15
  min_time_between_operations: 5 minutes
  max_concurrent_operations: 3
```

### Monitoring and Alerting
```yaml
Alert Thresholds:
  cpu_utilization: 75%
  memory_utilization: 80%
  error_rate: 2%
  response_time: 2 seconds
  
Alert Routing:
  critical: platform-team + on-call
  warning: platform-team slack channel
  info: dashboard + weekly summary
  
Retention Periods:
  metrics: 30 days
  logs: 14 days
  traces: 7 days
```

### Staging-Specific Features
```yaml
Production Simulation:
  load_testing: comprehensive
  chaos_engineering: controlled
  performance_testing: full suite
  security_testing: complete
  
Validation Features:
  blue_green_deployments: enabled
  canary_analysis: automated
  rollback_testing: required
  integration_testing: comprehensive
  
Quality Gates:
  performance_regression: < 10%
  error_rate_increase: < 0.5%
  security_scan_pass: required
  load_test_pass: required
```

## Environment-Specific Workflows

### Deployment Strategy
- Production-like deployment procedures
- Automated quality gates and validation
- Performance benchmarking against production
- Full integration testing suite

### Security Posture
- Production-equivalent security policies
- Complete vulnerability scanning
- Penetration testing simulation
- Compliance validation testing

### Performance Expectations
- Response time: < 1 second p95
- Availability: > 99.5%
- Error rate: < 1%
- Resource efficiency: 70-80% utilization

## Pre-Production Validation

### Required Validations
- Performance benchmarks meet production targets
- Security scans pass with no critical issues
- Load testing validates capacity requirements
- Disaster recovery procedures tested
- Monitoring and alerting validated
- Cost projections within budget targets