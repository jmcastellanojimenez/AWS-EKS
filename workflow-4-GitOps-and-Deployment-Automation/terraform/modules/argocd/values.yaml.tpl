# ArgoCD Helm Values Template
global:
  domain: ${domain != "" ? domain : "argocd.local"}

configs:
  params:
    server.insecure: ${enable_tls ? "false" : "true"}
    controller.repo.server.timeout.seconds: "600"
    controller.status.processors: "20"
    controller.operation.processors: "10"
    
  cm:
    # Enable exec for debugging
    exec.enabled: "true"
    # Repository timeout
    timeout.reconciliation: "300s"
    # Application in any namespace
    application.instanceLabelKey: argocd.argoproj.io/instance
    
    # OIDC configuration (if using external auth)
    %{if domain != ""}
    url: https://${domain}
    %{endif}
    
    # Resource customizations
    resource.customizations: |
      networking.k8s.io/Ingress:
        health.lua: |
          hs = {}
          hs.status = "Healthy"
          return hs

  rbac:
    policy.default: role:readonly
    policy.csv: |
      p, role:admin, applications, *, */*, allow
      p, role:admin, clusters, *, *, allow
      p, role:admin, repositories, *, *, allow
      p, role:developer, applications, get, */*, allow
      p, role:developer, applications, sync, */*, allow
      g, argocd-admins, role:admin

  repositories:
    ecotrack-apps:
      url: https://github.com/your-org/ecotrack-apps
      type: git
    ecotrack-manifests:
      url: https://github.com/your-org/ecotrack-manifests
      type: git

# Controller configuration
controller:
  replicas: ${replica_count}
  
  serviceAccount:
    create: true
    name: argocd-application-controller
    annotations:
      eks.amazonaws.com/role-arn: ${role_arn}
  
  metrics:
    enabled: ${enable_monitoring}
    serviceMonitor:
      enabled: ${enable_monitoring}
      
  resources:
    limits:
      cpu: 500m
      memory: 512Mi
    requests:
      cpu: 250m
      memory: 256Mi

# Server configuration  
server:
  replicas: ${replica_count}
  
  %{if domain != ""}
  ingress:
    enabled: true
    ingressClassName: ambassador
    annotations:
      getambassador.io/config: |
        ---
        apiVersion: getambassador.io/v3alpha1
        kind: Mapping
        name: argocd-server
        prefix: /
        service: argocd-server:80
        host: ${domain}
        %{if enable_tls}
        tls: argocd-tls
        %{endif}
    hosts:
      - ${domain}
    %{if enable_tls}
    tls:
      - secretName: argocd-tls
        hosts:
          - ${domain}
    %{endif}
  %{else}
  service:
    type: LoadBalancer
  %{endif}
  
  metrics:
    enabled: ${enable_monitoring}
    serviceMonitor:
      enabled: ${enable_monitoring}
      
  resources:
    limits:
      cpu: 200m
      memory: 256Mi
    requests:
      cpu: 100m
      memory: 128Mi

# Repository server configuration
repoServer:
  replicas: ${replica_count}
  
  serviceAccount:
    create: true
    annotations:
      eks.amazonaws.com/role-arn: ${role_arn}
  
  metrics:
    enabled: ${enable_monitoring}
    serviceMonitor:
      enabled: ${enable_monitoring}
      
  resources:
    limits:
      cpu: 200m
      memory: 256Mi
    requests:
      cpu: 100m
      memory: 128Mi

# ApplicationSet controller
applicationSet:
  enabled: true
  replicas: ${replica_count}
  
  metrics:
    enabled: ${enable_monitoring}
    serviceMonitor:
      enabled: ${enable_monitoring}
      
  resources:
    limits:
      cpu: 100m
      memory: 128Mi
    requests:
      cpu: 50m
      memory: 64Mi

# Notifications controller
notifications:
  enabled: ${enable_notifications}
  
  %{if slack_webhook != ""}
  secret:
    create: true
    items:
      slack-token: ${slack_webhook}
      
  notifiers:
    service.slack: |
      token: $slack-token
      
  templates:
    template.app-deployed: |
      message: |
        Application {{.app.metadata.name}} is now running new version.
      slack:
        attachments: |
          [{
            "title": "{{.app.metadata.name}}",
            "title_link":"{{.context.argocdUrl}}/applications/{{.app.metadata.name}}",
            "color": "#18be52",
            "fields": [
            {
              "title": "Sync Status",
              "value": "{{.app.status.sync.status}}",
              "short": true
            },
            {
              "title": "Repository",
              "value": "{{.app.spec.source.repoURL}}",
              "short": true
            },
            {
              "title": "Revision",
              "value": "{{.app.status.sync.revision}}",
              "short": true
            }]
          }]
          
    template.app-health-degraded: |
      message: |
        Application {{.app.metadata.name}} has degraded health.
      slack:
        attachments: |
          [{
            "title": "{{.app.metadata.name}}",
            "title_link": "{{.context.argocdUrl}}/applications/{{.app.metadata.name}}",
            "color": "#f4c430",
            "fields": [
            {
              "title": "Health Status",
              "value": "{{.app.status.health.status}}",
              "short": true
            },
            {
              "title": "Repository",
              "value": "{{.app.spec.source.repoURL}}",
              "short": true
            }]
          }]
          
  triggers:
    trigger.on-deployed: |
      - when: app.status.operationState.phase in ['Succeeded'] and app.status.health.status == 'Healthy'
        send: [app-deployed]
    trigger.on-health-degraded: |
      - when: app.status.health.status == 'Degraded'
        send: [app-health-degraded]
  %{endif}

# Redis configuration
redis:
  enabled: true
  
  metrics:
    enabled: ${enable_monitoring}
    serviceMonitor:
      enabled: ${enable_monitoring}

# Dex (disabled - using built-in auth)
dex:
  enabled: false
