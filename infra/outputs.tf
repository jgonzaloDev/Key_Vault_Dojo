###############################################################
# Outputs - Información importante después del despliegue
###############################################################

output "resource_group_name" {
  description = "Nombre del Resource Group"
  value       = azurerm_resource_group.dojo.name
}

output "vnet_name" {
  description = "Nombre de la Virtual Network"
  value       = azurerm_virtual_network.vnet.name
}

###############################################################
# Outputs de VM Observability
###############################################################

output "vm_public_ip" {
  description = "IP Pública de la VM"
  value       = azurerm_public_ip.vm_pip.ip_address
}

output "vm_private_ip" {
  description = "IP Privada de la VM"
  value       = azurerm_network_interface.vm_nic.private_ip_address
}

output "vm_kibana_url" {
  description = "URL de Kibana"
  value       = "http://${azurerm_public_ip.vm_pip.ip_address}:5601"
}

###############################################################
# Outputs de App Services
###############################################################

output "frontend_url" {
  description = "URL del Frontend (React)"
  value       = "https://${azurerm_linux_web_app.frontend.default_hostname}"
}

output "backend_url" {
  description = "URL del Backend (Spring Boot)"
  value       = "https://${azurerm_linux_web_app.backend.default_hostname}"
}

###############################################################
# Outputs de SQL Server
###############################################################

output "sql_server_fqdn" {
  description = "FQDN del SQL Server"
  value       = azurerm_mssql_server.sql.fully_qualified_domain_name
}
