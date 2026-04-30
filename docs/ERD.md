# JikkoOps Control Database - Entity Relationship Diagram

> **Status**: v0.1 — First approach. Will evolve with product/CEO specs.

## Mermaid ERD

```mermaid
erDiagram
    entities ||--o{ tenants                    : owns
    entities ||--o{ users                      : "has staff"
    tenants  ||--o{ contracts                  : signs
    tenants  ||--o{ invoices                   : "billed via"
    tenants  ||--o{ tenant_entitlements        : "has rights"
    tenants  ||--o{ feature_flags              : "controls runtime"
    tenants  ||--o{ expedientes_sync           : "reports volume"
    tenants  }o--|| plans                      : "subscribed to"
    tenants  ||--o{ sdk_metrics                : generates
    tenants  ||--o{ audit_log                  : "audited via"

    products ||--o{ plans                      : groups
    plans    ||--o{ plan_features              : includes
    plans    ||--o{ plan_protected_resources   : "explicit grants"
    plans    ||--o{ contracts                  : "applied via"

    features ||--o{ feature_protected_resources : bundles
    features ||--o{ tenant_entitlements        : "granted as"
    features ||--o{ plan_features              : "in plans"

    protected_resources ||--o{ feature_protected_resources : "belongs to"
    protected_resources ||--o{ plan_protected_resources    : "explicit in plans"
    protected_resources ||--o{ feature_flags               : "toggled by"
    protected_resources ||--o{ tenant_entitlements         : "granted as"
    protected_resources ||--o{ sdk_metrics                 : "executed as"

    contracts ||--o{ invoices                  : "billed via"
    contracts }o--|| revenue_model_configs     : "uses model"

    invoices  ||--o{ invoice_lines             : "broken down by"

    feature_flags ||--o{ feature_flag_audit    : "changes logged in"

    users    ||--o{ user_roles                 : has
    roles    ||--o{ user_roles                 : "granted via"
    users    ||--|| mfa_credentials            : "secured by"
    users    ||--o{ audit_log                  : "actor in"

    entities {
        UUID    id PK
        VARCHAR nombre
        VARCHAR nit UK
        ENUM    tipo
        ENUM    estado
        JSONB   metadata
    }

    tenants {
        UUID    id PK
        UUID    entity_id FK
        UUID    plan_id FK
        VARCHAR nombre_tecnico UK
        ENUM    estado
        DATE    fecha_activacion
        DATE    fecha_vencimiento
    }

    contracts {
        UUID    id PK
        UUID    tenant_id FK
        UUID    plan_id FK
        UUID    revenue_model_id FK
        VARCHAR numero UK
        ENUM    estado
        DATE    fecha_vencimiento
        NUMERIC valor_total_cop
    }

    plans {
        UUID    id PK
        UUID    producto_id FK
        VARCHAR nombre
        INT     usuario_limite
        INT     expediente_limite_mes
        JSONB   modelo_revenue_config
    }

    products {
        UUID    id PK
        VARCHAR nombre
        ENUM    estado
    }

    features {
        UUID    id PK
        VARCHAR nombre
        ENUM    modulo
        ENUM    criticidad
    }

    protected_resources {
        UUID     id PK
        UUID     feature_id FK
        VARCHAR  codigo UK
        ENUM     tipo
        ENUM     modulo
        TEXT_ARRAY dependencias
        ENUM     estado
    }

    feature_flags {
        UUID    id PK
        UUID    tenant_id FK
        UUID    protected_resource_id FK
        VARCHAR codigo_recurso
        BOOL    activo
    }

    tenant_entitlements {
        UUID id PK
        UUID tenant_id FK
        UUID feature_id FK
        UUID protected_resource_id FK
        ENUM estado
    }

    invoices {
        UUID    id PK
        UUID    tenant_id FK
        UUID    contract_id FK
        VARCHAR numero_factura UK
        DATE    periodo_inicio
        DATE    periodo_fin
        ENUM    estado
        NUMERIC total
    }

    invoice_lines {
        UUID    id PK
        UUID    invoice_id FK
        ENUM    origen
        NUMERIC subtotal
    }

    revenue_model_configs {
        UUID  id PK
        ENUM  tipo
        JSONB parametros
    }

    expedientes_sync {
        UUID    id PK
        UUID    tenant_id FK
        VARCHAR expediente_id_externo
        DATE    fecha
        ENUM    estado
    }

    users {
        UUID    id PK
        UUID    entity_id FK
        VARCHAR email UK
        ENUM    estado
    }

    roles {
        UUID    id PK
        VARCHAR nombre UK
        JSONB   permisos
    }

    user_roles {
        UUID user_id FK
        UUID role_id FK
        UUID tenant_id FK
    }

    mfa_credentials {
        UUID    id PK
        UUID    user_id FK
        TEXT    secret
        BOOL    habilitado
    }

    audit_log {
        UUID    id PK
        UUID    tenant_id FK
        UUID    usuario_id FK
        VARCHAR tabla_afectada
        UUID    registro_id
        ENUM    operacion
        TIMESTAMPTZ timestamp
    }

    sdk_metrics {
        UUID    id PK
        UUID    tenant_id FK
        VARCHAR resource_codigo
        INT     execution_time_ms
        NUMERIC cost_usd
        TIMESTAMPTZ timestamp
    }

    feature_flag_audit {
        UUID id PK
        UUID flag_id FK
        ENUM accion
        TIMESTAMPTZ timestamp
    }
```

## Relationship Summary

| From | Cardinality | To | Purpose |
|------|-------------|-----|---------|
| entities | 1..N | tenants | One entity, multiple JikkoOps instances |
| tenants | N..1 | plans | Each tenant subscribed to one plan at a time |
| tenants | 1..N | contracts | A tenant signs multiple contracts over time |
| tenants | 1..N | invoices | Billing per service period |
| tenants | 1..N | feature_flags | One flag per protected resource per tenant |
| plans | 1..N | plan_features | Plan grants access to multiple features |
| features | 1..N | protected_resources | A feature bundles many resources |
| protected_resources | 1..N | feature_flags | A resource has one flag per tenant |
| contracts | 1..N | invoices | A contract is billed across periods |
| contracts | N..1 | revenue_model_configs | Each contract uses one revenue model |
| feature_flags | 1..N | feature_flag_audit | Every change recorded |
| users | 1..N | user_roles | RBAC assignment with optional tenant scope |
| users | 1..1 | mfa_credentials | One MFA setup per user |

## Key Design Choices

1. **DB-per-tenant for operational data** — this control database holds only tenant configuration, contracts, billing. Tenant-specific operational records live in separate per-tenant databases.
2. **Feature flags denormalize `codigo_recurso`** — avoids a JOIN in the hot path.
3. **Audit log is insert-only** — UPDATE/DELETE prohibited at app layer + RLS hint provided.
4. **Junction tables (`*_features`, `*_protected_resources`)** instead of UUID arrays — easier to index, query, and join.
5. **Revenue models as reusable configs** — contracts reference a `revenue_model_config` instead of embedding logic.
6. **Encryption noted in column comments** — `db_connection_string`, `mfa_credentials.secret`, `mfa_credentials.backup_codes` MUST be encrypted at rest by the application layer.

## Scaling Hooks

- `audit_log`, `sdk_metrics`, `expedientes_sync` are designed for monthly partitioning when row counts demand it (hints in comments).
- `feature_flags` covers index `(tenant_id, protected_resource_id, activo)` keeps the runtime check < 1ms even at 100k+ tenants.
- Indexes on `fecha_vencimiento` are filtered (`WHERE estado = 'activo'`) to minimize index size.
