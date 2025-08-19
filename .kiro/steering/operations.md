# Operational Procedures

## Deployment Sequences and Procedures

### Initial Platform Deployment

#### Phase 1: Foundation Infrastructure
```bash
# 1. Initialize Terraform backend
cd terraform/environments/dev
terraform init

# 2. Deploy VPC and networking
terraform plan -target=module.vpc -var-file="terraform.tfvars"
terraform apply -target=module.vpc -var-file="terraform.tfvars" -auto-approve

# 3. Deploy IAM roles and policies
terraform plan -target=module.iam -var-file="terraform.tfvars"
terraform apply -target=module.iam -var-file="terraform.tfvars" -auto-approve

# 4. Deploy EKS cluster
terraform plan -target=module.eks -var-file="terraform.tfvars"
terraform apply -target=module.eks -var-file="terraform.tfvars" -auto-approve

# 5. Update kubeconfig
aws eks update-kubeconfig --region us-east-1 --name eks-learning-lab-dev-cluster

# 6. Verify cluster health
kubectl get nodes
kubectl get pods -A
```

#### Phase 2: Ingress and External Access
```bash
# 1. Deploy cert-manager
terraform plan -target=module.cert-manager -var-file="terraform.tfvars"
terraform apply -target=module.cert-manager -var-file="terraform.tfvars" -auto-approve

# 2. Deploy external-dns
terraform plan -target=module.external-dns -var-file="terraform.tfvars"
terraform apply -target=module.external-dns -var-file="terraform.tfvars" -auto-approve

# 3. Deploy Ambassador API Gateway
terraform plan -target=module.ambassador -var-file="terraform.tfvars"
terraform apply -target=module.ambassador -var-file="terraform.tfvars" -auto-approve

# 4. Verify ingress components
kubectl get pods -n cert-manager
kubectl get pods -n external-dns
kubectl get pods -n ambassador
```

#### Phase 3: Observability Stack
```bash
# 1. Deploy LGTM observability stack
terraform plan -target=module.lgtm-observability -var-file="terraform.tfvars"
terraform apply -target=module.lgtm-observability -var-file="terraform.tfvars" -auto-approve

# 2. Verify observability components
kubectl get pods -n observability

# 3. Access Grafana dashboard
kubectl port-forward -n observability svc/grafana 3000:80
# Get admin password
kubectl get secret -n observability grafana-credentials -o jsonpath='{.data.admin-password}' | base64 -d
```

### Application Deployment Procedures

#### Microservices Deployment Sequence
```bash
# 1. Create namespace and configure Istio injection
kubectl create namespace ecotrack
kubectl label namespace ecotrack istio-injection=enabled

# 2. Deploy database infrastructure
kubectl apply -f k8s/database/postgres-cluster.yaml
kubectl apply -f k8s/database/redis-cluster.yaml

# 3. Wait for database readiness
kubectl wait --for=condition=Ready pod -l app=postgres-primary -n ecotrack --timeout=300s
kubectl wait --for=condition=Ready pod -l app=redis -n ecotrack --timeout=300s

# 4. Deploy services in dependency order
kubectl apply -f k8s/services/user-service/
kubectl apply -f k8s/services/product-service/
kubectl apply -f k8s/services/payment-service/
kubectl apply -f k8s/services/order-service/
kubectl apply -f k8s/services/notification-service/

# 5. Verify service health
kubectl get pods -n ecotrack
kubectl get svc -n ecotrack
kubectl get ingress -n ecotrack
```

#### Rolling Updates and Deployments
```bash
# 1. Update application image
kubectl set image deployment/user-service user-service=user-service:v1.2.0 -n ecotrack

# 2. Monitor rollout status
kubectl rollout status deployment/user-service -n ecotrack

# 3. Verify health after deployment
kubectl get pods -n ecotrack -l app=user-service
curl -f https://user-service.ecotrack.dev/actuator/health

# 4. Rollback if needed
kubectl rollout undo deployment/user-service -n ecotrack
```

## Common Operational Procedures

### Health Monitoring and Checks

