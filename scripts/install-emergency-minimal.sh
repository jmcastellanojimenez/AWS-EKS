#!/bin/bash
set -euo pipefail

# Emergency Ultra-Minimal Installation
# For extremely resource-constrained clusters (originally designed for t3.small)

ENVIRONMENT=${1:-dev}

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'  
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date +'%H:%M:%S')] $1${NC}"; }
warn() { echo -e "${YELLOW}[$(date +'%H:%M:%S')] WARNING: $1${NC}"; }
error() { echo -e "${RED}[$(date +'%H:%M:%S')] ERROR: $1${NC}"; }

# Emergency resource check
emergency_check() {
    log "🚨 Emergency resource check..."
    
    # Get actual pod limits
    available_pods=$(kubectl get nodes -o jsonpath='{.items[0].status.allocatable.pods}' 2>/dev/null || echo "11")
    current_pods=$(kubectl get pods --all-namespaces --no-headers 2>/dev/null | wc -l || echo "0")
    
    log "📊 Cluster Status:"
    log "  • Current pods: $current_pods"
    log "  • Node capacity: $available_pods" 
    log "  • Usage: $((current_pods * 100 / available_pods))%"
    
    if [ "$current_pods" -gt "$available_pods" ]; then
        error "🚨 CRITICAL: Cluster is OVER capacity!"
        error "This explains all the installation failures."
        error "The cluster is running $current_pods pods on nodes that can only handle $available_pods"
        
        log "📋 Diagnosis:"
        log "  • t3.small nodes had severe pod limits (now using t3.medium)"
        log "  • Core AWS tools + Kubernetes system pods = ~35-40 pods"
        log "  • Node capacity is only 11 pods per node"
        log "  • This is why Helm installations timeout/fail"
        
        log "💡 Solutions:"
        log "  1. Use t3.medium nodes (50+ pod capacity)" 
        log "  2. Reduce number of nodes to 1"
        log "  3. Remove some system components"
        log "  4. This was a known EKS + t3.small limitation (fixed with t3.medium)"
        
        warn "Proceeding with emergency mode - will not install anything new"
        warn "Focus will be on providing cluster information only"
        
        return 1
    fi
    
    return 0
}

