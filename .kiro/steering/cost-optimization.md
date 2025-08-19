# Cost Optimization

## Resource Optimization Strategies

### Compute Cost Optimization

#### Spot Instance Management
```yaml
EKS Node Group Configuration:
  capacity_type: SPOT
  instance_types: ["t3.large", "t3a.large", "t2.large"]
  spot_allocation_strategy: diversified
  on_demand_base_capacity: 1
  on_demand_percentage_above_base: 20
  
Cost Savings:
  spot_discount: 60-70% vs on-demand
  mixed_instance_policy: Additional 10-15% savings
  estimated_monthly_savings: $200-300 per cluster
```

#### Right-Sizing Strategies
```yaml
Resource Optimization:
  node_instance_types:
    development: t3.medium (2 vCPU, 4GB RAM)
    staging: t3.large (2 vCPU, 8GB RAM)
    production: t3.large + t3.xlarge mix
  
  pod_resource_optimization:
    requests_vs_limits_ratio: 0.5-0.7
    cpu_utilization_target: 60-70%
    memory_utilization_target: 70-80%
    
  auto_scaling_configuration:
    cluster_autoscaler: enabled
    scale_down_delay: 10m
    scale_down_utilization_threshold: 0.5
```

#### Container Resource Management
```yaml
Microservices Resource Allocation:
  user_service:
    requests: { cpu: "100m", memory: "256Mi" }
    limits: { cpu: "300m", memory: "512Mi" }
    estimated_cost: $15/month
    
  product_service:
    requests: { cpu: "150m", memory: "384Mi" }
    limits: { cpu: "400m", memory: "768Mi" }
    estimated_cost: $25/month
    
  order_service:
    requests: { cpu: "200m", memory: "512Mi" }
    limits: { cpu: "500m", memory: "1Gi" }
    estimated_cost: $35/month
    
  payment_service:
    requests: { cpu: "100m", memory: "256Mi" }
    limits: { cpu: "300m", memory: "512Mi" }
    estimated_cost: $15/month
    
  notification_service:
    requests: { cpu: "50m", memory: "128Mi" }
    limits: { cpu: "200m", memory: "256Mi" }
    estimated_cost: $8/month

Total Microservices Cost: ~$98/month
```

### Storage Cost Optimization

#### S3 Lifecycle Policies
```yaml
Observability Data Lifecycle:
  prometheus_metrics:
    standard_storage: 30 days
    standard_ia: 30-90 days
    glacier: 90-365 days
    deep_archive: 365+ days
    estimated_savings: 60-80%
    
  loki_logs:
    standard_storage: 7 days
    standard_ia: 7-30 days
    glacier: 30-90 days
    deletion: 90+ days
    estimated_savings: 70-85%
    
  tempo_traces:
    standard_storage: 3 days
    standard_ia: 3-14 days
    deletion: 14+ days
    estimated_savings: 80-90%

S3 Bucket Configuration:
  versioning: enabled (with lifecycle)
  intelligent_tiering: enabled
  compression: gzip for logs and metrics
  estimated_monthly_cost: $50-80 (vs $200-300 without optimization)
```

#### EBS Volume Optimization
```yaml
Persistent Volume Strategy:
  storage_class: gp3 (20% cheaper than gp2)
  volume_type_optimization:
    database_volumes: gp3 with provisioned IOPS
    application_volumes: gp3 standard
    backup_volumes: sc1 (cold HDD)
    
  volume_sizing:
    initial_size: 20GB (minimum for gp3)
    auto_expansion: enabled via CSI driver
    unused_volume_cleanup: automated via scripts
    
Cost Comparison:
  gp2: $0.10/GB/month
  gp3: $0.08/GB/month (20% savings)
  sc1: $0.025/GB/month (75% savings for backups)
```

### Network Cost Optimization

#### Data Transfer Optimization
```yaml
Network Architecture:
  vpc_endpoints: S3, ECR, EKS (reduce NAT gateway costs)
  nat_gateway_optimization: Single NAT per AZ in dev, redundant in prod
  cloudfront_integration: Static assets and API caching
  
Data Transfer Costs:
  vpc_endpoints_savings: $45/month (1TB transfer)
  nat_gateway_optimization: $32/month per gateway
  cloudfront_caching: 50-70% reduction in origin requests
```