#### Cluster Health Verification
```bash
# Node status and resource usage
kubectl get nodes
kubectl top nodes

# System pod health
kubectl get pods -n kube-system
kubectl get pods -n observability
kubectl get pods -n ambassador

# Resource usage by namespace
kubectl top pods -A --sort-by=memory
kubectl top pods -A --sort-by=cpu

# Persistent volume status
kubectl get pv
kubectl get pvc -A
```

#### Application Health Checks
```bash
# Service endpoint health
for service in user product order payment notification; do
  echo "Checking ${service}-service health..."
  curl -f https://${service}-service.ecotrack.dev/actuator/health || echo "FAILED"
done

# Database connectivity
kubectl exec -it postgres-primary-1 -n ecotrack -- psql -U ecotrack -d ecotrack -c "SELECT 1;"

# Redis connectivity
kubectl exec -it redis-0 -n ecotrack -- redis-cli ping

# Service mesh status
istioctl proxy-status
istioctl analyze -n ecotrack
```

### Log Management and Analysis

#### Centralized Log Access
```bash
# Access logs via Loki
kubectl port-forward -n observability svc/loki-query-frontend 3100:3100

# Query logs for specific service
curl -G -s "http://localhost:3100/loki/api/v1/query_range" \
  --data-urlencode 'query={namespace="ecotrack",app="user-service"}' \
  --data-urlencode 'start=2024-01-01T00:00:00Z' \
  --data-urlencode 'end=2024-01-01T23:59:59Z'

# Stream logs in real-time
kubectl logs -f deployment/user-service -n ecotrack
kubectl logs -f -l app=user-service -n ecotrack --all-containers=true
```

#### Log Analysis Procedures
```bash
# Error log analysis
kubectl logs -l app=user-service -n ecotrack --since=1h | grep -i error

# Performance analysis
kubectl logs -l app=user-service -n ecotrack --since=1h | grep -E "(slow|timeout|latency)"

# Security analysis
kubectl logs -l app=user-service -n ecotrack --since=1h | grep -E "(unauthorized|forbidden|authentication)"
```

### Performance Monitoring

#### Resource Usage Monitoring
```bash
# CPU and memory usage trends
kubectl top pods -n ecotrack --sort-by=memory
kubectl top pods -n ecotrack --sort-by=cpu

# HPA status and scaling events
kubectl get hpa -n ecotrack
kubectl describe hpa user-service-hpa -n ecotrack

# Node resource allocation
kubectl describe nodes | grep -E "(Allocated resources|Resource.*Requests.*Limits)"
```

#### Application Performance Metrics
```bash
# Prometheus metrics access
kubectl port-forward -n observability svc/prometheus-server 9090:80

# Key metrics to monitor:
# - HTTP request rate: rate(http_requests_total[5m])
# - HTTP error rate: rate(http_requests_total{status=~"5.."}[5m])
# - Response time: histogram_quantile(0.95, http_request_duration_seconds_bucket)
# - JVM memory usage: jvm_memory_used_bytes / jvm_memory_max_bytes
# - Database connection pool: hikaricp_connections_active / hikaricp_connections_max
```

### Maintenance Tasks

#### Regular Maintenance Schedule
```yaml
Daily Tasks:
  - Monitor cluster resource usage
  - Check application health endpoints
  - Review error logs and alerts
  - Verify backup completion

Weekly Tasks:
  - Update Helm charts and dependencies
  - Review security scan results
  - Analyze performance trends
  - Clean up unused resources

Monthly Tasks:
  - Update Kubernetes cluster version
  - Review and update resource quotas
  - Conduct disaster recovery testing
  - Update documentation and runbooks

Quarterly Tasks:
  - Security audit and penetration testing
  - Capacity planning review
  - Cost optimization analysis
  - Team training and knowledge sharing
```

#### Cluster Maintenance Procedures
```bash
# Node maintenance (drain and cordon)
kubectl cordon <node-name>
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data
# Perform maintenance
kubectl uncordon <node-name>

# Kubernetes version upgrade
aws eks update-cluster-version --name eks-learning-lab-dev-cluster --version 1.29
aws eks describe-update --name eks-learning-lab-dev-cluster --update-id <update-id>

# Node group version upgrade
aws eks update-nodegroup-version --cluster-name eks-learning-lab-dev-cluster --nodegroup-name <nodegroup-name>
```

