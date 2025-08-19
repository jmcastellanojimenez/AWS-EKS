# Technology Stack

## Infrastructure as Code

- **Terraform/OpenTofu** - Primary IaC tool for AWS resource management
- **Terraform modules** - Reusable components in `terraform/modules/`
- **Environment-specific configurations** - Located in `terraform/environments/{env}/`
- **Remote state** - S3 backend with DynamoDB locking

## Container Orchestration

- **Amazon EKS** - Managed Kubernetes service (v1.28+)
- **Managed node groups** - t3.large instances with spot capacity
- **Essential add-ons**: vpc-cni, kube-proxy, coredns, aws-ebs-csi-driver
- **IRSA (IAM Roles for Service Accounts)** - Secure AWS service access

## Observability Stack (LGTM)

- **Prometheus** - Metrics collection and alerting
- **Mimir** - Long-term metrics storage (S3 backend)
- **Loki** - Log aggregation and querying
- **Tempo** - Distributed tracing (OpenTelemetry compatible)
- **Grafana** - Unified dashboards and visualization
- **Promtail** - Log shipping agent

## Ingress & Networking

- **Ambassador (Emissary-Ingress)** - API Gateway and ingress controller
- **cert-manager** - Automatic SSL certificate management (Let's Encrypt)
- **external-dns** - Automatic DNS record management (Cloudflare integration)
- **AWS Network Load Balancer** - L4 load balancing

## Storage & Data

- **Amazon EBS** - Persistent volumes via CSI driver
- **Amazon S3** - Object storage for logs, metrics, and traces
- **S3 lifecycle policies** - Cost optimization with IA/Glacier transitions

## Security

- **AWS KMS** - Encryption at rest for EKS secrets
- **Security groups** - Network-level access control
- **IRSA** - Pod-level AWS permissions without long-lived credentials
- **Private subnets** - Worker nodes isolated from internet

## Development & Deployment

- **GitHub Actions** - CI/CD workflows with manual triggers
- **Helm charts** - Kubernetes application packaging
- **kubectl** - Kubernetes CLI tool
- **AWS CLI** - AWS service management

## Common Commands

### Terraform Operations
```bash
# Initialize and plan
terraform init
terraform plan -var-file="terraform.tfvars"

# Apply changes
terraform apply -var-file="terraform.tfvars" -auto-approve

# Destroy infrastructure
terraform destroy -var-file="terraform.tfvars" -auto-approve
```

### Kubernetes Operations
```bash
# Get cluster credentials
aws eks update-kubeconfig --region us-east-1 --name <cluster-name>

# Check cluster status
kubectl get nodes
kubectl get pods -A

# Port forward to services
kubectl port-forward -n observability svc/grafana 3000:80
kubectl port-forward -n ambassador svc/ambassador-admin 8877:8877
```

### Observability Access
```bash
# Get Grafana admin password
kubectl get secret -n observability grafana-credentials -o jsonpath='{.data.admin-password}' | base64 -d

# Check component health
kubectl get pods -n observability
kubectl get pods -n ambassador
kubectl get pods -n cert-manager
```

### AWS Operations
```bash
# List S3 buckets for observability
aws s3 ls | grep lgtm

# Check EKS cluster status
aws eks describe-cluster --name <cluster-name>

# Verify IRSA configuration
aws iam list-attached-role-policies --role-name <role-name>
```

## Environment Variables

Key environment variables used in deployments:
- `AWS_REGION` - Target AWS region (default: us-east-1)
- `AWS_ACCOUNT_ID` - AWS account identifier
- `CLUSTER_NAME` - EKS cluster name
- `ENVIRONMENT` - Deployment environment (dev/staging/prod)
- `SLACK_WEBHOOK_URL` - Optional Slack integration for alerts