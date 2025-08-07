#!/bin/bash
set -euo pipefail

# Cost Estimation Script
# Provides detailed cost analysis for the EKS learning lab

ENVIRONMENT=${1:-dev}
REGION=${2:-us-east-1}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
}

info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1${NC}"
}

highlight() {
    echo -e "${CYAN}$1${NC}"
}

# Cost calculation functions
calculate_eks_costs() {
    local environment=$1
    
    case $environment in
        "dev")
            # Development environment costs
            EKS_CLUSTER_HOURLY=0.10
            EC2_INSTANCES=1
            INSTANCE_TYPE="t3.medium"
            INSTANCE_HOURLY_ONDEMAND=0.0416
            INSTANCE_HOURLY_SPOT=0.0125  # ~70% savings
            EBS_STORAGE_GB=20
            NAT_GATEWAY=0  # Disabled for cost savings
            ;;
        "staging")
            # Staging environment costs
            EKS_CLUSTER_HOURLY=0.10
            EC2_INSTANCES=2
            INSTANCE_TYPE="t3.medium"
            INSTANCE_HOURLY_ONDEMAND=0.0416
            INSTANCE_HOURLY_SPOT=0.0125
            EBS_STORAGE_GB=40
            NAT_GATEWAY=1
            ;;
        "prod")
            # Production environment costs
            EKS_CLUSTER_HOURLY=0.10
            EC2_INSTANCES=3
            INSTANCE_TYPE="t3.medium"
            INSTANCE_HOURLY_ONDEMAND=0.0416
            INSTANCE_HOURLY_SPOT=0.0125
            EBS_STORAGE_GB=60
            NAT_GATEWAY=2
            ;;
        *)
            error "Unknown environment: $environment"
            exit 1
            ;;
    esac
    
    # Calculate monthly costs (24 hours * 30 days = 720 hours)
    local hours_per_month=720
    
    # EKS Control Plane
    EKS_MONTHLY=$(echo "scale=2; $EKS_CLUSTER_HOURLY * $hours_per_month" | bc)
    
    # EC2 Instances (Spot pricing)
    EC2_MONTHLY=$(echo "scale=2; $INSTANCE_HOURLY_SPOT * $EC2_INSTANCES * $hours_per_month" | bc)
    EC2_ONDEMAND_MONTHLY=$(echo "scale=2; $INSTANCE_HOURLY_ONDEMAND * $EC2_INSTANCES * $hours_per_month" | bc)
    
    # EBS Storage (GP3)
    EBS_MONTHLY=$(echo "scale=2; $EBS_STORAGE_GB * 0.08" | bc)  # $0.08 per GB/month
    
    # NAT Gateway
    if [ $NAT_GATEWAY -gt 0 ]; then
        NAT_MONTHLY=$(echo "scale=2; $NAT_GATEWAY * 45.0" | bc)  # $45/month per NAT Gateway
        NAT_DATA_PROCESSING=5.0  # Estimated data processing costs
    else
        NAT_MONTHLY=0
        NAT_DATA_PROCESSING=0
    fi
    
    # Application Load Balancer (if using ALB)
    ALB_MONTHLY=16.20  # $0.0225/hour
    
    # Data Transfer
    DATA_TRANSFER_MONTHLY=2.0  # Estimated inter-AZ data transfer
    
    # CloudWatch Logs
    CLOUDWATCH_LOGS=3.0  # Estimated log ingestion and storage
    
    # Total
    TOTAL_MONTHLY=$(echo "scale=2; $EKS_MONTHLY + $EC2_MONTHLY + $EBS_MONTHLY + $NAT_MONTHLY + $NAT_DATA_PROCESSING + $ALB_MONTHLY + $DATA_TRANSFER_MONTHLY + $CLOUDWATCH_LOGS" | bc)
    TOTAL_ONDEMAND=$(echo "scale=2; $EKS_MONTHLY + $EC2_ONDEMAND_MONTHLY + $EBS_MONTHLY + $NAT_MONTHLY + $NAT_DATA_PROCESSING + $ALB_MONTHLY + $DATA_TRANSFER_MONTHLY + $CLOUDWATCH_LOGS" | bc)
    
    # Savings
    SPOT_SAVINGS=$(echo "scale=2; $TOTAL_ONDEMAND - $TOTAL_MONTHLY" | bc)
}

