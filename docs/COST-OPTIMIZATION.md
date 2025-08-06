# 💰 EKS Learning Lab - Cost Optimization Guide

Comprehensive strategies to minimize AWS costs while maximizing learning value.

## 🎯 Cost Optimization Overview

The EKS Learning Lab is designed with cost optimization as a primary concern, targeting **~$45-50/month** for a full-featured learning environment.

### 💡 Core Cost Principles

1. **Spot Instances First** - 70% savings on compute
2. **Right-Sizing** - Match resources to learning needs
3. **Scheduled Operations** - Shut down when not learning
4. **Smart Defaults** - Cost-optimized configurations
5. **Continuous Monitoring** - Track and alert on spending

## 📊 Detailed Cost Breakdown

### Current Architecture Costs (Monthly)

| Service | Configuration | Cost | Optimization |
|---------|---------------|------|--------------|
| **EKS Control Plane** | 1 cluster | $72.00 | Fixed AWS cost |
| **EC2 Instances** | 1 × t3.small (Spot) | $7.30 | 70% vs On-Demand |
| **EBS Storage** | 20GB GP3 | $2.00 | 20% cheaper than GP2 |
| **Application Load Balancer** | 1 ALB | $16.20 | Shared across apps |
| **Data Transfer** | Inter-AZ | $3.00 | Minimal cross-AZ traffic |
| **CloudWatch Logs** | 7-day retention | $3.00 | Short retention period |
| **NAT Gateway** | Disabled (dev) | $0.00 | $45/month savings |
| **VPC Endpoints** | Disabled (dev) | $0.00 | $22/month savings |
| **Total Monthly** | | **$103.50** | **$67/month savings** |

### Cost Comparison by Environment

| Environment | Instances | Storage | NAT | Monthly Cost |
|-------------|-----------|---------|-----|--------------|
| **Development** | 1 × t3.small (Spot) | 20GB | No | **$103.50** |
| **Staging** | 2 × t3.small (Spot) | 40GB | Yes | **$158.90** |
| **Production** | 3 × t3.medium (On-Demand) | 60GB | Yes × 2 | **$267.40** |

## 🚀 Optimization Strategies

### 1. Scheduled Cluster Management

Automated shutdown schedules provide massive savings:

#### Weekend Shutdown (Recommended)
```yaml
# Friday 6 PM → Monday 8 AM
Savings: 65 hours/week (38.7% uptime)
Monthly Savings: ~$40-50
Annual Savings: ~$480-600
```

#### Nightly Shutdown
```yaml
# 10 PM → 6 AM daily (8 hours down)
Savings: 56 hours/week (66.7% uptime)  
Monthly Savings: ~$35-45
Annual Savings: ~$420-540
```

#### Combined Schedule
```yaml
# Nights + Weekends
Savings: 121 hours/week (27.8% uptime)
Monthly Savings: ~$75-85
Annual Savings: ~$900-1000
```

### 2. Instance Optimization

#### Spot Instance Strategy
```hcl
# Terraform configuration
capacity_type = "SPOT"
instance_types = ["t3.small", "t3.medium"]  # Multiple types for availability

# Savings: 60-70% vs On-Demand
# Risk: Occasional interruption (acceptable for learning)
```

#### Right-Sizing Guidelines
```hcl
# Development
instance_types = ["t3.small"]          # 2 vCPU, 2GB RAM
desired_capacity = 1
max_capacity = 2

# Learning/Testing  
instance_types = ["t3.medium"]         # 2 vCPU, 4GB RAM
desired_capacity = 2
max_capacity = 3

# Production Learning
instance_types = ["t3.large"]          # 2 vCPU, 8GB RAM
desired_capacity = 3
max_capacity = 5
```

### 3. Storage Optimization

#### EBS Volume Settings
```hcl
# Use GP3 instead of GP2 (20% savings)
volume_type = "gp3"
volume_size = 20        # Minimal for learning
encrypted = true
delete_on_termination = true

# Avoid provisioned IOPS unless needed
throughput = "125"      # Default GP3 throughput
iops = "3000"          # Default GP3 IOPS
```

#### Storage Class Configuration
```yaml
# Cost-optimized storage classes
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: gp3-standard
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  encrypted: "true"
  throughput: "125"     # Minimal throughput
  iops: "3000"         # Minimal IOPS
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
```

### 4. Network Cost Optimization

#### NAT Gateway Strategy
```hcl
# Development: No NAT Gateway (save $45/month)
enable_nat_gateway = false

# Staging: Single NAT Gateway  
enable_nat_gateway = true
nat_gateway_count = 1

# Production: Multi-AZ NAT Gateways
enable_nat_gateway = true
nat_gateway_count = 2
```

#### VPC Endpoint Usage
```hcl
# Only enable for production workloads
enable_vpc_endpoints = false  # Save ~$22/month per endpoint

# When enabled, be selective
vpc_endpoints = [
  "s3",        # Gateway endpoint (free)
  "ec2",       # Only if heavy EC2 API usage
  "eks"        # Only if cluster in private subnets
]
```

