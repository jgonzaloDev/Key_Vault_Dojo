###############################################################
# Azure info
###############################################################

variable "subscription_id" {
  type        = string
  description = "Azure Subscription ID"
}

variable "tenant_id" {
  type        = string
  description = "Azure Tenant ID"
}

variable "resource_group_name" {
  type        = string
  description = "Nombre del Resource Group"
}

variable "location" {
  type        = string
  description = "Ubicación de los recursos de Azure"
}

###############################################################
# SQL Server
###############################################################

variable "sql_server_name" {
  type        = string
  description = "Nombre del SQL Server"
}

variable "sql_database_name" {
  type        = string
  description = "Nombre de la base de datos SQL"
}

variable "sql_admin_login" {
  type        = string
  description = "Usuario administrador de SQL Server"
}

variable "sql_admin_password" {
  type        = string
  description = "Contraseña del administrador de SQL Server"
  sensitive   = true
}

###############################################################
# Variables de Red Virtual
###############################################################

variable "vnet_name" {
  type        = string
  description = "Nombre de la Virtual Network"
  default     = "vnet-dojo"
}

variable "address_space" {
  type        = string
  description = "Espacio de direcciones de la VNet"
  default     = "10.0.0.0/16"
}

variable "subnet_integration_cidr" {
  type        = string
  description = "CIDR para subnet de integración de App Services"
  default     = "10.0.1.0/24"
}

variable "subnet_vm_cidr" {
  type        = string
  description = "CIDR para subnet de la VM Docker"
  default     = "10.0.2.0/24"
}

variable "subnet_privateendpoint_cidr" {
  type        = string
  description = "CIDR para subnet de Private Endpoints"
  default     = "10.0.3.0/24"
}

variable "subnet_appgw_cidr" {
  type        = string
  description = "CIDR para subnet del Application Gateway"
  default     = "10.0.4.0/24"
}

###############################################################
# Variables de Virtual Machine
###############################################################

variable "vm_name" {
  type        = string
  description = "Nombre de la Virtual Machine para Docker"
  default     = "vm-docker-dojo"
}

variable "vm_size" {
  type        = string
  description = "Tamaño de la VM"
  default     = "Standard_D2s_v3"
}

variable "vm_admin_username" {
  type        = string
  description = "Usuario administrador de la VM"
  default     = "dojo"
}

variable "vm_admin_password" {
  type        = string
  description = "Contraseña para el usuario administrador de la VM"
  sensitive   = true
}

###############################################################
# Variables de App Services
###############################################################

variable "app_service_plan_name" {
  type        = string
  description = "Nombre del App Service Plan"
  default     = "plan-apps-dojo"
}

variable "webapp_frontend_name" {
  type        = string
  description = "Nombre del App Service Frontend"
}

variable "webapp_backend_name" {
  type        = string
  description = "Nombre del App Service Backend"
}

###############################################################
# Variables de Application Gateway
###############################################################

variable "appgw_name" {
  type        = string
  description = "Nombre del Application Gateway"
  default     = "appgw-dojo"
}

variable "cert_data" {
  type        = string
  description = "Contenido del certificado PFX en base64 (viene de GitHub Secrets)"
  sensitive   = true
}

variable "cert_password" {
  type        = string
  description = "Contraseña del certificado PFX (viene de GitHub Secrets)"
  sensitive   = true
}