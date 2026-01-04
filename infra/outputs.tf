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

output "vnet_address_space" {
  description = "Espacio de direcciones de la VNet"
  value       = azurerm_virtual_network.vnet.address_space
}

###############################################################
# Outputs de VM Backend
###############################################################

output "vm_name" {
  description = "Nombre de la VM Backend"
  value       = azurerm_linux_virtual_machine.backend_vm.name
}

output "vm_public_ip" {
  description = "IP Pública de la VM Backend"
  value       = azurerm_public_ip.vm_pip.ip_address
}

output "vm_private_ip" {
  description = "IP Privada de la VM Backend"
  value       = azurerm_network_interface.vm_nic.private_ip_address
}

output "vm_ssh_command" {
  description = "Comando SSH para conectar a la VM"
  value       = "ssh ${var.vm_admin_username}@${azurerm_public_ip.vm_pip.ip_address}"
}

output "vm_rdp_connection" {
  description = "Información para conexión RDP"
  value = {
    ip       = azurerm_public_ip.vm_pip.ip_address
    port     = "3389"
    username = var.vm_admin_username
  }
}

###############################################################
# Outputs de App Service Frontend
###############################################################

output "frontend_url" {
  description = "URL del App Service Frontend"
  value       = "https://${azurerm_linux_web_app.frontend.default_hostname}"
}

output "frontend_name" {
  description = "Nombre del App Service Frontend"
  value       = azurerm_linux_web_app.frontend.name
}

output "frontend_outbound_ips" {
  description = "IPs salientes del App Service"
  value       = azurerm_linux_web_app.frontend.outbound_ip_addresses
}

###############################################################
# Outputs de SQL Server
###############################################################

output "sql_server_fqdn" {
  description = "FQDN del SQL Server"
  value       = azurerm_mssql_server.sql.fully_qualified_domain_name
}

output "sql_database_name" {
  description = "Nombre de la base de datos"
  value       = azurerm_mssql_database.db.name
}

output "sql_connection_string" {
  description = "Cadena de conexión a SQL Server (sin password)"
  value       = "Server=tcp:${azurerm_mssql_server.sql.fully_qualified_domain_name},1433;Initial Catalog=${azurerm_mssql_database.db.name};User ID=${var.sql_admin_login};"
  sensitive   = true
}

###############################################################
# Outputs de Key Vault
###############################################################

output "key_vault_name" {
  description = "Nombre del Key Vault"
  value       = azurerm_key_vault.kv.name
}

output "key_vault_uri" {
  description = "URI del Key Vault"
  value       = azurerm_key_vault.kv.vault_uri
}

###############################################################
# Información de Acceso y Próximos Pasos
###############################################################

output "next_steps" {
  description = "Próximos pasos después del despliegue"
  value = <<-EOT
  
  ========================================
  🎉 Despliegue Completado Exitosamente
  ========================================
  
  📡 FRONTEND (App Service):
     URL: https://${azurerm_linux_web_app.frontend.default_hostname}
     
  🖥️  BACKEND (VM Linux):
     SSH: ssh ${var.vm_admin_username}@${azurerm_public_ip.vm_pip.ip_address}
     RDP: ${azurerm_public_ip.vm_pip.ip_address}:3389
     IP Privada: ${azurerm_network_interface.vm_nic.private_ip_address}
     
     Software instalado:
     ✅ Ubuntu 22.04 con escritorio XFCE
     ✅ Java (OpenJDK 17)
     ✅ Maven
     ✅ Postman
     ✅ Git, Firefox, Vim
  
  🗄️  SQL SERVER:
     Server: ${azurerm_mssql_server.sql.fully_qualified_domain_name}
     Database: ${azurerm_mssql_database.db.name}
     
  🔐 KEY VAULT:
     Nombre: ${azurerm_key_vault.kv.name}
     URI: ${azurerm_key_vault.kv.vault_uri}
  
  📋 Próximos pasos:
  
  1. Conectar a la VM vía RDP:
     - Descarga un cliente RDP (Microsoft Remote Desktop)
     - Conecta a: ${azurerm_public_ip.vm_pip.ip_address}:3389
     - Usuario: ${var.vm_admin_username}
     - Lee el archivo ~/README.txt en la VM para más info
  
  2. Verificar instalaciones en la VM:
     java -version
     mvn -version
     postman
  
  3. Desplegar tu backend en la VM:
     - Los proyectos van en ~/projects
     - El backend debería correr en el puerto 8080
     - La VM ya está integrada en la VNet
  
  4. Desplegar tu frontend en el App Service:
     - Usa GitHub Actions o Azure CLI
     - El App Service ya tiene integración con la VNet
     - Puede comunicarse con el backend vía IP privada
  
  ========================================
  EOT
}
