terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
  required_version = ">= 1.1.0"
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id
}

###############################################################
# 1️⃣ Resource Group
###############################################################
resource "azurerm_resource_group" "dojo" {
  name     = var.resource_group_name
  location = var.location
}

###############################################################
# 2️⃣ Virtual Network (VNet)
###############################################################

resource "azurerm_virtual_network" "vnet" {
  name                = var.vnet_name
  resource_group_name = azurerm_resource_group.dojo.name
  location            = azurerm_resource_group.dojo.location
  address_space       = [var.address_space]
}

# Subnet para integración de App Services
resource "azurerm_subnet" "integration" {
  name                 = "subnet-integration"
  resource_group_name  = azurerm_resource_group.dojo.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.subnet_integration_cidr]

  delegation {
    name = "delegation"
    service_delegation {
      name    = "Microsoft.Web/serverFarms"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

# Subnet para la VM (Docker Collector + Elastic)
resource "azurerm_subnet" "vm_subnet" {
  name                 = "subnet-vm-docker"
  resource_group_name  = azurerm_resource_group.dojo.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.subnet_vm_cidr]
}

# Subnet para Private Endpoints
resource "azurerm_subnet" "privateendpoint" {
  name                 = "subnet-privateendpoint"
  resource_group_name  = azurerm_resource_group.dojo.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.subnet_privateendpoint_cidr]
}

# Subnet para Application Gateway
resource "azurerm_subnet" "appgw_subnet" {
  name                 = "subnet-appgw"
  resource_group_name  = azurerm_resource_group.dojo.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.subnet_appgw_cidr]
}

###############################################################
# 3️⃣ Network Security Group para VM
###############################################################

