# Tekton Triggers Configuration
controller:
  replicas: 1
  
  # Enable metrics
  %{if enable_monitoring}
  metrics:
    enabled: true
    port: 9000
  %{endif}
  
  resources:
    requests:
      cpu: 100m
      memory: 100Mi
    limits:
      cpu: 500m
      memory: 500Mi
      
  # Node selector for controller
  nodeSelector:
    kubernetes.io/os: linux
    
  # Security context
  securityContext:
    runAsNonRoot: true
    runAsUser: 65532
    fsGroup: 65532

webhook:
  replicas: 1
  
  # Service configuration
  service:
    type: ClusterIP
    port: 8080
  
  resources:
    requests:
      cpu: 100m
      memory: 20Mi
    limits:
      cpu: 500m
      memory: 500Mi
      
  # Node selector for webhook
  nodeSelector:
    kubernetes.io/os: linux
    
  # Security context
  securityContext:
    runAsNonRoot: true
    runAsUser: 65532
    fsGroup: 65532

# Core Interceptors
coreInterceptors:
  replicas: 1
  
  resources:
    requests:
      cpu: 100m
      memory: 100Mi
    limits:
      cpu: 500m
      memory: 500Mi
      
  # Node selector for core interceptors
  nodeSelector:
    kubernetes.io/os: linux
    
  # Security context
  securityContext:
    runAsNonRoot: true
    runAsUser: 65532
    fsGroup: 65532

# Pod Security Standards
podSecurityStandards:
  enforceLevel: "baseline"
  warnLevel: "baseline"
  auditLevel: "baseline"
