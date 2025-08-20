# 🌐 Ingress + API Gateway Stack Deployment

This document describes the infrastructure resources deployed by the **Ingress + API Gateway Stack** GitHub workflow.

## 📋 Overview

The Ingress + API Gateway Stack workflow deploys comprehensive ingress and routing capabilities for the Kubernetes cluster, providing SSL termination, load balancing, and API gateway functionality.

## ✅ Deployed Resources (10 Total)

### 🔒 SSL Certificate Management

- **cert-manager**: Automated SSL certificate management using Let's Encrypt (~2 minute deployment)
  - Controller: Manages certificate lifecycle and renewals
  - Webhook: Validates certificate requests
  - CA Injector: Manages CA bundles for webhooks
- **ClusterIssuer**: Let's Encrypt ACME issuer for automated certificate provisioning
- **Cloudflare Integration**: DNS-01 challenge solver for wildcard certificates

### 🚀 Ambassador API Gateway

- **Ambassador/Emissary-Ingress**: Cloud-native API Gateway and ingress controller (~3 minute deployment)
  - **Features**:
    - Layer 7 load balancing and routing
    - Rate limiting and circuit breakers
    - Authentication and authorization
    - Traffic management and observability
  - **Custom Resource Definitions (CRDs)**:
    - `modules.getambassador.io`: Configuration modules
    - `hosts.getambassador.io`: Host management
    - `mappings.getambassador.io`: Service routing rules
  - **Default Configurations**:
    - **Module**: Core Ambassador configuration with diagnostics
    - **Host**: Default host configuration with Let's Encrypt integration
    - **Service**: ClusterIP service (ready to be converted to LoadBalancer)

### 🌍 DNS Management (Currently Disabled)

- **external-dns**: Automatic DNS record management with Cloudflare (temporarily disabled due to timeout optimization)
  - Will automatically create DNS records for services
  - Integrates with Ambassador for seamless domain management

## 🔧 Resource Allocation

### CPU & Memory Usage
- **cert-manager**: ~125m CPU, ~192Mi memory (controller + webhook + cainjector)
- **Ambassador**: ~100m CPU, ~256Mi memory (production-ready configuration)
- **Total**: ~225m CPU, ~448Mi memory
- **Headroom**: ~2.77 CPU, ~1.55Gi memory remaining for future workloads

