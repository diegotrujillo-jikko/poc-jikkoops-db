# JikkoOps Control Database — Data Dictionary

---

## entities

**Purpose**: Physical government organizations that contract JikkoOps services.

| Field | Type | Business Meaning |
|-------|------|-----------------|
| `id` | UUID PK | Internal identifier |
| `nit` | VARCHAR(20) UK | Colombian tax ID. Used for DIAN invoicing compliance |
| `tipo` | entity_tipo | Classification: municipio, gobernacion, dian, otro |
| `region` | VARCHAR | Colombian department (e.g. Valle del Cauca) |
| `estado` | entity_estado | Active/inactive/cancelled status |
| `metadata` | JSONB | dane_code, nivel_alcaldia, presupuesto_anual_cop |

**Business Rules**: NIT must be unique. Cancelling an entity does not delete tenants — managed separately.

**Typical Queries**: Filter by estado='activo' and tipo for commercial pipeline.

---

## tenants

**Purpose**: A JikkoOps instance scoped to one entity. The unit of isolation, billing, and access control.

| Field | Type | Business Meaning |
|-------|------|-----------------|
| `nombre_tecnico` | VARCHAR UK | Slug used in Redis keys and API routing |
| `db_connection_string` | TEXT | ENCRYPTED. Connection string to tenant's operational DB |
| `plan_id` | UUID FK | Currently active commercial plan |
| `expedientes_mes_limite` | INT | Monthly cap for caute model triggering |
| `feature_flags_cache` | JSONB | DB-level fallback when Redis is unavailable |

**Business Rules**: `fecha_vencimiento > fecha_activacion`. `db_connection_string` must never be logged or exposed.

**Typical Queries**: Join to entities for commercial reports; filter by estado for billing jobs.

---

## users

**Purpose**: JikkoOps platform operators and administrators (not end-users of government apps).

| Field | Type | Business Meaning |
|-------|------|-----------------|
| `entity_id` | UUID FK nullable | NULL = global admin; set for entity-scoped operators |
| `password_hash` | TEXT | bcrypt cost≥12. Never store plaintext |
| `estado` | user_estado | bloqueado after MFA lockout |

**Business Rules**: Email is globally unique. `ultimo_acceso` updated on every successful login.

---

## roles / user_roles

**Purpose**: RBAC for platform operators.

| Field | Type | Business Meaning |
|-------|------|-----------------|
| `permisos` | JSONB | Array of strings: ["tenants:read", "flags:write"] |
| `tenant_id` | UUID nullable | NULL = global scope; set for tenant-scoped assignment |

**Typical Queries**: `SELECT permisos FROM roles r JOIN user_roles ur ON r.id = ur.role_id WHERE ur.user_id = $1`.

---

## mfa_credentials

**Purpose**: TOTP MFA required for critical endpoints (liquidation, flag changes, contract activation).

| Field | Type | Business Meaning |
|-------|------|-----------------|
| `secret` | TEXT | AES-256-GCM encrypted TOTP seed. Application-layer only |
| `intentos_fallidos` | INT | Locked after 5 failures |
| `bloqueado_hasta` | TIMESTAMPTZ | NULL = not locked |
| `backup_codes` | TEXT[] | Encrypted one-time recovery codes |

**Business Rules**: One record per user (unique on user_id). Locked users cannot authenticate until admin resets.

---

## features

**Purpose**: Logical groupings of protected resources, aligned to a module (SILIN, DOS, SOCIA, IAM).

| Field | Type | Business Meaning |
|-------|------|-----------------|
| `modulo` | modulo | Which integration module owns this feature |
| `criticidad` | criticidad | Severity if feature is unavailable |
| `estado` | feature_estado | activo/beta/deprecated |

**Business Rules**: Feature names are unique per module. Deprecating a feature should not break existing entitlements.

---

## protected_resources

**Purpose**: Granular inventory of every activatable element — the unit of access control.

| Field | Type | Business Meaning |
|-------|------|-----------------|
| `codigo` | VARCHAR(20) UK | Immutable business code (LIQ-001). NEVER rename after creation |
| `tipo` | pr_tipo | button, endpoint, view, or action |
| `feature_id` | UUID FK nullable | NULL = orphan (code deployed but not yet inventoried) |
| `dependencias` | TEXT[] | Other PR codes that must be ON for this to function |
| `estado` | pr_estado | huerfano until grouped; activo when in a plan |

**Business Rules**: `codigo` is immutable. Changing it breaks all feature_flags and entitlements. Orphan resources must be grouped by a manager before they appear in plans.

---

## products

**Purpose**: Commercial product bundle (e.g. JikkoOps Básico). Groups features for plan assignment.

**Business Rules**: Soft-delete via estado='deprecated'. Do not hard-delete products with active plans.

---

## plans

**Purpose**: Commercial offerings with pricing, limits, and feature access.

| Field | Type | Business Meaning |
|-------|------|-----------------|
| `usuario_limite` | INT nullable | NULL = unlimited |
| `expediente_limite_mes` | INT nullable | NULL = unlimited |
| `precio_fijo` | NUMERIC(15,2) nullable | Fixed monthly fee; NULL for usage-based |
| `modelo_revenue_default` | JSONB | Default revenue model for new contracts |

**Business Rules**: Deprecated plans retain FK refs from existing contracts. New contracts cannot use deprecated plans.

