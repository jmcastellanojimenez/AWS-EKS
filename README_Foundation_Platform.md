# 🏗️ Foundation Platform Deployment

This document describes the infrastructure resources deployed by the **Foundation Platform** GitHub workflow.

## 📋 Overview

The Foundation Platform workflow deploys the core Kubernetes infrastructure on AWS, establishing the base layer for all subsequent platform components.

## ✅ Deployed Resources (98 Total)

### 🌐 VPC & Networking Infrastructure

- **VPC**: Main virtual private cloud for the platform
- **Subnets**: 3 public + 3 private subnets distributed across multiple availability zones
- **NAT Gateway**: Enables outbound internet connectivity for private subnets (~2 minute deployment)
- **Internet Gateway**: Provides internet access for public subnets
- **Route Tables**: Configured for both public and private subnet routing
- **Security Groups**: Cluster and node security groups with appropriate ingress/egress rules

### 🏗️ EKS Cluster Infrastructure

- **EKS Cluster**: Primary Kubernetes cluster (~10 minute deployment)
- **Cluster Endpoint**: HTTPS API endpoint for cluster management
- **Node Groups**:
  - **System nodes**: Dedicated nodes for system workloads
  - **Workload nodes**: Nodes for application workloads
- **EKS Add-ons**:
  - `vpc-cni`: Container Network Interface for pod networking
  - `kube-proxy`: Network proxy for service load balancing
  - `coredns`: DNS server for service discovery
  - `aws-ebs-csi-driver`: Persistent storage driver

### 🔐 Security & IAM

- **OIDC Provider**: Enables IAM roles for service accounts (IRSA)
- **Service Account Roles**:
  - EBS CSI Driver role for storage management
  - Cluster Autoscaler role for node scaling
  - Load Balancer Controller role for ingress management
  - EKS Admins role for cluster administration
  - Observability roles for monitoring stack (Prometheus, Loki, Tempo)
- **KMS Key**: Encryption key for EKS secrets and persistent volumes

### 🪣 Storage Infrastructure

- **S3 Buckets for Observability**:
  - Prometheus metrics storage bucket
  - Loki logs storage bucket
  - Tempo traces storage bucket
- **Lifecycle Policies**:
  - 30 days → Infrequent Access (IA)
  - 90 days → Glacier storage
  - 365 days → Automatic expiration
- **Versioning**: Enabled on all storage buckets for data protection

## 🚀 Next Steps

After successful Foundation Platform deployment:

1. **Verify cluster access**: Configure kubectl with the deployed cluster
2. **Deploy additional stacks**: Foundation enables deployment of:
   - Ingress + API Gateway Stack
   - LGTM Observability Stack
   - GitOps Deployment Automation
   - Security Foundation
   - Service Mesh
   - Data Services

## 📊 Resource Allocation

- **Estimated deployment time**: ~12-15 minutes
- **Core infrastructure**: VPC, EKS cluster, IAM roles
- **Storage**: S3 buckets with lifecycle management
- **Security**: KMS encryption and OIDC integration

## 🔧 Management

This infrastructure is managed through Terraform and deployed via GitHub Actions workflow. All resources follow AWS best practices for security, networking, and cost optimization.