### 5. Monitoring and Logging Optimization

#### CloudWatch Logs Retention
```yaml
# Short retention for learning environments
log_groups:
  - name: "/aws/eks/cluster/cluster"
    retention_days: 7      # vs 30+ days
  - name: "/aws/containerinsights/cluster/performance"  
    retention_days: 3      # vs 14+ days
```

#### Metrics Optimization
```yaml
# Prometheus configuration
prometheus:
  retention: 7d            # vs 15d+ default
  storage: 10Gi           # vs 50Gi+ default
  scrape_interval: 60s     # vs 15s default (for learning)
```

## 🔧 Implementation Guide

### 1. Automated Cost Controls

#### GitHub Actions Workflows

```yaml
# .github/workflows/scheduled-cost-control.yml
name: Scheduled Cost Control
on:
  schedule:
    - cron: '0 18 * * 5'  # Friday 6 PM shutdown
    - cron: '0 8 * * 1'   # Monday 8 AM startup
  workflow_dispatch:
    inputs:
      action: [shutdown, startup, status]
```

#### Cost Control Scripts

```bash
# scripts/cost-control.sh
#!/bin/bash

case "$1" in
  shutdown)
    echo "Shutting down cluster for cost savings..."
    terraform destroy -auto-approve
    ;;
  startup) 
    echo "Starting cluster for learning session..."
    terraform apply -auto-approve
    ;;
  status)
    ./scripts/cost-estimate.sh
    ;;
esac
```

### 2. Budget and Alerts

#### AWS Budget Configuration
```json
{
  "BudgetName": "EKS-Learning-Lab-Budget",
  "BudgetLimit": {
    "Amount": "75.00",
    "Unit": "USD"
  },
  "TimeUnit": "MONTHLY",
  "BudgetType": "COST",
  "CostFilters": {
    "TagKey": ["Project"],
    "TagValue": ["eks-learning-lab"]
  },
  "NotificationsWithSubscribers": [
    {
      "Notification": {
        "NotificationType": "ACTUAL",
        "ComparisonOperator": "GREATER_THAN", 
        "Threshold": 80
      },
      "Subscribers": [
        {
          "SubscriptionType": "EMAIL",
          "Address": "your-email@example.com"
        }
      ]
    }
  ]
}
```

#### Cost Anomaly Detection
```bash
# Enable cost anomaly detection
aws ce create-anomaly-detector \
    --anomaly-detector MonitorType=DIMENSIONAL,DimensionKey=SERVICE,DimensionValueList=AmazonEKS \
    --monitor-name "EKS Learning Lab Anomaly Detection"
```

### 3. Resource Cleanup Automation

#### Automated Cleanup Script
```bash
#!/bin/bash
# scripts/cleanup-resources.sh

# Clean up unused EBS volumes
aws ec2 describe-volumes \
    --filters "Name=status,Values=available" \
    --query 'Volumes[].VolumeId' \
    --output text | xargs -I {} aws ec2 delete-volume --volume-id {}

# Clean up unattached Elastic IPs
aws ec2 describe-addresses \
    --query 'Addresses[?AssociationId==null].AllocationId' \
    --output text | xargs -I {} aws ec2 release-address --allocation-id {}

# Clean up old snapshots (30+ days)
aws ec2 describe-snapshots --owner-ids self \
    --query "Snapshots[?StartTime<='$(date -d '30 days ago' +%Y-%m-%d)'].SnapshotId" \
    --output text | xargs -I {} aws ec2 delete-snapshot --snapshot-id {}
```

## 📈 Cost Monitoring Dashboard

### Grafana Dashboard Panels

```json
{
  "panels": [
    {
      "title": "Estimated Hourly Cost",
      "type": "stat",
      "targets": [{
        "expr": "0.10 + (count(kube_node_info) * 0.0062)",
        "legendFormat": "Hourly Cost ($)"
      }]
    },
    {
      "title": "Monthly Projection",
      "type": "stat", 
      "targets": [{
        "expr": "(0.10 + (count(kube_node_info) * 0.0062)) * 24 * 30",
        "legendFormat": "Monthly Cost ($)"
      }]
    },
    {
      "title": "Spot Instance Percentage",
      "type": "stat",
      "targets": [{
        "expr": "count(kube_node_info{node=~\".*spot.*\"}) / count(kube_node_info) * 100",
        "legendFormat": "Spot Instances (%)"
      }]
    }
  ]
}
```

### Cost Alerts