#### Load Balancer Optimization
```yaml
Load Balancer Strategy:
  development: Single ALB shared across services
  staging: ALB per service group
  production: Dedicated ALBs with WAF
  
Cost Structure:
  alb_fixed_cost: $16.20/month per ALB
  alb_lcu_cost: $0.008 per LCU-hour
  nlb_fixed_cost: $16.20/month per NLB
  nlb_lcu_cost: $0.006 per NLCU-hour
  
Optimization:
  shared_alb_dev: Save $48/month (3 ALBs → 1 ALB)
  intelligent_routing: Reduce LCU consumption by 20-30%
```

## Spot Instance Management

### Spot Instance Configuration
```yaml
Node Group Spot Configuration:
  spot_instance_pools: 3-5 pools for diversification
  instance_types:
    - t3.large
    - t3a.large
    - t2.large
    - m5.large
    - m5a.large
  
  interruption_handling:
    node_termination_handler: AWS Node Termination Handler
    graceful_shutdown: 120 seconds
    pod_disruption_budgets: configured for all services
    
Spot Instance Monitoring:
  interruption_rate: < 5% with proper diversification
  cost_savings: 60-70% vs on-demand
  availability_target: 99.5% with mixed capacity
```

### Spot Instance Best Practices
```yaml
Workload Placement:
  stateless_workloads: Prefer spot instances
  stateful_workloads: On-demand instances
  critical_services: Mixed capacity (20% on-demand minimum)
  
Interruption Mitigation:
  multiple_az_deployment: Spread across 3 AZs
  pod_anti_affinity: Distribute replicas across nodes
  horizontal_pod_autoscaler: Quick scaling on interruption
  cluster_autoscaler: Automatic node replacement
  
Monitoring and Alerting:
  spot_interruption_alerts: CloudWatch + Slack
  cost_anomaly_detection: AWS Cost Anomaly Detection
  utilization_monitoring: Container Insights
```

### Spot Fleet Management
```bash
# Monitor spot instance interruptions
aws ec2 describe-spot-fleet-requests --spot-fleet-request-ids <fleet-id>

# Check spot price history
aws ec2 describe-spot-price-history \
  --instance-types t3.large \
  --product-descriptions "Linux/UNIX" \
  --start-time 2024-01-01T00:00:00Z \
  --end-time 2024-01-31T23:59:59Z

# Monitor node termination events
kubectl get events -A | grep -i "spot\|termination"

# Check cluster autoscaler logs
kubectl logs -n kube-system -l app=cluster-autoscaler
```

## S3 Lifecycle Policies

### Automated Data Lifecycle Management
```yaml
Prometheus Metrics Lifecycle:
  bucket: eks-learning-lab-dev-lgtm-prometheus
  lifecycle_policy:
    - id: prometheus-metrics-lifecycle
      status: Enabled
      transitions:
        - days: 30
          storage_class: STANDARD_IA
        - days: 90
          storage_class: GLACIER
        - days: 365
          storage_class: DEEP_ARCHIVE
      expiration:
        days: 2555  # 7 years retention
        
Loki Logs Lifecycle:
  bucket: eks-learning-lab-dev-lgtm-loki
  lifecycle_policy:
    - id: loki-logs-lifecycle
      status: Enabled
      transitions:
        - days: 7
          storage_class: STANDARD_IA
        - days: 30
          storage_class: GLACIER
      expiration:
        days: 90  # 3 months retention for logs
        
Tempo Traces Lifecycle:
  bucket: eks-learning-lab-dev-lgtm-tempo
  lifecycle_policy:
    - id: tempo-traces-lifecycle
      status: Enabled
      transitions:
        - days: 3
          storage_class: STANDARD_IA
      expiration:
        days: 14  # 2 weeks retention for traces
```

