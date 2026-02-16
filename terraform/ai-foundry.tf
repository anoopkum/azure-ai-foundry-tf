# ──────────────────────────────────────────────────────────────
# AI Services (Cognitive Services account)
# ──────────────────────────────────────────────────────────────

resource "azurerm_ai_services" "this" {
  name                  = local.rn.ai_services
  location              = azurerm_resource_group.this.location
  resource_group_name   = azurerm_resource_group.this.name
  sku_name              = "S0"
  custom_subdomain_name = local.rn.ai_services

  local_authentication_enabled       = !var.disable_local_auth
  public_network_access              = var.public_network_access_enabled ? "Enabled" : "Disabled"
  outbound_network_access_restricted = true

  network_acls {
    default_action = var.public_network_access_enabled ? "Allow" : "Deny"
  }

  identity {
    type = "SystemAssigned"
  }

  tags = local.common_tags
}

# ──────────────────────────────────────────────────────────────
# AI Foundry Hub
# ──────────────────────────────────────────────────────────────

resource "azurerm_ai_foundry" "hub" {
  name                = local.rn.ai_hub
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name

  storage_account_id      = azurerm_storage_account.this.id
  key_vault_id            = azurerm_key_vault.this.id
  application_insights_id = azurerm_application_insights.this.id

  public_network_access        = var.public_network_access_enabled ? "Enabled" : "Disabled"
  high_business_impact_enabled = var.high_business_impact

  managed_network {
    isolation_mode = var.managed_network_isolation_mode
  }

  identity {
    type = "SystemAssigned"
  }

  friendly_name = "AI Foundry Hub – ${var.project_name} (${var.environment})"
  description   = "Managed by Terraform. Environment: ${var.environment}."

  tags = local.common_tags
}

# ──────────────────────────────────────────────────────────────
# AI Foundry Project
# ──────────────────────────────────────────────────────────────

resource "azurerm_ai_foundry_project" "this" {
  name               = local.rn.ai_project
  location           = azurerm_ai_foundry.hub.location
  ai_services_hub_id = azurerm_ai_foundry.hub.id

  friendly_name = "Project – ${var.project_name} (${var.environment})"
  description   = "AI Foundry Project. Managed by Terraform."

  identity {
    type = "SystemAssigned"
  }

  tags = local.common_tags
}

# ──────────────────────────────────────────────────────────────
# AI Services ↔ Hub Connection (via azapi)
#
# The azurerm provider does not yet support workspace connections
# for AI Services. We use azapi as an escape hatch.
# See: https://github.com/hashicorp/terraform-provider-azurerm/issues/29956
# ──────────────────────────────────────────────────────────────

resource "azapi_resource" "hub_ai_services_connection" {
  type      = "Microsoft.MachineLearningServices/workspaces/connections@2024-10-01"
  name      = "ais-connection"
  parent_id = azurerm_ai_foundry.hub.id

  body = {
    properties = {
      category      = "AIServices"
      target        = azurerm_ai_services.this.endpoint
      authType      = "AAD"
      isSharedToAll = true
      metadata = {
        ApiType    = "Azure"
        ResourceId = azurerm_ai_services.this.id
      }
    }
  }
}

# ──────────────────────────────────────────────────────────────
# Model Deployments (DataZone Standard by default)
# ──────────────────────────────────────────────────────────────

resource "azurerm_cognitive_deployment" "models" {
  for_each = { for d in var.openai_deployments : d.name => d }

  name                 = each.value.name
  cognitive_account_id = azurerm_ai_services.this.id

  model {
    format  = "OpenAI"
    name    = each.value.model_name
    version = each.value.model_version
  }

  sku {
    name     = each.value.sku_name
    capacity = each.value.sku_capacity
  }
}

# ──────────────────────────────────────────────────────────────
# RBAC – Hub Managed Identity → dependent resources
# ──────────────────────────────────────────────────────────────

resource "azurerm_role_assignment" "hub_storage_blob" {
  scope                = azurerm_storage_account.this.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_ai_foundry.hub.identity[0].principal_id
}

resource "azurerm_role_assignment" "hub_storage_file" {
  scope                = azurerm_storage_account.this.id
  role_definition_name = "Storage File Data Privileged Contributor"
  principal_id         = azurerm_ai_foundry.hub.identity[0].principal_id
}

resource "azurerm_role_assignment" "hub_kv_secrets" {
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_ai_foundry.hub.identity[0].principal_id
}

resource "azurerm_role_assignment" "hub_cognitive" {
  scope                = azurerm_ai_services.this.id
  role_definition_name = "Cognitive Services OpenAI User"
  principal_id         = azurerm_ai_foundry.hub.identity[0].principal_id
}

# ──────────────────────────────────────────────────────────────
# RBAC – Project Managed Identity → AI Services
# ──────────────────────────────────────────────────────────────

resource "azurerm_role_assignment" "project_cognitive" {
  scope                = azurerm_ai_services.this.id
  role_definition_name = "Cognitive Services OpenAI User"
  principal_id         = azurerm_ai_foundry_project.this.identity[0].principal_id
}

resource "azurerm_role_assignment" "project_cognitive_contributor" {
  scope                = azurerm_ai_services.this.id
  role_definition_name = "Cognitive Services OpenAI Contributor"
  principal_id         = azurerm_ai_foundry_project.this.identity[0].principal_id
}

# ──────────────────────────────────────────────────────────────
# RBAC – User / group assignments
# ──────────────────────────────────────────────────────────────

resource "azurerm_role_assignment" "hub_contributors" {
  for_each = toset(var.hub_contributors)

  scope                = azurerm_ai_foundry.hub.id
  role_definition_name = "Azure AI Developer"
  principal_id         = each.value
}

resource "azurerm_role_assignment" "project_developers" {
  for_each = toset(var.project_developers)

  scope                = azurerm_ai_foundry_project.this.id
  role_definition_name = "Azure AI Developer"
  principal_id         = each.value
}
