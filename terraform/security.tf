# ──────────────────────────────────────────────────────────────
# Key Vault — RBAC mode, purge-protection enabled
# ──────────────────────────────────────────────────────────────

resource "azurerm_key_vault" "key_vault" {
  name                = local.rn.key_vault
  location            = azurerm_resource_group.resource_group_aifoundry.location
  resource_group_name = azurerm_resource_group.resource_group_aifoundry.name
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

  lifecycle {
    ignore_changes = [tags]
  }
}

# Deployer needs Key Vault admin to bootstrap secrets / keys
resource "azurerm_role_assignment" "kv_admin_deployer" {
  scope                = azurerm_key_vault.key_vault.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azurerm_client_config.current.object_id
}

# ──────────────────────────────────────────────────────────────
# Storage Account — Hardened
# ──────────────────────────────────────────────────────────────

resource "azurerm_storage_account" "storage_account_foundry" {
  name                     = local.rn.storage_account
  location                 = azurerm_resource_group.resource_group_aifoundry.location
  resource_group_name      = azurerm_resource_group.resource_group_aifoundry.name
  account_tier             = "Standard"
  account_replication_type = var.environment == "dev" ? "GRS" : "LRS"

  # Security hardening
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = true
  public_network_access_enabled   = var.public_network_access_enabled
  https_traffic_only_enabled      = true

  # SAS expiration policy
  sas_policy {
    expiration_period = "00.01:00:00"
    expiration_action = "Log"
  }

  blob_properties {
    delete_retention_policy {
      days = 7
    }
    container_delete_retention_policy {
      days = 7
    }
    cors_rule {
      allowed_headers    = ["*"]
      allowed_methods    = ["GET", "HEAD", "PUT", "DELETE", "OPTIONS", "POST", "PATCH"]
      allowed_origins    = ["https://mlworkspace.azure.ai", "https://ml.azure.com", "https://*.ml.azure.com", "https://ai.azure.com", "https://*.ai.azure.com"]
      exposed_headers    = ["*"]
      max_age_in_seconds = 1800
    }
  }

  network_rules {
    default_action = var.public_network_access_enabled ? "Allow" : "Deny"
    bypass         = ["AzureServices"]
  }

  tags = local.common_tags

  lifecycle {
    ignore_changes = [tags]
  }
}
