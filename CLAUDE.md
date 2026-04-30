# CLAUDE.md

Guidance for Claude Code (claude.ai/code) when working in this repo.

## What this repo is

`poc-jikkoops-db` — the **PostgreSQL control database** for JikkoOps. First approach (v0.1), designed to be **evolutive**. Schema will change as Product and CEO refine specs.

It is the central commercial source-of-truth: entities, tenants, plans, contracts, feature flags, invoices, audit log. It is **not** the per-tenant operational database (those live separately, one per tenant).

## Architecture context

Read [poc-jikkoops-docs](https://github.com/diegotrujillo-jikko/poc-jikkoops-docs) — especially:
- `01-arquitectura/01-vision-general.md`
- `03-datos/02-data-model.md`
- `03-datos/01-principios-base-datos.md`
- `06-riesgos-decisiones/02-decisiones-arquitecturales.md`

## Repo structure

```
schema/         # DDL files (run in numeric order)
migrations/     # Versioned schema changes (V001__, V002__, ...)
seed/           # Initial catalog data
docs/           # ERD + data dictionary
```

## 🚫 DO NOT change without approval

- **Revenue calculation logic** — needs CFO + Legal sign-off.
- **`protected_resources.codigo` values** — they're referenced by plans, tenants, flags, and external systems.
- **`audit_log` structure** — designed insert-only for compliance.
- **`feature_flags` UPDATE/DELETE policies** — runtime depends on consistency.
- **Junction PKs** — they're referenced by app-layer code.

## ✅ Safe to change

- Add new tables for new modules.
- Add nullable columns to existing tables (with safe DEFAULT).
- Add indexes (after EXPLAIN-validating they help).
- Add views.
- Add seed data for new features.

## Migration conventions

1. Every schema change is a new file in `migrations/V{NNN}__{description}.sql`.
2. Numbering is monotonically increasing — never reuse numbers.
3. The migration must be **reversible**:
   - Either via Alembic `downgrade()` (when wired to Alembic).
   - Or via a paired `migrations/V{NNN}__{description}_DOWN.sql`.
4. Migrations should be idempotent where possible (`IF NOT EXISTS`).
5. Migrations must NOT contain seed data — seed lives in `seed/`.

### Conventional commit prefixes for DB changes

- `feat(db):` new table or significant column.
- `fix(db):` bug fix in constraint, index, default value.
- `refactor(db):` rename, cleanup without behavior change.
- `chore(db):` documentation, comments, formatting.
- `perf(db):` index additions, partition tweaks.

## Testing requirements

Before merging any schema change:

- [ ] Migration applies cleanly to a fresh DB (`createdb test_db && psql -f migration`).
- [ ] Migration applies cleanly on top of `V001` (forward compatibility).
- [ ] All existing seed data loads successfully.
- [ ] All existing views still work.
- [ ] If revenue/billing-adjacent: add SQL tests covering edge cases.
- [ ] If touching `audit_log`: confirm insert-only invariants still hold.

## Key files to read before changes

| Topic | Read |
|-------|------|
| Adding a new module | `schema/03-catalog.sql`, `seed/001-catalog-seed.sql` |
| Revenue model change | `schema/04-contracts.sql`, `docs/DICCIONARIO.md` (#7, #8) |
| New protected resource | `schema/03-catalog.sql`, `seed/001-catalog-seed.sql` |
| Feature flag mechanics | `schema/05-entitlements.sql`, related doc in `poc-jikkoops-docs` |
| Audit-related work | `schema/08-audit.sql`, `docs/DICCIONARIO.md` (#18) |

## Encryption notes

These columns hold sensitive data and **MUST be encrypted at rest** by the application layer (AES-256-GCM):

- `tenants.db_connection_string`
- `mfa_credentials.secret`
- `mfa_credentials.backup_codes`

Never store plaintext in these columns. The DB has no in-built protection — it's the app's responsibility.

## Common tasks

### Add a new protected resource

1. Insert into `protected_resources` via seed or migration (use next code in module sequence: `LIQ-005`, `DOC-004`, etc.).
2. Link to feature via `feature_protected_resources`.
3. Add to relevant plans via `plan_protected_resources` if granular.
4. Resync feature_flags for affected tenants (handled by app job).

### Change a revenue model

1. **DO NOT** modify existing `revenue_model_configs` rows in production — create a new row.
2. Mark old row `activo = false`.
3. Update affected `contracts.revenue_model_id` only after CFO approval + audit_log entry.

### Add a new tenant

1. Insert `entities` row (if entity new).
2. Insert `tenants` row with `estado = 'en_prueba'`.
3. Provision per-tenant operational DB (out of scope for this repo).
4. Activate via UI/API — system creates `contracts`, `tenant_entitlements`, `feature_flags`.

## Conventions

- **camelCase** for SQL identifiers? **NO** — use `snake_case` (PostgreSQL convention).
- **Naming**:
  - Tables: plural (`entities`, `tenants`).
  - Junctions: `{singular}_{singular_plural}` (`plan_features`, `feature_protected_resources`).
  - Indexes: `idx_{table}_{cols}`.
  - Triggers: `trg_{table}_{event}`.
  - Views: `v_{purpose}`.
- **Money**: `NUMERIC(15,2)` (Colombian Pesos, two decimals).
- **Percentages**: `NUMERIC(5,4)` stored as fraction (`0.1000` = 10%).
- **Timestamps**: always `TIMESTAMPTZ`, never `TIMESTAMP`.
- **PKs**: always `UUID DEFAULT gen_random_uuid()`.

## When in doubt

Default to writing a **new migration** rather than editing an existing one. Migration files are immutable once merged.

For ambiguous changes (does this affect revenue? is this a breaking change?), pause and confirm with the user before generating SQL.
