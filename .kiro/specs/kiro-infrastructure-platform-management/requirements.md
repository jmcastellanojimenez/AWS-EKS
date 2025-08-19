# Infrastructure Platform 🎯

## Project Overview

**Objective**: Build a cloud-agnostic, enterprise-grade Infrastructure Platform on AWS EKS designed specifically for **microservices architectures**.

**Key Principles**:
* 🔄 **Reusable**: Platform works for any application
* 🌐 **Cloud-Agnostic**: Easy migration between AWS, GCP, Azure  
* 🔧 **GitOps-Native**: Everything managed through Git
* 📊 **Observable**: Complete LGTM stack observability
* 🔒 **Secure**: Zero-trust security model
* 🏗️ **Microservices-Ready**: Optimized for distributed architectures

## 🏗️ Core Platform Requirements

**Compute Resources**:
```yaml
EKS Cluster Configuration:
  Instance Type: t3.large (2 vCPU, 8GB RAM)
  Auto-scaling: 3-10 nodes
  Capacity Type: SPOT instances (cost optimization)
  Region: us-east-1 (US East - N. Virginia)
  
Microservices Resource Allocation:
  Memory: 256Mi request, 512Mi limit per service
  CPU: 100m request, 300m limit per service   
  Replicas: 3 per service (HPA enabled)   

Platform Components Resource Requirements:
  Ambassador: ~500Mi memory, 200m CPU
  LGTM Stack: ~2GB memory, 1 CPU
  ArgoCD: ~1GB memory, 500m CPU
  Istio: ~800Mi memory, 300m CPU
  Security Tools: ~600Mi memory, 200m CPU
```

## 🔄 Workflow List

### 🏗️ Workflow 1: Foundation Platform
**Description**: Production-ready EKS cluster with VPC, IAM, CNI, and essential add-ons 
**Components**: VPC Infrastructure, EKS Cluster, IAM & Security, Cilium CNI, Essential Add-ons

### 🌐 Workflow 2: Ingress + API Gateway Stack 
**Description**: Kubernetes-native ingress with automatic SSL and DNS management 
**Components**: Ambassador (emissary-ingress), cert-manager, external-dns + Cloudflare

### 📈 Workflow 3: Observability Stack
**Description**: Complete observability using LGTM stack with long-term storage 
**Components**: Prometheus + Mimir, Loki, Grafana, Tempo + OpenTelemetry

### 🔄 Workflow 4: GitOps & Deployment Automation
**Description**: Pure GitOps deployment automation with application lifecycle management 
**Components**: ArgoCD, Tekton, Git repositories

### 🔐 Workflow 5: Security Foundation
**Description**: Vault secrets management with policy enforcement and runtime security 
**Components**: OpenBao + ExternalSecret, OPA Gatekeeper, Falco

### 🛡️ Workflow 6: Service Mesh
**Description**: mTLS for all services with traffic management and security policies 
**Components**: Istio

### 📊 Workflow 7: Data Services
**Description**: Database, cache, and messaging services with operators 
**Components**: CloudNativePG (PostgreSQL), Spotahome Redis Operator, Strimzi Kafka

## Additional Requirements
- Use the Terraform structure employed in workflows 1, 2, and 3
- The names of GitHub workflows must be entered exactly as they appear in the list, icon included
- Once we have tested all the workflows, final task: Microservices Platform Configuration Guide: A dedicated `.md` file explaining how to adapt and configure both the platform and microservices applications to leverage the complete deployed stack for distributed architectures

## Requirements

### Requirement 1: Comprehensive Project Understanding

**User Story:** As a platform engineer, I want Kiro to have deep understanding of my EKS Foundation Platform architecture, so that it can provide contextually relevant assistance across all workflows and components.

#### Acceptance Criteria

1. WHEN I ask about any component THEN Kiro SHALL understand the relationships between VPC, EKS, observability, ingress, and future workflows
2. WHEN I request infrastructure changes THEN Kiro SHALL consider dependencies and impact across all workflows
3. WHEN I mention environment names (dev/staging/prod) THEN Kiro SHALL understand the specific configurations and constraints
4. WHEN I reference AWS services THEN Kiro SHALL understand how they integrate with the EKS platform
5. WHEN I discuss microservices THEN Kiro SHALL understand the EcoTrack application context and requirements

### Requirement 2: Intelligent Terraform Management

**User Story:** As a DevOps engineer, I want Kiro to assist with Terraform operations across all modules and environments, so that I can efficiently manage infrastructure changes with confidence.

#### Acceptance Criteria

1. WHEN I request infrastructure changes THEN Kiro SHALL suggest appropriate Terraform modules and configurations
2. WHEN I plan deployments THEN Kiro SHALL validate dependencies and suggest deployment order
3. WHEN I encounter Terraform errors THEN Kiro SHALL provide specific troubleshooting guidance
4. WHEN I need to modify variables THEN Kiro SHALL understand environment-specific requirements
5. WHEN I want to add new resources THEN Kiro SHALL follow established naming conventions and tagging standards

### Requirement 3: Workflow-Aware Operations

**User Story:** As a platform administrator, I want Kiro to understand the sequential nature of the 7 planned workflows, so that it can guide me through proper deployment sequences and integration points.

#### Acceptance Criteria