# Print detailed cost breakdown
print_cost_breakdown() {
    local environment=$1
    
    echo ""
    highlight "===================================================="
    highlight "      EKS Learning Lab - Cost Breakdown"
    highlight "===================================================="
    echo ""
    
    info "Environment: $(echo $environment | tr '[:lower:]' '[:upper:]')"
    info "Region: $REGION"
    info "Instance Type: $INSTANCE_TYPE (Spot instances)"
    info "Instance Count: $EC2_INSTANCES"
    echo ""
    
    highlight "Monthly Cost Breakdown:"
    echo "┌─────────────────────────────────┬──────────────┐"
    echo "│ Service                         │ Monthly Cost │"
    echo "├─────────────────────────────────┼──────────────┤"
    printf "│ EKS Control Plane               │ %12s │\n" "\$$EKS_MONTHLY"
    printf "│ EC2 Instances (Spot)            │ %12s │\n" "\$$EC2_MONTHLY"
    printf "│ EBS Storage (${EBS_STORAGE_GB}GB GP3)          │ %12s │\n" "\$$EBS_MONTHLY"
    if [ $NAT_GATEWAY -gt 0 ]; then
        printf "│ NAT Gateway ($NAT_GATEWAY)                  │ %12s │\n" "\$$NAT_MONTHLY"
        printf "│ NAT Data Processing             │ %12s │\n" "\$$NAT_DATA_PROCESSING"
    else
        printf "│ NAT Gateway (Disabled)          │ %12s │\n" "\$0.00"
    fi
    printf "│ Application Load Balancer       │ %12s │\n" "\$$ALB_MONTHLY"
    printf "│ Data Transfer                   │ %12s │\n" "\$$DATA_TRANSFER_MONTHLY"
    printf "│ CloudWatch Logs                 │ %12s │\n" "\$$CLOUDWATCH_LOGS"
    echo "├─────────────────────────────────┼──────────────┤"
    printf "│ TOTAL (Spot instances)          │ %12s │\n" "\$$TOTAL_MONTHLY"
    printf "│ TOTAL (On-Demand)               │ %12s │\n" "\$$TOTAL_ONDEMAND"
    printf "│ Monthly Savings (Spot)          │ %12s │\n" "\$$SPOT_SAVINGS"
    echo "└─────────────────────────────────┴──────────────┘"
    echo ""
}

# Calculate additional cost optimizations
print_cost_optimizations() {
    local environment=$1
    
    highlight "Cost Optimization Strategies:"
    echo ""
    
    info "✅ Already Implemented:"
    echo "  • Spot instances (70% savings on compute)"
    if [ $NAT_GATEWAY -eq 0 ]; then
        echo "  • No NAT Gateway (saves ~\$45/month)"
    fi
    echo "  • GP3 EBS volumes (20% cheaper than GP2)"
    echo "  • Right-sized instances for learning workloads"
    echo "  • Automated shutdown scheduling"
    echo ""
    
    info "💡 Additional Savings Opportunities:"
    echo "  • Scheduled cluster shutdown (evenings/weekends)"
    echo "    - 12 hours/day = 50% savings (\$$(echo "scale=0; $TOTAL_MONTHLY / 2" | bc)/month)"
    echo "    - Weekend shutdown = 28% savings (\$$(echo "scale=0; $TOTAL_MONTHLY * 0.28" | bc)/month)"
    echo "  • Use smaller instances for non-production workloads"
    echo "  • Enable AWS Compute Savings Plans for 1-3 year commitment"
    echo "  • Use AWS Free Tier resources where possible"
    echo ""
    
    # Calculate potential savings with scheduled shutdown
    EVENING_SAVINGS=$(echo "scale=2; $TOTAL_MONTHLY * 0.5" | bc)
    WEEKEND_SAVINGS=$(echo "scale=2; $TOTAL_MONTHLY * 0.28" | bc)
    COMBINED_SAVINGS=$(echo "scale=2; $TOTAL_MONTHLY * 0.65" | bc)
    
    highlight "Automated Shutdown Savings:"
    echo "┌─────────────────────────────────┬──────────────┐"
    echo "│ Shutdown Schedule               │ Monthly Cost │"
    echo "├─────────────────────────────────┼──────────────┤"
    printf "│ No shutdown (24/7)             │ %12s │\n" "\$$TOTAL_MONTHLY"
    printf "│ Evening shutdown (12hrs/day)   │ %12s │\n" "\$$EVENING_SAVINGS"
    printf "│ Weekend shutdown (5days/week)  │ %12s │\n" "\$$WEEKEND_SAVINGS"
    printf "│ Combined (evening + weekend)   │ %12s │\n" "\$$COMBINED_SAVINGS"
    echo "└─────────────────────────────────┴──────────────┘"
    echo ""
}

