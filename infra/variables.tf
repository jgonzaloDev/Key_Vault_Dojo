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

# Key Vault
variable "key_vault_name" {
  type = string
}

# IAM principal (GitHub Federated Credential)
variable "github_principal_id" {
  type        = string
  description = "Object ID del GitHub Federated Credential"
}

# IAM para ti (usuario administrador del Key Vault)
variable "admin_user_object_id" {
  type        = string
  description = "Object ID del usuario administrador que puede leer y administrar secretos"
}
variable "sql_database_name" {
  type = string
}

variable "sql_admin_login" {
  type = string
}

variable "sql_admin_password" {
  type = string
}

