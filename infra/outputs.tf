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

output "vm_elasticsearch_url" {
  description = "URL de Elasticsearch"
  value       = "http://${azurerm_public_ip.vm_pip.ip_address}:9200"
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

output "frontend_private_ip" {
  description = "IP Privada del Frontend Private Endpoint"
  value       = azurerm_private_endpoint.frontend_pe.private_service_connection[0].private_ip_address
}

output "backend_private_ip" {
  description = "IP Privada del Backend Private Endpoint"
  value       = azurerm_private_endpoint.backend_pe.private_service_connection[0].private_ip_address
}

###############################################################
# Outputs de SQL Server
###############################################################

output "sql_server_fqdn" {
  description = "FQDN del SQL Server"
  value       = azurerm_mssql_server.sql.fully_qualified_domain_name
}

output "sql_database_name" {
  description = "Nombre de la base de datos SQL"
  value       = azurerm_mssql_database.db.name
}

###############################################################
# Outputs de Storage Account (Blob Storage)
###############################################################

output "storage_account_name" {
  description = "Nombre del Storage Account"
  value       = azurerm_storage_account.images.name
}

output "storage_account_endpoint" {
  description = "Endpoint del Blob Storage"
  value       = azurerm_storage_account.images.primary_blob_endpoint
}

output "storage_container_name" {
  description = "Nombre del container de imágenes"
  value       = azurerm_storage_container.images.name
}

output "blob_private_endpoint_ip" {
  description = "IP Privada del Blob Storage Private Endpoint"
  value       = azurerm_private_endpoint.blob_pe.private_service_connection[0].private_ip_address
}

###############################################################
# Outputs de Application Gateway
###############################################################

output "application_gateway_public_ip" {
  description = "IP Pública del Application Gateway"
  value       = azurerm_public_ip.appgw_pip.ip_address
}

output "application_gateway_url" {
  description = "URL HTTPS del Application Gateway (punto de entrada principal)"
  value       = "https://${azurerm_public_ip.appgw_pip.ip_address}"
}

output "application_gateway_name" {
  description = "Nombre del Application Gateway"
  value       = azurerm_application_gateway.appgw.name
}

###############################################################
# Outputs de Conexión OTLP
###############################################################

output "otlp_endpoint" {
  description = "Endpoint OTLP para OpenTelemetry"
  value       = "http://${azurerm_network_interface.vm_nic.private_ip_address}:4317"
}

###############################################################
# Resumen de URLs de Acceso
###############################################################

output "access_summary" {
  description = "Resumen de todas las URLs de acceso"
  value = {
    "Application Gateway (Principal)" = "https://${azurerm_public_ip.appgw_pip.ip_address}"
    "Frontend (Directo)"              = "https://${azurerm_linux_web_app.frontend.default_hostname}"
    "Backend (Directo)"               = "https://${azurerm_linux_web_app.backend.default_hostname}"
    "Kibana"                          = "http://${azurerm_public_ip.vm_pip.ip_address}:5601"
    "Elasticsearch"                   = "http://${azurerm_public_ip.vm_pip.ip_address}:9200"
    "Blob Storage (Privado)"          = azurerm_storage_account.images.primary_blob_endpoint
  }
}

###############################################################
# Comandos útiles para subir imágenes
###############################################################

output "upload_images_command" {
  description = "Comando para subir imágenes al Blob Storage"
  value       = <<-EOT
    # Subir una imagen:
    az storage blob upload \
      --account-name ${azurerm_storage_account.images.name} \
      --container-name ${azurerm_storage_container.images.name} \
      --name mi-imagen.jpg \
      --file ./ruta/local/mi-imagen.jpg \
      --auth-mode login

    # Subir múltiples imágenes desde una carpeta:
    az storage blob upload-batch \
      --account-name ${azurerm_storage_account.images.name} \
      --destination ${azurerm_storage_container.images.name} \
      --source ./carpeta-imagenes/ \
      --auth-mode login

    # Listar todas las imágenes:
    az storage blob list \
      --account-name ${azurerm_storage_account.images.name} \
      --container-name ${azurerm_storage_container.images.name} \
      --auth-mode login \
      --output table
  EOT
}

###############################################################
# Variables de entorno para el Frontend (referencia)
###############################################################

output "frontend_environment_variables" {
  description = "Variables de entorno configuradas en el Frontend"
  value = {
    "AZURE_STORAGE_ACCOUNT_NAME"   = azurerm_storage_account.images.name
    "AZURE_STORAGE_CONTAINER_NAME" = azurerm_storage_container.images.name
    "AZURE_STORAGE_ENDPOINT"       = azurerm_storage_account.images.primary_blob_endpoint
  }
}
