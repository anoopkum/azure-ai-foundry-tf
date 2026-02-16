# ──────────────────────────────────────────────────────────────
# Private DNS Zones
# ──────────────────────────────────────────────────────────────

locals {
  private_dns_zones = {
    key_vault    = "privatelink.vaultcore.azure.net"
    storage_blob = "privatelink.blob.core.windows.net"
    storage_file = "privatelink.file.core.windows.net"
    ai_services  = "privatelink.cognitiveservices.azure.com"
    ai_hub       = "privatelink.api.azureml.ms"
    ai_notebook  = "privatelink.notebooks.azure.net"
  }
}

resource "azurerm_private_dns_zone" "zones" {
  for_each = local.private_dns_zones

  name                = each.value
  resource_group_name = azurerm_resource_group.this.name
  tags                = local.common_tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "links" {
  for_each = local.private_dns_zones

  name                  = "link-${each.key}"
  resource_group_name   = azurerm_resource_group.this.name
  private_dns_zone_name = azurerm_private_dns_zone.zones[each.key].name
  virtual_network_id    = azurerm_virtual_network.this.id
  registration_enabled  = false
}

# ──────────────────────────────────────────────────────────────
# Private Endpoints
# ──────────────────────────────────────────────────────────────

# --- Key Vault ---
resource "azurerm_private_endpoint" "key_vault" {
  name                = "pe-${local.rn.key_vault}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  subnet_id           = azurerm_subnet.private_endpoints.id

  private_service_connection {
    name                           = "psc-kv"
    private_connection_resource_id = azurerm_key_vault.this.id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "dns-kv"
    private_dns_zone_ids = [azurerm_private_dns_zone.zones["key_vault"].id]
  }

  tags = local.common_tags
}

# --- Storage Account (Blob) ---
resource "azurerm_private_endpoint" "storage_blob" {
  name                = "pe-${local.rn.storage_account}-blob"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  subnet_id           = azurerm_subnet.private_endpoints.id

  private_service_connection {
    name                           = "psc-st-blob"
    private_connection_resource_id = azurerm_storage_account.this.id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "dns-st-blob"
    private_dns_zone_ids = [azurerm_private_dns_zone.zones["storage_blob"].id]
  }

  tags = local.common_tags
}

# --- Storage Account (File) ---
resource "azurerm_private_endpoint" "storage_file" {
  name                = "pe-${local.rn.storage_account}-file"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  subnet_id           = azurerm_subnet.private_endpoints.id

  private_service_connection {
    name                           = "psc-st-file"
    private_connection_resource_id = azurerm_storage_account.this.id
    subresource_names              = ["file"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "dns-st-file"
    private_dns_zone_ids = [azurerm_private_dns_zone.zones["storage_file"].id]
  }

  tags = local.common_tags
}

# --- AI Services ---
resource "azurerm_private_endpoint" "ai_services" {
  name                = "pe-${local.rn.ai_services}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  subnet_id           = azurerm_subnet.private_endpoints.id

  private_service_connection {
    name                           = "psc-ais"
    private_connection_resource_id = azurerm_ai_services.this.id
    subresource_names              = ["account"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "dns-ais"
    private_dns_zone_ids = [azurerm_private_dns_zone.zones["ai_services"].id]
  }

  tags = local.common_tags
}

# --- AI Foundry Hub ---
resource "azurerm_private_endpoint" "ai_hub" {
  name                = "pe-${local.rn.ai_hub}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  subnet_id           = azurerm_subnet.private_endpoints.id

  private_service_connection {
    name                           = "psc-hub"
    private_connection_resource_id = azurerm_ai_foundry.hub.id
    subresource_names              = ["amlworkspace"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name = "dns-hub"
    private_dns_zone_ids = [
      azurerm_private_dns_zone.zones["ai_hub"].id,
      azurerm_private_dns_zone.zones["ai_notebook"].id,
    ]
  }

  tags = local.common_tags
}
