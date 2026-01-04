terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    time = {
      source = "hashicorp/time"
      version = "~> 0.9"
    }
  }
  required_version = ">= 1.1.0"
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id
}

provider "time" {}

###############################################################
# 1️⃣ Resource Group
###############################################################
resource "azurerm_resource_group" "dojo" {
  name     = var.resource_group_name
  location = var.location
}

###############################################################
# 2️⃣ Key Vault con RBAC
###############################################################
resource "azurerm_key_vault" "kv" {
  name                = var.key_vault_name
  resource_group_name = azurerm_resource_group.dojo.name
  location            = azurerm_resource_group.dojo.location
  tenant_id           = var.tenant_id

  sku_name                   = "standard"
  soft_delete_retention_days = 7
  purge_protection_enabled   = false
  enable_rbac_authorization  = true
}

###############################################################
# 3️⃣ GitHub OIDC → Key Vault Secrets Officer
###############################################################
resource "azurerm_role_assignment" "github_kv_secrets" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = var.github_principal_id
}

###############################################################
# 4️⃣ Tu Usuario → Key Vault Administrator
###############################################################
resource "azurerm_role_assignment" "user_kv_admin" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = var.admin_user_object_id
}

###############################################################
# 5️⃣ Espera propagación IAM
###############################################################
resource "time_sleep" "wait_for_iam" {
  depends_on = [
    azurerm_role_assignment.github_kv_secrets,
    azurerm_role_assignment.user_kv_admin
  ]
  create_duration = "45s"
}

###############################################################
# 6️⃣ Secretos (CREA O ADOPTA — NO FALLA)
###############################################################

resource "azurerm_key_vault_secret" "bd_datos" {
  name         = "BDdatos"
  value        = var.sql_database_name
  key_vault_id = azurerm_key_vault.kv.id

  lifecycle {
    ignore_changes = [
      value
    ]
  }

  depends_on = [time_sleep.wait_for_iam]
}

resource "azurerm_key_vault_secret" "userbd" {
  name         = "userbd"
  value        = var.sql_admin_login
  key_vault_id = azurerm_key_vault.kv.id

  lifecycle {
    ignore_changes = [
      value
    ]
  }

  depends_on = [time_sleep.wait_for_iam]
}

resource "azurerm_key_vault_secret" "passwordbd" {
  name         = "passwordbd"
  value        = var.sql_admin_password
  key_vault_id = azurerm_key_vault.kv.id

  lifecycle {
    ignore_changes = [
      value
    ]
  }

  depends_on = [time_sleep.wait_for_iam]
}

###############################################################
# 7️⃣ Lectura final
###############################################################

data "azurerm_key_vault_secret" "bd_datos_read" {
  name         = azurerm_key_vault_secret.bd_datos.name
  key_vault_id = azurerm_key_vault.kv.id
}

data "azurerm_key_vault_secret" "userbd_read" {
  name         = azurerm_key_vault_secret.userbd.name
  key_vault_id = azurerm_key_vault.kv.id
}

data "azurerm_key_vault_secret" "passwordbd_read" {
  name         = azurerm_key_vault_secret.passwordbd.name
  key_vault_id = azurerm_key_vault.kv.id
}

###############################################################
# 8️⃣ Virtual Network (VNet)
###############################################################

resource "azurerm_virtual_network" "vnet" {
  name                = var.vnet_name
  resource_group_name = azurerm_resource_group.dojo.name
  location            = azurerm_resource_group.dojo.location
  address_space       = [var.address_space]
}

# Subnet para integración de App Service
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

