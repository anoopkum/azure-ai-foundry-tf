# ──────────────────────────────────────────────────────────────
# General
# ──────────────────────────────────────────────────────────────

variable "project_name" {
  description = "Short project identifier used in all resource names."
  type        = string
  default     = "aifoundry"

  validation {
    condition     = can(regex("^[a-z0-9]{3,12}$", var.project_name))
    error_message = "project_name must be 3-12 chars, lowercase alphanumeric only."
  }
}

variable "environment" {
  description = "Deployment environment (dev, staging, prod)."
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Allowed values: dev, staging, prod."
  }
}

variable "location" {
  description = "Azure region. Restricted to EU regions for data residency."
  type        = string
  default     = "swedencentral"

  validation {
    condition = contains([
      "swedencentral",
      "westeurope",
      "germanywestcentral",
      "francecentral",
      "northeurope",
      "italynorth",
    ], var.location)
    error_message = "Only EU regions are allowed. Recommended: swedencentral or germanywestcentral for Data Zone deployments."
  }
}

variable "tags" {
  description = "Additional tags applied to every resource."
  type        = map(string)
  default     = {}
}

# ──────────────────────────────────────────────────────────────
# Networking
# ──────────────────────────────────────────────────────────────

variable "vnet_address_space" {
  description = "Address space for the virtual network."
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "subnet_private_endpoints_prefix" {
  description = "CIDR prefix for the private-endpoints subnet."
  type        = string
  default     = "10.0.1.0/24"
}

variable "public_network_access_enabled" {
  description = "Allow public network access to Hub and dependencies. Set to false for production."
  type        = bool
  default     = false
}

# ──────────────────────────────────────────────────────────────
# Security
# ──────────────────────────────────────────────────────────────

variable "disable_local_auth" {
  description = "Disable API-key authentication (Entra-ID / Managed Identity only)."
  type        = bool
  default     = true
}

variable "high_business_impact" {
  description = "Enable High Business Impact (HBI) mode. Reduces diagnostic data collected by the service."
  type        = bool
  default     = false
}

variable "managed_network_isolation_mode" {
  description = "Hub managed-network isolation mode."
  type        = string
  default     = "AllowInternetOutbound"

  validation {
    condition     = contains(["Disabled", "AllowInternetOutbound", "AllowOnlyApprovedOutbound"], var.managed_network_isolation_mode)
    error_message = "Allowed values: Disabled, AllowInternetOutbound, AllowOnlyApprovedOutbound."
  }
}

# ──────────────────────────────────────────────────────────────
# AI Model Deployments
# ──────────────────────────────────────────────────────────────

variable "openai_deployments" {
  description = "OpenAI model deployments. sku_name defaults to DataZoneStandard for EU data residency."
  type = list(object({
    name          = string
    model_name    = string
    model_version = string
    sku_name      = optional(string, "DataZoneStandard")
    sku_capacity  = optional(number, 10)
  }))
  default = [
    {
      name          = "gpt-4o"
      model_name    = "gpt-4o"
      model_version = "2024-11-20"
    },
  ]
}

# ──────────────────────────────────────────────────────────────
# RBAC
# ──────────────────────────────────────────────────────────────

variable "hub_contributors" {
  description = "Entra-ID Object IDs granted Azure AI Developer on the Hub."
  type        = list(string)
  default     = []
}

variable "project_developers" {
  description = "Entra-ID Object IDs granted Azure AI Developer on the Project."
  type        = list(string)
  default     = []
}

# ──────────────────────────────────────────────────────────────
# Monitoring
# ──────────────────────────────────────────────────────────────

variable "log_retention_days" {
  description = "Log Analytics retention in days. Overridden to 90 when environment is prod."
  type        = number
  default     = 30
}
