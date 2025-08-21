# Analyze GitHub Actions

Análisis detallado de workflows de GitHub Actions:

**Workflow**: $ARGUMENTS

Análisis incluye:
1. **Workflow Structure** - Jobs, steps, dependencies
2. **Authentication** - AWS credentials, OIDC, permissions
3. **Terraform Integration** - Init, plan, apply sequence
4. **Error Patterns** - Common failure points
5. **Resource Timing** - CRD installation, dependencies
6. **Optimization** - Caching, parallelization, efficiency

Revisa:
- .github/workflows/ files
- Terraform backend configuration
- AWS IAM roles and policies
- EKS cluster authentication
- Resource creation order
- Error logs and failure patterns
