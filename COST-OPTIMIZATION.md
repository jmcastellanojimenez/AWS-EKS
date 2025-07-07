# EKS Cost Optimization Guide

## Cheapest Configuration Setup

### 1. Use the Cheap Configuration File
```bash
export CLUSTER=np-alpha-eks-01-cheap
cdktf deploy
```

### 2. Cost Comparison

#### Current Configuration (EXPENSIVE)
- **Nodes**: 3x m6a.2xlarge (8 vCPU, 32GB RAM each)
- **Capacity**: On-Demand
- **Monthly Cost**: ~$400-500/month

#### Optimized Configuration (CHEAP)
- **Nodes**: 2x t3.small (2 vCPU, 2GB RAM each) 
- **Capacity**: SPOT instances
- **Monthly Cost**: ~$15-25/month

### 3. Expected Savings: **85-95% reduction**

## Key Optimizations Applied

### ✅ Instance Type Changes
- **XS size**: Changed from `t3.micro` to `t3.small` (avoiding micro limits)
- **Multiple types**: `["t3.small", "t3a.small", "t2.small"]` for better spot availability
- **Reduced nodes**: From 3 to 2 nodes minimum

### ✅ Spot Instances
- **Capacity type**: Changed to `SPOT` for 60-90% savings
- **Interruption handling**: EKS manages spot interruptions automatically
- **Fallback types**: Multiple instance types prevent capacity issues

### ✅ Right-sizing
- **Min nodes**: 1 (auto-scaling down when not needed)
- **Max nodes**: 3 (limited capacity to control costs)
- **Desired**: 2 (minimal for HA)

## Trade-offs and Considerations

### ⚠️ Limitations
- **Memory**: Only 2GB RAM per node (suitable for small workloads)
- **Spot interruptions**: Possible but managed by EKS
- **Limited capacity**: May not handle large workloads

### ✅ Still Supports
- **Cilium**: DaemonSets work fine
- **ArgoCD**: Fits in 2GB nodes
- **Basic monitoring**: Prometheus/Grafana with resource limits
- **Auto-scaling**: Scales up to 3 nodes when needed

## Usage Commands

### Deploy Cheap Version
```bash
export CLUSTER=np-alpha-eks-01-cheap
cdktf synth
cdktf deploy
```

### Switch Back to Original
```bash
export CLUSTER=np-alpha-eks-01
cdktf deploy
```

### Monitor Costs
```bash
# Check node status
kubectl get nodes -o wide

# Check resource usage
kubectl top nodes
kubectl top pods --all-namespaces
```

## Best Practices for Cost Control

1. **Use resource limits** on all pods
2. **Enable cluster autoscaler** for dynamic scaling
3. **Monitor spot interruptions** with AWS CloudWatch
4. **Use horizontal pod autoscaling** for applications
5. **Set up cost alerts** in AWS Cost Explorer

## Expected Monthly Costs (eu-central-1)

```
EKS Control Plane:           $73.00
2x t3.small SPOT:           $8-12.00
Data transfer:              $2-5.00
EBS volumes:                $3-8.00
---------------------------------
Total:                      $86-98/month
```

**Total savings: ~$300-400/month** compared to original configuration.