---

## revenue_model_configs

**Purpose**: Named, reusable revenue model templates. CFO configures; contracts reference.

| Field | Type | Business Meaning |
|-------|------|-----------------|
| `tipo` | revenue_model_tipo | CAUTE, PERCENTAGE_REVENUE, PER_USER, PER_EXPEDIENT, CAUTE_THEN_PERCENTAGE, USERS_AND_EXPEDIENTS, TIERED |
| `parametros` | JSONB | Model-specific parameters (thresholds, rates, tiers) |

**Business Rules**: **NEVER modify an active config in place.** Create a new config and update the contract reference. Changes to active configs affect billing retroactively.

---

## contracts

**Purpose**: Formalizes the commercial agreement: plan, term, revenue model, and pricing limits.

| Field | Type | Business Meaning |
|-------|------|-----------------|
| `numero` | VARCHAR UK | Human-readable ID: CONTRATO-{YYYY}-{SLUG}-{SEQ} |
| `revenue_model_id` | UUID FK | Points to the revenue_model_configs in use |
| `limite_expedientes` | INT | Monthly threshold for caute escalado |
| `porcentaje_recaudo` | NUMERIC(5,4) | Revenue share: 0.1000 = 10% |
| `escalado_tipo` | VARCHAR | Set when model auto-transitions (e.g. caute → percentage) |

**Business Rules**: Revenue calculations require CFO + legal approval to change. `fecha_vencimiento > fecha_inicio`.

---

## tenant_entitlements

**Purpose**: What each tenant has contractually activated. Drives feature_flags creation.

**Business Rules**: Exactly one of `feature_id` or `protected_resource_id` must be set (enforced by CHECK constraint). Time-bounded entitlements set `fecha_vencimiento`.

---

## feature_flags

**Purpose**: Runtime ON/OFF state per tenant per protected resource. Checked on every authenticated request.

| Field | Type | Business Meaning |
|-------|------|-----------------|
| `codigo_recurso` | VARCHAR | Denormalized PR code for fast indexed lookup |
| `activo` | BOOLEAN | Current state. Redis cache (TTL 5 min) mirrors this |
| `razon` | TEXT | Required for audit compliance on every change |

**Business Rules**: **NEVER edit directly in DB.** Use JikkoOps UI or admin API only. Every change must produce a row in `feature_flag_audit`.

**Typical Queries**: `SELECT activo FROM feature_flags WHERE tenant_id=$1 AND codigo_recurso=$2`.

---

## feature_flag_audit

**Purpose**: Immutable log of every flag state change (manual or automatic).

**Business Rules**: INSERT-ONLY. Application must prevent UPDATE/DELETE via RLS. `activado_por` = user UUID or literal 'system'.

---

## invoices

**Purpose**: Monthly billing documents sent to tenants.

| Field | Type | Business Meaning |
|-------|------|-----------------|
| `numero_factura` | VARCHAR UK | Format: FACT-{YYYY}-{MM}-{SLUG} |
| `estado` | invoice_estado | borrador → emitida → pagada/vencida/anulada |
| `total` | NUMERIC(15,2) | Cached aggregate of invoice_lines |

**Business Rules**: Totals must match sum of invoice_lines. Anulada invoices cannot be reopened.

---

## invoice_lines

**Purpose**: Individual line items composing an invoice. Enables detailed querying and audit.

| Field | Type | Business Meaning |
|-------|------|-----------------|
| `origen` | invoice_line_origen | Source of this charge: expediente, usuarios, recaudo, fijo, minimo, descuento |
| `metadata` | JSONB | Source data used for calculation (for audit verification) |

**Business Rules**: `subtotal = cantidad × precio_unitario` (enforced by CHECK except for descuento lines).

---

## expedientes_sync

**Purpose**: Tracks expedients reported by SILIN, used for caute limit detection and per-expedient billing.

**Business Rules**: `(tenant_id, expediente_id_externo)` is unique — prevents double-counting from retry events.

**Typical Queries**: `SELECT COUNT(*) FROM expedientes_sync WHERE tenant_id=$1 AND DATE_TRUNC('month',fecha)=DATE_TRUNC('month',NOW())`.

---

## audit_log

**Purpose**: Immutable 7-year audit trail of all significant state changes. Fiscal compliance requirement.

| Field | Type | Business Meaning |
|-------|------|-----------------|
| `tabla_afectada` | VARCHAR | Which table changed |
| `registro_id` | UUID | Which row changed |
| `valores_anterior` | JSONB | Full row state before change (NULL for INSERTs) |
| `valores_nuevo` | JSONB | Full row state after change (NULL for DELETEs) |

**Business Rules**: INSERT-ONLY. Enforce via RLS. Archive rows >2 years to cold storage; retain 7 years minimum.

---

## sdk_metrics

**Purpose**: Performance and cost telemetry per protected resource invocation.

| Field | Type | Business Meaning |
|-------|------|-----------------|
| `resource_codigo` | VARCHAR | Denormalized PR code (e.g. LIQ-001) |
| `cost_usd` | NUMERIC(10,6) | tokens_used × per-token rate |
| `execution_time_ms` | INT | Latency for observability SLAs |

**Business Rules**: Partitioned by month (RANGE on timestamp). Monthly partitions must be pre-created. Retain 24 months online; archive older data.
