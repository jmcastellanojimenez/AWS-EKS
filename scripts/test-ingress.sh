#!/bin/bash

# 🧪 Kubernetes Ingress Workshop - End-to-End Testing Script
# This script performs comprehensive testing of deployed ingress patterns

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parameters
PATTERN="${1:-alb}"
DOMAIN_NAME="${2:-k8s-demo.local}"
LB_HOSTNAME="${3:-}"

# Test configuration
TEST_TIMEOUT=300
RETRY_INTERVAL=10
MAX_RETRIES=30

echo -e "${BLUE}🧪 Kubernetes Ingress End-to-End Testing${NC}"
echo -e "${BLUE}Pattern: ${PATTERN}${NC}"
echo -e "${BLUE}Domain: ${DOMAIN_NAME}${NC}"
echo -e "${BLUE}LoadBalancer: ${LB_HOSTNAME}${NC}"
echo ""

# Function to print status
print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Function to wait for condition with timeout
wait_for_condition() {
    local description="$1"
    local condition_cmd="$2"
    local timeout="$3"
    local interval="${4:-5}"
    
    echo -e "${BLUE}⏳ Waiting for: ${description}${NC}"
    
    local elapsed=0
    while [ $elapsed -lt $timeout ]; do
        if eval "$condition_cmd" 2>/dev/null; then
            print_status "$description completed"
            return 0
        fi
        
        echo -n "."
        sleep $interval
        elapsed=$((elapsed + interval))
    done
    
    echo ""
    print_error "$description timed out after ${timeout}s"
    return 1
}

# Test 1: Verify kubectl connectivity
echo -e "${BLUE}🔍 Test 1: Kubernetes Connectivity${NC}"
if kubectl cluster-info >/dev/null 2>&1; then
    print_status "Kubernetes cluster is accessible"
else
    print_error "Cannot connect to Kubernetes cluster"
    exit 1
fi

# Test 2: Check deployed resources
echo -e "${BLUE}🔍 Test 2: Deployed Resources${NC}"

# Check namespaces
REQUIRED_NAMESPACES=("cert-manager" "external-dns")
if [[ "$PATTERN" == "nginx" ]]; then
    REQUIRED_NAMESPACES+=("ingress-nginx")
fi

for ns in "${REQUIRED_NAMESPACES[@]}"; do
    if kubectl get namespace "$ns" >/dev/null 2>&1; then
        print_status "Namespace '$ns' exists"
    else
        print_error "Namespace '$ns' not found"
        exit 1
    fi
done

# Check deployments
echo -e "${BLUE}🔍 Test 3: Controller Deployments${NC}"

# cert-manager deployment
if wait_for_condition "cert-manager deployment ready" \
   "kubectl get deployment cert-manager -n cert-manager -o jsonpath='{.status.readyReplicas}' | grep -q '^[1-9]'" \
   120; then
    print_status "cert-manager is ready"
else
    print_error "cert-manager deployment failed"
    exit 1
fi

# external-dns deployment
if wait_for_condition "external-dns deployment ready" \
   "kubectl get deployment external-dns -n external-dns -o jsonpath='{.status.readyReplicas}' | grep -q '^[1-9]'" \
   120; then
    print_status "external-dns is ready"
else
    print_error "external-dns deployment failed"
    exit 1
fi

# Pattern-specific controller checks
if [[ "$PATTERN" == "alb" ]]; then
    if wait_for_condition "AWS Load Balancer Controller ready" \
       "kubectl get deployment aws-load-balancer-controller -n kube-system -o jsonpath='{.status.readyReplicas}' | grep -q '^[1-9]'" \
       120; then
        print_status "AWS Load Balancer Controller is ready"
    else
        print_error "AWS Load Balancer Controller deployment failed"
        exit 1
    fi
elif [[ "$PATTERN" == "nginx" ]]; then
    if wait_for_condition "NGINX Ingress Controller ready" \
       "kubectl get deployment ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.readyReplicas}' | grep -q '^[1-9]'" \
       120; then
        print_status "NGINX Ingress Controller is ready"
    else
        print_error "NGINX Ingress Controller deployment failed"
        exit 1
    fi