# Subnet para la VM (Backend)
resource "azurerm_subnet" "vm_subnet" {
  name                 = "subnet-vm-backend"
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
# 9️⃣ Network Security Group para VM
###############################################################

resource "azurerm_network_security_group" "vm_nsg" {
  name                = "nsg-vm-backend"
  location            = azurerm_resource_group.dojo.location
  resource_group_name = azurerm_resource_group.dojo.name

  # Permitir SSH
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

  # Permitir RDP para escritorio remoto (XRDP)
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

  # Permitir tráfico desde la VNet
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

  # Permitir puerto de aplicación backend (ejemplo: 8080)
  security_rule {
    name                       = "Allow-Backend-Port"
    priority                   = 130
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8080"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "vm_nsg_assoc" {
  subnet_id                 = azurerm_subnet.vm_subnet.id
  network_security_group_id = azurerm_network_security_group.vm_nsg.id
}

###############################################################
# 🔟 Public IP para VM
###############################################################

resource "azurerm_public_ip" "vm_pip" {
  name                = "pip-vm-backend"
  location            = azurerm_resource_group.dojo.location
  resource_group_name = azurerm_resource_group.dojo.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

###############################################################
# 1️⃣1️⃣ Network Interface para VM
###############################################################

resource "azurerm_network_interface" "vm_nic" {
  name                = "nic-vm-backend"
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
# 1️⃣2️⃣ Virtual Machine Linux con Escritorio + Java + Maven + Postman
###############################################################

resource "azurerm_linux_virtual_machine" "backend_vm" {
  name                = var.vm_name
  resource_group_name = azurerm_resource_group.dojo.name
  location            = azurerm_resource_group.dojo.location
  size                = var.vm_size
  admin_username      = var.vm_admin_username

  network_interface_ids = [
    azurerm_network_interface.vm_nic.id,
  ]

  admin_ssh_key {
    username   = var.vm_admin_username
    public_key = var.vm_ssh_public_key
  }

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

  custom_data = base64encode(templatefile("${path.module}/cloud-init.yaml", {
    admin_username = var.vm_admin_username
  }))

  tags = {
    Environment = "Development"
    Purpose     = "Backend"
  }
}

###############################################################
# 1️⃣3️⃣ SQL Server
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

# Firewall rule para permitir servicios de Azure
resource "azurerm_mssql_firewall_rule" "allow_azure_services" {
  name             = "AllowAzureServices"
  server_id        = azurerm_mssql_server.sql.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

# Firewall rule para permitir acceso desde la VM (se actualiza después del deploy)
resource "azurerm_mssql_firewall_rule" "allow_vm" {
  name             = "AllowVM"
  server_id        = azurerm_mssql_server.sql.id
  start_ip_address = azurerm_public_ip.vm_pip.ip_address
  end_ip_address   = azurerm_public_ip.vm_pip.ip_address
}

###############################################################
# 1️⃣4️⃣ SQL Database
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
# 1️⃣5️⃣ App Service Plan
###############################################################

resource "azurerm_service_plan" "frontend_plan" {
  name                = var.app_service_plan_name
  resource_group_name = azurerm_resource_group.dojo.name
  location            = azurerm_resource_group.dojo.location
  os_type             = "Linux"
  sku_name            = "B2"
}

###############################################################
# 1️⃣6️⃣ App Service (Frontend) con VNet Integration
###############################################################

resource "azurerm_linux_web_app" "frontend" {
  name                = var.webapp_name
  resource_group_name = azurerm_resource_group.dojo.name
  location            = azurerm_service_plan.frontend_plan.location
  service_plan_id     = azurerm_service_plan.frontend_plan.id

  site_config {
    always_on = true

    application_stack {
      node_version = "18-lts"
    }
  }

  app_settings = {
    "WEBSITE_NODE_DEFAULT_VERSION" = "18-lts"
    "BACKEND_URL"                  = "http://${azurerm_network_interface.vm_nic.private_ip_address}:8080"
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
# 1️⃣7️⃣ VNet Integration para App Service
###############################################################

resource "azurerm_app_service_virtual_network_swift_connection" "frontend_vnet" {
  app_service_id = azurerm_linux_web_app.frontend.id
  subnet_id      = azurerm_subnet.integration.id
}

###############################################################
# 1️⃣8️⃣ Asignar permisos al App Service para leer secretos
###############################################################

resource "azurerm_role_assignment" "webapp_kv_secrets" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_web_app.frontend.identity[0].principal_id

  depends_on = [time_sleep.wait_for_iam]
}