# Create cluster info dashboard (no new pods)
create_cluster_info_only() {
    log "📊 Creating cluster information dashboard (no new pods)..."
    
    # Create a simple configmap with cluster information
    kubectl apply -f - <<EOF || true
apiVersion: v1
kind: ConfigMap
metadata:
  name: cluster-diagnosis
  namespace: default
data:
  diagnosis.html: |
    <!DOCTYPE html>
    <html>
    <head>
        <title>EKS Learning Lab - Cluster Diagnosis</title>
        <style>
            body { font-family: monospace; margin: 20px; background: #1a1a1a; color: #00ff00; }
            .card { background: #2a2a2a; padding: 20px; margin: 10px 0; border: 1px solid #444; }
            .error { color: #ff4444; }
            .warn { color: #ffaa00; }
            .ok { color: #44ff44; }
            pre { background: #333; padding: 10px; overflow-x: auto; }
        </style>
    </head>
    <body>
        <h1>🚨 EKS Learning Lab - Emergency Diagnosis</h1>
        
        <div class="card">
            <h2 class="error">❌ Critical Issue Detected</h2>
            <p><strong>Problem:</strong> Current nodes may be undersized for EKS workload</p>
            <p><strong>Pod Capacity:</strong> $available_pods per node</p>
            <p><strong>Current Usage:</strong> $current_pods pods (over capacity!)</p>
            <p><strong>Usage Percentage:</strong> $((current_pods * 100 / available_pods))%</p>
        </div>
        
        <div class="card">
            <h2 class="warn">📊 Resource Breakdown</h2>
            <p>Typical EKS pod usage on current nodes:</p>
            <ul>
                <li>kube-system pods: ~15-20</li>
                <li>AWS Load Balancer Controller: ~3</li>
                <li>Cluster Autoscaler: ~2</li>
                <li>Metrics Server: ~2</li>
                <li>Container Insights: ~5</li>
                <li>Your applications: ???</li>
                <li><strong>Total needed: 35-40+ pods</strong></li>
                <li><strong>Current capacity: Check node type</strong></li>
            </ul>
        </div>
        
        <div class="card">
            <h2 class="ok">✅ Solutions</h2>
            <ol>
                <li><strong>Use t3.medium nodes:</strong>
                    <pre>instance_type = "t3.medium"  # 50+ pod capacity</pre>
                </li>
                <li><strong>Reduce node count to 1:</strong>
                    <pre>min_size = 1
desired_capacity = 1
max_size = 1</pre>
                </li>
                <li><strong>Use Fargate:</strong> No node limits, pay per pod</li>
                <li><strong>Disable some AWS add-ons:</strong> Reduce core tools</li>
            </ol>
        </div>
        
        <div class="card">
            <h2>🛠️ Immediate Actions</h2>
            <p>To fix this cluster:</p>
            <pre>
# 1. Update terraform/modules/eks/main.tf:
   instance_types = ["t3.medium"]  # Should already be t3.medium

# 2. Or reduce nodes:
   min_size         = 1
   desired_capacity = 1 
   max_size         = 1

# 3. Apply changes:
   terraform plan
   terraform apply
            </pre>
        </div>
        
        <div class="card">
            <h2>💰 Cost Impact</h2>
            <p><strong>t3.medium (current):</strong> ~$40/month for 2 nodes</p>
            <p><strong>t3.medium:</strong> ~$40/month for 2 nodes</p>
            <p><strong>Savings:</strong> Still way cheaper than on-demand!</p>
        </div>
    </body>
    </html>
EOF
    
    log "✅ Cluster diagnosis created"
}

# Show cluster resource information
show_resource_info() {
    log "📊 Cluster Resource Information:"
    log ""
    
    # Show node information
    log "🖥️ Node Information:"
    kubectl get nodes -o wide 2>/dev/null || true
    log ""
    
    # Show top nodes if available
    log "📈 Node Resource Usage:"
    kubectl top nodes 2>/dev/null || warn "Metrics not available yet"
    log ""
    
    # Show pod distribution
    log "📦 Pod Distribution by Namespace:"
    kubectl get pods --all-namespaces | awk '{print $1}' | sort | uniq -c | head -10 2>/dev/null || true
    log ""
    
    # Show resource quotas
    log "📊 Resource Limits:"
    kubectl describe node | grep -A 5 "Allocated resources" 2>/dev/null | head -20 || true
    log ""
}

# Main execution
main() {
    log "🚨 EKS Learning Lab - Emergency Minimal Installation"
    log "🎯 Designed for severely resource-constrained clusters"
    log ""
    
    # Emergency check first
    if ! emergency_check; then
        log "⚠️ Cluster is over capacity - switching to emergency mode"
        
        # Just provide information, don't install anything
        create_cluster_info_only
        show_resource_info
        
        log ""
        log "🚨 SUMMARY:"
        log "❌ Cannot install new tools - cluster is over pod capacity"
        log "📊 Diagnosis dashboard created as ConfigMap"
        log "💡 Recommendation: Upgrade to t3.medium nodes"
        log ""
        log "🔍 To view diagnosis:"
        log "  kubectl get configmap cluster-diagnosis -o yaml"
        log ""
        log "💰 Cost to fix: +$20/month for t3.medium nodes"
        log "🎯 Benefit: 50+ pod capacity vs current 11"
        
        return 0
    fi
    
    log "✅ Cluster has sufficient capacity - would proceed with minimal installation"
    log "📊 Available pod slots: $((available_pods - current_pods))"
}

# Run main function
main "$@"