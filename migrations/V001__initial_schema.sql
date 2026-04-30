-- =============================================================================
-- Migration: V001__initial_schema
-- Description: Initial JikkoOps control database schema
-- Version: 1.0.0
-- Date: 2026-04-30
-- Author: JikkoOps Team
-- =============================================================================
-- Run order matters — ENUMs must exist before tables that reference them,
-- and tables with FKs must come after their referenced tables.
-- =============================================================================

\i schema/00-extensions.sql
\i schema/01-entities.sql
\i schema/07-users-auth.sql
\i schema/03-catalog.sql
\i schema/02-tenants.sql
\i schema/04-contracts.sql
\i schema/05-entitlements.sql
\i schema/06-billing.sql
\i schema/08-audit.sql
\i schema/09-views-indexes.sql
