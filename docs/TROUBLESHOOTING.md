# 🚨 EKS Learning Lab - Troubleshooting Guide

Comprehensive troubleshooting guide for common issues and their solutions.

## 🎯 Quick Diagnosis

### 🔍 First Steps for Any Issue

1. **Check Cluster Status**
   ```bash
   kubectl cluster-info
   kubectl get nodes
   kubectl get pods --all-namespaces | grep -v Running
   ```

2. **Review Recent Events**
   ```bash
   kubectl get events --sort-by='.lastTimestamp' --all-namespaces
   ```

3. **Check GitHub Actions Logs**
   - Navigate to Actions tab in your repository
   - Review the most recent workflow runs
   - Look for failed steps with red X marks

4. **Verify AWS Resources**
   ```bash
   aws eks describe-cluster --name eks-learning-lab-dev
   aws ec2 describe-instances --filters "Name=tag:Name,Values=*eks-learning-lab*"
   ```

## 🚀 Deployment Issues

### Issue: Infrastructure Deployment Fails

#### Symptoms
- GitHub Actions workflow fails during Terraform apply
- Error: "ValidationException: 1 validation error detected"
- Resources stuck in CREATE_IN_PROGRESS

#### Common Causes & Solutions

**1. Insufficient AWS Permissions**
```bash
# Verify IAM role permissions
aws sts get-caller-identity
aws iam get-role --role-name GitHubActions-EKS-Deploy

# Solution: Ensure role has necessary policies
aws iam attach-role-policy \
    --role-name GitHubActions-EKS-Deploy \
    --policy-arn arn:aws:iam::aws:policy/AdministratorAccess
```

**2. Quota Limits Exceeded**
```bash
# Check service quotas
aws service-quotas get-service-quota \
    --service-code vpc \
    --quota-code L-F678F1CE

# Solution: Request quota increase or clean up resources
aws ec2 describe-vpcs --query 'Vpcs[?State==`available`]'
```

**3. Conflicting Resources**
```bash
# Check for existing resources
aws eks list-clusters
aws ec2 describe-vpcs --filters "Name=tag:Project,Values=eks-learning-lab"

# Solution: Either delete conflicts or modify resource names
terraform state list
terraform state rm aws_vpc.main  # If needed
```

**4. Terraform State Issues**
```bash
# Check state file
aws s3 ls s3://eks-learning-lab-terraform-state-${AWS_ACCOUNT_ID}/
aws dynamodb describe-table --table-name eks-learning-lab-terraform-lock

# Solution: Recover or reset state
terraform force-unlock <lock-id>
terraform refresh
```

### Issue: EKS Cluster Creation Timeout

#### Symptoms
- Cluster creation takes >20 minutes
- Nodes not joining cluster
- Cluster status shows CREATING for extended time

#### Solutions

**1. Check Subnet Configuration**
```bash
# Verify subnets have correct tags
aws ec2 describe-subnets \
    --filters "Name=tag:kubernetes.io/cluster/eks-learning-lab-dev,Values=owned"

# Should show at least 2 subnets in different AZs
```

**2. Security Group Rules**
```bash
# Check cluster security group
CLUSTER_SG=$(aws eks describe-cluster \
    --name eks-learning-lab-dev \
    --query 'cluster.resourcesVpcConfig.clusterSecurityGroupId' \
    --output text)

aws ec2 describe-security-groups --group-ids $CLUSTER_SG
```

**3. IAM Role Trust Relationships**
```bash
# Verify EKS service role
aws iam get-role --role-name eks-learning-lab-dev-eks-cluster-role
aws iam list-attached-role-policies --role-name eks-learning-lab-dev-eks-cluster-role
```

### Issue: Node Group Creation Fails

#### Symptoms
- Nodes show "NotReady" status
- EC2 instances launch but don't join cluster
- Node group stuck in CREATE_FAILED

#### Solutions

**1. Check Node IAM Role**
```bash
# Verify node group role permissions
aws iam get-role --role-name eks-learning-lab-dev-eks-node-group-role
aws iam list-attached-role-policies --role-name eks-learning-lab-dev-eks-node-group-role

# Required policies:
# - AmazonEKSWorkerNodePolicy
# - AmazonEKS_CNI_Policy  
# - AmazonEC2ContainerRegistryReadOnly
```

