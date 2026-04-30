-- =============================================================================
-- Migration: V001__initial_schema
-- Description: Initial JikkoOps control database schema (first approach)
-- Version: 0.1.0
-- Date: 2026-04-30
-- Author: JikkoOps Team
-- =============================================================================
-- This migration runs all schema files in dependency order to bootstrap
-- a fresh JikkoOps control database. To run from psql in repo root:
--
--   psql -d jikkoops_control -f migrations/V001__initial_schema.sql
--
-- For Alembic (Python), this file's contents should be wrapped into the
-- corresponding `alembic revision --autogenerate` migration scripts.
-- =============================================================================

\echo '=== JikkoOps Schema V001 — Initial Setup ==='

\echo '--> Step 1/9: Extensions and ENUMs'
\i schema/00-extensions.sql

\echo '--> Step 2/9: Entities'
\i schema/01-entities.sql

\echo '--> Step 3/9: Tenants'
\i schema/02-tenants.sql

\echo '--> Step 4/9: Catalog (features, protected_resources, products, plans)'
\i schema/03-catalog.sql

\echo '--> Step 5/9: Revenue models and contracts'
\i schema/04-contracts.sql

\echo '--> Step 6/9: Tenant entitlements and feature flags'
\i schema/05-entitlements.sql

\echo '--> Step 7/9: Billing (invoices, lines, expedient sync)'
\i schema/06-billing.sql

\echo '--> Step 8/9: Users, roles, MFA'
\i schema/07-users-auth.sql

\echo '--> Step 9/9: Audit log and SDK metrics'
\i schema/08-audit.sql

\echo '--> Indexes and reporting views'
\i schema/09-views-indexes.sql

\echo '=== Schema V001 applied successfully ==='
