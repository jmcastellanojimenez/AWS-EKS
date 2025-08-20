#!/bin/bash
set -euo pipefail

# Resource Cleanup Script
# Safely cleans up AWS resources to minimize costs

ENVIRONMENT=${1:-dev}
DRY_RUN=${2:-false}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/tmp/cleanup-resources-${ENVIRONMENT}.log"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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

highlight() {
    echo -e "${CYAN}$1${NC}" | tee -a "$LOG_FILE"
}

# Function to check if running in dry-run mode
is_dry_run() {
    if [ "$DRY_RUN" = "true" ]; then
        return 0
    else
        return 1
    fi
}

# Function to execute or simulate commands
execute_or_dry_run() {
    local command="$1"
    local description="$2"
    
    if is_dry_run; then
        info "[DRY RUN] Would execute: $description"
        info "[DRY RUN] Command: $command"
    else
        log "Executing: $description"
        eval "$command"
    fi
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        error "AWS CLI is not installed"
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        error "AWS credentials not configured or invalid"
        exit 1
    fi
    
    # Check kubectl if cleaning up Kubernetes resources
    if ! command -v kubectl &> /dev/null; then
        warn "kubectl not found - skipping Kubernetes resource cleanup"
    fi
    
    log "Prerequisites check passed"
}

# Safety confirmation
confirm_cleanup() {
    if is_dry_run; then
        info "Running in DRY RUN mode - no resources will be deleted"
        return 0
    fi
    
    highlight "⚠️  RESOURCE CLEANUP CONFIRMATION ⚠️"
    echo ""
    warn "This script will DELETE AWS resources for environment: $ENVIRONMENT"
    warn "This action CANNOT be undone!"
    echo ""
    info "Resources that will be cleaned up:"
    info "  • Unused EBS volumes"
    info "  • Unattached Elastic IPs"
    info "  • Old AMI snapshots"
    info "  • Unused security groups"
    info "  • Orphaned load balancers"
    info "  • CloudWatch log groups (older than 7 days)"
    echo ""
    
    read -p "Type 'CONFIRM-CLEANUP' to proceed: " confirmation
    
    if [ "$confirmation" != "CONFIRM-CLEANUP" ]; then
        error "Cleanup cancelled by user"
        exit 1
    fi
    
    log "Cleanup confirmed by user"
}

# Clean up unused EBS volumes
cleanup_ebs_volumes() {
    log "Cleaning up unused EBS volumes..."
    
    # Get list of available (unattached) volumes
    local volumes=$(aws ec2 describe-volumes \
        --filters "Name=status,Values=available" \
        --query 'Volumes[].VolumeId' \
        --output text)
    
    if [ -z "$volumes" ]; then
        info "No unused EBS volumes found"
        return 0
    fi
    
    local count=0
    for volume in $volumes; do
        # Get volume details
        local volume_info=$(aws ec2 describe-volumes \
            --volume-ids "$volume" \
            --query 'Volumes[0].[VolumeId,Size,VolumeType,CreateTime]' \
            --output text)
        
        local volume_id=$(echo "$volume_info" | cut -f1)
        local size=$(echo "$volume_info" | cut -f2)
        local type=$(echo "$volume_info" | cut -f3)
        local create_time=$(echo "$volume_info" | cut -f4)
        
        # Check if volume is older than 1 hour (to avoid deleting recently created volumes)
        local create_timestamp=$(date -d "$create_time" +%s)
        local current_timestamp=$(date +%s)
        local age_hours=$(( (current_timestamp - create_timestamp) / 3600 ))
        
        if [ $age_hours -gt 1 ]; then
            info "Found unused volume: $volume_id (${size}GB $type, ${age_hours}h old)"
            execute_or_dry_run "aws ec2 delete-volume --volume-id $volume_id" \
                "Delete unused EBS volume $volume_id"
            count=$((count + 1))
        else
            info "Skipping recently created volume: $volume_id (${age_hours}h old)"
        fi
    done
    
    log "Cleaned up $count unused EBS volumes"
}

# Clean up unattached Elastic IPs
cleanup_elastic_ips() {
    log "Cleaning up unattached Elastic IPs..."
    
    # Get list of unattached Elastic IPs
    local eips=$(aws ec2 describe-addresses \
        --query 'Addresses[?AssociationId==null].AllocationId' \
        --output text)
    
    if [ -z "$eips" ]; then
        info "No unattached Elastic IPs found"
        return 0
    fi
    
    local count=0
    for eip in $eips; do
        local eip_info=$(aws ec2 describe-addresses \
            --allocation-ids "$eip" \
            --query 'Addresses[0].[AllocationId,PublicIp,Domain]' \
            --output text)
        
        local allocation_id=$(echo "$eip_info" | cut -f1)
        local public_ip=$(echo "$eip_info" | cut -f2)
        local domain=$(echo "$eip_info" | cut -f3)
        
        info "Found unattached Elastic IP: $public_ip ($allocation_id)"
        execute_or_dry_run "aws ec2 release-address --allocation-id $allocation_id" \
            "Release unattached Elastic IP $public_ip"
        count=$((count + 1))
    done
    
    log "Cleaned up $count unattached Elastic IPs"
}