**2. Subnet and Security Group Issues**
```bash
# Check if subnets have internet access
aws ec2 describe-route-tables \
    --filters "Name=association.subnet-id,Values=subnet-xxxxx"

# Verify security groups allow required traffic
aws ec2 describe-security-groups --group-ids sg-xxxxx
```

**3. Launch Template Issues**
```bash
# Check launch template configuration
aws ec2 describe-launch-templates \
    --filters "Name=tag:Name,Values=*eks-learning-lab*"

# Verify user data script
aws ec2 describe-launch-template-versions \
    --launch-template-id lt-xxxxx
```

## 🛠️ Tool Installation Issues

### Issue: Tool Installation Timeouts

#### Symptoms
- GitHub Actions workflow fails during tool installation
- Pods stuck in Pending or ContainerCreating state
- Helm installations timeout

#### Solutions

**1. Check Node Resources**
```bash
# Verify node capacity
kubectl describe nodes
kubectl top nodes  # Requires metrics server

# Check for resource pressure
kubectl get events --field-selector reason=FailedScheduling
```

**2. Image Pull Issues**
```bash
# Check image pull secrets
kubectl get secrets --all-namespaces | grep docker

# Verify image accessibility
docker pull <image-name>

# Check registry credentials
kubectl describe pod <pod-name> -n <namespace>
```

**3. Persistent Volume Issues**
```bash
# Check storage classes
kubectl get storageclass

# Verify EBS CSI driver
kubectl get pods -n kube-system | grep ebs-csi

# Check PVC status
kubectl get pvc --all-namespaces
kubectl describe pvc <pvc-name> -n <namespace>
```

### Issue: ArgoCD Installation Fails

#### Symptoms
- ArgoCD pods crash or fail to start
- UI not accessible
- Applications not syncing

#### Solutions

**1. Check ArgoCD Components**
```bash
# Verify all components are running
kubectl get pods -n argocd
kubectl get svc -n argocd

# Check logs for errors
kubectl logs -n argocd deployment/argocd-server
kubectl logs -n argocd deployment/argocd-repo-server
```

**2. Resource Constraints**
```bash
# Check resource usage
kubectl top pods -n argocd
kubectl describe pod <argocd-pod> -n argocd

# Increase resources if needed
kubectl patch deployment argocd-server -n argocd -p '{"spec":{"template":{"spec":{"containers":[{"name":"argocd-server","resources":{"limits":{"memory":"512Mi"}}}]}}}}'
```

**3. RBAC Issues**
```bash
# Check service account permissions
kubectl get clusterrolebinding | grep argocd
kubectl describe clusterrolebinding argocd-server

# Verify API access
kubectl auth can-i create applications --as=system:serviceaccount:argocd:argocd-server
```

### Issue: Prometheus/Grafana Issues

#### Symptoms
- Metrics not collecting
- Grafana dashboards empty
- Alerts not firing

#### Solutions

**1. Check Prometheus Configuration**
```bash
# Verify Prometheus is scraping targets
kubectl port-forward svc/prometheus-kube-prometheus-prometheus -n monitoring 9090:9090
# Visit http://localhost:9090/targets

# Check configuration
kubectl get prometheus -n monitoring -o yaml
kubectl get servicemonitor --all-namespaces
```

**2. Storage Issues**
```bash
# Check persistent volumes
kubectl get pv | grep prometheus
kubectl get pvc -n monitoring

# Verify storage class
kubectl describe storageclass gp3-encrypted
```

**3. Grafana Data Source**
```bash
# Check Grafana configuration
kubectl get secret -n monitoring prometheus-grafana -o yaml
kubectl logs -n monitoring deployment/prometheus-grafana

# Test data source connectivity
kubectl exec -it -n monitoring deployment/prometheus-grafana -- \
    curl http://prometheus-kube-prometheus-prometheus:9090/api/v1/query?query=up
```

## 🔒 Security and Access Issues

### Issue: Cannot Access Cluster

#### Symptoms
- `kubectl` commands fail with authentication errors
- "error: You must be logged in to the server"
- Connection timeouts

#### Solutions

**1. Update Kubeconfig**
```bash
# Refresh kubeconfig
aws eks update-kubeconfig --region us-east-1 --name eks-learning-lab-dev

# Verify configuration
kubectl config current-context
kubectl config view --minify
```