fi

# Test 4: Demo Applications
echo -e "${BLUE}🔍 Test 4: Demo Applications${NC}"

if [[ "$PATTERN" == "alb" ]]; then
    APP_NAME="purple-demo-app"
    SERVICE_NAME="purple-demo-service"
    INGRESS_NAME="demo-app-alb"
else
    APP_NAME="pink-demo-app"
    SERVICE_NAME="pink-demo-service"
    INGRESS_NAME="demo-app-nginx"
fi

# Check if demo apps are deployed
if kubectl get deployment "$APP_NAME" >/dev/null 2>&1; then
    if wait_for_condition "$APP_NAME deployment ready" \
       "kubectl get deployment $APP_NAME -o jsonpath='{.status.readyReplicas}' | grep -q '^[1-9]'" \
       120; then
        print_status "$APP_NAME is ready"
    else
        print_error "$APP_NAME deployment failed"
        exit 1
    fi
    
    # Check service
    if kubectl get service "$SERVICE_NAME" >/dev/null 2>&1; then
        print_status "$SERVICE_NAME service exists"
    else
        print_error "$SERVICE_NAME service not found"
        exit 1
    fi
    
    DEMO_APPS_DEPLOYED=true
else
    print_warning "Demo applications not deployed - skipping app-specific tests"
    DEMO_APPS_DEPLOYED=false
fi

# Test 5: Ingress Resources
echo -e "${BLUE}🔍 Test 5: Ingress Configuration${NC}"

