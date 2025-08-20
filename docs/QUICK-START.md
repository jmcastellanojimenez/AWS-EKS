# 🚀 Quick Start Guide

Get up and running with EKS and ingress patterns in 15 minutes.

## 📋 Prerequisites

### Required Tools
- AWS CLI configured with appropriate permissions
- GitHub account with repository access
- Basic understanding of Kubernetes concepts

### Required GitHub Secrets
Set these in your repository settings:
```
AWS_ROLE_ARN=arn:aws:iam::ACCOUNT:role/github-actions-role
AWS_REGION=us-east-1  
AWS_ACCOUNT_ID=123456789012
SLACK_WEBHOOK_URL=https://hooks.slack.com/... (optional)
```

---

## 🎯 15-Minute Setup

### Step 1: Deploy EKS Infrastructure (5 minutes)

1. **Navigate to Actions** → 🚀 EKS Infrastructure Management
2. **Configure workflow:**
   ```yaml
   Action: apply
   Environment: dev
   Auto Approve: false
   ```
3. **Click "Run workflow"** and wait ~5 minutes

**What gets created:**
- VPC with public/private subnets
- EKS cluster with 2 t3.medium SPOT nodes
- Essential add-ons (VPC-CNI, CoreDNS, EBS CSI)
- Cost: ~$88/month

### Step 2: Choose Your Ingress Pattern

#### Option A: AWS ALB Pattern (Recommended for beginners)
- **Best for:** AWS-native applications, simple requirements
- **Benefits:** Native AWS integration, built-in WAF support
- **Cost:** Base + $16.50/month

#### Option B: NGINX Pattern  
- **Best for:** Complex routing, multi-cloud strategy
- **Benefits:** Advanced features, vendor-neutral
- **Cost:** Base + $16.50/month

### Step 3: Deploy Ingress Pattern (8 minutes)

1. **Navigate to Actions** → 🚀 Deploy Kubernetes Ingress Patterns
2. **Configure workflow:**
   ```yaml
   Pattern: alb                    # or nginx
   Deploy Apps: true              # Includes demo app
   Dry Run: false
   Environment: dev
   Domain: k8s-demo.local         # Default is fine
   Hosted Zone ID: [leave empty]  # Auto-creates
   ```
3. **Click "Run workflow"** and wait ~8 minutes

**What gets deployed:**
- Ingress controller (ALB or NGINX)
- External-DNS for Route53 automation
- cert-manager for SSL certificates
- Demo application for testing
- Automatic DNS and SSL setup

### Step 4: Test Your Deployment (2 minutes)

1. **Navigate to Actions** → 🧪 Test Kubernetes Ingress
2. **Configure workflow:**
   ```yaml
   Pattern: alb                   # Match your choice
   Environment: dev
   Domain: k8s-demo.local
   ```
3. **Click "Run workflow"** and verify all tests pass

---

## ✅ Success! What You Now Have

### Working Infrastructure
- **EKS Cluster**: Production-ready with 2 worker nodes
- **Load Balancer**: ALB or NLB automatically provisioned
- **DNS**: Automatic Route53 record management
- **SSL**: Let's Encrypt certificates (staging)
- **Demo App**: Working application for testing

### Access Your Application

#### Find Your Application URL
Check workflow logs or run:
```bash
kubectl get ingress
# Look for ADDRESS column - that's your load balancer URL
```

#### Test Connectivity
```bash
# Direct load balancer access
curl http://YOUR-LB-HOSTNAME.us-east-1.elb.amazonaws.com

# Via DNS (once propagated)
curl http://demo-alb.k8s-demo.local     # ALB pattern
curl http://demo-nginx.k8s-demo.local   # NGINX pattern

# HTTPS (once certificate issued)
curl https://demo-alb.k8s-demo.local
```

### Estimated Costs
- **Development Environment**: ~$105/month total
- **Base EKS**: $88/month (cluster + nodes)
- **Ingress Pattern**: $16.50/month (load balancer + Route53)

---

