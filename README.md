# Azure AI Foundry — Terraform

Deploy Azure AI Foundry (Hub + Project) with Terraform. Features private networking, Managed Identity authentication, and EU data residency support.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  Resource Group (EU Region)                                  │
│                                                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │  Key Vault    │  │  Storage     │  │  AI Services  │      │
│  │  RBAC mode    │  │  Account     │  │  (Cognitive)  │      │
│  │  purge prot.  │  │  TLS 1.2     │  │  OpenAI models│      │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘      │
│         │ PE               │ PE               │ PE           │
│         ▼                  ▼                  ▼              │
│  ┌─────────────────────────────────────────────────┐        │
│  │           AI Foundry Hub                         │        │
│  │  SystemAssigned MI · Managed Network             │ ◄─ PE │
│  │                                                   │        │
│  │   ┌───────────────────────────────────────┐      │        │
│  │   │      AI Foundry Project                │      │        │
│  │   │  + Model Deployments (GPT-4o, etc.)    │      │        │
│  │   └───────────────────────────────────────┘      │        │
│  └─────────────────────────────────────────────────┘        │
│                                                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │  VNet + NSG   │  │  Log         │  │  App         │      │
│  │  (PE subnet)  │  │  Analytics   │  │  Insights    │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
│                                                              │
│  Private DNS Zones: vault, blob, file, cognitive,           │
│                     azureml, notebooks                       │
└─────────────────────────────────────────────────────────────┘
```

## Features

- Private networking with Private Endpoints
- Managed Identity authentication (no API keys)
- EU data residency with DataZoneStandard deployments
- Key Vault with RBAC and purge protection
- Storage Account with security hardening
- Network Security Group on subnets
- Checkov security scanning compliance
- Lifecycle ignore for Azure-managed tags

## Prerequisites

- Terraform >= 1.6
- Azure CLI authenticated (`az login`)
- Azure Role: Owner or Contributor + User Access Administrator

## Quick Start

```bash
cd terraform

# Configure
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values

# Deploy
terraform init
terraform plan
terraform apply
```

## Remote Backend Setup

The configuration uses Azure Storage for remote state. Create the backend:

```bash
# Create resource group and storage account
az group create --name rg-terraform-state --location uksouth
az storage account create --name <unique-name> --resource-group rg-terraform-state --location uksouth --sku Standard_LRS
az storage container create --name tfstate --account-name <unique-name>

# Update providers.tf with your storage account name
```

## File Structure

```
terraform/
├── providers.tf          # Provider config + backend
├── variables.tf          # Input variables with validations
├── locals.tf             # Naming conventions
├── main.tf               # Resource Group, VNet, Monitoring
├── security.tf           # Key Vault, Storage Account
├── ai-foundry.tf         # Hub, Project, AI Services, RBAC
├── networking.tf         # Private DNS Zones + Private Endpoints
├── outputs.tf            # Resource IDs and endpoints
├── terraform.tfvars      # Your configuration
└── .checkov.yaml         # Security scan exclusions
```

## Key Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `project_name` | `aifoundry` | Short identifier (3-12 chars, alphanumeric) |
| `environment` | `dev` | `dev`, `staging`, or `prod` |
| `location` | `swedencentral` | Azure region (EU only) |
| `public_network_access_enabled` | `false` | Enable public access |
| `disable_local_auth` | `true` | Disable API key authentication |
| `openai_deployments` | GPT-4o | Model deployments list |
| `hub_contributors` | `[]` | Entra ID Object IDs for Hub access |
| `project_developers` | `[]` | Entra ID Object IDs for Project access |

## Accessing AI Foundry

### With Public Access Enabled
Set `public_network_access_enabled = true` and add your Object ID to RBAC:

```bash
# Get your Object ID
az ad signed-in-user show --query id -o tsv

# Add to terraform.tfvars
hub_contributors = ["your-object-id"]
project_developers = ["your-object-id"]
```

### With Private Access Only
Options:
1. Deploy a jumpbox VM in the VNet + Azure Bastion
2. Use VPN Gateway or ExpressRoute
3. Deploy applications with VNet integration

## Model Deployments

| SKU Type | Processing Location | Use Case |
|----------|---------------------|----------|
| `GlobalStandard` | Any Azure region | Maximum throughput |
| `DataZoneStandard` | EU Data Zone | EU data residency |
| `Standard` | Deployment region only | Strictest residency |

## Security Checklist

- [x] Private Endpoints for all services
- [x] Network Security Group on subnets
- [x] Key Vault with RBAC and purge protection
- [x] Storage Account with TLS 1.2, no public blobs
- [x] Managed Identity authentication
- [x] Lifecycle ignore for Azure-managed tags
- [x] Checkov security scanning

## Troubleshooting

### State Lock Issues
```bash
# Break blob lease
az storage blob lease break --account-name <storage> --container-name tfstate --blob-name ai-foundry.tfstate --auth-mode key

# Or force unlock
terraform force-unlock <LOCK_ID>
```

### Role Assignment Conflicts
If role assignments already exist, import them:
```bash
terraform import 'azurerm_role_assignment.<name>' '<role-assignment-id>'
```

### Network Connectivity (EOF errors)
- Check VPN/proxy settings
- Verify storage account network rules allow your IP
- Try different network or wait for transient issues

## Outputs

| Output | Description |
|--------|-------------|
| `resource_group_name` | Resource group name |
| `ai_foundry_hub_id` | Hub resource ID |
| `ai_foundry_project_id` | Project resource ID |
| `ai_services_endpoint` | AI Services endpoint |
| `hub_principal_id` | Hub Managed Identity |
| `project_principal_id` | Project Managed Identity |

## License

MIT
