#!/bin/bash
set -euo pipefail

# Core Tools Installation Script
# Installs essential Kubernetes tools for learning and development

ENVIRONMENT=${1:-dev}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/tmp/install-core-${ENVIRONMENT}.log"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}" | tee -a "$LOG_FILE"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}" | tee -a "$LOG_FILE"
}

info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1${NC}" | tee -a "$LOG_FILE"
}

# Check if kubectl is available and cluster is accessible
check_cluster_access() {
    log "Checking Kubernetes cluster access..."
    
    if ! command -v kubectl &> /dev/null; then
        error "kubectl is not installed or not in PATH"
        exit 1
    fi
    
    if ! kubectl cluster-info &> /dev/null; then
        error "Cannot access Kubernetes cluster. Please check your kubeconfig"
        exit 1
    fi
    
    CLUSTER_NAME=$(kubectl config current-context | cut -d'/' -f2 2>/dev/null || echo "unknown")
    log "Connected to cluster: $CLUSTER_NAME"
}

# Install Helm if not present
install_helm() {
    if command -v helm &> /dev/null; then
        log "Helm already installed: $(helm version --short)"
        return 0
    fi
    
    log "Installing Helm..."
    curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    
    # Add stable repo
    helm repo add stable https://charts.helm.sh/stable
    helm repo update
    
    log "Helm installed successfully"
}

# Install AWS Load Balancer Controller
install_aws_load_balancer_controller() {
    log "Installing AWS Load Balancer Controller..."
    
    # Add EKS Helm repository
    helm repo add eks https://aws.github.io/eks-charts
    helm repo update
    
    # Get cluster information
    CLUSTER_NAME=$(kubectl config current-context | cut -d'/' -f2 2>/dev/null || echo "eks-learning-lab-${ENVIRONMENT}")
    REGION=$(aws configure get region || echo "us-east-1")
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    
    # Install AWS Load Balancer Controller
    helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
        --namespace kube-system \
        --set clusterName="$CLUSTER_NAME" \
        --set serviceAccount.create=true \
        --set serviceAccount.name=aws-load-balancer-controller \
        --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"="arn:aws:iam::${ACCOUNT_ID}:role/eks-learning-lab-${ENVIRONMENT}-aws-load-balancer-controller" \
        --set region="$REGION" \
        --set vpcId=$(kubectl get nodes -o jsonpath='{.items[0].spec.providerID}' | cut -d'/' -f4 | xargs aws ec2 describe-instances --instance-ids --query 'Reservations[0].Instances[0].VpcId' --output text) \
        --wait --timeout=900s
    
    log "AWS Load Balancer Controller installed successfully"
}

# Install Cluster Autoscaler
install_cluster_autoscaler() {
    log "Installing Cluster Autoscaler..."
    
    CLUSTER_NAME=$(kubectl config current-context | cut -d'/' -f2 2>/dev/null || echo "eks-learning-lab-${ENVIRONMENT}")
    REGION=$(aws configure get region || echo "us-east-1")
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    
    # Create service account
    kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  labels:
    k8s-addon: cluster-autoscaler.addons.k8s.io
    k8s-app: cluster-autoscaler
  name: cluster-autoscaler
  namespace: kube-system
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::${ACCOUNT_ID}:role/eks-learning-lab-${ENVIRONMENT}-cluster-autoscaler
EOF
    
    # Install cluster autoscaler
    kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cluster-autoscaler
  namespace: kube-system
  labels:
    app: cluster-autoscaler
spec:
  replicas: 1
  selector:
    matchLabels:
      app: cluster-autoscaler
  template:
    metadata:
      labels:
        app: cluster-autoscaler
      annotations:
        prometheus.io/scrape: 'true'
        prometheus.io/port: '8085'
    spec:
      serviceAccountName: cluster-autoscaler
      containers:
      - image: k8s.gcr.io/autoscaling/cluster-autoscaler:v1.28.2
        name: cluster-autoscaler
        resources:
          limits:
            cpu: 100m
            memory: 300Mi
          requests:
            cpu: 100m
            memory: 300Mi
        command:
        - ./cluster-autoscaler
        - --v=4
        - --stderrthreshold=info
        - --cloud-provider=aws
        - --skip-nodes-with-local-storage=false
        - --expander=least-waste
        - --node-group-auto-discovery=asg:tag=k8s.io/cluster-autoscaler/enabled,k8s.io/cluster-autoscaler/${CLUSTER_NAME}
        - --balance-similar-node-groups
        - --skip-nodes-with-system-pods=false
        env:
        - name: AWS_REGION
          value: ${REGION}
        volumeMounts:
        - name: ssl-certs
          mountPath: /etc/ssl/certs/ca-certificates.crt
          readOnly: true
        imagePullPolicy: Always
      volumes:
      - name: ssl-certs
        hostPath:
          path: "/etc/ssl/certs/ca-bundle.crt"
EOF
    
    log "Cluster Autoscaler installed successfully"
}

