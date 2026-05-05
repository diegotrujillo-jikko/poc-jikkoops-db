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
│   ├── 001-catalog-seed.sql    # Catálogo inicial: features, PRs, planes, roles (PROD-safe)
│   └── dev-only/
│       └── 002-demo-tenants.sql # Datos demo: entidades, tenants, contratos (DEV ONLY)
├── docs/
│   ├── ERD.md                  # Diagrama Entidad-Relación (Mermaid)
│   └── DICCIONARIO.md          # Diccionario de datos (por tabla)
├── CLAUDE.md                   # Guía para Claude Code
└── README.md                   # Este archivo
```

## Quick Start

> ⚠️ **Importante**: Ejecuta los comandos **desde la raíz del repo** (`poc-jikkoops-db/`).
> El archivo `migrations/V001__initial_schema.sql` usa rutas relativas (`\i schema/00-extensions.sql`, etc.) que se resuelven contra el `cwd` de `psql`.
>
> ⚠️ **Orden obligatorio**: V001 → 001-catalog-seed → (opcional) 002-demo-tenants. El paso 002 referencia UUIDs creados por 001; si lo corres sin 001, la transacción se hace rollback completo y no verás registros.

### 1. Crear BD vacía

```bash
createdb jikkoops_control
```

### 2. Aplicar el esquema inicial

```bash
cd poc-jikkoops-db
psql -v ON_ERROR_STOP=1 --echo-errors -d jikkoops_control \
     -f migrations/V001__initial_schema.sql
```

Las flags `-v ON_ERROR_STOP=1 --echo-errors` aseguran que cualquier error aborte y se muestre en consola en vez de quedar enterrado.

### 3. Cargar el catálogo seed (datos de referencia, PROD-safe)

```bash
psql -v ON_ERROR_STOP=1 --echo-errors -d jikkoops_control \
     -f seed/001-catalog-seed.sql
```

Inserta: 3 features, 8 protected resources, 2 products, 3 plans, 7 revenue model configs, 4 roles. Estos datos son referencia del sistema y son seguros para producción.

### 4. (Opcional) Cargar datos demo — SOLO DESARROLLO

```bash
psql -v ON_ERROR_STOP=1 --echo-errors -d jikkoops_control \
     -f seed/dev-only/002-demo-tenants.sql
```

Inserta datos sintéticos para ejercitar el sistema end-to-end: 2 entities (Cali, Medellin), 2 tenants, 3 users, 2 contracts, entitlements, feature_flags, 250 expedientes, 1 invoice, sample audit_log y sdk_metrics.

🚫 **No ejecutar en producción.** El archivo tiene un guard `DO` que aborta si detecta entidades sin el prefijo UUID `aaaaaaaa-...`.

### 5. Verificar

```sql
-- Listar tablas creadas
\dt

-- Ver el catálogo seed
SELECT codigo, nombre, modulo, estado FROM protected_resources ORDER BY codigo;

-- Ver vistas disponibles
\dv

-- Si cargaste demo data: ver tenants demo
SELECT t.nombre_tecnico, t.estado, p.nombre AS plan
FROM tenants t JOIN plans p ON t.plan_id = p.id;
```

### Troubleshooting

| Error | Causa probable | Solución |
|-------|---------------|----------|
| `relation "entities" does not exist` | V001 no aplicado | Correr paso 2 |
| `violates foreign key constraint "tenants_plan_id_fkey"` | 001-catalog-seed no aplicado antes de 002 | Correr paso 3 antes de paso 4 |
| `Refusing to seed demo data: N non-demo entities` | Entidades reales pre-existentes | Limpiar BD o usar otro esquema |
| `duplicate key value violates unique constraint` | Re-ejecutaste 002 sin limpiar | Borrar filas demo (`WHERE id::TEXT LIKE 'aaaaaaaa-%'`) y reintentar |
| Cero registros, sin error visible | Corriste sin `-v ON_ERROR_STOP=1` y la transacción hizo rollback | Re-correr con la flag para ver el error real |

### Reset de datos demo (mantiene catálogo y datos reales)

```sql
BEGIN;
DELETE FROM audit_log           WHERE tenant_id::TEXT LIKE 'aaaaaaaa-%';
DELETE FROM sdk_metrics         WHERE tenant_id::TEXT LIKE 'aaaaaaaa-%';
DELETE FROM invoice_lines       WHERE invoice_id IN (SELECT id FROM invoices WHERE id::TEXT LIKE 'aaaaaaaa-%');
DELETE FROM invoices            WHERE id::TEXT LIKE 'aaaaaaaa-%';
DELETE FROM expedientes_sync    WHERE tenant_id::TEXT LIKE 'aaaaaaaa-%';
DELETE FROM feature_flags       WHERE tenant_id::TEXT LIKE 'aaaaaaaa-%';
DELETE FROM tenant_entitlements WHERE tenant_id::TEXT LIKE 'aaaaaaaa-%';
DELETE FROM contracts           WHERE id::TEXT LIKE 'aaaaaaaa-%';
DELETE FROM mfa_credentials     WHERE id::TEXT LIKE 'aaaaaaaa-%';
DELETE FROM user_roles          WHERE user_id::TEXT LIKE 'aaaaaaaa-%';
DELETE FROM users               WHERE id::TEXT LIKE 'aaaaaaaa-%';
DELETE FROM tenants             WHERE id::TEXT LIKE 'aaaaaaaa-%';
DELETE FROM entities            WHERE id::TEXT LIKE 'aaaaaaaa-%';
COMMIT;
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
