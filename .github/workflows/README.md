# GitHub Actions Workflows

## ✅ Active Workflows (9 total)

### 🚀 Platform Deployment Workflows (7)

| Workflow | File | Description |
|----------|------|-------------|
| **1️⃣ Foundation Platform** | `foundation-platform.yml` | VPC, EKS cluster, IAM, core add-ons |
| **2️⃣ Ingress + API Gateway** | `ingress-api-gateway-stack.yml` | Ambassador, cert-manager, external-dns |
| **3️⃣ LGTM Observability** | `lgtm-observability-stack.yml` | Prometheus, Loki, Grafana, Tempo, Mimir |
| **4️⃣ GitOps & Deployment** | `gitops-deployment-automation.yml` | ArgoCD, Tekton, Kaniko, Trivy |
| **5️⃣ Security Foundation** | `security-foundation.yml` | OpenBao, OPA Gatekeeper, Falco |
| **6️⃣ Service Mesh** | `service-mesh.yml` | Istio, Kiali, traffic management |
| **7️⃣ Data Services** | `data-services.yml` | PostgreSQL, Redis, Kafka |

### 🔧 Management Workflows (2)

| Workflow | File | Description |
|----------|------|-------------|
| **📦 Complete Platform** | `complete-platform-deployment.yml` | Deploy all 7 workflows in sequence |
| **🗑️ Destroy Infrastructure** | `destroy-infrastructure.yml` | Safely destroy any/all workflows |

## 📋 Deployment Order

Must be deployed in sequence:
1. Foundation → 2. Ingress → 3. LGTM → 4. GitOps → 5. Security → 6. Service Mesh → 7. Data Services

## 🎯 Usage

### Deploy Individual Workflow
1. Go to Actions tab
2. Select workflow (e.g., "Foundation Platform")
3. Click "Run workflow"
4. Select environment (dev/staging/prod)
5. Confirm deployment

### Deploy Everything
Use `complete-platform-deployment.yml` for automated sequential deployment

### Destroy Infrastructure
Use `destroy-infrastructure.yml` with options:
- Destroy all
- Destroy specific workflow
- Destroy multiple workflows

## ❌ Removed Workflows

The following deprecated workflows have been removed:
- cleanup.yml
- daily-cost-monitoring.yml
- deploy-ingress-complete.yml
- deploy-ingress.yml
- docker-build.yml
- ingress-controllers.yml
- ingress-infrastructure.yml
- ingress-validation.yml
- terraform-apply.yml
- terraform-plan.yml
- update-eks-addons.yml
- validate-gitops-fix.yml

These were old SA Infra workflows and are no longer needed.