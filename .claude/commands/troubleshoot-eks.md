# Troubleshoot EKS Issue

Diagnóstico específico para problemas de AWS EKS:

**Issue**: $ARGUMENTS

Áreas de diagnóstico:
1. **terraform** - Errores de plan/apply, dependencias, state
2. **github-actions** - Fallos de CI/CD, autenticación AWS
3. **eks-cluster** - Problemas de conectividad, nodes, add-ons
4. **helm-charts** - Fallos de instalación, CRDs, valores
5. **networking** - VPC, subnets, security groups, Istio
6. **crd-order** - Problemas de orden de instalación de CRDs
7. **gitops** - ArgoCD, sync issues, applications

Proceso sistemático:
1. Identificar el componente afectado
2. Revisar logs relevantes (terraform, kubectl, GitHub Actions)
3. Verificar dependencias y prerrequisitos
4. Validar configuración y variables
5. Proponer solución con pasos específicos
6. Implementar fix con verificación
