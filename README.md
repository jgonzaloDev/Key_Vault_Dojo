# 🚀 Infraestructura Azure - Dojo Project

Este proyecto despliega una infraestructura completa en Azure con:
- **Frontend**: App Service (Node.js) con integración VNet
- **Backend**: Máquina Virtual Linux con escritorio XFCE, Java 17, Maven y Postman
- **Base de datos**: SQL Server + Database
- **Seguridad**: Key Vault con RBAC
- **Networking**: VNet con múltiples subnets

## 📋 Arquitectura

```
┌─────────────────────────────────────────────────────────┐
│                    Azure Cloud                          │
│                                                          │
│  ┌──────────────────────────────────────────────────┐  │
│  │  Virtual Network (10.0.0.0/16)                   │  │
│  │                                                   │  │
│  │  ┌─────────────────┐  ┌──────────────────────┐  │  │
│  │  │ Subnet          │  │ Subnet VM            │  │  │
│  │  │ Integration     │  │ (10.0.2.0/24)        │  │  │
│  │  │ (10.0.1.0/24)   │  │                      │  │  │
│  │  │                 │  │  ┌────────────────┐  │  │  │
│  │  │  App Service    │──┼──┤ VM Backend     │  │  │  │
│  │  │  (Frontend)     │  │  │ - Ubuntu 22.04 │  │  │  │
│  │  │                 │  │  │ - XFCE Desktop │  │  │  │
│  │  └─────────────────┘  │  │ - Java 17      │  │  │  │
│  │                       │  │ - Maven        │  │  │  │
│  │                       │  │ - Postman      │  │  │  │
│  │                       │  └────────────────┘  │  │  │
│  │                       │                      │  │  │
│  │  ┌─────────────────┐ └──────────────────────┘  │  │
│  │  │ Subnet          │                            │  │
│  │  │ Private Endpoint│                            │  │
│  │  │ (10.0.3.0/24)   │                            │  │
│  │  └─────────────────┘                            │  │
│  └──────────────────────────────────────────────────┘  │
│                                                          │
│  ┌──────────────┐  ┌─────────────┐  ┌──────────────┐  │
│  │ SQL Server   │  │ Key Vault   │  │ Public IP    │  │
│  │ + Database   │  │ (Secrets)   │  │ (VM Access)  │  │
│  └──────────────┘  └─────────────┘  └──────────────┘  │
└─────────────────────────────────────────────────────────┘
```

## 📦 Recursos Creados

### Networking
- ✅ Virtual Network (VNet)
- ✅ Subnet de Integración (App Service)
- ✅ Subnet para VM Backend
- ✅ Subnet para Private Endpoints
- ✅ Network Security Group (NSG)
- ✅ Public IP para VM

### Compute
- ✅ App Service Plan (Linux, B2)
- ✅ App Service (Frontend - Node.js)
- ✅ Linux Virtual Machine (Backend - Ubuntu 22.04)
  - Escritorio XFCE4
  - XRDP (Acceso remoto)
  - Java (OpenJDK 17)
  - Maven
  - Postman
  - Git, Firefox, Vim

### Data
- ✅ SQL Server
- ✅ SQL Database (Basic SKU)
- ✅ Firewall Rules (Azure Services + VM)

### Security
- ✅ Key Vault con RBAC
- ✅ Secretos gestionados
- ✅ Role Assignments (GitHub OIDC, Admin User, App Service)

## 🔧 Requisitos Previos

1. **Azure CLI** instalado y autenticado
2. **Terraform** >= 1.1.0
3. **Cuenta de Azure** con permisos de Owner o Contributor
4. **GitHub Repository** configurado con OIDC
5. **SSH Key Pair** generada

### Generar SSH Key (si no tienes)

```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/azure_vm_key
```

Tu clave pública estará en `~/.ssh/azure_vm_key.pub`

## 🚀 Configuración y Despliegue

### 1. Clonar el repositorio

```bash
git clone <tu-repo>
cd <tu-repo>/infra
```

### 2. Configurar variables

Copia el archivo de ejemplo y edita con tus valores:

```bash
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars
```

Variables requeridas:

```hcl
subscription_id      = "tu-subscription-id"
tenant_id           = "tu-tenant-id"
resource_group_name = "rg-dojo-dev"
location            = "East US"

key_vault_name      = "kv-dojo-unique123"  # Debe ser único globalmente
github_principal_id = "object-id-del-github-credential"
admin_user_object_id = "tu-object-id"

sql_server_name     = "sql-dojo-unique123"  # Debe ser único globalmente
sql_database_name   = "db-dojo"
sql_admin_login     = "sqladmin"
sql_admin_password  = "TuPassword123!"

vm_ssh_public_key   = "ssh-rsa AAAA... tu-clave-publica"
webapp_name         = "webapp-frontend-unique123"  # Debe ser único globalmente
```

### 3. Obtener IDs necesarios

**Object ID de tu usuario:**
```bash
az ad signed-in-user show --query id -o tsv
```

**Object ID del GitHub Federated Credential:**
```bash
az ad sp list --display-name "github-actions-apply-main" --query [0].id -o tsv
```

### 4. Inicializar Terraform

```bash
terraform init
```

### 5. Revisar el plan

```bash
terraform plan
```

### 6. Aplicar la infraestructura

```bash
terraform apply
```

Confirma con `yes` cuando se te solicite.

## 🔐 Configurar GitHub Secrets

Para que GitHub Actions funcione, configura estos secrets en tu repositorio:

### Settings → Secrets and variables → Actions → New repository secret

```
AZURE_CLIENT_ID
AZURE_TENANT_ID
AZURE_SUBSCRIPTION_ID
TF_VAR_LOCATION
TF_VAR_RESOURCE_GROUP_NAME
TF_VAR_KEY_VAULT_NAME
TF_VAR_ADMIN_USER_OBJECT_ID
TF_VAR_GITHUB_PRINCIPAL_ID
TF_VAR_SQL_SERVER_NAME
TF_VAR_SQL_DATABASE_NAME
TF_VAR_SQL_ADMIN_LOGIN
TF_VAR_SQL_ADMIN_PASSWORD
TF_VAR_VNET_NAME
TF_VAR_ADDRESS_SPACE
TF_VAR_SUBNET_INTEGRATION_CIDR
TF_VAR_SUBNET_VM_CIDR
TF_VAR_SUBNET_PRIVATEENDPOINT_CIDR
TF_VAR_VM_NAME
TF_VAR_VM_SIZE
TF_VAR_VM_ADMIN_USERNAME
TF_VAR_VM_SSH_PUBLIC_KEY
TF_VAR_APP_SERVICE_PLAN_NAME
TF_VAR_WEBAPP_NAME
```

## 🖥️ Acceso a la VM Backend

### Opción 1: SSH

```bash
ssh azureuser@<VM_PUBLIC_IP>
```

### Opción 2: RDP (Escritorio Remoto)

1. Descarga **Microsoft Remote Desktop** o cualquier cliente RDP
2. Conecta a: `<VM_PUBLIC_IP>:3389`
3. Usuario: `azureuser` (o el que hayas configurado)
4. Contraseña: usa tu clave SSH o configura password

### Verificar instalaciones en la VM

```bash
# Conectarse por SSH
ssh azureuser@<VM_PUBLIC_IP>

# Verificar Java
java -version

# Verificar Maven
mvn -version

# Abrir Postman (desde el escritorio XFCE)
postman
```

## 📱 Desplegar tu Aplicación

### Frontend (App Service)

El App Service ya está configurado para Node.js 18. Para desplegar:

```bash
# Opción 1: Desde GitHub Actions (recomendado)
# Configura tu workflow de deploy

# Opción 2: Desde Azure CLI
az webapp deployment source config-zip \
  --resource-group rg-dojo-dev \
  --name webapp-frontend-unique123 \
  --src frontend.zip
```

### Backend (VM)

```bash
# Conectarse a la VM
ssh azureuser@<VM_PUBLIC_IP>

# Navegar al directorio de proyectos
cd ~/projects

# Clonar tu repositorio
git clone <tu-repo-backend>
cd <tu-repo-backend>

# Compilar con Maven
mvn clean package

# Ejecutar tu aplicación (ejemplo Spring Boot)
java -jar target/mi-app.jar

# O con Maven
mvn spring-boot:run
```

**Nota**: Tu backend debería correr en el puerto **8080** para que el Frontend pueda comunicarse correctamente.

## 🔗 Comunicación Frontend ↔ Backend

El App Service tiene integración VNet y puede comunicarse con el backend usando la **IP privada de la VM**:

```javascript
// En tu código frontend
const BACKEND_URL = process.env.BACKEND_URL; // http://10.0.2.X:8080
```

Esta variable ya está configurada en el App Service.

## 📊 Verificar el Despliegue

```bash
# Ver outputs de Terraform
terraform output

# Obtener URL del frontend
terraform output frontend_url

# Obtener IP pública de la VM
terraform output vm_public_ip

# Ver toda la información
terraform output next_steps
```

## 🧹 Limpieza

Para destruir todos los recursos:

```bash
terraform destroy
```

## 📝 Notas Importantes

### Software en la VM

La VM incluye:
- **Sistema Operativo**: Ubuntu 22.04 LTS
- **Entorno de Escritorio**: XFCE4
- **Acceso Remoto**: XRDP (puerto 3389)
- **Java**: OpenJDK 17
- **Build Tool**: Maven
- **API Testing**: Postman
- **Otros**: Git, Firefox, Vim

### Puertos Abiertos

- **22** (SSH)
- **3389** (RDP)
- **8080** (Backend app)
- Tráfico dentro de la VNet permitido

### Seguridad

- El SQL Server solo acepta conexiones desde Azure Services y la VM
- El Key Vault usa RBAC (no Access Policies)
- La VM tiene NSG configurado
- El App Service tiene Managed Identity para acceder al Key Vault

## 🐛 Troubleshooting

### No puedo conectarme a la VM por RDP

1. Verifica que el puerto 3389 esté abierto en el NSG
2. Asegúrate de que XRDP esté corriendo: `sudo systemctl status xrdp`
3. Reinicia XRDP: `sudo systemctl restart xrdp`

### El backend no responde

1. Verifica que la aplicación esté corriendo: `ps aux | grep java`
2. Verifica el puerto: `netstat -tulpn | grep 8080`
3. Revisa los logs de la aplicación

### El frontend no puede conectarse al backend

1. Verifica la integración VNet del App Service
2. Confirma que el backend esté corriendo en la VM
3. Verifica la variable de entorno `BACKEND_URL` en el App Service

## 📞 Soporte

Si tienes problemas:
1. Revisa los logs de Terraform
2. Verifica los recursos en el Portal de Azure
3. Consulta la documentación de Azure

## 📄 Licencia

Este proyecto es de código abierto bajo licencia MIT.