1. WHEN I ask about workflow dependencies THEN Kiro SHALL explain prerequisites and deployment order
2. WHEN I'm working on a specific workflow THEN Kiro SHALL understand its integration points with other workflows
3. WHEN I plan new workflows THEN Kiro SHALL suggest how they fit into the overall architecture
4. WHEN I troubleshoot issues THEN Kiro SHALL consider cross-workflow impacts and dependencies
5. WHEN I optimize resources THEN Kiro SHALL understand capacity planning across all workflows

### Requirement 4: Automated Development Assistance

**User Story:** As a developer, I want Kiro to automate repetitive tasks and provide intelligent suggestions, so that I can focus on high-value architecture and business logic.

#### Acceptance Criteria

1. WHEN I create new Terraform modules THEN Kiro SHALL generate boilerplate following project conventions
2. WHEN I write documentation THEN Kiro SHALL maintain consistency with existing README patterns
3. WHEN I configure new services THEN Kiro SHALL apply appropriate security and observability patterns
4. WHEN I need code reviews THEN Kiro SHALL validate against project standards and best practices
5. WHEN I update configurations THEN Kiro SHALL suggest related changes needed in other files

### Requirement 5: Proactive Monitoring and Alerting

**User Story:** As an SRE, I want Kiro to help me set up intelligent monitoring and alerting for the infrastructure platform, so that I can maintain high availability and performance.

#### Acceptance Criteria

1. WHEN new services are deployed THEN Kiro SHALL suggest appropriate monitoring configurations
2. WHEN alerts fire THEN Kiro SHALL provide contextual troubleshooting guidance
3. WHEN performance issues occur THEN Kiro SHALL suggest optimization strategies
4. WHEN capacity planning is needed THEN Kiro SHALL analyze resource usage trends
5. WHEN incidents happen THEN Kiro SHALL help with root cause analysis and remediation

### Requirement 6: Security and Compliance Management

**User Story:** As a security engineer, I want Kiro to enforce security best practices and compliance requirements, so that the infrastructure platform maintains high security standards.

#### Acceptance Criteria

1. WHEN I create IAM policies THEN Kiro SHALL apply least privilege principles
2. WHEN I configure networking THEN Kiro SHALL suggest appropriate security group rules
3. WHEN I deploy services THEN Kiro SHALL validate security configurations
4. WHEN I review access patterns THEN Kiro SHALL identify potential security risks
5. WHEN compliance audits occur THEN Kiro SHALL help generate required documentation

### Requirement 7: Cost Optimization and Resource Management

**User Story:** As a financial operations manager, I want Kiro to help optimize infrastructure costs while maintaining performance and reliability, so that we achieve cost-effective operations.

#### Acceptance Criteria

1. WHEN I review resource usage THEN Kiro SHALL identify optimization opportunities
2. WHEN I plan capacity changes THEN Kiro SHALL suggest cost-effective configurations
3. WHEN I analyze spending THEN Kiro SHALL correlate costs with specific workflows and services
4. WHEN I implement cost controls THEN Kiro SHALL validate impact on performance and availability
5. WHEN I forecast budgets THEN Kiro SHALL provide data-driven projections

### Requirement 8: Knowledge Management and Documentation

**User Story:** As a team lead, I want Kiro to maintain comprehensive and up-to-date documentation, so that team members can efficiently onboard and contribute to the platform.

#### Acceptance Criteria

1. WHEN infrastructure changes are made THEN Kiro SHALL update relevant documentation automatically
2. WHEN new team members join THEN Kiro SHALL provide guided onboarding assistance
3. WHEN troubleshooting procedures are needed THEN Kiro SHALL maintain current runbooks
4. WHEN architectural decisions are made THEN Kiro SHALL document rationale and alternatives considered
5. WHEN knowledge gaps are identified THEN Kiro SHALL suggest documentation improvements

### Requirement 9: Integration and Extensibility

**User Story:** As a platform architect, I want Kiro to integrate with external tools and services, so that it can provide comprehensive platform management capabilities.

#### Acceptance Criteria

1. WHEN I use AWS CLI THEN Kiro SHALL understand and assist with AWS service operations
2. WHEN I work with kubectl THEN Kiro SHALL provide Kubernetes-specific guidance
3. WHEN I integrate monitoring tools THEN Kiro SHALL understand observability data and metrics
4. WHEN I use CI/CD pipelines THEN Kiro SHALL assist with GitHub Actions and deployment automation
5. WHEN I add new tools THEN Kiro SHALL learn their integration patterns and usage

### Requirement 10: Autonomous Operation Capabilities

**User Story:** As a platform owner, I want Kiro to operate autonomously for routine tasks while maintaining appropriate oversight, so that I can focus on strategic initiatives while ensuring operational excellence.

#### Acceptance Criteria

1. WHEN routine maintenance is needed THEN Kiro SHALL execute standard procedures autonomously
2. WHEN configuration drift is detected THEN Kiro SHALL suggest or apply corrections
3. WHEN monitoring alerts trigger THEN Kiro SHALL execute predefined response procedures
4. WHEN resource scaling is needed THEN Kiro SHALL adjust configurations within defined parameters
5. WHEN critical issues occur THEN Kiro SHALL escalate appropriately while taking immediate protective actions