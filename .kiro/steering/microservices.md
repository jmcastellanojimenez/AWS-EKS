# Microservices Integration

## EcoTrack Application Architecture

### Service Overview
The EcoTrack application consists of 5 microservices designed for environmental tracking and sustainability management:

```yaml
Services:
  user-service:
    purpose: User management, authentication, profiles
    database: PostgreSQL (users, roles, preferences)
    external_apis: OAuth providers, email services
    
  product-service:
    purpose: Product catalog, sustainability metrics
    database: PostgreSQL (products, categories, metrics)
    external_apis: Product data providers, carbon footprint APIs
    
  order-service:
    purpose: Order processing, fulfillment tracking
    database: PostgreSQL (orders, order_items, status)
    dependencies: [user-service, product-service, payment-service]
    
  payment-service:
    purpose: Payment processing, billing management
    database: PostgreSQL (payments, billing, invoices)
    external_apis: Payment gateways (Stripe, PayPal)
    
  notification-service:
    purpose: Email, SMS, push notifications
    database: Redis (notification queue, templates)
    external_apis: Email providers, SMS gateways, push services
```

### Spring Boot Integration Requirements

#### Standard Spring Boot Configuration
```yaml
Application Properties:
  server.port: 8080
  management.endpoints.web.exposure.include: health,info,metrics,prometheus
  management.endpoint.health.show-details: always
  management.metrics.export.prometheus.enabled: true
  
Actuator Endpoints:
  /actuator/health: Kubernetes liveness/readiness probes
  /actuator/info: Application metadata and version
  /actuator/metrics: Micrometer metrics
  /actuator/prometheus: Prometheus-formatted metrics
  /actuator/env: Environment configuration (secured)
```

#### Database Integration Patterns
```yaml
Spring Data JPA Configuration:
  spring.datasource.url: jdbc:postgresql://postgres-primary:5432/ecotrack
  spring.jpa.hibernate.ddl-auto: validate
  spring.jpa.show-sql: false
  spring.jpa.properties.hibernate.format_sql: true
  
Connection Pool (HikariCP):
  spring.datasource.hikari.maximum-pool-size: 10
  spring.datasource.hikari.minimum-idle: 2
  spring.datasource.hikari.connection-timeout: 30000
  spring.datasource.hikari.idle-timeout: 600000
```

#### OpenTelemetry Integration
```yaml
OpenTelemetry Configuration:
  otel.service.name: ${spring.application.name}
  otel.resource.attributes: service.version=${app.version}
  otel.exporter.otlp.endpoint: http://tempo-distributor:4317
  otel.traces.exporter: otlp
  otel.metrics.exporter: prometheus
  
Instrumentation:
  - Spring Boot auto-instrumentation
  - Database query tracing
  - HTTP client/server tracing
  - Custom business logic spans
```

## Platform Integration Patterns

### Kubernetes Deployment Configuration

#### Standard Deployment Template
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${service-name}
  namespace: ecotrack
  labels:
    app: ${service-name}
    version: v1
spec:
  replicas: 3
  selector:
    matchLabels:
      app: ${service-name}
  template:
    metadata:
      labels:
        app: ${service-name}
        version: v1
      annotations:
        sidecar.istio.io/inject: "true"
        prometheus.io/scrape: "true"
        prometheus.io/port: "8080"
        prometheus.io/path: "/actuator/prometheus"
    spec:
      serviceAccountName: ${service-name}-sa
      containers:
      - name: ${service-name}
        image: ${service-name}:${version}
        ports:
        - containerPort: 8080
          name: http
        resources:
          requests:
            memory: "256Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
            cpu: "300m"
        env:
        - name: SPRING_PROFILES_ACTIVE
          value: "kubernetes"
        - name: OTEL_SERVICE_NAME
          value: ${service-name}
        livenessProbe:
          httpGet:
            path: /actuator/health/liveness
            port: 8080
          initialDelaySeconds: 60
          periodSeconds: 30
        readinessProbe:
          httpGet:
            path: /actuator/health/readiness
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
```

#### Service and Ingress Configuration
```yaml
apiVersion: v1
kind: Service
metadata:
  name: ${service-name}
  namespace: ecotrack
  labels:
    app: ${service-name}
spec:
  selector:
    app: ${service-name}
  ports:
  - port: 80
    targetPort: 8080
    name: http
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ${service-name}
  namespace: ecotrack
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
    external-dns.alpha.kubernetes.io/hostname: ${service-name}.ecotrack.dev
