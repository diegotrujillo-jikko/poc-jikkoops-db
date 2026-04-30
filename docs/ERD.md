# JikkoOps Control Database — Entity Relationship Diagram

```mermaid
erDiagram
    entities {
        UUID id PK
        string nombre
        string nit UK
        entity_tipo tipo
        string region
        string email
        entity_estado estado
    }

    tenants {
        UUID id PK
        UUID entity_id FK
        UUID plan_id FK
        string nombre_tecnico UK
        text db_connection_string
        tenant_estado estado
        date fecha_activacion
        date fecha_vencimiento
    }

    users {
        UUID id PK
        UUID entity_id FK
        string nombre
        string email UK
        text password_hash
        user_estado estado
    }

    roles {
        UUID id PK
        string nombre UK
        jsonb permisos
    }

    user_roles {
        UUID user_id FK
        UUID role_id FK
        UUID tenant_id FK
        UUID granted_by FK
    }

    mfa_credentials {
        UUID id PK
        UUID user_id FK
        text secret
        boolean habilitado
        int intentos_fallidos
    }

    features {
        UUID id PK
        string nombre
        modulo modulo
        criticidad criticidad
        feature_estado estado
    }

    protected_resources {
        UUID id PK
        UUID feature_id FK
        string codigo UK
        string nombre
        pr_tipo tipo
        modulo modulo
        pr_estado estado
    }

    feature_protected_resources {
        UUID feature_id FK
        UUID protected_resource_id FK
    }

    products {
        UUID id PK
        string nombre UK
        plan_estado estado
    }

    plans {
        UUID id PK
        UUID producto_id FK
        string nombre UK
        int usuario_limite
        int expediente_limite_mes
        plan_estado estado
    }

    plan_features {
        UUID plan_id FK
        UUID feature_id FK
    }

    plan_protected_resources {
        UUID plan_id FK
        UUID protected_resource_id FK
    }

    revenue_model_configs {
        UUID id PK
        string nombre UK
        revenue_model_tipo tipo
        jsonb parametros
    }

    contracts {
        UUID id PK
        UUID tenant_id FK
        UUID revenue_model_id FK
        UUID plan_id FK
        string numero UK
        contract_tipo tipo
        contract_estado estado
        date fecha_vencimiento
        int limite_expedientes
        numeric porcentaje_recaudo
    }

    tenant_entitlements {
        UUID id PK
        UUID tenant_id FK
        UUID feature_id FK
        UUID protected_resource_id FK
        entitlement_estado estado
    }

    feature_flags {
        UUID id PK
        UUID tenant_id FK
        UUID protected_resource_id FK
        string codigo_recurso
        boolean activo
        timestamptz fecha_activacion
    }

    feature_flag_audit {
        UUID id PK
        UUID flag_id FK
        UUID tenant_id FK
        string codigo_recurso
        flag_accion accion
        boolean valor_anterior
        boolean valor_nuevo
    }

    invoices {
        UUID id PK
        UUID tenant_id FK
        UUID contract_id FK
        string numero_factura UK
        invoice_estado estado
        numeric total
        date periodo_inicio
        date periodo_fin
    }

    invoice_lines {
        UUID id PK
        UUID invoice_id FK
        string descripcion
        numeric cantidad
        numeric precio_unitario
        invoice_line_origen origen
    }

    expedientes_sync {
        UUID id PK
        UUID tenant_id FK
        string expediente_id_externo
        date fecha
        expediente_estado estado
    }

    audit_log {
        UUID id PK
        UUID tenant_id FK
        UUID usuario_id FK
        string tabla_afectada
        UUID registro_id
        audit_operacion operacion
        jsonb valores_anterior
        jsonb valores_nuevo
        timestamptz timestamp
    }

    sdk_metrics {
        UUID id PK
        UUID tenant_id FK
        UUID resource_id FK
        string resource_codigo
        int execution_time_ms
        numeric cost_usd
        boolean success
        timestamptz timestamp
    }

    %% Relationships
    entities            ||--o{ tenants                  : "has"
    entities            ||--o{ users                    : "employs"
    tenants             ||--o{ contracts                : "has"
    tenants             ||--o{ feature_flags            : "controls"
    tenants             ||--o{ tenant_entitlements      : "holds"
    tenants             ||--o{ invoices                 : "billed_via"
    tenants             ||--o{ expedientes_sync         : "reports"
    contracts           ||--o{ invoices                 : "generates"
    contracts           }o--|| revenue_model_configs    : "uses"
    contracts           }o--|| plans                    : "under"
    plans               }o--|| products                 : "bundles"
    plans               ||--o{ plan_features            : "includes"
    plans               ||--o{ plan_protected_resources : "grants"
    features            ||--o{ feature_protected_resources : "groups"
    features            ||--o{ plan_features            : "in"
    protected_resources ||--o{ feature_protected_resources : "member_of"
    protected_resources ||--o{ plan_protected_resources : "in"
    protected_resources ||--o{ feature_flags            : "controlled_by"
    protected_resources ||--o{ tenant_entitlements      : "referenced_by"
    feature_flags       ||--o{ feature_flag_audit       : "logged_in"
    invoices            ||--o{ invoice_lines            : "composed_of"
    users               ||--o{ user_roles               : "assigned"
    roles               ||--o{ user_roles               : "granted_to"
    users               ||--o| mfa_credentials          : "secures"
    audit_log           }o--|| tenants                  : "scoped_to"
    audit_log           }o--|| users                    : "by"
    sdk_metrics         }o--|| protected_resources      : "measures"
```

## Architecture Note: Central DB vs Tenant DBs

This diagram represents the **central JikkoOps control database**. It stores commercial, billing, and access-control data only.

Each tenant also has its own **isolated operational database** (connection string stored encrypted in `tenants.db_connection_string`) that holds the tenant's domain data (expedients, liquidations, documents, etc.). That schema is managed by SILIN/DOS/SOCIA and is **not** represented here.

```
JikkoOps Central DB (this repo)
├── Commercial: entities, tenants, contracts, plans, products
├── Access Control: feature_flags, protected_resources, entitlements
├── Billing: invoices, invoice_lines, revenue_model_configs
├── Auth: users, roles, mfa_credentials
└── Audit: audit_log, sdk_metrics, expedientes_sync

Tenant Operational DB (per tenant, separate)
├── Expedientes (domain data)
├── Liquidaciones
├── Documentos
└── Ciudadanos
```
