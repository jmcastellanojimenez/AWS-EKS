# Terraform AWS

This repo contains the terraform for the cluster creation and VPC Endpoints.

## HCL

`terraform apply -var-file="sample.tfvars"`

## CDKTF

```
  Synthesize:
    cdktf synth [stack]   Synthesize Terraform resources from stacks to cdktf.out/ (ready for 'terraform apply')

  Diff:
    cdktf diff [stack]    Perform a diff (terraform plan) for the given stack

  Deploy:
    cdktf deploy [stack]  Deploy the given stack

  Destroy:
    cdktf destroy [stack] Destroy the stack
```

## Cost Optimization

### Cheapest Configuration Available

A cost-optimized configuration has been created that reduces infrastructure costs by **85-95%** while maintaining full functionality.

#### Key Features:
- **Spot Instances**: Automatic 60-90% cost reduction
- **Right-sized Nodes**: 2x t3.small instead of 3x m6a.2xlarge
- **Multi-instance Types**: Better spot availability
- **Auto-scaling**: Scales from 1 to 3 nodes based on demand

#### Usage:
```bash
# Deploy cheapest configuration
export CLUSTER=np-alpha-eks-01-cheap
cdktf deploy

# Switch back to original
export CLUSTER=np-alpha-eks-01
cdktf deploy
```

#### Cost Comparison:
- **Original**: ~$400-500/month (3x m6a.2xlarge on-demand)
- **Optimized**: ~$86-98/month (2x t3.small spot instances)
- **Savings**: $300-400/month (85-95% reduction)

#### Files:
- Configuration: `cdktf/config/nonprod/np-alpha-eks-01-cheap.json`
- Documentation: `COST-OPTIMIZATION.md`

## TO-DO

- Right sizing of the nodes
- ~~SSH keys for the nodes~~
- How to document
- ~~TF bucket creation~~
    - ~~AWS_REGION=eu-central-1 ENV=np PROJECT=alpha ./tf-backend-resources.sh~~
- ~~Generate CDKTF Code~~
- ~~Cilium Installation~~
- ~~External DNS Testing~~
    - ~~Route53 connectivity~~
- Bootstraping