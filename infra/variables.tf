# Azure info
variable "subscription_id" {
  type = string
}

variable "tenant_id" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

# SQL Server
variable "sql_server_name" {
  type = string
}

variable "sql_database_name" {
  type = string
}

variable "sql_admin_login" {
  type = string
}

variable "sql_admin_password" {
  type      = string
  sensitive = true
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
