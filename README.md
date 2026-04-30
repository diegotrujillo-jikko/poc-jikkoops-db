# poc-jikkoops-db

**JikkoOps Control Database** — First-approach PostgreSQL schema for the JikkoOps back-office system.

> **Status**: v0.1 — First approach. Evolutive design. Will be refined as product specs are confirmed by the product area and CEO.

---

## What This Is

This repository contains the **central control database** schema for JikkoOps — a modular back-office system that enables Colombian municipalities, gobernaciones, and public entities to:

- Commercialize digital government services as configurable plans
- Control tenant access via Protected Resources and feature flags
- Monetize flexibly (caute, percentage revenue, per-user, per-expedient, hybrid)
- Integrate with SILIN (liquidation), DOS (documents), SOCIA (citizen services)
- Audit every revenue and access-control change for 7-year fiscal compliance

This is the **central** database only. Each tenant also has its own isolated operational database (managed by SILIN/DOS/SOCIA) — that schema is not in this repo.

---

## Architecture: Central DB vs Tenant DBs

```
JikkoOps Central DB (this repo)          Tenant Operational DB (per tenant)
─────────────────────────────────        ──────────────────────────────────
entities (clients)                       expedientes (domain data)
tenants (instances)                      liquidaciones
contracts (agreements)                   documentos
plans / products (catalog)               ciudadanos
feature_flags (access control)           (managed by SILIN/DOS/SOCIA)
invoices / billing
users / auth / MFA
audit_log (immutable)
sdk_metrics
```

The tenant's DB connection string is stored encrypted in `tenants.db_connection_string` and used by the API to route requests to the correct isolated database.

---

## Stack

| Component | Technology |
|-----------|-----------|
| Database | PostgreSQL 15+ |
| Migrations | Alembic (Python) |
| Schema Format | Plain SQL (`.sql` files) |
| Extensions | uuid-ossp, pgcrypto, btree_gist |

---

## Repository Structure

```
poc-jikkoops-db/
├── schema/
│   ├── 00-extensions.sql       # Extensions + all ENUM types (run first)
│   ├── 01-entities.sql         # entities table + set_updated_at() trigger fn
│   ├── 02-tenants.sql          # tenants table
│   ├── 03-catalog.sql          # features, protected_resources, products, plans, junctions
│   ├── 04-contracts.sql        # revenue_model_configs, contracts
│   ├── 05-entitlements.sql     # tenant_entitlements, feature_flags, feature_flag_audit
│   ├── 06-billing.sql          # invoices, invoice_lines, expedientes_sync
│   ├── 07-users-auth.sql       # users, roles, user_roles, mfa_credentials
│   ├── 08-audit.sql            # audit_log, sdk_metrics (partitioned)
│   └── 09-views-indexes.sql    # All indexes + 4 materialized views
│
├── migrations/
│   └── V001__initial_schema.sql  # Entry point: runs all schema files in order
│
├── seed/
│   └── 001-catalog-seed.sql    # Features, protected resources, products, plans
│
├── docs/
│   ├── ERD.md                  # Mermaid entity relationship diagram
│   └── DICCIONARIO.md          # Data dictionary for all 20 tables
│
├── CLAUDE.md                   # Guidance for Claude Code
└── README.md                   # This file
```

---

## Quick Start

### Prerequisites

- PostgreSQL 15+
- `psql` CLI

### Run Initial Migration

```bash
# Create the database
createdb jikkoops_control

# Run the full migration
psql -d jikkoops_control -f migrations/V001__initial_schema.sql

# Seed catalog data (features, resources, products, plans)
psql -d jikkoops_control -f seed/001-catalog-seed.sql
```

### With Alembic (Python)

```bash
pip install alembic psycopg2-binary

# Initialize alembic (if not already done)
alembic init alembic

# Configure alembic.ini with your DB URL
# sqlalchemy.url = postgresql://user:pass@localhost/jikkoops_control

# Generate and apply migration
alembic revision --autogenerate -m "initial schema"
alembic upgrade head
```

---

## Key Domain Concepts

### Protected Resources
Every button, endpoint, view, and action has a unique code (e.g. `LIQ-001`). These codes are **immutable** — never rename them after deployment.

### Feature Flags
Runtime ON/OFF state per tenant per resource. Checked on every authenticated request. Source of truth is the `feature_flags` table; Redis (TTL 5 min) is the cache layer.

### Revenue Models
Stored as JSON config in `revenue_model_configs`. Supported models: CAUTE, PERCENTAGE_REVENUE, PER_USER, PER_EXPEDIENT, CAUTE_THEN_PERCENTAGE, USERS_AND_EXPEDIENTS, TIERED.

### Audit Log
Insert-only table. 7-year retention required by Colombian fiscal law. Application enforces no UPDATE/DELETE via RLS.

---

## Full Documentation

See [poc-jikkoops-docs](https://github.com/diegotrujillo-jikko/poc-jikkoops-docs) for:
- Architecture overview
- Business processes and contract lifecycle
- API endpoints and integration events
- Risk matrix and architectural decisions

---

## Version

**v0.1** — First approach. Schema will evolve based on:
- Product area specifications
- CEO-approved revenue model updates
- Team tech stack confirmation (Python/FastAPI vs Node.js/NestJS)
- Load testing results (50M expedients/month target)

See `docs/ERD.md` for the full entity relationship diagram.