## Troubleshooting Procedures

### Common Issues and Solutions

#### Pod Startup Issues
```bash
# Diagnose pod startup problems
kubectl describe pod <pod-name> -n ecotrack
kubectl logs <pod-name> -n ecotrack --previous

# Common causes and solutions:
# 1. Image pull errors
kubectl get events -n ecotrack --sort-by='.lastTimestamp'

# 2. Resource constraints
kubectl top nodes
kubectl describe node <node-name>

# 3. Configuration issues
kubectl get configmap -n ecotrack
kubectl get secret -n ecotrack
```

#### Network Connectivity Issues
```bash
# Test service-to-service connectivity
kubectl exec -it <pod-name> -n ecotrack -- curl http://user-service:80/actuator/health

# Check DNS resolution
kubectl exec -it <pod-name> -n ecotrack -- nslookup user-service.ecotrack.svc.cluster.local

# Verify network policies
kubectl get networkpolicy -n ecotrack
kubectl describe networkpolicy <policy-name> -n ecotrack

# Check Istio service mesh
istioctl proxy-config cluster <pod-name> -n ecotrack
istioctl proxy-config listener <pod-name> -n ecotrack
```

#### Database Connection Issues
```bash
# Check PostgreSQL cluster status
kubectl get cluster postgres-cluster -n ecotrack
kubectl describe cluster postgres-cluster -n ecotrack

# Test database connectivity
kubectl exec -it postgres-primary-1 -n ecotrack -- psql -U ecotrack -d ecotrack -c "\l"

# Check connection pool metrics
curl -s http://user-service.ecotrack.dev/actuator/metrics/hikaricp.connections.active
curl -s http://user-service.ecotrack.dev/actuator/metrics/hikaricp.connections.max
```

#### Observability Stack Issues
```bash
# Check Prometheus targets
kubectl port-forward -n observability svc/prometheus-server 9090:80
# Navigate to http://localhost:9090/targets

# Verify Loki log ingestion
kubectl logs -n observability -l app=promtail

# Check Grafana dashboard access
kubectl get secret -n observability grafana-credentials -o jsonpath='{.data.admin-password}' | base64 -d
kubectl port-forward -n observability svc/grafana 3000:80
```

### Performance Troubleshooting

#### High CPU/Memory Usage
```bash
# Identify resource-intensive pods
kubectl top pods -A --sort-by=cpu
kubectl top pods -A --sort-by=memory

# Analyze JVM heap usage
curl -s http://user-service.ecotrack.dev/actuator/metrics/jvm.memory.used | jq '.measurements[0].value'
curl -s http://user-service.ecotrack.dev/actuator/metrics/jvm.memory.max | jq '.measurements[0].value'

# Check garbage collection metrics
curl -s http://user-service.ecotrack.dev/actuator/metrics/jvm.gc.pause
```

#### Slow Response Times
```bash
# Analyze HTTP request metrics
curl -s http://user-service.ecotrack.dev/actuator/metrics/http.server.requests

# Check database query performance
kubectl exec -it postgres-primary-1 -n ecotrack -- psql -U ecotrack -d ecotrack -c "
SELECT query, mean_exec_time, calls 
FROM pg_stat_statements 
ORDER BY mean_exec_time DESC 
LIMIT 10;"

# Review distributed traces
kubectl port-forward -n observability svc/tempo-query-frontend 3200:3200
# Access Grafana and query traces
```

## Incident Response and Recovery Procedures

### Incident Classification and Response