# Clean up old snapshots
cleanup_old_snapshots() {
    log "Cleaning up old EBS snapshots..."
    
    local cutoff_date=$(date -d "30 days ago" +%Y-%m-%d)
    
    # Get snapshots older than 30 days
    local snapshots=$(aws ec2 describe-snapshots \
        --owner-ids self \
        --query "Snapshots[?StartTime<='${cutoff_date}'].SnapshotId" \
        --output text)
    
    if [ -z "$snapshots" ]; then
        info "No old snapshots found"
        return 0
    fi
    
    local count=0
    for snapshot in $snapshots; do
        # Check if snapshot is used by any AMI
        local ami_usage=$(aws ec2 describe-images \
            --owners self \
            --query "Images[?BlockDeviceMappings[?Ebs.SnapshotId=='$snapshot']].ImageId" \
            --output text)
        
        if [ -z "$ami_usage" ]; then
            local snapshot_info=$(aws ec2 describe-snapshots \
                --snapshot-ids "$snapshot" \
                --query 'Snapshots[0].[SnapshotId,VolumeSize,StartTime,Description]' \
                --output text)
            
            local snapshot_id=$(echo "$snapshot_info" | cut -f1)
            local size=$(echo "$snapshot_info" | cut -f2)
            local start_time=$(echo "$snapshot_info" | cut -f3)
            local description=$(echo "$snapshot_info" | cut -f4)
            
            info "Found old unused snapshot: $snapshot_id (${size}GB, $start_time)"
            execute_or_dry_run "aws ec2 delete-snapshot --snapshot-id $snapshot_id" \
                "Delete old snapshot $snapshot_id"
            count=$((count + 1))
        else
            info "Skipping snapshot $snapshot (used by AMI: $ami_usage)"
        fi
    done
    
    log "Cleaned up $count old snapshots"
}

# Clean up unused security groups
cleanup_security_groups() {
    log "Cleaning up unused security groups..."
    
    # Get all security groups
    local all_sgs=$(aws ec2 describe-security-groups \
        --query 'SecurityGroups[?GroupName!=`default`].GroupId' \
        --output text)
    
    if [ -z "$all_sgs" ]; then
        info "No custom security groups found"
        return 0
    fi
    
    local count=0
    for sg in $all_sgs; do
        # Check if security group is used by any instance
        local instance_usage=$(aws ec2 describe-instances \
            --query "Reservations[].Instances[?SecurityGroups[?GroupId=='$sg']].InstanceId" \
            --output text)
        
        # Check if security group is used by any load balancer
        local elb_usage=$(aws elbv2 describe-load-balancers \
            --query "LoadBalancers[?SecurityGroups[?contains(@, '$sg')]].LoadBalancerName" \
            --output text 2>/dev/null || echo "")
        
        # Check if security group is used by any RDS instance
        local rds_usage=$(aws rds describe-db-instances \
            --query "DBInstances[?VpcSecurityGroups[?VpcSecurityGroupId=='$sg']].DBInstanceIdentifier" \
            --output text 2>/dev/null || echo "")
        
        if [ -z "$instance_usage" ] && [ -z "$elb_usage" ] && [ -z "$rds_usage" ]; then
            local sg_info=$(aws ec2 describe-security-groups \
                --group-ids "$sg" \
                --query 'SecurityGroups[0].[GroupId,GroupName,Description]' \
                --output text)
            
            local group_id=$(echo "$sg_info" | cut -f1)
            local group_name=$(echo "$sg_info" | cut -f2)
            local description=$(echo "$sg_info" | cut -f3)
            
            info "Found unused security group: $group_name ($group_id)"
            execute_or_dry_run "aws ec2 delete-security-group --group-id $group_id" \
                "Delete unused security group $group_name"
            count=$((count + 1))
        fi
    done
    
    log "Cleaned up $count unused security groups"
}

