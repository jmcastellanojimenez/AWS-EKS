# Tekton Pipelines Configuration
config:
  defaults:
    default-timeout-minutes: "60"
    default-service-account: "tekton-build-sa"
    default-managed-by-label-value: "tekton-pipelines"
    default-pod-template: |
      securityContext:
        runAsNonRoot: true
        runAsUser: 65532
        fsGroup: 65532
      nodeSelector:
        kubernetes.io/os: linux
      tolerations:
      - key: kubernetes.io/arch
        operator: Equal
        value: amd64
        effect: NoSchedule
      - key: kubernetes.io/arch
        operator: Equal
        value: arm64
        effect: NoSchedule

  artifact-bucket: |
    location: s3://tekton-artifacts-${namespace}
    bucket.service.account.secret.name: tekton-build-sa
    bucket.service.account.secret.key: serviceaccount
    
  artifact-pvc: |
    size: 10Gi
    storageClassName: ${storage_class}

controller:
  replicas: 1
  
  # Enable metrics
  %{if enable_monitoring}
  metrics:
    enabled: true
    port: 9090
  %{endif}
  
  resources:
    requests:
      cpu: 100m
      memory: 100Mi
    limits:
      cpu: 1000m
      memory: 4Gi
      
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

# Pod Security Standards
podSecurityStandards:
  enforceLevel: "baseline"
  warnLevel: "baseline"
  auditLevel: "baseline"

# Feature flags
featureFlags:
  # Enable Task-level resource requirements
  enable-task-resource-limits: "true"
  # Enable Tekton API fields
  enable-tekton-oci-bundles: "true"
  # Enable custom task validation
  enable-custom-tasks: "true"
  # Enable StepActions
  enable-step-actions: "true"
