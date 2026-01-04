# 🔐 GitHub Secrets - Arquitectura Actualizada

## ⚠️ CAMBIOS IMPORTANTES

### ❌ YA NO SE USA:
- Key Vault (eliminado)
- TF_VAR_KEY_VAULT_NAME
- TF_VAR_ADMIN_USER_OBJECT_ID
- TF_VAR_GITHUB_PRINCIPAL_ID
- TF_VAR_VM_SSH_PUBLIC_KEY

### ✅ NUEVA ARQUITECTURA:
- 2 App Services (Frontend React + Backend Spring Boot)
- 1 VM con Docker (OTel Collector + Elasticsearch + Kibana)
- SQL Server de Azure
- VNet con integración

---

## 📋 Secretos Requeridos (Total: 18)

### 🔵 Azure Basics (3 secretos)

| Secreto | Descripción | Cómo obtener |
|---------|-------------|--------------|
| `AZURE_CLIENT_ID` | Client ID del App Registration | `az ad app list --display-name "github-actions"` |
| `AZURE_TENANT_ID` | Tenant ID | `az account show --query tenantId -o tsv` |
| `AZURE_SUBSCRIPTION_ID` | Subscription ID | `az account show --query id -o tsv` |

### 🌍 General (2 secretos)

| Secreto | Valor Ejemplo |
|---------|---------------|
| `TF_VAR_LOCATION` | `East US` |
| `TF_VAR_RESOURCE_GROUP_NAME` | `rg-dojo-dev` |

### 🗄️ SQL Server (4 secretos)

| Secreto | Valor Ejemplo | Nota |
|---------|---------------|------|
| `TF_VAR_SQL_SERVER_NAME` | `sql-dojo-7834` | ⚠️ Único globalmente |
| `TF_VAR_SQL_DATABASE_NAME` | `db-dojo` | |
| `TF_VAR_SQL_ADMIN_LOGIN` | `sqladmin` | |
| `TF_VAR_SQL_ADMIN_PASSWORD` | `YourP@ssw0rd123!` | Mín 8 caracteres |

### 🌐 Virtual Network (5 secretos)

| Secreto | Valor Ejemplo |
|---------|---------------|
| `TF_VAR_VNET_NAME` | `vnet-dojo` |
| `TF_VAR_ADDRESS_SPACE` | `10.0.0.0/16` |
| `TF_VAR_SUBNET_INTEGRATION_CIDR` | `10.0.1.0/24` |
| `TF_VAR_SUBNET_VM_CIDR` | `10.0.2.0/24` |
| `TF_VAR_SUBNET_PRIVATEENDPOINT_CIDR` | `10.0.3.0/24` |

### 🖥️ Virtual Machine - Observability (4 secretos)

| Secreto | Valor |
|---------|-------|
| `TF_VAR_VM_NAME` | `vm-observability-dojo` |
| `TF_VAR_VM_SIZE` | `Standard_D2s_v3` |
| `TF_VAR_VM_ADMIN_USERNAME` | `dojo` |
| `TF_VAR_VM_ADMIN_PASSWORD` | `123456789Da` |

### 📱 App Services (3 secretos)

| Secreto | Valor Ejemplo | Nota |
|---------|---------------|------|
| `TF_VAR_APP_SERVICE_PLAN_NAME` | `plan-dojo` | |
| `TF_VAR_WEBAPP_FRONTEND_NAME` | `webapp-frontend-dojo-7834` | ⚠️ Único globalmente |
| `TF_VAR_WEBAPP_BACKEND_NAME` | `webapp-backend-dojo-7834` | ⚠️ Único globalmente |

---

## 🎲 Generar Nombres Únicos

```powershell
$random = Get-Random -Minimum 1000 -Maximum 9999
Write-Host "SQL Server: sql-dojo-$random"
Write-Host "Frontend: webapp-frontend-dojo-$random"
Write-Host "Backend: webapp-backend-dojo-$random"
```

---

## ✅ Checklist de Configuración