# Install Metrics Server
install_metrics_server() {
    log "Installing Metrics Server..."
    
    kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
    
    # Wait for metrics server to be ready
    kubectl wait --for=condition=available --timeout=600s deployment/metrics-server -n kube-system
    
    log "Metrics Server installed successfully"
}

# Install Kubernetes Dashboard
install_kubernetes_dashboard() {
    log "Installing Kubernetes Dashboard..."
    
    # Add kubernetes-dashboard repository
    helm repo add kubernetes-dashboard https://kubernetes.github.io/dashboard/
    helm repo update
    
    # Install Kubernetes Dashboard
    helm upgrade --install kubernetes-dashboard kubernetes-dashboard/kubernetes-dashboard \
        --create-namespace \
        --namespace kubernetes-dashboard \
        --set service.type=ClusterIP \
        --set protocolHttp=true \
        --set serviceAccount.create=true \
        --set serviceAccount.name=kubernetes-dashboard \
        --set rbac.create=true \
        --timeout=600s
    
    # Create admin user for dashboard
    kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kubernetes-dashboard
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: admin-user
  namespace: kubernetes-dashboard
EOF
    
    log "Kubernetes Dashboard installed successfully"
    info "To access the dashboard:"
    info "1. Run: kubectl -n kubernetes-dashboard port-forward svc/kubernetes-dashboard-kong-proxy 8443:443"
    info "2. Open: https://localhost:8443"
    info "3. Get token: kubectl -n kubernetes-dashboard create token admin-user"
}

# Install Container Insights (CloudWatch)
install_container_insights() {
    log "Installing Container Insights for CloudWatch..."
    
    CLUSTER_NAME=$(kubectl config current-context | cut -d'/' -f2 2>/dev/null || echo "eks-learning-lab-${ENVIRONMENT}")
    REGION=$(aws configure get region || echo "us-east-1")
    
    # Create namespace first
    kubectl create namespace amazon-cloudwatch || true
    
    # Download and apply CloudWatch agent
    curl -o cloudwatch-config.json https://raw.githubusercontent.com/aws-samples/amazon-cloudwatch-container-insights/latest/k8s-deployment-manifest-templates/deployment-mode/daemonset/container-insights-monitoring/cloudwatch-config.json
    
    kubectl create configmap cluster-info \
        --from-literal=cluster.name="$CLUSTER_NAME" \
        --from-literal=logs.region="$REGION" \
        -n amazon-cloudwatch || true
    
    kubectl apply -f https://raw.githubusercontent.com/aws-samples/amazon-cloudwatch-container-insights/latest/k8s-deployment-manifest-templates/deployment-mode/daemonset/container-insights-monitoring/cwagent/cwagent-daemonset.yaml
    
    # Note: Using fluent-bit instead of fluentd (more lightweight and actively maintained)
    kubectl apply -f https://raw.githubusercontent.com/aws-samples/amazon-cloudwatch-container-insights/latest/k8s-deployment-manifest-templates/deployment-mode/daemonset/container-insights-monitoring/fluent-bit/fluent-bit-daemonset-cloudwatch.yaml || {
        log "FluentBit installation failed, Container Insights will work with CloudWatch agent only"
    }
    
    log "Container Insights installed successfully"
}

