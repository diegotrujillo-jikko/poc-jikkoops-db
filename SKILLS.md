# SKILLS.md — poc-jikkoops-db

Claude Code skill reference for the JikkoOps control database. Use these when the task matches.

---

## Architecture quirks to keep in mind

- **Control DB only.** This repo is the central commercial source of truth (entities, tenants, plans, contracts, billing, audit). Per-tenant operational databases are separate (DB-per-tenant model — not in this repo).
- **`audit_log` is insert-only.** No UPDATE or DELETE ever. 7-year retention. Never add delete/purge controls or cascade deletes that touch it.
- **`protected_resources.codigo` is immutable.** Codes like `LIQ-001`, `DOC-003` are referenced by plans, tenants, flags, and external systems. Changing one is a breaking change.
- **Revenue calculation logic needs CFO + Legal sign-off.** Don't modify `planes` revenue model fields or billing views without approval.
- **Redis TTL 5 min.** `feature_flags` changes don't take effect instantly. Backend job replicates to Redis; UI should reflect this with a resync affordance.
- **Migrations are monotonically numbered** (`V{NNN}__description.sql`) and must be reversible. Never reuse numbers. Seed data goes in `seed/`, not migrations.

---

## Skill map by task

### Schema design / new tables
```
/everything-claude-code:postgres-patterns   → PostgreSQL idioms, constraint patterns
/everything-claude-code:database-migrations → migration file conventions, rollback strategy
/everything-claude-code:database-reviewer   → review DDL before committing
```
Safe additions: new tables, nullable columns with DEFAULT, indexes, views.
Requires approval: revenue logic, `audit_log` structure, `feature_flags` policies, junction PKs.

### Query optimization
```
/everything-claude-code:postgres-patterns    → index usage, EXPLAIN analysis
/everything-claude-code:performance-optimizer → slow query identification
/everything-claude-code:database-reviewer    → query review
```
Critical indexes already defined — know them before adding more:
- `idx_tenants_entity` → `tenants(entity_id)`
- `idx_contratos_tenant` → `contratos(tenant_id)`
- `idx_facturas_tenant_periodo` → `facturas(tenant_id, periodo_inicio, periodo_fin)`
- `idx_feature_flags_tenant_activo` → `feature_flags(tenant_id, activo)`
- `idx_recursos_protegidos_codigo` → `recursos_protegidos(codigo)` — high-frequency lookup

### Security review
```
/everything-claude-code:security-review    → RLS policies, privilege escalation, PII exposure
/everything-claude-code:database-reviewer  → injection-safe queries, access control
```
Sensitive surfaces: `audit_log`, `feature_flags` UPDATE policies, `usuarios_internos` auth fields, revenue model parameters.

### Code review (SQL / migrations)
```
/everything-claude-code:database-reviewer  → DDL/DML correctness, constraint completeness
/everything-claude-code:code-review        → migration file structure, idempotency
```

### Git & PR
```
/everything-claude-code:git-workflow
```
Commit prefixes: `feat(db):`, `fix(db):`, `refactor(db):`, `chore(db):`, `perf(db):`.
Never commit seed data inside migration files.

---

## Domain knowledge shortcuts

| Concept | Key constraint for DB work |
|---------|---------------------------|
| **Entidad** | `entidades` table — identified by NIT. Not the same as `tenants`. |
| **Tenant** | `tenants` table — one entidad → many tenants. Each has its own operational DB. |
| **Plan hierarchy** | `planes` → `funcionalidades` → `recursos_protegidos`. Codes are immutable once assigned. |
| **Derechos Tenant** | `derechos_tenant` — which funcionalidades/resources are active for a tenant, with activation date, optional expiry, approver. |
| **Feature Flags** | `feature_flags` table + Redis TTL 5 min. 4 types: plan-based, escalado automático, manual override, time-bounded. |
| **Revenue models** | 5 types on `planes`: CAUTE, PERCENTAGE_REVENUE, PER_USER, PER_EXPEDIENT, HÍBRIDO. Changes require CFO + Legal. |
| **Facturación state machine** | `facturas.estado`: borrador → emitida → pagada (terminal) / anulada (terminal) / vencida. Enforce via CHECK constraint — no backward transitions. |
| **Contrato estado flow** | borrador → en_revision → activo → vencido / cancelado. Only `activo` triggers flag activation. |
| **Audit trail** | Every state-changing action writes to `audit_log` with before/after JSONB, IP, reason. Also `feature_flag_audit` for per-flag history. |
| **Escalado automático** | Hourly job per tenant — compares expedientes vs `expediente_limite_mes`, auto-activates CAUTE flags. Never editable via UI. |

---

## Schema file map

| File | Tables covered |
|------|---------------|
| `schema/00-extensions.sql` | Extensions (uuid-ossp, pgcrypto, etc.) |
| `schema/01-entities.sql` | `entidades` |
| `schema/02-tenants.sql` | `tenants` |
| `schema/03-catalog.sql` | `productos`, `planes`, `funcionalidades`, `recursos_protegidos` |
| `schema/04-contracts.sql` | `contratos` |
| `schema/05-entitlements.sql` | `derechos_tenant`, `feature_flags` |
| `schema/06-billing.sql` | `facturas` |
| `schema/07-users-auth.sql` | `usuarios_internos`, auth tables |
| `schema/08-audit.sql` | `audit_log`, `feature_flag_audit` |
| `schema/09-views-indexes.sql` | Views and performance indexes |
| `migrations/` | Versioned changes (`V001__` onward) |
| `seed/` | Catalog seed data (plans, resources, etc.) |
