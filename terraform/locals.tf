resource "random_string" "suffix" {
  length  = 5
  special = false
  upper   = false
  numeric = true
}

locals {
  name_suffix = "${var.project_name}-${var.environment}-${random_string.suffix.result}"

  rn = {
    resource_group  = "rg-${local.name_suffix}"
    key_vault       = "kv${replace(local.name_suffix, "-", "")}"
    storage_account = "st${replace(local.name_suffix, "-", "")}"
    ai_services     = "ais-${local.name_suffix}"
    ai_hub          = "hub-${local.name_suffix}"
    ai_project      = "proj-${local.name_suffix}"
    vnet            = "vnet-${local.name_suffix}"
    log_analytics   = "log-${local.name_suffix}"
    app_insights    = "appi-${local.name_suffix}"
  }

  common_tags = merge(var.tags, {
    Environment = var.environment
    ManagedBy   = "terraform"
    Project     = var.project_name
    DataClass   = "eu-restricted"
  })

  log_retention = var.environment == "prod" ? max(var.log_retention_days, 90) : var.log_retention_days
}