if [[ "$DEMO_APPS_DEPLOYED" == "true" ]]; then
    if kubectl get ingress "$INGRESS_NAME" >/dev/null 2>&1; then
        print_status "Ingress '$INGRESS_NAME' exists"
        
        # Get ingress hostname
        if [[ -z "$LB_HOSTNAME" ]]; then
            if [[ "$PATTERN" == "alb" ]]; then
                LB_HOSTNAME=$(kubectl get ingress "$INGRESS_NAME" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
            else
                LB_HOSTNAME=$(kubectl get service ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
            fi
        fi
        
        if [[ -n "$LB_HOSTNAME" ]]; then
            print_status "LoadBalancer hostname: $LB_HOSTNAME"
        else
            print_warning "LoadBalancer hostname not yet available"
        fi
    else
        print_error "Ingress '$INGRESS_NAME' not found"
        exit 1
    fi
fi

# Test 6: DNS Resolution
echo -e "${BLUE}🔍 Test 6: DNS Resolution${NC}"

# Check domain resolution
if nslookup "$DOMAIN_NAME" >/dev/null 2>&1; then
    print_status "Domain '$DOMAIN_NAME' resolves"
else
    print_warning "Domain '$DOMAIN_NAME' does not resolve (may be expected for .local domains)"
fi

# Check ingress hostname resolution if available
if [[ "$DEMO_APPS_DEPLOYED" == "true" && -n "$LB_HOSTNAME" ]]; then
    INGRESS_HOSTNAME="demo-${PATTERN}.${DOMAIN_NAME}"
    
    echo -e "${BLUE}Testing ingress hostname: $INGRESS_HOSTNAME${NC}"
    
    if nslookup "$INGRESS_HOSTNAME" >/dev/null 2>&1; then
        print_status "Ingress hostname '$INGRESS_HOSTNAME' resolves"
        
        # Check if it points to the load balancer
        RESOLVED_IPS=$(nslookup "$INGRESS_HOSTNAME" | grep -A 10 "Name:" | grep "Address:" | awk '{print $2}' | sort)
        LB_IPS=$(nslookup "$LB_HOSTNAME" | grep -A 10 "Name:" | grep "Address:" | awk '{print $2}' | sort)
        
        if [[ "$RESOLVED_IPS" == "$LB_IPS" ]]; then
            print_status "Ingress hostname correctly points to LoadBalancer"
        else
            print_warning "Ingress hostname may not point to correct LoadBalancer (DNS propagation)"
        fi
    else
        print_warning "Ingress hostname '$INGRESS_HOSTNAME' does not resolve (DNS may be propagating)"
    fi
fi

# Test 7: HTTP Connectivity
echo -e "${BLUE}🔍 Test 7: HTTP Connectivity${NC}"

if [[ "$DEMO_APPS_DEPLOYED" == "true" && -n "$LB_HOSTNAME" ]]; then
    # Test direct LoadBalancer access
    print_info "Testing HTTP connectivity to LoadBalancer: $LB_HOSTNAME"
    
    HTTP_TEST_PASSED=false
    for i in $(seq 1 $MAX_RETRIES); do
        if curl -s --max-time 30 --connect-timeout 10 "http://$LB_HOSTNAME" >/dev/null 2>&1; then
            print_status "LoadBalancer responds to HTTP requests"
            HTTP_TEST_PASSED=true
            break
        else
            if [[ $i -eq $MAX_RETRIES ]]; then
                print_error "LoadBalancer does not respond to HTTP requests after $MAX_RETRIES attempts"
            else
                print_info "Attempt $i/$MAX_RETRIES failed, retrying in ${RETRY_INTERVAL}s..."
                sleep $RETRY_INTERVAL
            fi
        fi
    done
    
    if [[ "$HTTP_TEST_PASSED" == "true" ]]; then
        # Test application content
        RESPONSE=$(curl -s --max-time 30 "http://$LB_HOSTNAME" 2>/dev/null || echo "")
        
        if [[ -n "$RESPONSE" ]]; then
            if [[ "$PATTERN" == "alb" && "$RESPONSE" == *"ALB Pattern Demo"* ]]; then
                print_status "ALB demo application content verified"
            elif [[ "$PATTERN" == "nginx" && "$RESPONSE" == *"NGINX Pattern Demo"* ]]; then
                print_status "NGINX demo application content verified"
            elif [[ "$RESPONSE" == *"<html>"* ]]; then
                print_status "Application returns valid HTML content"
            else
                print_warning "Application content may not be pattern-specific"
            fi
        fi
        
        # Test pattern-specific headers
        if [[ "$PATTERN" == "alb" ]]; then
            ALB_HEADERS=$(curl -s --max-time 10 -I "http://$LB_HOSTNAME" 2>/dev/null | grep -i "server\|x-amzn" || true)
            if [[ -n "$ALB_HEADERS" ]]; then
                print_status "ALB-specific headers detected"
            else
                print_warning "ALB-specific headers not detected"
            fi
        else
            NGINX_HEADERS=$(curl -s --max-time 10 -I "http://$LB_HOSTNAME" 2>/dev/null | grep -i "nginx\|server" || true)
            if [[ -n "$NGINX_HEADERS" ]]; then
                print_status "NGINX-specific headers detected"
            else
                print_warning "NGINX-specific headers not detected"
            fi
        fi
    fi
else
    print_info "Skipping HTTP connectivity test (no demo apps or LoadBalancer hostname)"
fi

# Test 8: SSL Certificates
echo -e "${BLUE}🔍 Test 8: SSL Certificates${NC}"

if [[ "$DEMO_APPS_DEPLOYED" == "true" ]]; then
    # Check certificate resources
    CERT_NAME="demo-${PATTERN}-tls-cert"
    if kubectl get certificate "$CERT_NAME" >/dev/null 2>&1; then
        print_status "Certificate '$CERT_NAME' resource exists"
        
        # Check certificate status
        CERT_READY=$(kubectl get certificate "$CERT_NAME" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "False")
        
        if [[ "$CERT_READY" == "True" ]]; then
            print_status "Certificate is ready"
            
            # Test HTTPS if hostname resolves
            INGRESS_HOSTNAME="demo-${PATTERN}.${DOMAIN_NAME}"
            if nslookup "$INGRESS_HOSTNAME" >/dev/null 2>&1; then
                if curl -s --max-time 30 --connect-timeout 10 "https://$INGRESS_HOSTNAME" >/dev/null 2>&1; then
                    print_status "HTTPS connection successful"
                    
                    # Get certificate information
                    CERT_INFO=$(openssl s_client -connect "$INGRESS_HOSTNAME:443" -servername "$INGRESS_HOSTNAME" </dev/null 2>/dev/null | openssl x509 -noout -issuer -dates 2>/dev/null || true)
                    if [[ -n "$CERT_INFO" ]]; then
                        if echo "$CERT_INFO" | grep -qi "let's encrypt"; then
                            print_status "Let's Encrypt certificate detected"
                        elif echo "$CERT_INFO" | grep -qi "staging"; then
                            print_status "Let's Encrypt Staging certificate detected (expected for demo)"
                        else
                            print_info "Certificate issuer: $(echo "$CERT_INFO" | grep issuer | sed 's/issuer=//')"
                        fi
                    fi
                else
                    print_warning "HTTPS connection failed (certificate may still be provisioning)"
                fi
            else
                print_warning "Cannot test HTTPS - ingress hostname does not resolve"
            fi
        else
            print_warning "Certificate is not ready yet (may still be provisioning)"
        fi
    else
        print_warning "Certificate resource not found"
    fi
else
    print_info "Skipping SSL certificate test (no demo apps deployed)"
fi

# Test 9: Resource Health Check
echo -e "${BLUE}🔍 Test 9: Resource Health Check${NC}"

# Check pod status
UNHEALTHY_PODS=$(kubectl get pods --all-namespaces --field-selector=status.phase!=Running,status.phase!=Succeeded -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")

if [[ -z "$UNHEALTHY_PODS" ]]; then
    print_status "All pods are healthy"
else
    print_warning "Some pods are not in Running/Succeeded state: $UNHEALTHY_PODS"
fi

# Check for events indicating problems
ERROR_EVENTS=$(kubectl get events --all-namespaces --field-selector type=Warning -o jsonpath='{.items[*].message}' 2>/dev/null | head -5 || echo "")

if [[ -n "$ERROR_EVENTS" ]]; then
    print_warning "Recent warning events detected (may be normal during deployment)"
else
    print_status "No recent warning events"
fi

# Final Summary
echo ""
echo -e "${GREEN}🎉 Testing Complete!${NC}"
echo ""
echo -e "${BLUE}📋 Test Summary:${NC}"
echo -e "• Pattern: ${PATTERN}"
echo -e "• Domain: ${DOMAIN_NAME}"
if [[ -n "$LB_HOSTNAME" ]]; then
    echo -e "• LoadBalancer: ${LB_HOSTNAME}"
fi
if [[ "$DEMO_APPS_DEPLOYED" == "true" ]]; then
    echo -e "• Demo App: ${APP_NAME}"
    echo -e "• Ingress: ${INGRESS_NAME}"
fi

echo ""
echo -e "${BLUE}🌐 Access Information:${NC}"
if [[ -n "$LB_HOSTNAME" ]]; then
    echo -e "Direct LoadBalancer Access: ${YELLOW}http://${LB_HOSTNAME}${NC}"
fi
if [[ "$DEMO_APPS_DEPLOYED" == "true" ]]; then
    INGRESS_HOSTNAME="demo-${PATTERN}.${DOMAIN_NAME}"
    echo -e "Ingress Hostname: ${YELLOW}http://${INGRESS_HOSTNAME}${NC}"
    echo -e "HTTPS (when cert ready): ${YELLOW}https://${INGRESS_HOSTNAME}${NC}"
fi

echo ""
echo -e "${BLUE}💰 Cost Information:${NC}"
if [[ "$PATTERN" == "alb" ]]; then
    echo -e "• ALB: ~\$16/month"
else
    echo -e "• NLB: ~\$16/month"
fi
echo -e "• Route53: ~\$0.50/month"
echo -e "• Total Additional: ~\$16.50/month"

print_status "End-to-end testing completed successfully!"