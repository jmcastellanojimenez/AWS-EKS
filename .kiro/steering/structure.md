# Project Structure

## Repository Organization

```
eks-learning-lab/
├── .github/                    # GitHub Actions workflows
├── .kiro/                      # Kiro AI assistant configuration
│   └── steering/              # AI guidance documents
├── terraform/                  # Infrastructure as Code
│   ├── environments/          # Environment-specific configurations
│   │   └── dev/              # Development environment
│   └── modules/              # Reusable Terraform modules
└── README*.md                 # Documentation files
```

## Terraform Module Structure

Each module follows a consistent pattern:

```
terraform/modules/{module-name}/
├── main.tf                    # Primary resource definitions
├── variables.tf               # Input variables
├── outputs.tf                 # Output values
├── versions.tf               # Provider version constraints (if needed)
└── templates/                # Template files (if needed)
```

### Core Modules

- **`vpc/`** - VPC, subnets, NAT gateways, route tables
- **`iam/`** - IAM roles and policies for EKS
- **`iam-irsa/`** - IAM Roles for Service Accounts
- **`eks/`** - EKS cluster, node groups, and add-ons
- **`cert-manager/`** - SSL certificate management
- **`external-dns/`** - Automatic DNS record management
- **`ambassador/`** - API Gateway and ingress controller
- **`lgtm-observability/`** - Complete observability stack

## Environment Structure

Each environment (dev/staging/prod) contains:

```
terraform/environments/{env}/
├── backend.tf                 # S3 backend configuration
├── main.tf                   # Foundation platform (Workflow 1)
├── ingress-stack.tf          # Ingress components (Workflow 2)
├── lgtm-observability.tf     # Observability stack (Workflow 3)
├── variables.tf              # Environment-specific variables
└── outputs.tf                # Environment outputs
```

## File Naming Conventions

### Terraform Files
- `main.tf` - Primary resource definitions
- `variables.tf` - Input variable declarations
- `outputs.tf` - Output value definitions
- `versions.tf` - Provider version constraints
- `locals.tf` - Local value definitions
- `{component}.tf` - Component-specific resources (e.g., `storage.tf`, `irsa.tf`)

### Documentation Files
- `README.md` - Main project documentation
- `README_{Component}.md` - Component-specific documentation
- Use descriptive names with underscores for multi-word components

## Resource Naming Patterns

### AWS Resources
```
{project}-{environment}-{resource-type}-{identifier}
```
Examples:
- `eks-learning-lab-dev-vpc`
- `eks-learning-lab-dev-cluster`
- `eks-learning-lab-dev-lgtm-prometheus-bucket`

### Kubernetes Resources
```
{component}-{service-type}
```
Examples:
- `prometheus-server`
- `grafana-credentials`
- `ambassador-admin`

## Directory Guidelines

### What Goes Where

**Root Level:**
- Documentation files (`README*.md`)
- Configuration files (`.gitignore`, `.claude_code`)
- Tool-specific directories (`.github/`, `.kiro/`)

**`terraform/modules/`:**
- Reusable infrastructure components
- Each module should be self-contained
- Include comprehensive variable documentation

**`terraform/environments/`:**
- Environment-specific configurations
- Reference modules, don't duplicate code
- Keep environment differences minimal

**`.github/`:**
- GitHub Actions workflow definitions
- Issue and PR templates
- Repository automation

## Code Organization Principles

### Terraform Best Practices
- **One resource type per file** when files become large
- **Group related resources** in logical files
- **Use locals** for computed values and repetitive expressions
- **Consistent tagging** using local common_tags
- **Descriptive variable names** with clear descriptions

### Module Design
- **Single responsibility** - each module has one clear purpose
- **Minimal dependencies** - reduce coupling between modules
- **Comprehensive outputs** - expose all useful values
- **Flexible inputs** - use variables for customization

### Environment Management
- **Consistent structure** across all environments
- **Parameterized differences** via variables
- **Shared modules** to ensure consistency
- **Environment-specific overrides** only when necessary

## Documentation Standards

### README Structure
1. **Purpose** - What the component does
2. **Prerequisites** - Required dependencies
3. **Usage** - How to deploy/use
4. **Configuration** - Available options
5. **Troubleshooting** - Common issues and solutions

### Code Comments
- **Resource purpose** - Why the resource exists
- **Complex logic** - Explain non-obvious configurations
- **Dependencies** - Note resource relationships
- **Security considerations** - Highlight security-related settings

## Workflow Integration

### GitHub Actions Structure
- **Manual triggers only** - No automatic deployments
- **Environment-specific workflows** - Separate dev/staging/prod
- **Validation steps** - Input validation and confirmation
- **Comprehensive outputs** - Deployment status and access information

### State Management
- **Remote state** - S3 backend with DynamoDB locking
- **Environment isolation** - Separate state files per environment
- **State locking** - Prevent concurrent modifications
- **Backup strategy** - S3 versioning enabled