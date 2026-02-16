# ──────────────────────────────────────────────────────────────
# Key Vault — RBAC mode, purge-protection enabled
# ──────────────────────────────────────────────────────────────

resource "azurerm_key_vault" "this" {
  name                = local.rn.key_vault
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  # Security hardening
  purge_protection_enabled      = true
  soft_delete_retention_days    = 90
  rbac_authorization_enabled    = true
  public_network_access_enabled = var.public_network_access_enabled

  network_acls {
    default_action = var.public_network_access_enabled ? "Allow" : "Deny"
    bypass         = "AzureServices"
  }

  tags = local.common_tags
}

# Deployer needs Key Vault admin to bootstrap secrets / keys
resource "azurerm_role_assignment" "kv_admin_deployer" {
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azurerm_client_config.current.object_id
}

# ──────────────────────────────────────────────────────────────
# Storage Account — Hardened
# ──────────────────────────────────────────────────────────────

resource "azurerm_storage_account" "this" {
  name                     = local.rn.storage_account
  location                 = azurerm_resource_group.this.location
  resource_group_name      = azurerm_resource_group.this.name
  account_tier             = "Standard"
  account_replication_type = var.environment == "prod" ? "GRS" : "LRS"

  # Security hardening
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = !var.disable_local_auth
  public_network_access_enabled   = var.public_network_access_enabled
  https_traffic_only_enabled      = true

  blob_properties {
    delete_retention_policy {
      days = 7
    }
    container_delete_retention_policy {
      days = 7
    }
  }

  network_rules {
    default_action = var.public_network_access_enabled ? "Allow" : "Deny"
    bypass         = ["AzureServices"]
  }

  tags = local.common_tags
}
