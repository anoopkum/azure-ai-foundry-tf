# ──────────────────────────────────────────────────────────────
# Data Sources
# ──────────────────────────────────────────────────────────────

data "azurerm_client_config" "current" {}

# ──────────────────────────────────────────────────────────────
# Resource Group
# ──────────────────────────────────────────────────────────────

resource "azurerm_resource_group" "resource_group_aifoundry" {
  name     = local.rn.resource_group
  location = var.location
  tags     = local.common_tags

  lifecycle {
    ignore_changes = [tags]
  }
}

# ──────────────────────────────────────────────────────────────
# Virtual Network + Private-Endpoints Subnet
# ──────────────────────────────────────────────────────────────

resource "azurerm_virtual_network" "vpc_aifoundry" {
  name                = local.rn.vnet
  location            = azurerm_resource_group.resource_group_aifoundry.location
  resource_group_name = azurerm_resource_group.resource_group_aifoundry.name
  address_space       = var.vnet_address_space
  tags                = local.common_tags

  lifecycle {
    ignore_changes = [tags]
  }
}

resource "azurerm_subnet" "private_endpoints" {
  name                              = "snet-private-endpoints"
  resource_group_name               = azurerm_resource_group.resource_group_aifoundry.name
  virtual_network_name              = azurerm_virtual_network.vpc_aifoundry.name
  address_prefixes                  = [var.subnet_private_endpoints_prefix]
  private_endpoint_network_policies = "Enabled"
}

# ──────────────────────────────────────────────────────────────
# Network Security Group for Private Endpoints Subnet
# ──────────────────────────────────────────────────────────────

resource "azurerm_network_security_group" "private_endpoints" {
  name                = "nsg-private-endpoints"
  location            = azurerm_resource_group.resource_group_aifoundry.location
  resource_group_name = azurerm_resource_group.resource_group_aifoundry.name
  tags                = local.common_tags

  lifecycle {
    ignore_changes = [tags]
  }
}

resource "azurerm_subnet_network_security_group_association" "private_endpoints" {
  subnet_id                 = azurerm_subnet.private_endpoints.id
  network_security_group_id = azurerm_network_security_group.private_endpoints.id
}

# ──────────────────────────────────────────────────────────────
# Monitoring
# ──────────────────────────────────────────────────────────────

resource "azurerm_log_analytics_workspace" "log_analytics" {
  name                = local.rn.log_analytics
  location            = azurerm_resource_group.resource_group_aifoundry.location
  resource_group_name = azurerm_resource_group.resource_group_aifoundry.name
  sku                 = "PerGB2018"
  retention_in_days   = local.log_retention
  tags                = local.common_tags

  lifecycle {
    ignore_changes = [tags]
  }
}

resource "azurerm_application_insights" "app_insights" {
  name                = local.rn.app_insights
  location            = azurerm_resource_group.resource_group_aifoundry.location
  resource_group_name = azurerm_resource_group.resource_group_aifoundry.name
  workspace_id        = azurerm_log_analytics_workspace.log_analytics.id
  application_type    = "web"
  tags                = local.common_tags

  lifecycle {
    ignore_changes = [tags]
  }
}