- [ ] `AZURE_CLIENT_ID`
- [ ] `AZURE_TENANT_ID`
- [ ] `AZURE_SUBSCRIPTION_ID`
- [ ] `TF_VAR_LOCATION`
- [ ] `TF_VAR_RESOURCE_GROUP_NAME`
- [ ] `TF_VAR_SQL_SERVER_NAME` (único)
- [ ] `TF_VAR_SQL_DATABASE_NAME`
- [ ] `TF_VAR_SQL_ADMIN_LOGIN`
- [ ] `TF_VAR_SQL_ADMIN_PASSWORD`
- [ ] `TF_VAR_VNET_NAME`
- [ ] `TF_VAR_ADDRESS_SPACE`
- [ ] `TF_VAR_SUBNET_INTEGRATION_CIDR`
- [ ] `TF_VAR_SUBNET_VM_CIDR`
- [ ] `TF_VAR_SUBNET_PRIVATEENDPOINT_CIDR`
- [ ] `TF_VAR_VM_NAME`
- [ ] `TF_VAR_VM_SIZE`
- [ ] `TF_VAR_VM_ADMIN_USERNAME`
- [ ] `TF_VAR_VM_ADMIN_PASSWORD`
- [ ] `TF_VAR_APP_SERVICE_PLAN_NAME`
- [ ] `TF_VAR_WEBAPP_FRONTEND_NAME` (único)
- [ ] `TF_VAR_WEBAPP_BACKEND_NAME` (único)

---

## 📊 Arquitectura Resultante

```
┌─────────────────────────────────────────────┐
│         DIAGRAMA ETAPA 3                    │
├─────────────────────────────────────────────┤
│                                             │
│  ┌──────────────┐    ┌──────────────────┐  │
│  │  Frontend    │───▶│  Backend         │  │
│  │  (React)     │    │  (Spring Boot)   │  │
│  │  App Service │    │  App Service     │  │
│  └──────────────┘    └──────────────────┘  │
│         │                     │             │
│         │                     │ OTel gRPC   │
│         └─────────────────────┼────────┐    │
│                               ▼        │    │
│                      ┌─────────────────┴─┐  │
│                      │ VM - Observability│  │
│                      ├───────────────────┤  │
│                      │ • OTel Collector  │  │
│                      │ • Elasticsearch   │  │
│                      │ • Kibana          │  │
│                      └───────────────────┘  │
│                                             │
│                      ┌───────────────────┐  │
│                      │ SQL Server Azure  │  │
│                      └───────────────────┘  │
└─────────────────────────────────────────────┘
```

---

## 🚀 Después del Despliegue

### Acceder a la VM:
```bash
ssh dojo@<VM_PUBLIC_IP>
# Password: 123456789Da
```

### Verificar Docker Stack:
```bash
cd ~/otel-stack
docker compose -f docker-compose-elastic.yaml ps
docker compose -f docker-compose-collector.yaml ps
```

### Acceder a Kibana:
```
http://<VM_PUBLIC_IP>:5601
```

### URLs de App Services:
```
Frontend: https://webapp-frontend-dojo-XXXX.azurewebsites.net
Backend:  https://webapp-backend-dojo-XXXX.azurewebsites.net
```

---

## 📝 Configuración de Spring Boot

Tu aplicación Spring Boot debe tener estas variables configuradas (ya están en App Service):

```properties
# SQL Server
spring.datasource.url=jdbc:sqlserver://sql-dojo-XXXX.database.windows.net:1433;database=db-dojo
spring.datasource.username=sqladmin
spring.datasource.password=YourP@ssw0rd123!

# OTel Exporter
otel.exporter.otlp.endpoint=http://10.0.2.X:4317
otel.service.name=spring-boot-backend
otel.traces.exporter=otlp
otel.metrics.exporter=otlp
otel.logs.exporter=otlp
```

---

## ⚠️ Notas Importantes

1. Los nombres de App Services deben ser únicos globalmente
2. El SQL Server name también debe ser único
3. La VM tarda ~5 minutos en iniciar Docker completamente
4. Kibana estará disponible en puerto 5601
5. OTel Collector acepta trazas en puerto 4317 (gRPC)