```yaml
# Prometheus alerting rules
groups:
- name: cost.rules
  rules:
  - alert: HighDailyCost
    expr: (0.10 + (count(kube_node_info) * 0.0062)) * 24 > 5
    for: 1h
    labels:
      severity: warning
    annotations:
      summary: "Daily cost exceeding $5"
      description: "Projected daily cost is ${{ $value }}"
      
  - alert: TooManyNodes
    expr: count(kube_node_info) > 3
    for: 5m
    labels:
      severity: critical
    annotations:
      summary: "Too many nodes running"
      description: "{{ $value }} nodes are running (expected ≤3)"
```

## 🎯 Cost Optimization Checklist

### ✅ Pre-Deployment
- [ ] Choose appropriate instance types for workload
- [ ] Enable Spot instances where possible
- [ ] Configure minimal storage requirements
- [ ] Disable unnecessary services (NAT, VPC endpoints)
- [ ] Set up budget alerts

### ✅ Post-Deployment  
- [ ] Verify Spot instance utilization >80%
- [ ] Check resource requests vs usage
- [ ] Enable scheduled shutdown
- [ ] Configure log retention policies
- [ ] Set up automated cleanup

### ✅ Ongoing Monitoring
- [ ] Weekly cost review
- [ ] Monthly budget analysis
- [ ] Quarterly architecture review
- [ ] Annual instance type optimization

## 🔄 Advanced Optimization Techniques

### 1. Multi-Instance Type Strategy

```hcl
# Increase Spot availability with multiple instance types
instance_types = [
  "t3.small",
  "t3a.small",    # AMD instances (often cheaper)
  "t2.small"      # Previous generation fallback
]

# Allow mixed instance groups
mixed_instances_policy = {
  instances_distribution = {
    on_demand_base_capacity = 0
    on_demand_percentage_above_base_capacity = 0
    spot_allocation_strategy = "diversified"
  }
}
```

### 2. Cluster API Cost Optimization

```yaml
# Use cluster-api for advanced autoscaling
apiVersion: cluster.x-k8s.io/v1beta1
kind: MachinePool
metadata:
  name: spot-workers
spec:
  clusterName: eks-learning-lab
  replicas: 2
  template:
    spec:
      bootstrap:
        configRef:
          name: spot-worker-bootstrap
      infrastructureRef:
        name: spot-worker-machinepool
      version: v1.28.0
```

### 3. Workload-Based Scheduling

```yaml
# Schedule non-critical workloads on Spot instances
apiVersion: v1
kind: Pod
metadata:
  name: batch-job
spec:
  nodeSelector:
    karpenter.sh/capacity-type: spot
  tolerations:
  - key: "karpenter.sh/capacity-type"
    operator: "Equal"
    value: "spot"
    effect: "NoSchedule"
```

## 📊 ROI Analysis

### Learning Investment
```
Traditional Learning Options:
- AWS Training Course: $2,000-4,000
- Kubernetes Certification Prep: $500-1,000  
- Cloud Sandbox Environment: $200-500/month

EKS Learning Lab:
- Setup Time: 2-4 hours
- Monthly Cost: $45-75
- Annual Cost: $540-900
- Learning Value: Equivalent to $5,000+ training
```

### Cost vs. Capability Matrix

| Feature | Cost Impact | Learning Value | Recommendation |
|---------|-------------|----------------|----------------|
| Spot Instances | -70% | High | ✅ Always Enable |
| Multiple Instance Types | 0% | Medium | ✅ Enable |
| Scheduled Shutdown | -65% | Low | ✅ Enable |
| NAT Gateway | +$45/month | Low | ❌ Disable for Dev |
| VPC Endpoints | +$22/month | Medium | ❌ Disable for Dev |
| ELK Stack | +$15/month | High | ✅ Enable |
| Service Mesh | +$5/month | High | ✅ Enable |

## 🎓 Cost Optimization Learning Path

### Week 1: Foundation
- [ ] Understand AWS pricing models
- [ ] Configure cost budgets and alerts
- [ ] Enable basic cost monitoring

### Week 2: Instance Optimization  
- [ ] Implement Spot instance strategy
- [ ] Practice right-sizing exercises
- [ ] Configure cluster autoscaling

### Week 3: Scheduling & Automation
- [ ] Set up scheduled operations
- [ ] Implement automated cleanup
- [ ] Practice cost-aware deployments

### Week 4: Advanced Techniques
- [ ] Multi-instance type configurations
- [ ] Workload-based scheduling
- [ ] Cost allocation and chargebacks

## 📞 Cost Support Resources

- 💰 [AWS Cost Calculator](https://calculator.aws/)
- 📊 [AWS Cost Explorer](https://aws.amazon.com/aws-cost-management/aws-cost-explorer/)
- 🔔 [AWS Budgets](https://aws.amazon.com/aws-cost-management/aws-budgets/)
- 📈 [Cost Optimization Scripts](../scripts/cost-estimate.sh)
- 🛠️ [Resource Cleanup Tools](../scripts/cleanup-resources.sh)

---

**💡 Remember: The goal is learning, not perfection. Start with basic optimizations and gradually implement advanced techniques as you learn!**