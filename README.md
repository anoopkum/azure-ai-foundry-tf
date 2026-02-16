# Azure AI Foundry — Terraform (Sovereign AI on Azure)

Deploy Azure AI Foundry (Hub + Project) with Terraform. Maximizes sovereignty within Azure: private-by-default, Managed Identity only, EU data residency enforced, no API keys.

> **Sovereignty positioning:** This repo implements the "Cloud Private" tier of the sovereignty spectrum — you control identity, network boundaries, data residency, access, and auditability. What you delegate is compute and model hosting. For full sovereignty (your hardware, your models), see [sovereign LLM inference on Apple Silicon](https://medium.com/@yourusername/sovereign-llm-tutorial).

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  Resource Group (EU Region)                                  │
│                                                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │  Key Vault    │  │  Storage     │  │  AI Services  │      │
│  │  RBAC mode    │  │  Account     │  │  (Cognitive)  │      │
│  │  purge prot.  │  │  no SAS keys │  │  no local auth│      │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘      │
│         │ PE               │ PE               │ PE           │
│         ▼                  ▼                  ▼              │
│  ┌─────────────────────────────────────────────────┐        │
│  │           AI Foundry Hub                         │        │
│  │  SystemAssigned MI · Managed Network             │ ◄─ PE │
│  │                                                   │        │
│  │   ┌───────────────────────────────────┐          │        │
│  │   │      AI Foundry Project            │          │        │
│  │   │  + Model Deployments               │          │        │
│  │   │    (DataZoneStandard = EU only)     │          │        │
│  │   └───────────────────────────────────┘          │        │
│  └─────────────────────────────────────────────────┘        │
│                                                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │  VNet/Subnet  │  │  Log         │  │  App         │      │
│  │  (PE subnet)  │  │  Analytics   │  │  Insights    │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
│                                                              │
│  Private DNS Zones (6): vault, blob, file, cognitive,       │
│                          azureml, notebooks                  │
└─────────────────────────────────────────────────────────────┘
```

## Sovereignty Defaults

Every default is chosen to maximize control within Azure's boundaries:

| Setting | Default | Sovereignty Impact |
|---|---|---|
| `location` | `swedencentral` | EU jurisdiction, best Data Zone coverage |
| `public_network_access_enabled` | `false` | No public attack surface — all traffic through private network |
| `disable_local_auth` | `true` | No shared secrets — identity via Entra ID only |
| `openai_deployments[].sku_name` | `DataZoneStandard` | Inference processing stays in EU Data Zone |
| `managed_network_isolation_mode` | `AllowInternetOutbound` | Hub managed network with outbound control |
| `high_business_impact` | `false` (set `true` for prod) | Reduces diagnostic telemetry sent to Microsoft |
| Key Vault | RBAC mode + purge protection | No legacy access policies, no key leakage |
| Storage Account | No SAS keys, TLS 1.2, no public blob | No credential-based access paths |

## Prerequisites

- **Terraform** >= 1.6
- **Azure CLI** authenticated (`az login`)
- **Azure Role**: Owner or Contributor + User Access Administrator
- **Registered providers**: `Microsoft.MachineLearningServices`, `Microsoft.CognitiveServices`, `Microsoft.Network`

## Quick Start

```bash
# Clone
git clone https://github.com/<your-org>/ai-foundry-terraform.git
cd ai-foundry-terraform

# Configure
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values

# Deploy
terraform init
terraform plan -out=tfplan
terraform apply tfplan

# Verify outputs
terraform output
```

### Production Deployment

```bash
cp prod.tfvars.example terraform.tfvars
# Edit, then:
terraform plan -var-file=terraform.tfvars -out=tfplan
terraform apply tfplan
```

## File Structure

```
├── providers.tf                    # azurerm ~4.0 + azapi ~2.0
├── variables.tf                    # All inputs with validations
├── locals.tf                       # Naming conventions, computed values
├── main.tf                         # Resource Group, VNet, Monitoring
├── security.tf                     # Key Vault (RBAC), Storage Account
├── ai-foundry.tf                   # Hub, Project, AI Services, RBAC
├── networking.tf                   # Private DNS Zones + Private Endpoints
├── outputs.tf                      # Resource IDs, endpoints, MI principals
├── terraform.tfvars.example        # Dev example
└── prod.tfvars.example             # Hardened production example
```

## Key Variables

| Variable | Type | Default | Description |
|---|---|---|---|
| `project_name` | `string` | `aifoundry` | Short identifier, used in all names |
| `environment` | `string` | `dev` | `dev`, `staging`, or `prod` |
| `location` | `string` | `swedencentral` | EU regions only (validated) |
| `public_network_access_enabled` | `bool` | `false` | Enable public access |
| `disable_local_auth` | `bool` | `true` | Disable API keys |
| `managed_network_isolation_mode` | `string` | `AllowInternetOutbound` | Hub network isolation |
| `high_business_impact` | `bool` | `false` | HBI mode (reduces telemetry) |
| `openai_deployments` | `list(object)` | GPT-4o DataZone | Model deployments |
| `hub_contributors` | `list(string)` | `[]` | Entra ID principals for Hub |
| `project_developers` | `list(string)` | `[]` | Entra ID principals for Project |

## EU Data Residency & Sovereignty

Model deployment types control where your prompts and completions are physically processed:

| Deployment Type | Processing Location | EU Residency | Sovereignty Level |
|---|---|---|---|
| `GlobalStandard` | Any Azure region worldwide | ❌ | None |
| `DataZoneStandard` | EU Data Zone (any EU member state) | ✅ | Regional |
| `Standard` | Deployment region only | ✅ (strictest) | Zonal |

This repo defaults to `DataZoneStandard` — best trade-off between compliance and throughput. For maximum control, switch to `Standard` (inference stays in the exact region, e.g., Sweden Central only).

**What this controls:** Where inference processing happens. **What it doesn't:** Model weights, training data, and versioning remain under Microsoft's control. For full model sovereignty, self-hosted open-weight models are the path — see the [sovereign LLM tutorial](https://medium.com/@yourusername/sovereign-llm-tutorial).

**Recommended EU regions:**
- `swedencentral` — broadest model availability
- `germanywestcentral` — alternative for DACH compliance

## Managed Network Provisioning

When managed network isolation is enabled, the VNet is **not** provisioned until a compute resource is created or manually triggered:

```bash
az ml workspace provision-network \
  --name $(terraform output -raw ai_foundry_hub_name) \
  --resource-group $(terraform output -raw resource_group_name)
```

## Known Limitations

- **Sovereignty boundary**: This setup maximizes control within Azure, but inference compute and model weights remain under Microsoft's control. You own identity, network, data residency, access, and auditability.
- **Portal access with network isolation**: The new Foundry portal does not support end-to-end network isolation. Use the classic portal, SDK/CLI, or a jump box via Azure Bastion.
- **azurerm provider gaps**: Workspace connections and some newer Foundry features require the `azapi` provider. See [hashicorp/terraform-provider-azurerm#29956](https://github.com/hashicorp/terraform-provider-azurerm/issues/29956).
- **Model availability**: Not all models are available in all EU regions or for all deployment types. Check the [region/model matrix](https://learn.microsoft.com/en-us/azure/ai-foundry/reference/region-support).

## Sovereignty & Security Checklist

**Data Residency**
- [ ] Deployment type: `DataZoneStandard` or `Standard` (not `GlobalStandard`)
- [ ] All resources in an EU region
- [ ] `high_business_impact = true` for prod (reduces Microsoft telemetry)

**Network Sovereignty**
- [ ] `public_network_access_enabled = false`
- [ ] Private Endpoints for all dependencies
- [ ] DNS zones linked to VNet
- [ ] `managed_network_isolation_mode = "AllowOnlyApprovedOutbound"` for prod

**Identity Sovereignty**
- [ ] `disable_local_auth = true`
- [ ] Key Vault: purge protection + RBAC mode
- [ ] Storage: SAS keys disabled, TLS 1.2
- [ ] RBAC assignments follow least privilege

**Operational Sovereignty**
- [ ] Diagnostic settings active (you own the audit trail)
- [ ] Terraform state in a secured backend with state locking
- [ ] All changes through Git (EU AI Act auditability)

## References

- [Azure Verified Module: AI Foundry](https://registry.terraform.io/modules/Azure/avm-ptn-aiml-ai-foundry/azurerm/latest)
- [Microsoft: Terraform for Foundry](https://learn.microsoft.com/en-us/azure/ai-foundry/how-to/create-hub-terraform)
- [Deployment Types & Data Residency](https://learn.microsoft.com/en-us/azure/ai-foundry/foundry-models/concepts/deployment-types)
- [AI Foundry Region Support](https://learn.microsoft.com/en-us/azure/ai-foundry/reference/region-support)

## License

MIT