### Storage Requirements
- **cert-manager**: No persistent storage required
- **Ambassador**: No persistent storage required
- **Total**: 0Gi additional storage (uses cluster's base storage)

## 🚦 Deployment Status & Health Checks

### ✅ Successful Deployment Indicators

1. **cert-manager Readiness**:
   ```bash
   kubectl get pods -n ingress-system -l app.kubernetes.io/name=cert-manager
   ```
   - All cert-manager pods should be `Running` and `Ready`

2. **ClusterIssuer Status**:
   ```bash
   kubectl get clusterissuers
   ```
   - `letsencrypt-prod` should show `Ready: True`

3. **Ambassador Readiness**:
   ```bash
   kubectl get pods -n ingress-system -l app.kubernetes.io/name=ambassador
   ```
   - Ambassador pods should be `Running` and pass readiness probes

4. **Service Availability**:
   ```bash
   kubectl get svc -n ingress-system | grep ambassador
   ```
   - `ambassador-emissary-ingress` service should be available

### 🔍 Verification Commands

After successful deployment, verify the stack with:

```bash
# Check all ingress components
kubectl get pods -n ingress-system

# Verify certificate management
kubectl get clusterissuers
kubectl get certificates -A

# Check Ambassador configuration
kubectl get hosts,mappings,modules -n ingress-system

# View service endpoints
kubectl get svc -n ingress-system
```

## 📊 Architecture Diagram

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Internet      │    │  Load Balancer   │    │   Ambassador    │
│   Traffic       ├────►   (Future NLB)   ├────►   API Gateway  │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                                         │
                       ┌─────────────────┐              │
                       │  cert-manager   ├──────────────┤
                       │ (Let's Encrypt) │              │
                       └─────────────────┘              │
                                                         │
                       ┌─────────────────┐              │
                       │  external-dns   │              │
                       │  (Cloudflare)   ├──────────────┤
                       └─────────────────┘              │
                                                         │
┌─────────────────┐    ┌─────────────────┐              │
│   Backend       │◄───┤   Kubernetes    │◄─────────────┘
│   Services      │    │    Services     │
└─────────────────┘    └─────────────────┘
```

## ⚙️ Configuration Details

### Ambassador Configuration

The Ambassador deployment includes several production-ready features:

- **Readiness Probes**: 30s initial delay, 10s period, 5s timeout
- **Resource Limits**: 500m CPU, 512Mi memory limits
- **Security**: 
  - No privileged containers
  - Disabled default configurations for security
  - Custom resource creation disabled for controlled setup

### Certificate Management

- **ACME Provider**: Let's Encrypt production environment
- **Challenge Type**: DNS-01 (supports wildcard certificates)
- **DNS Provider**: Cloudflare integration
- **Auto-renewal**: 30 days before expiration

## 🔄 Next Steps

After successful deployment of the Ingress + API Gateway Stack:

1. **Configure Load Balancer** (Optional):
   ```bash
   # Convert Ambassador service to LoadBalancer type
   kubectl patch svc ambassador-emissary-ingress -n ingress-system -p '{"spec":{"type":"LoadBalancer"}}'
   ```

2. **Get Load Balancer Hostname**:
   ```bash
   kubectl get svc ambassador-emissary-ingress -n ingress-system
   ```

3. **Configure DNS Records**:
   - Point your domain to the Load Balancer hostname
   - Enable external-dns for automatic DNS management (future)

4. **Deploy Application Mappings**:
   - Create Ambassador Mapping CRDs for your applications
   - Configure Host CRDs for additional domains

5. **Ready for Workflow 3**: 📈 LGTM Observability Stack
   - Monitoring and logging infrastructure
   - Grafana, Prometheus, Loki, Tempo integration

## 🎯 Use Cases

### Perfect For:
- **API-first applications** requiring advanced routing
- **Microservices architectures** needing traffic management
- **Multi-tenant platforms** requiring isolation and security
- **Production workloads** needing SSL termination and load balancing

### Integration Points:
- **LGTM Stack**: Automatic metrics collection from Ambassador
- **Service Mesh**: Can work alongside Istio for advanced traffic management
- **Security Stack**: Integrates with OPA Gatekeeper for policy enforcement
- **GitOps**: Supports ArgoCD for continuous deployment workflows

## 💰 Cost Optimization

- **ClusterIP Service**: Currently uses ClusterIP to minimize costs during testing
- **Single Replica**: Ambassador configured with 1 replica for development
- **Optimized Resources**: Minimal resource allocation while maintaining functionality
- **Future NLB**: When needed, AWS Network Load Balancer will be ~$16/month

## 🔧 Troubleshooting

### Common Issues:

1. **Ambassador Pods Not Ready**:
   - Check resource availability
   - Verify CRDs are properly installed
   - Review pod logs: `kubectl logs -l app.kubernetes.io/name=ambassador -n ingress-system`

2. **Certificate Issues**:
   - Verify Cloudflare API token is valid
   - Check ClusterIssuer status
   - Review cert-manager logs

3. **Service Not Found**:
   - Ensure Ambassador pods are ready before checking service
   - Verify namespace is correct (`ingress-system`)

### Debug Commands:
```bash
# Check Ambassador diagnostics
kubectl port-forward svc/ambassador-emissary-ingress 8877:8877 -n ingress-system
# Visit http://localhost:8877/ambassador/v0/diag/

# Check certificate manager logs
kubectl logs -l app.kubernetes.io/name=cert-manager -n ingress-system
```

---

**Status**: ✅ **DEPLOYED AND VERIFIED**  
**Workflow**: 🌐 Deploy Ingress + API Gateway Stack  
**Next**: 📈 Deploy LGTM Observability Stack  
**Resources**: 10 resources deployed successfully  
**Namespace**: `ingress-system`