output "resource_group_name" {
  description = "Name of the resource group."
  value       = azurerm_resource_group.this.name
}

output "ai_foundry_hub_name" {
  description = "Name of the AI Foundry Hub."
  value       = azurerm_ai_foundry.hub.name
}

output "ai_foundry_hub_id" {
  description = "Resource ID of the AI Foundry Hub."
  value       = azurerm_ai_foundry.hub.id
}

output "ai_foundry_project_name" {
  description = "Name of the AI Foundry Project."
  value       = azurerm_ai_foundry_project.this.name
}

output "ai_foundry_project_id" {
  description = "Resource ID of the AI Foundry Project."
  value       = azurerm_ai_foundry_project.this.id
}

output "ai_services_endpoint" {
  description = "Endpoint of the AI Services (Cognitive Services) account."
  value       = azurerm_ai_services.this.endpoint
}

output "hub_principal_id" {
  description = "Principal ID of the Hub System-Assigned Managed Identity."
  value       = azurerm_ai_foundry.hub.identity[0].principal_id
}

output "project_principal_id" {
  description = "Principal ID of the Project System-Assigned Managed Identity."
  value       = azurerm_ai_foundry_project.this.identity[0].principal_id
}

output "private_endpoint_ips" {
  description = "Private IP addresses of all endpoints (useful for firewall rules and debugging)."
  value = {
    key_vault    = azurerm_private_endpoint.key_vault.private_service_connection[0].private_ip_address
    storage_blob = azurerm_private_endpoint.storage_blob.private_service_connection[0].private_ip_address
    storage_file = azurerm_private_endpoint.storage_file.private_service_connection[0].private_ip_address
    ai_services  = azurerm_private_endpoint.ai_services.private_service_connection[0].private_ip_address
    ai_hub       = azurerm_private_endpoint.ai_hub.private_service_connection[0].private_ip_address
  }
}

output "log_analytics_workspace_id" {
  description = "Resource ID of the Log Analytics Workspace."
  value       = azurerm_log_analytics_workspace.this.id
}
