# poc-jikkoops-db

> **Status**: 🟡 v0.1 — Primer enfoque (first approach). Evolutivo. NO es la versión final.
>
> Este esquema seguirá evolucionando según especificaciones del área de Producto y CEO.

Esquema PostgreSQL de la **base de datos central de control** de JikkoOps — el back-office comercial del ecosistema SIGIA para municipios, gobernaciones y entidades públicas colombianas.

## ¿Qué es este repo?

Este repositorio contiene el **modelo de datos de la BD central** de JikkoOps:
- Tablas, ENUMs, índices y vistas (PostgreSQL 15+)
- Migraciones (estilo Alembic)
- Seed data inicial del catálogo
- Documentación: ERD + diccionario de datos

**No** contiene la BD operativa por tenant (cada tenant tiene su propia BD aislada — ver decisión arquitectural #1 en [poc-jikkoops-docs](https://github.com/diegotrujillo-jikko/poc-jikkoops-docs)).

## Arquitectura: Control DB vs Tenant DBs

```
                    ┌──────────────────────────┐
                    │  poc-jikkoops-db         │
                    │  (Control Database)      │
                    │                          │
                    │  - entities, tenants     │
                    │  - plans, contracts      │
                    │  - feature_flags         │
                    │  - invoices, audit_log   │
                    └──────────┬───────────────┘
                               │
              ┌────────────────┼────────────────┐
              ↓                ↓                ↓
    ┌─────────────────┐ ┌─────────────────┐ ┌──────────────┐
    │ tenant_cali_db  │ │ tenant_medellin │ │ tenant_*_db  │
    │  (operacional)  │ │      _db        │ │              │
    │                 │ │                 │ │              │
    │ - liquidaciones │ │ - liquidaciones │ │ - ...        │
    │ - expedientes   │ │ - expedientes   │ │              │
    │ - documentos    │ │ - documentos    │ │              │
    └─────────────────┘ └─────────────────┘ └──────────────┘
```

Esta BD (la central) es la **fuente de verdad comercial**: quién contrató qué, qué tiene activado, cuánto se le factura. Las BDs de tenant manejan los datos operativos del día a día.

## Stack

- **PostgreSQL** ≥ 15 (usa `gen_random_uuid()`, `INET`, JSONB, partitioning)
- **Extensiones**: `uuid-ossp`, `pgcrypto`, `btree_gist`
- **Migraciones**: estilo Alembic (Python) o Flyway (esquema versionado)
- **Encriptación**: AES-256-GCM en capa de aplicación para `db_connection_string`, `mfa_credentials.secret`, `mfa_credentials.backup_codes`

## Estructura del repo

```
poc-jikkoops-db/
├── schema/
│   ├── 00-extensions.sql       # Extensiones + ENUMs
│   ├── 01-entities.sql         # Clientes físicos
│   ├── 02-tenants.sql          # Instancias JikkoOps
│   ├── 03-catalog.sql          # Productos, planes, features, recursos
│   ├── 04-contracts.sql        # Modelos de revenue + contratos
│   ├── 05-entitlements.sql     # Derechos + feature flags + audit
│   ├── 06-billing.sql          # Facturas + líneas + sync expedientes
│   ├── 07-users-auth.sql       # Usuarios, roles, MFA
│   ├── 08-audit.sql            # Audit log + métricas SDK
│   └── 09-views-indexes.sql    # Índices + vistas
├── migrations/
│   └── V001__initial_schema.sql # Migración inicial (orquesta todos los .sql)
├── seed/
│   └── 001-catalog-seed.sql    # Catálogo inicial: features, PRs, planes, roles
├── docs/
│   ├── ERD.md                  # Diagrama Entidad-Relación (Mermaid)
│   └── DICCIONARIO.md          # Diccionario de datos (por tabla)
├── CLAUDE.md                   # Guía para Claude Code
└── README.md                   # Este archivo
```

## Quick Start

### 1. Crear BD vacía

```bash
createdb jikkoops_control
```

### 2. Aplicar el esquema inicial

```bash
psql -d jikkoops_control -f migrations/V001__initial_schema.sql
```

### 3. Cargar el catálogo seed

```bash
psql -d jikkoops_control -f seed/001-catalog-seed.sql
```

### 4. Verificar

```sql
-- Listar tablas creadas
\dt

-- Ver el catálogo seed
SELECT codigo, nombre, modulo, estado FROM protected_resources ORDER BY codigo;

-- Ver vistas disponibles
\dv
```

## Conceptos clave

### Protected Resources

Cada botón, endpoint, vista, y acción del sistema es un "Protected Resource" con código único (`LIQ-001`, `DOC-003`, etc.). Permite:
- Modularización comercial (vender features granulares)
- Control runtime ON/OFF por tenant (feature flags)
- Auditoría exacta de qué tiene cada cliente

### Plans + Contracts + Tenant Entitlements

- **Plan**: oferta comercial (Plan Básico, Plan Estándar, Plan Premium)
- **Contract**: instancia firmada con un tenant específico
- **Tenant Entitlement**: derechos otorgados (origen del flag)
- **Feature Flag**: estado runtime ON/OFF (con caché Redis)

### Revenue Models

7 tipos soportados, configurables vía JSON: `CAUTE`, `PERCENTAGE_REVENUE`, `PER_USER`, `PER_EXPEDIENT`, `CAUTE_THEN_PERCENTAGE`, `USERS_AND_EXPEDIENTS`, `TIERED`.

## Decisiones arquitecturales heredadas

(De [poc-jikkoops-docs/06-riesgos-decisiones/02-decisiones-arquitecturales.md](https://github.com/diegotrujillo-jikko/poc-jikkoops-docs/blob/main/06-riesgos-decisiones/02-decisiones-arquitecturales.md))

1. **DB-per-tenant** para datos operativos (esta BD es central, sólo de control).
2. **Feature flags en BD** (no en JWT) — control dinámico, auditable.
3. **PostgreSQL** (no NoSQL) — ACID + JOINs + JSON cuando hace falta.
4. **Audit log insert-only** — retención 7 años por requerimiento fiscal.
5. **Revenue models como JSON config** — el CFO puede ajustar sin code deploy.

## Reglas de cambio

🚫 **NO modificar sin aprobación**:
- Cálculos de revenue (CFO + Legal).
- Códigos de protected_resources existentes.
- Estructura de `audit_log` (insert-only por diseño).

✅ **Seguro modificar**:
- Agregar nuevas tablas para nuevos módulos.
- Agregar columnas con `DEFAULT NULL`.
- Crear nuevas vistas.
- Ajustar índices.

Toda modificación al esquema debe pasar por nueva migración versionada (`V002__...`, `V003__...`).

## Roadmap (no exhaustivo)

- [ ] Particionamiento de `audit_log`, `sdk_metrics`, `expedientes_sync`.
- [ ] Row-Level Security (RLS) en `audit_log` para enforcement insert-only.
- [ ] Triggers de captura automática para `audit_log` (vs cada UPDATE en código).
- [ ] Esquema de la BD operativa por tenant (separado, fuera de este repo).
- [ ] Procedimientos almacenados de cálculo de revenue (decisión: mantener en app por ahora).
- [ ] Integración con Alembic real (`alembic.ini`, `env.py`, `versions/`).

## Documentación complementaria

- 📘 [poc-jikkoops-docs](https://github.com/diegotrujillo-jikko/poc-jikkoops-docs) — Documentación funcional y arquitectural completa.
- 📊 `docs/ERD.md` — Diagrama Entidad-Relación.
- 📒 `docs/DICCIONARIO.md` — Diccionario de cada tabla.
- 🤖 `CLAUDE.md` — Guía para Claude Code en este repo.