## 🎓 Next Steps

### Explore Features

#### Customize Domain
```yaml
# Deploy with your own domain
Domain: myapp.example.com
Hosted Zone ID: Z123456789ABCDEFG  # Your existing zone
```

#### Production Setup
1. Deploy to `staging` environment
2. Use production Let's Encrypt issuer
3. Configure monitoring and alerts
4. Set up CI/CD pipelines

#### Maintenance Operations
- **Update EKS Add-ons**: Run 🔧 Update EKS Add-ons workflow to keep cluster components current
- **Monitor Costs**: Use 💰 Daily AWS Cost Monitoring for ongoing cost optimization

#### Advanced Patterns
- Deploy both ALB and NGINX for comparison
- Set up multi-environment workflow
- Configure advanced routing rules
- Add authentication and authorization

### Learn More
- **[WORKFLOWS.md](./WORKFLOWS.md)**: Detailed workflow documentation
- **[INGRESS-PATTERNS.md](./INGRESS-PATTERNS.md)**: ALB vs NGINX comparison
- **[TROUBLESHOOTING.md](./TROUBLESHOOTING.md)**: Common issues and fixes

---

## 🧹 Cleanup When Done

### Clean Up Ingress Resources
```yaml
🧹 Cleanup Workflow:
Pattern: all
Environment: dev  
Confirmation: CONFIRM-CLEANUP
Cleanup Shared: true
```

### Destroy EKS Cluster
```yaml
🚀 EKS Infrastructure:
Action: destroy
Environment: dev
Confirmation: CONFIRM-DESTROY
```

**💰 Cleanup saves ~$105/month in AWS costs**

---

## 🆘 Troubleshooting Quick Fixes

### Common Issues

**"EntityAlreadyExists: Role already exists"**
→ Run cleanup workflow first

**"ALB not created"**  
→ Ensure `Deploy Apps: true` in workflow

**"SSL certificate not ready"**
→ Wait 5-10 minutes for Let's Encrypt validation

**"DNS not resolving"**
→ DNS propagation takes 5-60 minutes

### Get Help
- Check workflow logs in GitHub Actions
- Review [TROUBLESHOOTING.md](./TROUBLESHOOTING.md)
- Create GitHub issue with error details

---

## 🎯 Alternative Quick Starts

### Just EKS (No Ingress)
```yaml
# Deploy minimal EKS for learning
🚀 EKS Infrastructure: Action=apply, Environment=dev
# Skip ingress workflows
# Cost: ~$88/month
```

### Testing Only
```yaml
# Use dry-run for planning
🚀 Deploy Ingress: Dry Run=true
# Review Terraform plans without creating resources
# Cost: $0
```

### Multiple Patterns
```yaml
# Deploy ALB first
🚀 Deploy Ingress: Pattern=alb, Deploy Apps=true

# Then deploy NGINX  
🚀 Deploy Ingress: Pattern=nginx, Deploy Apps=true

# Compare both patterns side-by-side
# Cost: ~$138/month (base + 2 patterns)
```

---

## 📊 What's Created in AWS

After successful deployment, check AWS Console:

### EC2 Dashboard
- **Load Balancers**: 1 ALB or NLB
- **Target Groups**: With healthy targets
- **Security Groups**: Allowing HTTP/HTTPS traffic

### EKS Dashboard  
- **Cluster**: eks-learning-lab-dev
- **Node Groups**: 2 t3.medium SPOT instances
- **Add-ons**: VPC-CNI, CoreDNS, EBS CSI

### Route53 Dashboard
- **Hosted Zone**: k8s-demo.local
- **Records**: A record pointing to load balancer

### IAM Dashboard
- **Roles**: Controller service account roles
- **Policies**: Route53 and ELB permissions

---

**🎉 Congratulations! You now have a production-ready EKS cluster with ingress patterns deployed and ready for your applications!**

---

**Last Updated:** 2024-01-15  
**Total Setup Time:** ~15 minutes  
**Monthly Cost:** ~$105 (dev environment)