# Print budget recommendations
print_budget_recommendations() {
    local environment=$1
    
    highlight "Budget Recommendations:"
    echo ""
    
    case $environment in
        "dev")
            RECOMMENDED_BUDGET=75
            ALERT_THRESHOLD=60
            ;;
        "staging")
            RECOMMENDED_BUDGET=150
            ALERT_THRESHOLD=120
            ;;
        "prod")
            RECOMMENDED_BUDGET=300
            ALERT_THRESHOLD=250
            ;;
    esac
    
    info "Environment: $environment"
    echo "  • Recommended monthly budget: \$$RECOMMENDED_BUDGET"
    echo "  • Set budget alerts at: \$$ALERT_THRESHOLD (80%)"
    echo "  • Current estimated cost: \$$TOTAL_MONTHLY"
    
    if (( $(echo "$TOTAL_MONTHLY > $RECOMMENDED_BUDGET" | bc -l) )); then
        warn "⚠️  Estimated cost exceeds recommended budget!"
        echo "     Consider implementing cost optimization strategies."
    else
        log "✅ Estimated cost is within recommended budget."
    fi
    echo ""
}

# Print monitoring and alerts setup
print_monitoring_setup() {
    highlight "Cost Monitoring Setup:"
    echo ""
    
    info "AWS Cost Management:"
    echo "  • Set up AWS Budgets with email alerts"
    echo "  • Enable Cost Anomaly Detection"
    echo "  • Use AWS Cost Explorer for detailed analysis"
    echo "  • Tag all resources for cost allocation"
    echo ""
    
    info "GitHub Actions Integration:"
    echo "  • Daily cost monitoring workflow"
    echo "  • Pre-deployment cost estimation"
    echo "  • Automated budget alerts"
    echo "  • Resource cleanup automation"
    echo ""
    
    info "Useful Commands:"
    echo "  • Get current costs: aws ce get-cost-and-usage"
    echo "  • List active resources: aws resourcegroupstaggingapi get-resources"
    echo "  • Check spot instance savings: aws ec2 describe-spot-price-history"
    echo ""
}

# Print comparison table
print_environment_comparison() {
    highlight "Environment Cost Comparison:"
    echo ""
    
    # Calculate costs for all environments
    calculate_eks_costs "dev"
    DEV_COST=$TOTAL_MONTHLY
    
    calculate_eks_costs "staging"
    STAGING_COST=$TOTAL_MONTHLY
    
    calculate_eks_costs "prod"
    PROD_COST=$TOTAL_MONTHLY
    
    echo "┌─────────────┬──────────────┬──────────────┬──────────────┐"
    echo "│ Component   │ Development  │ Staging      │ Production   │"
    echo "├─────────────┼──────────────┼──────────────┼──────────────┤"
    echo "│ Instances   │ 1 × t3.medium │ 2 × t3.medium │ 3 × t3.medium│"
    echo "│ Capacity    │ Spot         │ Spot         │ On-Demand    │"
    echo "│ NAT Gateway │ No           │ Yes (1)      │ Yes (2)      │"
    echo "│ Storage     │ 20GB         │ 40GB         │ 60GB         │"
    printf "│ Total Cost  │ %12s │ %12s │ %12s │\n" "\$$DEV_COST" "\$$STAGING_COST" "\$$PROD_COST"
    echo "└─────────────┴──────────────┴──────────────┴──────────────┘"
    echo ""
    
    # Restore original environment calculation
    calculate_eks_costs $ENVIRONMENT
}

# Main execution
main() {
    log "Calculating costs for EKS Learning Lab environment: $ENVIRONMENT"
    
    # Check if bc is available for calculations
    if ! command -v bc &> /dev/null; then
        error "bc (calculator) is required but not installed"
        info "Install with: sudo apt-get install bc (Ubuntu/Debian) or sudo yum install bc (RHEL/CentOS)"
        exit 1
    fi
    
    # Calculate costs
    calculate_eks_costs $ENVIRONMENT
    
    # Print detailed breakdown
    print_cost_breakdown $ENVIRONMENT
    print_cost_optimizations $ENVIRONMENT
    print_budget_recommendations $ENVIRONMENT
    print_monitoring_setup
    print_environment_comparison
    
    # Summary
    highlight "===================================================="
    highlight "                    SUMMARY"
    highlight "===================================================="
    echo ""
    log "Environment: $ENVIRONMENT"
    log "Estimated monthly cost: \$$TOTAL_MONTHLY (with optimizations)"
    log "Cost without optimizations: \$$TOTAL_ONDEMAND"
    log "Monthly savings: \$$SPOT_SAVINGS"
    echo ""
    
    if [ "$ENVIRONMENT" = "dev" ]; then
        info "💡 For maximum cost savings in development:"
        echo "  • Use scheduled shutdown: ./install-cost-control.sh"
        echo "  • Enable weekend shutdown: saves ~65% of compute costs"
        echo "  • Monitor usage with: aws ce get-cost-and-usage"
    fi
    
    echo ""
    log "Cost estimation completed successfully! 💰"
}

# Run main function
main "$@"