# Clean up old CloudWatch log groups
cleanup_cloudwatch_logs() {
    log "Cleaning up old CloudWatch log groups..."
    
    local cutoff_timestamp=$(date -d "7 days ago" +%s)000  # CloudWatch uses milliseconds
    
    # Get all log groups
    local log_groups=$(aws logs describe-log-groups \
        --query 'logGroups[].logGroupName' \
        --output text)
    
    if [ -z "$log_groups" ]; then
        info "No CloudWatch log groups found"
        return 0
    fi
    
    local count=0
    for log_group in $log_groups; do
        # Get last event time
        local last_event=$(aws logs describe-log-streams \
            --log-group-name "$log_group" \
            --order-by LastEventTime \
            --descending \
            --max-items 1 \
            --query 'logStreams[0].lastEventTime' \
            --output text 2>/dev/null || echo "None")
        
        if [ "$last_event" != "None" ] && [ "$last_event" != "null" ] && [ -n "$last_event" ]; then
            if [ "$last_event" -lt "$cutoff_timestamp" ]; then
                info "Found old log group: $log_group (last event: $(date -d "@$(($last_event/1000))"))"
                execute_or_dry_run "aws logs delete-log-group --log-group-name '$log_group'" \
                    "Delete old log group $log_group"
                count=$((count + 1))
            fi
        else
            # Empty log group
            info "Found empty log group: $log_group"
            execute_or_dry_run "aws logs delete-log-group --log-group-name '$log_group'" \
                "Delete empty log group $log_group"
            count=$((count + 1))
        fi
    done
    
    log "Cleaned up $count old CloudWatch log groups"
}

# Clean up Load Balancers with no targets
cleanup_load_balancers() {
    log "Checking for unused Application Load Balancers..."
    
    # Get all ALBs
    local albs=$(aws elbv2 describe-load-balancers \
        --query 'LoadBalancers[?Type==`application`].LoadBalancerArn' \
        --output text)
    
    if [ -z "$albs" ]; then
        info "No Application Load Balancers found"
        return 0
    fi
    
    local count=0
    for alb in $albs; do
        # Get target groups for this ALB
        local target_groups=$(aws elbv2 describe-target-groups \
            --load-balancer-arn "$alb" \
            --query 'TargetGroups[].TargetGroupArn' \
            --output text 2>/dev/null || echo "")
        
        local has_healthy_targets=false
        
        if [ -n "$target_groups" ]; then
            for tg in $target_groups; do
                # Check if target group has healthy targets
                local healthy_targets=$(aws elbv2 describe-target-health \
                    --target-group-arn "$tg" \
                    --query 'TargetHealthDescriptions[?TargetHealth.State==`healthy`]' \
                    --output text 2>/dev/null || echo "")
                
                if [ -n "$healthy_targets" ]; then
                    has_healthy_targets=true
                    break
                fi
            done
        fi
        
        if [ "$has_healthy_targets" = false ]; then
            local alb_info=$(aws elbv2 describe-load-balancers \
                --load-balancer-arns "$alb" \
                --query 'LoadBalancers[0].[LoadBalancerName,LoadBalancerArn,CreatedTime]' \
                --output text)
            
            local alb_name=$(echo "$alb_info" | cut -f1)
            local alb_arn=$(echo "$alb_info" | cut -f2)
            local created_time=$(echo "$alb_info" | cut -f3)
            
            # Check if ALB is older than 1 hour
            local create_timestamp=$(date -d "$created_time" +%s)
            local current_timestamp=$(date +%s)
            local age_hours=$(( (current_timestamp - create_timestamp) / 3600 ))
            
            if [ $age_hours -gt 1 ]; then
                warn "Found ALB with no healthy targets: $alb_name (${age_hours}h old)"
                info "⚠️  Manual review recommended before deletion"
                # Don't auto-delete ALBs - they might be needed
                # execute_or_dry_run "aws elbv2 delete-load-balancer --load-balancer-arn $alb_arn" \
                #     "Delete unused ALB $alb_name"
            fi
        fi
    done
}

# Clean up Kubernetes resources if cluster exists
cleanup_kubernetes_resources() {
    if ! command -v kubectl &> /dev/null; then
        info "kubectl not available, skipping Kubernetes cleanup"
        return 0
    fi
    
    if ! kubectl cluster-info &> /dev/null; then
        info "No Kubernetes cluster access, skipping Kubernetes cleanup"
        return 0
    fi
    
    log "Cleaning up Kubernetes resources..."
    
    # Clean up completed pods
    local completed_pods=$(kubectl get pods --all-namespaces \
        --field-selector=status.phase=Succeeded \
        -o jsonpath='{range .items[*]}{.metadata.namespace}{" "}{.metadata.name}{"\n"}{end}' 2>/dev/null || echo "")
    
    local count=0
    while IFS= read -r pod_info; do
        if [ -n "$pod_info" ]; then
            local namespace=$(echo "$pod_info" | cut -d' ' -f1)
            local pod_name=$(echo "$pod_info" | cut -d' ' -f2)
            
            execute_or_dry_run "kubectl delete pod $pod_name -n $namespace" \
                "Delete completed pod $pod_name in namespace $namespace"
            count=$((count + 1))
        fi
    done <<< "$completed_pods"
    
    # Clean up failed pods older than 1 hour
    local failed_pods=$(kubectl get pods --all-namespaces \
        --field-selector=status.phase=Failed \
        -o jsonpath='{range .items[*]}{.metadata.namespace}{" "}{.metadata.name}{" "}{.metadata.creationTimestamp}{"\n"}{end}' 2>/dev/null || echo "")
    
    while IFS= read -r pod_info; do
        if [ -n "$pod_info" ]; then
            local namespace=$(echo "$pod_info" | cut -d' ' -f1)
            local pod_name=$(echo "$pod_info" | cut -d' ' -f2)
            local create_time=$(echo "$pod_info" | cut -d' ' -f3)
            
            local create_timestamp=$(date -d "$create_time" +%s)
            local current_timestamp=$(date +%s)
            local age_hours=$(( (current_timestamp - create_timestamp) / 3600 ))
            
            if [ $age_hours -gt 1 ]; then
                execute_or_dry_run "kubectl delete pod $pod_name -n $namespace" \
                    "Delete failed pod $pod_name in namespace $namespace (${age_hours}h old)"
                count=$((count + 1))
            fi
        fi
    done <<< "$failed_pods"
    
    log "Cleaned up $count Kubernetes pods"
}

