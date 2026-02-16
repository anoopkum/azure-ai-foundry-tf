# ──────────────────────────────────────────────────────────────
# Data Sources
# ──────────────────────────────────────────────────────────────

data "azurerm_client_config" "current" {}

# ──────────────────────────────────────────────────────────────
# Resource Group
# ──────────────────────────────────────────────────────────────

resource "azurerm_resource_group" "this" {
  name     = local.rn.resource_group
  location = var.location
  tags     = local.common_tags
}

# ──────────────────────────────────────────────────────────────
# Virtual Network + Private-Endpoints Subnet
# ──────────────────────────────────────────────────────────────

resource "azurerm_virtual_network" "this" {
  name                = local.rn.vnet
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  address_space       = var.vnet_address_space
  tags                = local.common_tags
}

resource "azurerm_subnet" "private_endpoints" {
  name                              = "snet-private-endpoints"
  resource_group_name               = azurerm_resource_group.this.name
  virtual_network_name              = azurerm_virtual_network.this.name
  address_prefixes                  = [var.subnet_private_endpoints_prefix]
  private_endpoint_network_policies = "Enabled"
}

# ──────────────────────────────────────────────────────────────
# Monitoring
# ──────────────────────────────────────────────────────────────

resource "azurerm_log_analytics_workspace" "this" {
  name                = local.rn.log_analytics
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  sku                 = "PerGB2018"
  retention_in_days   = local.log_retention
  tags                = local.common_tags
}

resource "azurerm_application_insights" "this" {
  name                = local.rn.app_insights
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  workspace_id        = azurerm_log_analytics_workspace.this.id
  application_type    = "web"
  tags                = local.common_tags
}
