# Environment Configuration Selector

## Overview

This document describes how Kiro automatically selects and applies environment-specific configurations based on the current context.

## Environment Detection

### Automatic Detection Methods

```yaml
Detection Strategies:
  kubernetes_context:
    - pattern: "*-dev-*" → development environment
    - pattern: "*-staging-*" → staging environment  
    - pattern: "*-prod-*" → production environment
    
  aws_profile:
    - profile: "dev" → development environment
    - profile: "staging" → staging environment
    - profile: "prod" → production environment
    
  environment_variables:
    - KIRO_ENVIRONMENT: "dev|staging|prod"
    - AWS_PROFILE: environment indicator
    - KUBECONFIG: context-based detection
    
  cluster_tags:
    - Environment: "dev|staging|prod"
    - Project: "eks-learning-lab"
    - Component: workflow identifier
```

## Configuration Loading Priority

### Priority Order
1. Explicit environment variable (`KIRO_ENVIRONMENT`)
2. Kubernetes context pattern matching
3. AWS profile detection
4. Cluster tag inspection
5. Default to development environment

### Configuration Files Applied

```yaml
Development Environment:
  steering_documents:
    - .kiro/steering/environment-dev.md
    - .kiro/steering/workflows.md
    - .kiro/steering/microservices.md
    - .kiro/steering/operations.md
    - .kiro/steering/cost-optimization.md
    
  hooks:
    - .kiro/hooks/environment-dev-monitoring.yaml
    - .kiro/hooks/infrastructure-monitoring.yaml
    - .kiro/hooks/cost-optimization.yaml
    
  mcp_settings:
    - .kiro/settings/mcp-dev.json

Staging Environment:
  steering_documents:
    - .kiro/steering/environment-staging.md
    - .kiro/steering/workflows.md
    - .kiro/steering/microservices.md
    - .kiro/steering/operations.md
    - .kiro/steering/cost-optimization.md
    
  hooks:
    - .kiro/hooks/environment-staging-monitoring.yaml
    - .kiro/hooks/deployment-validation.yaml
    - .kiro/hooks/security-compliance.yaml
    
  mcp_settings:
    - .kiro/settings/mcp-staging.json

Production Environment:
  steering_documents:
    - .kiro/steering/environment-prod.md
    - .kiro/steering/workflows.md
    - .kiro/steering/microservices.md
    - .kiro/steering/operations.md
    - .kiro/steering/safety-controls-escalation.md
    
  hooks:
    - .kiro/hooks/environment-prod-monitoring.yaml
    - .kiro/hooks/security-compliance.yaml
    - .kiro/hooks/documentation-maintenance.yaml
    
  mcp_settings:
    - .kiro/settings/mcp-prod.json
```

## Environment-Specific Behaviors

### Development Environment
- Aggressive resource optimization
- Relaxed security policies for debugging
- Enhanced logging and tracing
- Rapid iteration support
- Cost optimization prioritized

### Staging Environment
- Production-like validation
- Quality gates and approval processes
- Comprehensive testing automation
- Performance benchmarking
- Pre-production validation

### Production Environment
- Conservative operation boundaries
- Strict approval gates
- Comprehensive monitoring and alerting
- Incident response automation
- Compliance and audit logging

## Configuration Validation

### Validation Checks
- Environment-specific resource limits
- Appropriate security policies
- Correct monitoring thresholds
- Valid escalation procedures
- Compliance requirements met

### Fallback Mechanisms
- Default to most restrictive settings on detection failure
- Manual environment override capability
- Configuration validation before application
- Rollback to previous configuration on failure