spec:
  tls:
  - hosts:
    - ${service-name}.ecotrack.dev
    secretName: ${service-name}-tls
  rules:
  - host: ${service-name}.ecotrack.dev
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: ${service-name}
            port:
              number: 80
```

### Observability Integration

#### Prometheus Metrics Collection
```yaml
Automatic Metrics:
  - JVM metrics (memory, GC, threads)
  - HTTP request metrics (duration, status codes)
  - Database connection pool metrics
  - Custom business metrics via Micrometer

Service Discovery:
  - Kubernetes service discovery via annotations
  - Automatic scraping of /actuator/prometheus endpoints
  - Namespace-based metric labeling

Alerting Rules:
  - High error rate (>5% 5xx responses)
  - High response time (>2s p95)
  - Database connection pool exhaustion
  - Memory usage >80%
  - Pod restart frequency
```

#### Loki Log Aggregation
```yaml
Log Configuration:
  format: JSON structured logging
  level: INFO (DEBUG in development)
  correlation_id: Trace ID from OpenTelemetry
  
Automatic Collection:
  - Promtail DaemonSet collects all pod logs
  - Namespace-based log routing
  - Automatic parsing of JSON logs
  
Log Labels:
  - namespace: ecotrack
  - service: ${service-name}
  - pod: ${pod-name}
  - container: ${service-name}
```

#### Tempo Distributed Tracing
```yaml
Trace Collection:
  - OpenTelemetry auto-instrumentation
  - Automatic trace correlation across services
  - Database query tracing
  - HTTP client/server spans
  
Trace Sampling:
  - 100% sampling in development
  - 10% sampling in production
  - Always sample on errors
  
Trace Attributes:
  - service.name: ${service-name}
  - service.version: ${app-version}
  - http.method, http.status_code
  - db.statement, db.connection_string
```

## Service Mesh Integration

### Istio Configuration

#### Service Mesh Injection
```yaml
Namespace Configuration:
  apiVersion: v1
  kind: Namespace
  metadata:
    name: ecotrack
    labels:
      istio-injection: enabled
      
Automatic Features:
  - mTLS between all services
  - Traffic management and load balancing
  - Circuit breaking and retries
  - Observability (metrics, logs, traces)
```

#### Traffic Management
```yaml
Virtual Service Example:
  apiVersion: networking.istio.io/v1beta1
  kind: VirtualService
  metadata:
    name: user-service
    namespace: ecotrack
  spec:
    hosts:
    - user-service
    http:
    - match:
      - headers:
          canary:
            exact: "true"
      route:
      - destination:
          host: user-service
          subset: canary
        weight: 100
    - route:
      - destination:
          host: user-service
          subset: stable
        weight: 100
    timeout: 30s
    retries:
      attempts: 3
      perTryTimeout: 10s
```

#### Security Policies
```yaml
Authorization Policy:
  apiVersion: security.istio.io/v1beta1
  kind: AuthorizationPolicy
  metadata:
    name: ecotrack-authz
    namespace: ecotrack
  spec:
    rules:
    - from:
      - source:
          namespaces: ["ecotrack", "istio-system"]
    - to:
      - operation:
          methods: ["GET", "POST", "PUT", "DELETE"]
          paths: ["/api/*", "/actuator/health"]
```

## Security Integration Guidelines

### Secrets Management with OpenBao
```yaml
External Secrets Configuration:
  apiVersion: external-secrets.io/v1beta1
  kind: SecretStore
  metadata:
    name: vault-backend
    namespace: ecotrack
  spec:
    provider:
      vault:
        server: "https://openbao.security.svc.cluster.local:8200"
        path: "secret"
        version: "v2"
        auth:
          kubernetes:
            mountPath: "kubernetes"
            role: "ecotrack-role"
            serviceAccountRef:
              name: "ecotrack-sa"
```

### OPA Gatekeeper Policies
```yaml
Resource Quotas Policy:
  apiVersion: templates.gatekeeper.sh/v1beta1
  kind: ConstraintTemplate
  metadata:
    name: k8srequiredresources
  spec:
    crd:
      spec:
        names:
          kind: K8sRequiredResources
        validation:
          properties:
            limits:
              type: array
              items:
                type: string
    targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8srequiredresources
        violation[{"msg": msg}] {
          container := input.review.object.spec.template.spec.containers[_]
          not container.resources.limits
          msg := "Container must have resource limits"
        }