### S3 Cost Optimization Features
```yaml
Intelligent Tiering:
  enabled: true
  monitoring_fee: $0.0025 per 1,000 objects
  automatic_optimization: Move objects between access tiers
  cost_savings: 20-40% without operational overhead
  
Compression:
  prometheus_metrics: gzip compression (70% size reduction)
  loki_logs: lz4 compression (60% size reduction)
  tempo_traces: snappy compression (50% size reduction)
  
Multipart Upload:
  threshold: 100MB
  chunk_size: 10MB
  parallel_uploads: 5 concurrent parts
  failed_upload_cleanup: 7 days
```

### S3 Monitoring and Optimization
```bash
# Monitor S3 storage usage and costs
aws s3api list-buckets --query 'Buckets[?contains(Name, `lgtm`)].Name'

# Check bucket sizes
aws s3 ls s3://eks-learning-lab-dev-lgtm-prometheus --recursive --human-readable --summarize

# Analyze storage class distribution
aws s3api list-objects-v2 --bucket eks-learning-lab-dev-lgtm-prometheus \
  --query 'Contents[].{Key:Key,StorageClass:StorageClass,Size:Size}' \
  --output table

# Monitor lifecycle policy effectiveness
aws s3api get-bucket-lifecycle-configuration --bucket eks-learning-lab-dev-lgtm-prometheus
```

## Cost Monitoring and Budget Forecasting

### AWS Cost Management Setup
```yaml
Cost Allocation Tags:
  Environment: dev/staging/prod
  Project: eks-learning-lab
  Component: foundation/ingress/observability/microservices
  Owner: platform-team
  CostCenter: engineering
  
Budget Configuration:
  monthly_budget: $500 per environment
  alert_thresholds: [50%, 80%, 100%, 120%]
  notification_targets: platform-team@company.com
  
Cost Anomaly Detection:
  threshold: 20% increase over 7-day average
  notification: Slack webhook + email
  evaluation_frequency: daily
```

### Cost Monitoring Dashboards
```yaml
CloudWatch Dashboard Metrics:
  ec2_costs: EC2 instance costs by instance type
  ebs_costs: EBS volume costs by volume type
  s3_costs: S3 storage costs by bucket and storage class
  data_transfer_costs: Network data transfer costs
  load_balancer_costs: ALB/NLB costs and LCU usage
  
Grafana Cost Dashboard:
  prometheus_metrics:
    - aws_billing_estimated_charges
    - aws_ec2_instance_cost_per_hour
    - aws_ebs_volume_cost_per_gb
    - aws_s3_bucket_size_bytes
  
Custom Metrics:
  cost_per_microservice: Allocated costs per service
  cost_per_request: Cost efficiency metrics
  resource_utilization_cost: Cost vs utilization correlation
```

### Budget Forecasting Models
```yaml
Monthly Cost Breakdown (Development):
  compute_costs:
    ec2_instances: $120 (3 t3.large spot instances)
    ebs_volumes: $25 (250GB total storage)
    
  storage_costs:
    s3_observability: $60 (with lifecycle policies)
    ebs_persistent: $40 (database and application storage)
    
  network_costs:
    load_balancers: $16 (single ALB)
    data_transfer: $20 (estimated)
    nat_gateway: $32 (single NAT gateway)
    
  total_monthly_cost: ~$313
  
Scaling Projections:
  staging_environment: 1.5x dev costs (~$470)
  production_environment: 3x dev costs (~$940)
  total_platform_cost: ~$1,723/month
```

### Cost Optimization Automation
```bash
# Automated cost optimization scripts
#!/bin/bash

# 1. Identify unused EBS volumes
aws ec2 describe-volumes --filters Name=status,Values=available \
  --query 'Volumes[].{VolumeId:VolumeId,Size:Size,CreateTime:CreateTime}'

# 2. Find unattached Elastic IPs
aws ec2 describe-addresses --query 'Addresses[?AssociationId==null].AllocationId'

# 3. Identify idle load balancers
aws elbv2 describe-load-balancers --query 'LoadBalancers[].LoadBalancerArn' | \
  xargs -I {} aws elbv2 describe-target-health --target-group-arn {}

# 4. Check for oversized instances
kubectl top nodes --sort-by=cpu
kubectl top nodes --sort-by=memory

# 5. Analyze S3 storage class optimization opportunities
aws s3api list-objects-v2 --bucket eks-learning-lab-dev-lgtm-prometheus \
  --query 'Contents[?LastModified<`2024-01-01`&&StorageClass==`STANDARD`]'
```

