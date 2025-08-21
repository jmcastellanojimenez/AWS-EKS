# Deploy EKS Workflow

Deploy específico workflow de la plataforma EKS:

**Workflow**: $ARGUMENTS

Workflows disponibles:
1. **foundation** - VPC, EKS cluster, IAM, add-ons
2. **ingress** - Ambassador, cert-manager, external-dns  
3. **observability** - Prometheus, Loki, Tempo, Grafana
4. **gitops** - ArgoCD, Tekton, Kaniko, Trivy
5. **security** - OpenBao, OPA Gatekeeper, Falco
6. **service-mesh** - Istio, Kiali, traffic management
7. **data-services** - PostgreSQL, Redis, Kafka

Proceso:
1. Verificar dependencias del workflow anterior
2. Aplicar terraform plan para validar cambios
3. Ejecutar terraform apply con aprobación
4. Verificar recursos creados correctamente
5. Configurar monitoring y alertas
6. Documentar cambios realizados