#### Severity Levels
```yaml
Critical (P0):
  description: Complete service outage, data loss risk
  response_time: Immediate (< 15 minutes)
  escalation: On-call engineer + management
  examples: Cluster down, database corruption, security breach

High (P1):
  description: Major functionality impaired, significant user impact
  response_time: < 1 hour
  escalation: On-call engineer
  examples: Service degradation, authentication issues, payment failures

Medium (P2):
  description: Minor functionality impaired, limited user impact
  response_time: < 4 hours
  escalation: Next business day
  examples: Non-critical feature issues, performance degradation

Low (P3):
  description: Cosmetic issues, no user impact
  response_time: < 24 hours
  escalation: Planned maintenance
  examples: Documentation updates, minor UI issues
```

#### Incident Response Workflow
```bash
# 1. Immediate Response (0-15 minutes)
# - Acknowledge alert
# - Assess impact and severity
# - Implement immediate mitigation if available

# 2. Investigation (15-60 minutes)
# - Gather logs and metrics
kubectl logs -l app=<affected-service> -n ecotrack --since=1h
kubectl get events -n ecotrack --sort-by='.lastTimestamp'

# - Check system health
kubectl get pods -n ecotrack
kubectl top nodes

# 3. Communication (Within 1 hour)
# - Notify stakeholders
# - Update status page
# - Document findings

# 4. Resolution and Recovery
# - Implement fix
# - Verify resolution
# - Monitor for recurrence

# 5. Post-Incident Review
# - Document root cause
# - Identify improvements
# - Update procedures
```

### Disaster Recovery Procedures

#### Backup and Restore Operations
```bash
# Database backup verification
kubectl exec -it postgres-primary-1 -n ecotrack -- pg_dumpall -U postgres > backup.sql

# Persistent volume backup
kubectl get pv
aws ec2 create-snapshot --volume-id <ebs-volume-id> --description "EcoTrack backup $(date)"

# Configuration backup
kubectl get all -n ecotrack -o yaml > ecotrack-backup.yaml
kubectl get configmap -n ecotrack -o yaml >> ecotrack-backup.yaml
kubectl get secret -n ecotrack -o yaml >> ecotrack-backup.yaml
```

#### Cluster Recovery Procedures
```bash
# 1. Assess damage and data integrity
kubectl get nodes
kubectl get pods -A
kubectl get pv

# 2. Restore from backup if needed
kubectl apply -f ecotrack-backup.yaml

# 3. Verify service functionality
for service in user product order payment notification; do
  curl -f https://${service}-service.ecotrack.dev/actuator/health
done

# 4. Monitor for stability
kubectl get events -A --sort-by='.lastTimestamp'
kubectl logs -f -l app=user-service -n ecotrack
```

### Escalation Procedures

#### Contact Information and Escalation Matrix
```yaml
Level 1 - On-Call Engineer:
  response_time: 15 minutes
  responsibilities: Initial response, basic troubleshooting
  escalation_criteria: Cannot resolve within 1 hour

Level 2 - Senior Engineer:
  response_time: 30 minutes
  responsibilities: Advanced troubleshooting, architecture decisions
  escalation_criteria: Requires architectural changes or vendor support

Level 3 - Engineering Manager:
  response_time: 1 hour
  responsibilities: Resource allocation, external communication
  escalation_criteria: Business impact, customer communication needed

Level 4 - CTO/VP Engineering:
  response_time: 2 hours
  responsibilities: Executive decisions, public communication
  escalation_criteria: Major outage, security incident, regulatory issues
```

#### Communication Templates
```yaml
Initial Alert:
  subject: "[P{severity}] {service} - {brief_description}"
  body: |
    Incident: {incident_id}
    Severity: P{severity}
    Service: {affected_service}
    Impact: {user_impact_description}
    Started: {incident_start_time}
    Status: Investigating
    ETA: {estimated_resolution_time}

Status Update:
  subject: "[UPDATE] [P{severity}] {service} - {brief_description}"
  body: |
    Incident: {incident_id}
    Update: {progress_description}
    Current Status: {current_status}
    Next Update: {next_update_time}
    ETA: {updated_eta}

Resolution:
  subject: "[RESOLVED] [P{severity}] {service} - {brief_description}"
  body: |
    Incident: {incident_id}
    Resolution: {resolution_description}
    Root Cause: {root_cause_summary}
    Resolved: {resolution_time}
    Post-Mortem: {post_mortem_link}
```