**2. Check AWS Credentials**
```bash
# Verify AWS credentials
aws sts get-caller-identity
aws configure list

# Check assume role capability
aws sts assume-role \
    --role-arn arn:aws:iam::011921741593:role/GitHubActions-EKS-Deploy \
    --role-session-name test-session
```

**3. RBAC Issues**
```bash
# Check your permissions
kubectl auth can-i --list
kubectl auth can-i get pods --all-namespaces

# If using IAM user, check ConfigMap
kubectl describe configmap aws-auth -n kube-system
```

### Issue: Pod Security Policy Violations

#### Symptoms
- Pods fail to start with security policy errors
- "pods 'pod-name' is forbidden: violates PodSecurity"
- Security context errors

#### Solutions

**1. Check Pod Security Standards**
```bash
# View namespace security labels
kubectl get namespaces --show-labels

# Check specific namespace
kubectl describe namespace <namespace>
```

**2. Fix Security Context**
```yaml
# Add proper security context
apiVersion: v1
kind: Pod
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    fsGroup: 2000
  containers:
  - name: app
    securityContext:
      allowPrivilegeEscalation: false
      capabilities:
        drop:
        - ALL
      readOnlyRootFilesystem: true
```

**3. Update Namespace Security Level**
```bash
# Relax security for development (temporarily)
kubectl label namespace default pod-security.kubernetes.io/enforce=baseline
```

## 💰 Cost and Resource Issues

### Issue: Unexpected High Costs

#### Symptoms
- AWS bill higher than expected
- Budget alerts firing
- Resource usage alerts

#### Solutions

**1. Identify Cost Drivers**
```bash
# Check running resources
aws ec2 describe-instances --filters "Name=instance-state-name,Values=running"
aws elbv2 describe-load-balancers
aws ec2 describe-volumes --filters "Name=status,Values=in-use"

# Use cost estimation script
./scripts/cost-estimate.sh dev
```

**2. Right-Size Resources**
```bash
# Check resource utilization
kubectl top nodes
kubectl top pods --all-namespaces

# Identify over-provisioned resources
kubectl describe nodes | grep -A 5 "Allocated resources"
```

**3. Clean Up Unused Resources**
```bash
# Run cleanup script
./scripts/cleanup-resources.sh dev true  # Dry run first
./scripts/cleanup-resources.sh dev false # Actual cleanup
```

### Issue: Resource Exhaustion

#### Symptoms
- Pods stuck in Pending state
- Node pressure conditions
- OOMKilled containers

#### Solutions

**1. Scale Cluster**
```bash
# Check current capacity
kubectl describe nodes

# Scale node group
aws eks update-nodegroup-config \
    --cluster-name eks-learning-lab-dev \
    --nodegroup-name <nodegroup-name> \
    --scaling-config minSize=1,maxSize=4,desiredSize=2
```

**2. Optimize Resource Requests**
```bash
# Check resource requests vs usage
kubectl top pods --all-namespaces --sort-by=cpu
kubectl top pods --all-namespaces --sort-by=memory

# Adjust resource requests
kubectl patch deployment <deployment-name> -p '{"spec":{"template":{"spec":{"containers":[{"name":"<container-name>","resources":{"requests":{"memory":"128Mi","cpu":"100m"}}}]}}}}'
```

## 🌐 Networking Issues

### Issue: Service Not Accessible

#### Symptoms
- Cannot reach services externally
- Load balancer not created
- DNS resolution failures

#### Solutions

**1. Check Service Configuration**
```bash
# Verify service exists and has endpoints
kubectl get svc --all-namespaces
kubectl get endpoints <service-name> -n <namespace>
kubectl describe svc <service-name> -n <namespace>
```

**2. AWS Load Balancer Controller**
```bash
# Check controller is running
kubectl get pods -n kube-system | grep aws-load-balancer-controller

# Check logs for errors
kubectl logs -n kube-system deployment/aws-load-balancer-controller

# Verify IAM permissions
aws iam get-role --role-name eks-learning-lab-dev-aws-load-balancer-controller
```

**3. Security Group Issues**
```bash
# Check security groups
aws ec2 describe-security-groups \
    --filters "Name=tag:kubernetes.io/cluster/eks-learning-lab-dev,Values=owned"

# Verify ingress rules allow traffic
aws elbv2 describe-load-balancers
aws elbv2 describe-target-groups
```