resource "azurerm_network_security_group" "vm_nsg" {
  name                = "nsg-vm-docker"
  location            = azurerm_resource_group.dojo.location
  resource_group_name = azurerm_resource_group.dojo.name

  # SSH
  security_rule {
    name                       = "Allow-SSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # RDP
  security_rule {
    name                       = "Allow-RDP"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # VNet
  security_rule {
    name                       = "Allow-VNet"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
  }

  # Elasticsearch
  security_rule {
    name                       = "Allow-Elasticsearch"
    priority                   = 130
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "9200"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Kibana
  security_rule {
    name                       = "Allow-Kibana"
    priority                   = 140
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5601"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # OTLP
  security_rule {
    name                       = "Allow-OTLP"
    priority                   = 150
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["4317", "4318"]
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "vm_nsg_assoc" {
  subnet_id                 = azurerm_subnet.vm_subnet.id
  network_security_group_id = azurerm_network_security_group.vm_nsg.id
}

###############################################################
# 4️⃣ Public IP para VM
###############################################################

resource "azurerm_public_ip" "vm_pip" {
  name                = "pip-vm-docker"
  location            = azurerm_resource_group.dojo.location
  resource_group_name = azurerm_resource_group.dojo.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

###############################################################
# 5️⃣ Network Interface para VM
###############################################################

resource "azurerm_network_interface" "vm_nic" {
  name                = "nic-vm-docker"
  location            = azurerm_resource_group.dojo.location
  resource_group_name = azurerm_resource_group.dojo.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.vm_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.vm_pip.id
  }
}

###############################################################
# 6️⃣ Virtual Machine con Docker
###############################################################

resource "azurerm_linux_virtual_machine" "docker_vm" {
  name                            = var.vm_name
  resource_group_name             = azurerm_resource_group.dojo.name
  location                        = azurerm_resource_group.dojo.location
  size                            = var.vm_size
  admin_username                  = var.vm_admin_username
  admin_password                  = var.vm_admin_password
  disable_password_authentication = false

  network_interface_ids = [
    azurerm_network_interface.vm_nic.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = 128
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  tags = {
    Environment = "Development"
    Purpose     = "Docker-Collector-Elastic"
  }
}

###############################################################
# 7️⃣ SQL Server
###############################################################

resource "azurerm_mssql_server" "sql" {
  name                         = var.sql_server_name
  resource_group_name          = azurerm_resource_group.dojo.name
  location                     = azurerm_resource_group.dojo.location
  version                      = "12.0"
  administrator_login          = var.sql_admin_login
  administrator_login_password = var.sql_admin_password

  tags = {
    Environment = "Development"
  }
}

resource "azurerm_mssql_firewall_rule" "allow_azure_services" {
  name             = "AllowAzureServices"
  server_id        = azurerm_mssql_server.sql.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

resource "azurerm_mssql_firewall_rule" "allow_vm" {
  name             = "AllowVM"
  server_id        = azurerm_mssql_server.sql.id
  start_ip_address = azurerm_public_ip.vm_pip.ip_address
  end_ip_address   = azurerm_public_ip.vm_pip.ip_address
}

###############################################################
# 8️⃣ SQL Database
###############################################################

resource "azurerm_mssql_database" "db" {
  name      = var.sql_database_name
  server_id = azurerm_mssql_server.sql.id
  sku_name  = "Basic"

  tags = {
    Environment = "Development"
  }
}

###############################################################
# 9️⃣ App Service Plan
###############################################################

resource "azurerm_service_plan" "app_plan" {
  name                = var.app_service_plan_name
  resource_group_name = azurerm_resource_group.dojo.name
  location            = azurerm_resource_group.dojo.location
  os_type             = "Linux"
  sku_name            = "B2"
}

###############################################################
# 🔟 Storage Account para imágenes del frontend
###############################################################

resource "azurerm_storage_account" "images" {
  name                     = var.storage_account_name
  resource_group_name      = azurerm_resource_group.dojo.name
  location                 = azurerm_resource_group.dojo.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  
  # ⭐ CAMBIO: Permitir acceso público durante la creación inicial
  public_network_access_enabled   = true
  allow_nested_items_to_be_public = false
  
  # ⭐ CAMBIO: Permitir acceso desde GitHub Actions durante la creación
  network_rules {
    default_action = "Allow"
    bypass         = ["AzureServices"]
  }

  tags = {
    Environment = "Development"
    Purpose     = "Frontend Images Storage"
  }
}

###############################################################
# 1️⃣1️⃣ Blob Container para imágenes
###############################################################

resource "azurerm_storage_container" "images" {
  name                  = "images"
  storage_account_name  = azurerm_storage_account.images.name
  container_access_type = "private"
}

###############################################################
# 1️⃣2️⃣ Private DNS Zone para Blob Storage
###############################################################

resource "azurerm_private_dns_zone" "blob" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = azurerm_resource_group.dojo.name

  tags = {
    Environment = "Development"
  }
}

resource "azurerm_private_dns_zone_virtual_network_link" "blob_link" {
  name                  = "blob-vnet-link"
  resource_group_name   = azurerm_resource_group.dojo.name
  private_dns_zone_name = azurerm_private_dns_zone.blob.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
  registration_enabled  = false

  tags = {
    Environment = "Development"
  }
}

###############################################################
# 1️⃣3️⃣ Private Endpoint para Blob Storage
###############################################################

resource "azurerm_private_endpoint" "blob_pe" {
  name                = "pe-blob-storage"
  resource_group_name = azurerm_resource_group.dojo.name
  location            = azurerm_resource_group.dojo.location
  subnet_id           = azurerm_subnet.privateendpoint.id

  private_service_connection {
    name                           = "blob-storage-connection"
    private_connection_resource_id = azurerm_storage_account.images.id
    is_manual_connection           = false
    subresource_names              = ["blob"]
  }

  private_dns_zone_group {
    name                 = "blob-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.blob.id]
  }

  tags = {
    Environment = "Development"
    Purpose     = "Blob Storage Private Access"
  }
}

###############################################################
# 1️⃣4️⃣ App Service FRONTEND
###############################################################

resource "azurerm_linux_web_app" "frontend" {
  name                = var.webapp_frontend_name
  resource_group_name = azurerm_resource_group.dojo.name
  location            = azurerm_service_plan.app_plan.location
  service_plan_id     = azurerm_service_plan.app_plan.id

  site_config {
    always_on = true

    application_stack {
      node_version = "20-lts"
    }

    # ⭐ Habilitar VNet Integration para acceder al Private Endpoint
    vnet_route_all_enabled = true
  }

  app_settings = {
    "WEBSITE_NODE_DEFAULT_VERSION" = "22-lts"
    "BACKEND_URL"                  = "https://${var.webapp_backend_name}.azurewebsites.net"
    "VITE_APIURL"                  = "https://webapp-backend-dojo-2026.azurewebsites.net/customer"
    "VITE_ORDERURL"                = "https://webapp-backend-dojo-2026.azurewebsites.net/orders"
    
    # ⭐ Variables para acceder al Blob Storage
    "AZURE_STORAGE_ACCOUNT_NAME"   = azurerm_storage_account.images.name
    "AZURE_STORAGE_CONTAINER_NAME" = azurerm_storage_container.images.name
    "AZURE_STORAGE_ENDPOINT"       = "https://${azurerm_storage_account.images.name}.blob.core.windows.net"
  }

  # ⭐ Habilitar Managed Identity
  identity {
    type = "SystemAssigned"
  }

  tags = {
    Environment = "Development"
    Purpose     = "Frontend"
  }
}

###############################################################
# 1️⃣5️⃣ Asignar rol al Frontend para leer blobs
###############################################################

resource "azurerm_role_assignment" "frontend_blob_reader" {
  scope                = azurerm_storage_account.images.id
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = azurerm_linux_web_app.frontend.identity[0].principal_id
}

###############################################################
# 1️⃣6️⃣ App Service BACKEND
###############################################################

resource "azurerm_linux_web_app" "backend" {
  name                = var.webapp_backend_name
  resource_group_name = azurerm_resource_group.dojo.name
  location            = azurerm_service_plan.app_plan.location
  service_plan_id     = azurerm_service_plan.app_plan.id

  site_config {
    always_on = true

    application_stack {
      java_server         = "JAVA"
      java_server_version = "17"
      java_version        = "17"
    }
    
    # ⭐ NO configurar app_command_line - usar JAVA_TOOL_OPTIONS en su lugar
    # Azure App Service usará: java $JAVA_TOOL_OPTIONS -jar app.jar
    
    # CORS para permitir que el frontend acceda al backend
    cors {
      allowed_origins = [
        "https://${var.webapp_frontend_name}.azurewebsites.net",
        "http://localhost:3000"
      ]
      support_credentials = true
    }
  }

  app_settings = {
    #####################################
    # 🗄️ Base de datos SQL Server
    #####################################
    "SQL_SERVER"                              = azurerm_mssql_server.sql.fully_qualified_domain_name
    "SQL_DATABASE"                            = azurerm_mssql_database.db.name
    "SQL_USER"                                = var.sql_admin_login
    "SQL_PASSWORD"                            = var.sql_admin_password
    "SPRING_DATASOURCE_DRIVER_CLASS_NAME"     = "com.microsoft.sqlserver.jdbc.SQLServerDriver"
    "SPRING_DATASOURCE_URL"                   = "jdbc:sqlserver://${azurerm_mssql_server.sql.fully_qualified_domain_name}:1433;databaseName=${azurerm_mssql_database.db.name};encrypt=true;trustServerCertificate=false;loginTimeout=30;"
    "SPRING_DATASOURCE_USERNAME"              = var.sql_admin_login
    "SPRING_DATASOURCE_PASSWORD"              = var.sql_admin_password

    #####################################
    # 🔍 Application Insights - DESHABILITADO
    #####################################
    "APPLICATIONINSIGHTS_ENABLED"             = "false"
    "ApplicationInsightsAgent_EXTENSION_VERSION" = "disabled"

    #####################################
    # 📊 OpenTelemetry - Agente JAR
    #####################################
    "JAVA_TOOL_OPTIONS"                       = "-javaagent:/home/site/wwwroot/otel/opentelemetry-javaagent.jar"
    "OTEL_SERVICE_NAME"                       = "spring-boot-backend"
    "OTEL_EXPORTER_OTLP_ENDPOINT"             = "http://${azurerm_network_interface.vm_nic.private_ip_address}:4317"
    "OTEL_EXPORTER_OTLP_HTTP"                 = "http://${azurerm_network_interface.vm_nic.private_ip_address}:4318"
    "OTEL_EXPORTER_OTLP_PROTOCOL"             = "grpc"
    "OTEL_TRACES_EXPORTER"                    = "otlp"
    "OTEL_METRICS_EXPORTER"                   = "otlp"
    "OTEL_LOGS_EXPORTER"                      = "otlp"

    #####################################
    # 🌐 Aplicación Spring Boot
    #####################################
    "SERVER_PORT"                             = "8080"
    "SPRING_APPLICATION_NAME"                 = "app"
    "SPRING_PROFILES_ACTIVE"                  = "production"
    "SERVER_SERVLET_CONTEXT_PATH"             = "/api"
    #####################################
    # 🗂️ Azure Blob Storage
    #####################################
    "CONNECTION_STRING_BLOB_STORAGE"           = azurerm_storage_account.images.secondary_connection_string
    "CONTAINER_NAME_CUSTOMER"                 = "images"
    "CONTAINER_NAME_ORDER"                    = "images"

    #####################################
    # 🧩 JPA / Hibernate
    #####################################
    "SPRING_JPA_HIBERNATE_DDL_AUTO"           = "create-drop"
    "SPRING_JPA_PROPERTIES_HIBERNATE_DIALECT" = "org.hibernate.dialect.SQLServerDialect"
    "SPRING_JPA_SHOW_SQL"                     = "false"

    #####################################
    # 🔍 Elasticsearch (deshabilitado)
    #####################################
    "ELASTICSEARCH_ENABLED"                   = "false"
    "ELASTICSEARCH_PORT"                      = "9200"
  }

  identity {
    type = "SystemAssigned"
  }

  tags = {
    Environment = "Development"
    Purpose     = "Backend"
  }
}

###############################################################
# 1️⃣7️⃣ VNet Integration Frontend
###############################################################

resource "azurerm_app_service_virtual_network_swift_connection" "frontend_vnet" {
  app_service_id = azurerm_linux_web_app.frontend.id
  subnet_id      = azurerm_subnet.integration.id
}

###############################################################
# 1️⃣8️⃣ VNet Integration Backend
###############################################################

resource "azurerm_app_service_virtual_network_swift_connection" "backend_vnet" {
  app_service_id = azurerm_linux_web_app.backend.id
  subnet_id      = azurerm_subnet.integration.id
}

###############################################################
# 1️⃣9️⃣ Private DNS Zone para App Services
###############################################################

resource "azurerm_private_dns_zone" "appservice" {
  name                = "privatelink.azurewebsites.net"
  resource_group_name = azurerm_resource_group.dojo.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "appservice_link" {
  name                  = "vnet-link-appservice"
  resource_group_name   = azurerm_resource_group.dojo.name
  private_dns_zone_name = azurerm_private_dns_zone.appservice.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
  registration_enabled  = false
}

###############################################################
# 2️⃣0️⃣ Private Endpoint para Frontend App Service
###############################################################

resource "azurerm_private_endpoint" "frontend_pe" {
  name                = "pe-frontend"
  location            = azurerm_resource_group.dojo.location
  resource_group_name = azurerm_resource_group.dojo.name
  subnet_id           = azurerm_subnet.privateendpoint.id

  private_service_connection {
    name                           = "psc-frontend"
    private_connection_resource_id = azurerm_linux_web_app.frontend.id
    is_manual_connection           = false
    subresource_names              = ["sites"]
  }

  private_dns_zone_group {
    name                 = "dns-group-frontend"
    private_dns_zone_ids = [azurerm_private_dns_zone.appservice.id]
  }
}

###############################################################
# 2️⃣1️⃣ Private Endpoint para Backend App Service
###############################################################

resource "azurerm_private_endpoint" "backend_pe" {
  name                = "pe-backend"
  location            = azurerm_resource_group.dojo.location
  resource_group_name = azurerm_resource_group.dojo.name
  subnet_id           = azurerm_subnet.privateendpoint.id

  private_service_connection {
    name                           = "psc-backend"
    private_connection_resource_id = azurerm_linux_web_app.backend.id
    is_manual_connection           = false
    subresource_names              = ["sites"]
  }

  private_dns_zone_group {
    name                 = "dns-group-backend"
    private_dns_zone_ids = [azurerm_private_dns_zone.appservice.id]
  }
}
###############################################################
# 1️⃣7️⃣ Public IP para Application Gateway
###############################################################

resource "azurerm_public_ip" "appgw_pip" {
  name                = "pip-appgw"
  resource_group_name = azurerm_resource_group.dojo.name
  location            = azurerm_resource_group.dojo.location
  allocation_method   = "Static"
  sku                 = "Standard"
}

###############################################################
# 1️⃣8️⃣ Application Gateway con HTTPS y Private Endpoints
###############################################################

locals {
  backend_pool_frontend_name     = "pool-frontend"
  backend_pool_backend_name      = "pool-backend"
  frontend_port_name_https       = "frontend-port-https"
  frontend_ip_configuration_name = "frontend-ip"
  http_setting_frontend_name     = "setting-frontend"
  http_setting_backend_name      = "setting-backend"
  listener_name_https            = "https-listener"
  request_routing_rule_name      = "routing-rule-https"
  ssl_certificate_name           = "cert-app-dojo"
  url_path_map_name              = "url-path-map"
}

resource "azurerm_application_gateway" "appgw" {
  name                = var.appgw_name
  resource_group_name = azurerm_resource_group.dojo.name
  location            = azurerm_resource_group.dojo.location

  sku {
    name     = "Standard_v2"
    tier     = "Standard_v2"
    capacity = 2
  }

  gateway_ip_configuration {
    name      = "gateway-ip-config"
    subnet_id = azurerm_subnet.appgw_subnet.id
  }

  ssl_policy {
    policy_type = "Predefined"
    policy_name = "AppGwSslPolicy20220101"
  }

  # Puerto HTTPS (443)
  frontend_port {
    name = local.frontend_port_name_https
    port = 443
  }

  frontend_ip_configuration {
    name                 = local.frontend_ip_configuration_name
    public_ip_address_id = azurerm_public_ip.appgw_pip.id
  }

  # Certificado SSL/TLS (PFX)
  ssl_certificate {
    name     = local.ssl_certificate_name
    data     = var.cert_data
    password = var.cert_password
  }

  # Backend Pool - Frontend App Service (IP Privada)
  backend_address_pool {
    name         = local.backend_pool_frontend_name
    ip_addresses = [azurerm_private_endpoint.frontend_pe.private_service_connection[0].private_ip_address]
  }

  # Backend Pool - Backend App Service (IP Privada)
  backend_address_pool {
    name         = local.backend_pool_backend_name
    ip_addresses = [azurerm_private_endpoint.backend_pe.private_service_connection[0].private_ip_address]
  }

  # Health Probe - Frontend
  probe {
    name                                      = "health-probe-frontend"
    protocol                                  = "Https"
    path                                      = "/"
    interval                                  = 30
    timeout                                   = 30
    unhealthy_threshold                       = 3
    pick_host_name_from_backend_http_settings = true
    match {
      status_code = ["200-399"]
    }
  }

  # Health Probe - Backend
  probe {
    name                                      = "probe-backend"
    protocol                                  = "Https"
    path                                      = "/customer"
    interval                                  = 30
    timeout                                   = 30
    unhealthy_threshold                       = 3
    pick_host_name_from_backend_http_settings = true
    match {
      status_code = ["200-399"]
    }
  }

  # HTTP Settings - Frontend
  backend_http_settings {
    name                                = local.http_setting_frontend_name
    cookie_based_affinity               = "Disabled"
    port                                = 443
    protocol                            = "Https"
    request_timeout                     = 60
    pick_host_name_from_backend_address = false
    host_name                           = azurerm_linux_web_app.frontend.default_hostname
    probe_name                          = "health-probe-frontend"
  }

  # HTTP Settings - Backend
  backend_http_settings {
    name                                = local.http_setting_backend_name
    cookie_based_affinity               = "Disabled"
    port                                = 443
    protocol                            = "Https"
    request_timeout                     = 60
    pick_host_name_from_backend_address = false
    host_name                           = azurerm_linux_web_app.backend.default_hostname
    probe_name                          = "probe-backend"
  }

  # Listener HTTPS con certificado SSL
  http_listener {
    name                           = local.listener_name_https
    frontend_ip_configuration_name = local.frontend_ip_configuration_name
    frontend_port_name             = local.frontend_port_name_https
    protocol                       = "Https"
    ssl_certificate_name           = local.ssl_certificate_name
  }

  # URL Path Map - Enrutamiento basado en rutas
  url_path_map {
    name                               = local.url_path_map_name
    default_backend_address_pool_name  = local.backend_pool_frontend_name
    default_backend_http_settings_name = local.http_setting_frontend_name

    # Regla para Frontend - /web/*
    path_rule {
      name                       = "frontend-rule"
      paths                      = ["/web/*"]
      backend_address_pool_name  = local.backend_pool_frontend_name
      backend_http_settings_name = local.http_setting_frontend_name
    }

    # Regla para Backend - /customer*
    path_rule {
      name                       = "backend-rule"
      paths                      = ["/customer*"]
      backend_address_pool_name  = local.backend_pool_backend_name
      backend_http_settings_name = local.http_setting_backend_name
    }

    # Regla para Backend - /order*
    path_rule {
      name                       = "backend-rule2"
      paths                      = ["/order*"]
      backend_address_pool_name  = local.backend_pool_backend_name
      backend_http_settings_name = local.http_setting_backend_name
    }
  }

  # Regla de enrutamiento HTTPS con path-based routing
  request_routing_rule {
    name              = local.request_routing_rule_name
    rule_type         = "PathBasedRouting"
    http_listener_name = local.listener_name_https
    url_path_map_name = local.url_path_map_name
    priority          = 100
  }

  depends_on = [
    azurerm_private_endpoint.frontend_pe,
    azurerm_private_endpoint.backend_pe,
    azurerm_private_dns_zone_virtual_network_link.appservice_link
  ]

  tags = {
    Environment = "Development"
    Purpose     = "LoadBalancer"
  }
}