## Resource Utilization Analysis

### Compute Resource Analysis
```yaml
Target Utilization Metrics:
  cpu_utilization: 60-70% average
  memory_utilization: 70-80% average
  node_utilization: 70-80% average
  
Optimization Triggers:
  underutilized_nodes: < 40% utilization for 7 days
  oversized_pods: requests < 30% of limits for 7 days
  idle_services: < 10 requests/hour for 24 hours
  
Right-Sizing Recommendations:
  vertical_pod_autoscaler: Automatic resource recommendation
  cluster_autoscaler: Node count optimization
  horizontal_pod_autoscaler: Replica count optimization
```

### Storage Utilization Monitoring
```bash
# Monitor persistent volume usage
kubectl get pv -o custom-columns=NAME:.metadata.name,CAPACITY:.spec.capacity.storage,STATUS:.status.phase

# Check storage class usage
kubectl get pvc -A -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,STORAGECLASS:.spec.storageClassName,CAPACITY:.spec.resources.requests.storage

# Analyze S3 bucket growth trends
aws s3api list-objects-v2 --bucket eks-learning-lab-dev-lgtm-prometheus \
  --query 'Contents[].{Key:Key,Size:Size,LastModified:LastModified}' \
  --output table | awk '{sum+=$3} END {print "Total Size: " sum/1024/1024/1024 " GB"}'
```

### Network Utilization Analysis
```yaml
Network Metrics:
  ingress_traffic: Monitor via Ambassador metrics
  egress_traffic: CloudWatch VPC Flow Logs
  inter_service_traffic: Istio service mesh metrics
  
Cost Optimization:
  vpc_endpoints: Reduce NAT gateway usage
  cloudfront_caching: Reduce origin requests
  compression: Reduce data transfer volume
  
Monitoring Tools:
  aws_vpc_flow_logs: Network traffic analysis
  istio_telemetry: Service mesh traffic metrics
  prometheus_network_metrics: Container network usage
```

## Automated Cost Optimization

### Cost Optimization Automation Framework
```yaml
Automation Components:
  cost_anomaly_detection: AWS Cost Anomaly Detection
  resource_cleanup: Scheduled Lambda functions
  right_sizing_recommendations: AWS Compute Optimizer
  storage_optimization: S3 Intelligent Tiering
  
Scheduled Optimizations:
  daily:
    - Unused EBS volume cleanup
    - Unattached EIP cleanup
    - Idle load balancer identification
    
  weekly:
    - Resource utilization analysis
    - Right-sizing recommendations
    - Storage class optimization review
    
  monthly:
    - Cost trend analysis
    - Budget variance reporting
    - Optimization opportunity assessment
```

### Cost Optimization Hooks and Alerts
```yaml
CloudWatch Alarms:
  high_cost_anomaly:
    threshold: 20% increase over baseline
    action: SNS notification + Lambda investigation
    
  budget_threshold_exceeded:
    thresholds: [80%, 100%, 120%]
    actions: Email + Slack notification
    
  resource_utilization_low:
    cpu_threshold: < 30% for 24 hours
    memory_threshold: < 40% for 24 hours
    action: Right-sizing recommendation
    
Custom Metrics:
  cost_per_request: Application-level cost efficiency
  resource_waste_percentage: Unused resource allocation
  optimization_savings: Monthly savings from optimizations
```

### ROI Tracking and Reporting
```yaml
Cost Optimization ROI:
  spot_instances: 60-70% savings on compute
  s3_lifecycle: 60-80% savings on storage
  right_sizing: 20-30% savings on over-provisioned resources
  resource_cleanup: 10-15% savings on unused resources
  
Monthly Reporting:
  total_infrastructure_cost: Current month spend
  optimization_savings: Savings from optimization efforts
  cost_per_service: Allocated costs per microservice
  efficiency_metrics: Cost per request, cost per user
  
Forecasting:
  growth_projections: Based on usage trends
  optimization_opportunities: Identified savings potential
  budget_recommendations: Adjusted budget allocations
```