```

### Network Policies
```yaml
Network Policy:
  apiVersion: networking.k8s.io/v1
  kind: NetworkPolicy
  metadata:
    name: ecotrack-netpol
    namespace: ecotrack
  spec:
    podSelector:
      matchLabels:
        app: user-service
    policyTypes:
    - Ingress
    - Egress
    ingress:
    - from:
      - namespaceSelector:
          matchLabels:
            name: istio-system
      - podSelector:
          matchLabels:
            app: order-service
    egress:
    - to:
      - podSelector:
          matchLabels:
            app: postgres-primary
      ports:
      - protocol: TCP
        port: 5432
```

## Database Integration Patterns

### PostgreSQL with CloudNativePG
```yaml
Database Configuration:
  apiVersion: postgresql.cnpg.io/v1
  kind: Cluster
  metadata:
    name: postgres-cluster
    namespace: ecotrack
  spec:
    instances: 3
    primaryUpdateStrategy: unsupervised
    postgresql:
      parameters:
        max_connections: "200"
        shared_buffers: "256MB"
        effective_cache_size: "1GB"
    bootstrap:
      initdb:
        database: ecotrack
        owner: ecotrack
        secret:
          name: postgres-credentials
    storage:
      size: 100Gi
      storageClass: gp3
```

### Redis Integration
```yaml
Redis Configuration:
  apiVersion: databases.spotahome.com/v1
  kind: RedisFailover
  metadata:
    name: redis-cluster
    namespace: ecotrack
  spec:
    sentinel:
      replicas: 3
      resources:
        requests:
          memory: "128Mi"
          cpu: "50m"
        limits:
          memory: "256Mi"
          cpu: "100m"
    redis:
      replicas: 3
      resources:
        requests:
          memory: "256Mi"
          cpu: "100m"
        limits:
          memory: "512Mi"
          cpu: "200m"
      storage:
        persistentVolumeClaim:
          metadata:
            name: redis-storage
          spec:
            accessModes:
            - ReadWriteOnce
            resources:
              requests:
                storage: 10Gi
```

## Performance and Scaling Patterns

### Horizontal Pod Autoscaling
```yaml
HPA Configuration:
  apiVersion: autoscaling/v2
  kind: HorizontalPodAutoscaler
  metadata:
    name: ${service-name}-hpa
    namespace: ecotrack
  spec:
    scaleTargetRef:
      apiVersion: apps/v1
      kind: Deployment
      name: ${service-name}
    minReplicas: 3
    maxReplicas: 10
    metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: 80
    behavior:
      scaleUp:
        stabilizationWindowSeconds: 60
        policies:
        - type: Percent
          value: 100
          periodSeconds: 15
      scaleDown:
        stabilizationWindowSeconds: 300
        policies:
        - type: Percent
          value: 10
          periodSeconds: 60
```

### Circuit Breaker Patterns
```yaml
Istio Destination Rule:
  apiVersion: networking.istio.io/v1beta1
  kind: DestinationRule
  metadata:
    name: ${service-name}
    namespace: ecotrack
  spec:
    host: ${service-name}
    trafficPolicy:
      connectionPool:
        tcp:
          maxConnections: 100
        http:
          http1MaxPendingRequests: 50
          maxRequestsPerConnection: 10
      outlierDetection:
        consecutiveErrors: 3
        interval: 30s
        baseEjectionTime: 30s
        maxEjectionPercent: 50
```

## Development and Testing Integration

### Local Development Setup
```yaml
Docker Compose Override:
  version: '3.8'
  services:
    ${service-name}:
      build: .
      ports:
        - "8080:8080"
      environment:
        - SPRING_PROFILES_ACTIVE=local
        - OTEL_EXPORTER_OTLP_ENDPOINT=http://jaeger:14268/api/traces
      depends_on:
        - postgres
        - redis
        
    postgres:
      image: postgres:15
      environment:
        POSTGRES_DB: ecotrack
        POSTGRES_USER: ecotrack
        POSTGRES_PASSWORD: password
      ports:
        - "5432:5432"
```

### Integration Testing
```yaml
Test Configuration:
  spring.test.database.replace: none
  spring.datasource.url: jdbc:h2:mem:testdb
  spring.jpa.hibernate.ddl-auto: create-drop
  
TestContainers Integration:
  - PostgreSQL container for integration tests
  - Redis container for caching tests
  - WireMock for external API mocking
  - Testcontainers for Kafka testing
```