# Create storage classes for different use cases
create_storage_classes() {
    log "Creating storage classes..."
    
    kubectl apply -f - <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: gp3-encrypted
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  encrypted: "true"
  throughput: "125"
  iops: "3000"
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: gp3-fast
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  encrypted: "true"
  throughput: "250"
  iops: "6000"
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: io2-high-performance
provisioner: ebs.csi.aws.com
parameters:
  type: io2
  encrypted: "true"
  iops: "10000"
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
EOF
    
    log "Storage classes created successfully"
}

# Install Node Problem Detector
install_node_problem_detector() {
    log "Installing Node Problem Detector..."
    
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/node-problem-detector/master/deployment/node-problem-detector.yaml
    
    log "Node Problem Detector installed successfully"
}

# Verify installations
verify_installations() {
    log "Verifying core tool installations..."
    
    local failed=0
    
    # Check AWS Load Balancer Controller
    if kubectl get deployment -n kube-system aws-load-balancer-controller &> /dev/null; then
        log "✅ AWS Load Balancer Controller: Running"
    else
        error "❌ AWS Load Balancer Controller: Failed"
        failed=1
    fi
    
    # Check Cluster Autoscaler
    if kubectl get deployment -n kube-system cluster-autoscaler &> /dev/null; then
        log "✅ Cluster Autoscaler: Running"
    else
        error "❌ Cluster Autoscaler: Failed"
        failed=1
    fi
    
    # Check Metrics Server
    if kubectl get deployment -n kube-system metrics-server &> /dev/null; then
        log "✅ Metrics Server: Running"
    else
        error "❌ Metrics Server: Failed"
        failed=1
    fi
    
    # Check Kubernetes Dashboard
    if kubectl get deployment -n kubernetes-dashboard &> /dev/null; then
        log "✅ Kubernetes Dashboard: Running"
    else
        error "❌ Kubernetes Dashboard: Failed"
        failed=1
    fi
    
    return $failed
}

# Print summary
print_summary() {
    log "Core tools installation completed!"
    info ""
    info "Installed tools:"
    info "  • AWS Load Balancer Controller - Manages ALB/NLB for services"
    info "  • Cluster Autoscaler - Automatically scales nodes based on demand"
    info "  • Metrics Server - Collects resource metrics"
    info "  • Kubernetes Dashboard - Web UI for cluster management"
    info "  • Container Insights - CloudWatch monitoring"
    info "  • Storage Classes - Various EBS storage options"
    info "  • Node Problem Detector - Monitors node health"
    info ""
    info "Next steps:"
    info "  1. Access Dashboard: kubectl -n kubernetes-dashboard port-forward svc/kubernetes-dashboard-kong-proxy 8443:443"
    info "  2. Get Dashboard token: kubectl -n kubernetes-dashboard create token admin-user"  
    info "  3. Install additional tools with: ./install-gitops.sh $ENVIRONMENT"
    info ""
    info "Log file: $LOG_FILE"
}

# Main execution
main() {
    log "Starting core tools installation for environment: $ENVIRONMENT"
    
    check_cluster_access
    install_helm
    install_aws_load_balancer_controller
    install_cluster_autoscaler
    install_metrics_server
    install_kubernetes_dashboard
    install_container_insights
    create_storage_classes
    install_node_problem_detector
    
    if verify_installations; then
        print_summary
        log "All core tools installed successfully! ✅"
        exit 0
    else
        error "Some installations failed. Check the log file: $LOG_FILE"
        exit 1
    fi
}

# Run main function
main "$@"