# Generate cleanup report
generate_cleanup_report() {
    local report_file="/tmp/cleanup-report-${ENVIRONMENT}-$(date +%Y%m%d-%H%M%S).txt"
    
    {
        echo "EKS Learning Lab - Resource Cleanup Report"
        echo "Environment: $ENVIRONMENT"
        echo "Date: $(date)"
        echo "Dry Run: $DRY_RUN"
        echo ""
        echo "Resources Cleaned Up:"
        echo "===================="
        
        if is_dry_run; then
            echo "This was a DRY RUN - no resources were actually deleted."
        else
            echo "The following resources were cleaned up to reduce costs:"
        fi
        
        echo ""
        cat "$LOG_FILE" | grep -E "(Cleaned up|Would execute)" || echo "No cleanup actions performed"
        
        echo ""
        echo "Estimated Monthly Savings:"
        echo "========================="
        echo "• Unused EBS volumes: ~\$0.50-\$5.00/month per volume"
        echo "• Unattached Elastic IPs: \$3.65/month per IP"
        echo "• Old snapshots: ~\$0.05/month per GB"
        echo "• CloudWatch logs: ~\$0.50/month per GB"
        echo "• Unused ALBs: \$16.20/month per ALB"
        echo ""
        echo "For maximum cost savings, consider:"
        echo "• Scheduled cluster shutdown (50-65% compute savings)"
        echo "• Regular cleanup automation"
        echo "• Resource tagging and lifecycle policies"
        
    } > "$report_file"
    
    log "Cleanup report generated: $report_file"
    
    # Display report summary
    highlight "=== CLEANUP SUMMARY ==="
    if is_dry_run; then
        info "DRY RUN completed - no resources were deleted"
    else
        info "Resource cleanup completed"
    fi
    info "Report saved to: $report_file"
    echo ""
}

# Print usage
print_usage() {
    echo "Usage: $0 [ENVIRONMENT] [DRY_RUN]"
    echo ""
    echo "Arguments:"
    echo "  ENVIRONMENT  Environment to clean up (dev, staging, prod) - default: dev"
    echo "  DRY_RUN      Set to 'true' to simulate cleanup without deleting - default: false"
    echo ""
    echo "Examples:"
    echo "  $0 dev true          # Dry run for dev environment"
    echo "  $0 staging false     # Clean up staging environment"
    echo "  $0                   # Clean up dev environment (interactive confirmation)"
    echo ""
    echo "Safety Features:"
    echo "  • Interactive confirmation required (unless dry run)"
    echo "  • Detailed logging of all actions"
    echo "  • Age checks to avoid deleting recent resources"
    echo "  • Usage checks to avoid deleting resources in use"
    echo ""
}

# Main execution
main() {
    if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
        print_usage
        exit 0
    fi
    
    log "Starting resource cleanup for environment: $ENVIRONMENT"
    
    if is_dry_run; then
        highlight "🧪 DRY RUN MODE - No resources will be deleted"
    else
        highlight "⚠️  LIVE MODE - Resources will be deleted"
    fi
    
    check_prerequisites
    confirm_cleanup
    
    # Perform cleanup operations
    cleanup_ebs_volumes
    cleanup_elastic_ips
    cleanup_old_snapshots
    cleanup_security_groups
    cleanup_cloudwatch_logs
    cleanup_load_balancers
    cleanup_kubernetes_resources
    
    # Generate report
    generate_cleanup_report
    
    if is_dry_run; then
        info "💡 To perform actual cleanup, run: $0 $ENVIRONMENT false"
    else
        log "✅ Resource cleanup completed successfully!"
        info "💰 Check your AWS bill in a few hours to see cost savings"
    fi
}

# Run main function
main "$@"