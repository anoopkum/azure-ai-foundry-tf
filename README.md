# Azure AI Foundry — Production-Ready Terraform Deployment

Enterprise-grade Azure AI Foundry with Private Endpoints, Managed Identity (no API keys), and EU data residency. Supports both public access for dev and fully private VNet access for production.

---

## 1. What You'll Deploy

```
┌─────────────────────────────────────────────────────────────────────────┐
│  Resource Group (EU Region)                                              │
│                                                                          │
│  ┌─────────────┐   ┌─────────────┐   ┌─────────────┐                   │
│  │  Key Vault   │   │  Storage    │   │ AI Services │                   │
│  │  (secrets)   │   │  (data)     │   │ (GPT-4o)    │                   │
│  └──────┬──────┘   └──────┬──────┘   └──────┬──────┘                   │
│         │                  │                  │                          │
│         └──────────────────┼──────────────────┘                          │
│                            ▼                                             │
│              ┌─────────────────────────┐                                │
│              │    AI Foundry Hub       │ ◄── Central control plane      │
│              │    (Managed Identity)   │                                │
│              │                         │                                │
│              │  ┌───────────────────┐  │                                │
│              │  │  AI Foundry       │  │ ◄── Your workspace             │
│              │  │  Project          │  │                                │
│              │  │  + GPT-4o model   │  │                                │
│              │  └───────────────────┘  │                                │
│              └─────────────────────────┘                                │
│                            │                                             │
│         ┌──────────────────┼──────────────────┐                          │
│         ▼                  ▼                  ▼                          │
│  ┌─────────────┐   ┌─────────────┐   ┌─────────────┐                   │
│  │    VNet     │   │    Log      │   │    App      │                   │
│  │  + NSG      │   │  Analytics  │   │  Insights   │                   │
│  │  + DNS      │   │  (logs)     │   │ (metrics)   │                   │
│  └─────────────┘   └─────────────┘   └─────────────┘                   │
│                                                                          │
│  Private DNS Zones: vault, blob, file, cognitive, azureml, notebooks    │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Prerequisites

```bash
# Required
terraform >= 1.6
az login  # Azure CLI authenticated

# Azure Role needed
Owner  OR  Contributor + User Access Administrator on subscription
```

---

## 3. Choose Your Environment

⚠️ **Pick ONE. Don't deploy both.**

| Setting | **Dev** (`terraform.tfvars`) | **Prod** (`prod.tfvars`) |
|---------|------------------------------|--------------------------|
| Use when | Learning, development, testing | Production, sensitive data |
| Access | ✅ Public — access from laptop | ❌ Private — requires VPN/Bastion |
| Network isolation | `AllowInternetOutbound` | `AllowOnlyApprovedOutbound` |
| High business impact | `false` | `true` |
| Model capacity | 10 (lower cost) | 50-100 (higher throughput) |
| Data classification | — | `confidential` |
| Deploy command | `terraform apply` | `terraform apply -var-file="prod.tfvars"` |

---

## 4. Deploy

### Step 1: Setup Remote Backend (one-time)

```bash
# Create storage for Terraform state
az group create --name rg-terraform-state --location uksouth
az storage account create --name <unique-name> --resource-group rg-terraform-state --location uksouth --sku Standard_LRS
az storage container create --name tfstate --account-name <unique-name>

# Update providers.tf with your storage account name
```

### Step 2: Configure

```bash
cd terraform

# Edit terraform.tfvars with your values:
# - project_name
# - location
# - hub_contributors (your Entra ID Object ID)
# - project_developers (your Entra ID Object ID)

# Get your Object ID:
az ad signed-in-user show --query id -o tsv
```

### Step 3: Deploy

```bash
# For Development (default)
terraform init
terraform plan
terraform apply

# For Production (only for private access)
terraform init
terraform plan -var-file="prod.tfvars"
terraform apply -var-file="prod.tfvars"
```

---

## 5. Access AI Foundry

### Dev Environment (public access enabled)
1. Go to [ai.azure.com](https://ai.azure.com)
2. Sign in with your Azure account
3. Select your Hub and Project

### Prod Environment (private access only)
You need one of these:
- Azure Bastion + jumpbox VM in the VNet
- VPN Gateway or ExpressRoute
- Application with VNet integration

---

## 6. File Structure

```
terraform/
├── providers.tf      # Azure provider + remote backend
├── variables.tf      # Input variables
├── locals.tf         # Naming conventions
├── main.tf           # Resource Group, VNet, Monitoring
├── security.tf       # Key Vault, Storage Account
├── ai-foundry.tf     # Hub, Project, AI Services, RBAC
├── networking.tf     # Private DNS + Private Endpoints
├── outputs.tf        # Resource IDs and endpoints
├── terraform.tfvars  # Dev configuration ← EDIT THIS
└── prod.tfvars       # Prod configuration
```

---

## 7. Components Explained

### Core AI

| Component | Purpose |
|-----------|---------|
| **AI Foundry Hub** | Control plane — connects storage, key vault, AI services |
| **AI Foundry Project** | Your workspace — models, data, team access |
| **AI Services** | Hosts GPT-4o and other models |
| **Model Deployments** | Specific models with allocated capacity |

### Security

| Component | Purpose |
|-----------|---------|
| **Key Vault** | Stores secrets (RBAC mode, purge protection) |
| **Managed Identity** | Auto-managed credentials, no passwords |
| **RBAC** | Who can access what |

### Networking

| Component | Purpose |
|-----------|---------|
| **VNet** | Private network isolation |
| **Private Endpoints** | Access services without public internet |
| **Private DNS Zones** | Route service names to private IPs |
| **NSG** | Firewall rules |

### Monitoring

| Component | Purpose |
|-----------|---------|
| **Log Analytics** | Centralized logs |
| **App Insights** | Performance metrics |
| **Storage Account** | Data, models, artifacts |

---

## 8. Model SKUs

| SKU | Data Location | Use Case |
|-----|---------------|----------|
| `GlobalStandard` | Any region | Max throughput |
| `DataZoneStandard` | EU only | EU data residency ✓ |
| `Standard` | Deployment region | Strictest residency |

---

## 9. Troubleshooting

### State Lock Error
```bash
# Break the lease
az storage blob lease break \
  --account-name <storage> \
  --container-name tfstate \
  --blob-name ai-foundry.tfstate

# Or force unlock
terraform force-unlock <LOCK_ID>
```

### Role Assignment Already Exists
```bash
terraform import 'azurerm_role_assignment.<name>' '<role-assignment-id>'
```

### EOF / Network Errors
- Check VPN/proxy
- Verify storage firewall allows your IP
- Wait and retry (transient issues)

---

## 10. Security Features

- ✅ Private Endpoints for all services
- ✅ NSG on subnets
- ✅ Key Vault with RBAC + purge protection
- ✅ Storage: TLS 1.2, no public blobs
- ✅ Managed Identity (no API keys)

---

## License

MIT
