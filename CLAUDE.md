# CLAUDE.md — JikkoOps Control Database

This file provides guidance to Claude Code when working in this repository.

## What This Repo Is

PostgreSQL schema for the **JikkoOps central control database** (v0.1, first approach).

This is **not** a tenant operational database. It manages:
- Commercial catalog (products, plans, features, protected resources)
- Tenant instances and their feature flag states
- Contracts, revenue models, and billing
- Users, MFA, and RBAC
- Immutable audit log (7-year retention)

## Read These First

Before making any changes, read in this order:

1. `docs/ERD.md` — understand all 20 tables and their relationships
2. `schema/04-contracts.sql` — revenue model structures
3. `schema/05-entitlements.sql` — feature flag design
4. `docs/DICCIONARIO.md` — business rules per table
5. [poc-jikkoops-docs](https://github.com/diegotrujillo-jikko/poc-jikkoops-docs) — full business context

## Safe vs Unsafe Changes

### Safe to change freely
- Adding new ENUM values (append-only, never remove)
- Adding nullable columns to existing tables (`ALTER TABLE ... ADD COLUMN ... NULL`)
- Adding new indexes
- Adding new views
- Creating new tables
- Updating seed data descriptions

### Requires approval before changing
| Change | Required Approver |
|--------|------------------|
| Revenue model calculation logic | CFO + Lead Dev |
| `protected_resources.codigo` values | Architecture review |
| Audit log schema or retention policy | Legal + CTO |
| `contracts` pricing columns | CFO |
| MFA credential schema | Security lead |
| Removing or renaming any column | Architecture review |
| Changing CHECK constraints on billing tables | CFO + Lead Dev |

### NEVER do without explicit instruction
- Remove or rename `protected_resources.codigo` values
- Modify the `audit_log` table to allow UPDATE/DELETE
- Decrypt or log `tenants.db_connection_string` or `mfa_credentials.secret`
- Drop any table that has live FK references
- Remove ENUM values (PostgreSQL requires table rewrite; breaks existing rows)

## Migration Conventions

This project uses Alembic for Python-based migrations.

```
Naming:  V{NNN}__{description_with_underscores}.sql
Example: V002__add_contacts_table.sql
         V003__add_caute_escalado_tracking.sql
```

Every migration must:
1. Include a header comment: version, description, date, author
2. Be **reversible** — include a downgrade section or note why it's not possible
3. Be tested on a copy of staging data before applying to production
4. Update `docs/ERD.md` and `docs/DICCIONARIO.md` if schema changes

## Revenue Model Changes — Testing Requirements

Revenue model changes are the **highest-risk** changes in this codebase.

Before any change to `revenue_model_configs`, `contracts`, or invoice calculation logic:

1. Run all existing revenue calculation test cases (see `tests/` when created)
2. Manually verify: CAUTE threshold, CAUTE_THEN_PERCENTAGE transition, TIERED band calculation
3. Get CFO sign-off on the change
4. Verify no active contracts reference the config being modified

Use cases to always test:
- CU-001: Caute contract — month below limit = $0
- CU-002: Caute contract — month above limit = correct charge
- CU-003: Caute → Percentage transition on escalado
- CU-004: TIERED model — expedients spanning multiple bands
- CU-005: PER_USER with user count change mid-month

## Immutable Tables

These tables must remain INSERT-ONLY at the application level:

- `audit_log` — Enforce via PostgreSQL RLS (see comment in `08-audit.sql`)
- `feature_flag_audit` — Enforce at application layer

**Do NOT add UPDATE or DELETE permissions for the app role on these tables.**

## Protected Resource Codes

Codes like `LIQ-001`, `DOC-003`, `SOC-001` are **immutable business identifiers**.

- Never rename them after first deployment
- Never reuse a code for a different resource
- Deprecate by setting `estado = 'deprecated'`, not by deleting the row

Breaking a code breaks every feature_flag and tenant_entitlement that references it.

## Partitioned Tables

`sdk_metrics` is partitioned by month (RANGE on timestamp).

- Monthly partitions must be created in advance (or via pg_partman)
- The default partition `sdk_metrics_default` catches overflow — monitor its size
- See `docs/PARTITIONS.md` (to be created) for management runbook

## Sensitive Data

| Column | Classification | Rule |
|--------|---------------|------|
| `tenants.db_connection_string` | Secret | Encrypted at rest. Never log or expose in API |
| `mfa_credentials.secret` | Secret | AES-256-GCM. App layer only |
| `mfa_credentials.backup_codes` | Secret | AES-256-GCM. App layer only |
| `users.password_hash` | Sensitive | bcrypt ≥12. Never log plaintext |
| `entities.nit` | PII | Fiscal ID. Mask in non-prod environments |
