# Tekton Dashboard Configuration
dashboard:
  replicas: 1
  
  # Service configuration
  service:
    type: ClusterIP
    port: 9097
  
  # Ingress configuration
  %{if domain != ""}
  ingress:
    enabled: true
    className: ambassador
    annotations:
      getambassador.io/config: |
        ---
        apiVersion: getambassador.io/v3alpha1
        kind: Mapping
        name: tekton-dashboard
        prefix: /
        service: tekton-dashboard:9097
        host: ${domain}
        %{if enable_tls}
        tls: tekton-dashboard-tls
        %{endif}
    hosts:
      - host: ${domain}
        paths:
          - path: /
            pathType: Prefix
    %{if enable_tls}
    tls:
      - secretName: tekton-dashboard-tls
        hosts:
          - ${domain}
    %{endif}
  %{endif}
  
  # Resource configuration
  resources:
    requests:
      cpu: 100m
      memory: 100Mi
    limits:
      cpu: 500m
      memory: 500Mi
      
  # Node selector
  nodeSelector:
    kubernetes.io/os: linux
    
  # Security context
  securityContext:
    runAsNonRoot: true
    runAsUser: 65532
    fsGroup: 65532
    
  # Environment variables
  env:
    - name: INSTALLED_NAMESPACE
      valueFrom:
        fieldRef:
          fieldPath: metadata.namespace

# RBAC configuration
rbac:
  create: true
  
# Service Account
serviceAccount:
  create: true
  name: tekton-dashboard

# Pod Security Standards
podSecurityStandards:
  enforceLevel: "baseline"
  warnLevel: "baseline"
  auditLevel: "baseline"