### Issue: Pod-to-Pod Communication Problems

#### Symptoms
- Services cannot reach each other
- Network policies blocking traffic
- DNS resolution issues

#### Solutions

**1. Check CNI Plugin**
```bash
# Verify VPC CNI is healthy
kubectl get pods -n kube-system | grep aws-node
kubectl describe daemonset aws-node -n kube-system
```

**2. Test Network Connectivity**
```bash
# Create test pod for debugging
kubectl run test-pod --image=busybox -i --tty --rm -- /bin/sh

# Inside pod, test connectivity
nslookup kubernetes.default.svc.cluster.local
ping <service-name>.<namespace>.svc.cluster.local
```

**3. Network Policy Issues**
```bash
# Check for restrictive network policies
kubectl get networkpolicy --all-namespaces
kubectl describe networkpolicy <policy-name> -n <namespace>

# Temporarily remove policies for testing
kubectl delete networkpolicy <policy-name> -n <namespace>
```

## 🔍 Debugging Commands Cheat Sheet

### General Debugging
```bash
# Check cluster health
kubectl cluster-info dump --output-directory=/tmp/cluster-dump

# Get all resources in namespace
kubectl get all -n <namespace>

# Describe resource with events
kubectl describe <resource-type> <resource-name> -n <namespace>

# Get logs from multiple containers
kubectl logs <pod-name> -c <container-name> -n <namespace> --previous

# Execute commands in pod
kubectl exec -it <pod-name> -n <namespace> -- /bin/bash

# Port forward for local access
kubectl port-forward <pod-name> <local-port>:<pod-port> -n <namespace>
```

### Resource Analysis  
```bash
# Resource usage
kubectl top nodes
kubectl top pods --all-namespaces --sort-by=memory

# Resource quotas and limits
kubectl describe quota -n <namespace>
kubectl describe limitrange -n <namespace>

# PVC and storage
kubectl get pv,pvc --all-namespaces
kubectl describe storageclass <storage-class-name>
```

### Networking Debugging
```bash
# Service and endpoint analysis
kubectl get svc,ep --all-namespaces
kubectl describe ingress <ingress-name> -n <namespace>

# Network policies
kubectl get networkpolicy --all-namespaces -o wide
kubectl describe networkpolicy <policy-name> -n <namespace>

# DNS debugging
kubectl exec -it <pod-name> -- nslookup kubernetes.default.svc.cluster.local
kubectl exec -it <pod-name> -- cat /etc/resolv.conf
```

## 📞 Getting Help

### Internal Resources
- 📖 Check other documentation in `docs/` folder
- 🔍 Search GitHub Issues for similar problems
- 📊 Review monitoring dashboards for insights

### External Resources
- 🎯 [Kubernetes Troubleshooting Guide](https://kubernetes.io/docs/tasks/debug-application-cluster/)
- 🏗️ [AWS EKS Troubleshooting](https://docs.aws.amazon.com/eks/latest/userguide/troubleshooting.html) 
- 💬 [EKS Workshop Troubleshooting](https://www.eksworkshop.com/beginner/050_deploy/troubleshooting/)

### Community Support
- 👥 [Kubernetes Slack](https://kubernetes.slack.com/)
- 📋 [Stack Overflow - Kubernetes](https://stackoverflow.com/questions/tagged/kubernetes)
- 💻 [AWS re:Post](https://repost.aws/)

### Creating Support Issues

When creating a GitHub issue, include:
1. **Environment**: dev/staging/prod
2. **Error Message**: Full error with context
3. **Steps to Reproduce**: Clear reproduction steps
4. **Expected vs Actual**: What should happen vs what happened
5. **Logs**: Relevant logs from kubectl/GitHub Actions
6. **Configuration**: Any custom configurations applied

**Template for Bug Reports**:
```markdown
## Issue Description
Brief description of the problem

## Environment
- Environment: dev/staging/prod
- Kubernetes Version: 1.28
- Tool Version: (if applicable)

## Steps to Reproduce
1. Step one
2. Step two
3. Step three

## Expected Behavior
What should happen

## Actual Behavior  
What actually happened

## Logs
```
Paste relevant logs here
```

## Additional Context
Any other relevant information
```

---

**💡 Remember: Most issues have been encountered before. Search existing issues and documentation first, then don't hesitate to ask for help!**