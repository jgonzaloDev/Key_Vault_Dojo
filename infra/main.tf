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

  custom_data = base64encode(templatefile("${path.module}/cloud-init-docker.yaml", {
    admin_username = var.vm_admin_username
  }))

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
# 🔟 App Service FRONTEND
###############################################################

resource "azurerm_linux_web_app" "frontend" {
  name                = var.webapp_frontend_name
  resource_group_name = azurerm_resource_group.dojo.name
  location            = azurerm_service_plan.app_plan.location
  service_plan_id     = azurerm_service_plan.app_plan.id

  site_config {
    always_on = true

    application_stack {
      node_version = "18-lts"
    }
  }

  app_settings = {
    "WEBSITE_NODE_DEFAULT_VERSION" = "18-lts"
    "BACKEND_URL"                  = "https://${var.webapp_backend_name}.azurewebsites.net"
  }

  identity {
    type = "SystemAssigned"
  }

  tags = {
    Environment = "Development"
    Purpose     = "Frontend"
  }
}

###############################################################
# 1️⃣1️⃣ App Service BACKEND
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
    # CORS para permitir que el frontend acceda al backend
    cors {
      allowed_origins = [
        "https://${var.app_service_name_web}.azurewebsites.net",
        "http://localhost:3000"
      ]
      support_credentials = true
    }

  }

  app_settings = {
    "SQL_SERVER"                  = azurerm_mssql_server.sql.fully_qualified_domain_name
    "SQL_DATABASE"                = azurerm_mssql_database.db.name
    "SQL_USER"                    = var.sql_admin_login
    "SQL_PASSWORD"                = var.sql_admin_password
    "OTEL_EXPORTER_OTLP_ENDPOINT" = "http://${azurerm_network_interface.vm_nic.private_ip_address}:4318"
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
# 1️⃣2️⃣ VNet Integration Frontend
###############################################################

resource "azurerm_app_service_virtual_network_swift_connection" "frontend_vnet" {
  app_service_id = azurerm_linux_web_app.frontend.id
  subnet_id      = azurerm_subnet.integration.id
}

###############################################################
# 1️⃣3️⃣ VNet Integration Backend
###############################################################

resource "azurerm_app_service_virtual_network_swift_connection" "backend_vnet" {
  app_service_id = azurerm_linux_web_app.backend.id
  subnet_id      = azurerm_subnet.integration.id
}
