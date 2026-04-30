-- =============================================================================
-- JikkoOps Control Database - Extensions and Custom Types
-- =============================================================================
-- This file must be run first. Installs PostgreSQL extensions and defines
-- all custom ENUM types used throughout the schema.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Extensions
-- ---------------------------------------------------------------------------

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";   -- gen_random_uuid() fallback
CREATE EXTENSION IF NOT EXISTS "pgcrypto";    -- encrypt/decrypt, gen_random_uuid()
CREATE EXTENSION IF NOT EXISTS "btree_gist";  -- exclusion constraints on ranges

-- ---------------------------------------------------------------------------
-- Entity ENUMs
-- ---------------------------------------------------------------------------

CREATE TYPE entity_tipo AS ENUM (
    'municipio',
    'gobernacion',
    'dian',
    'otro'
);

CREATE TYPE entity_estado AS ENUM (
    'activo',
    'inactivo',
    'cancelado'
);

-- ---------------------------------------------------------------------------
-- Tenant ENUMs
-- ---------------------------------------------------------------------------

CREATE TYPE tenant_estado AS ENUM (
    'activo',
    'inactivo',
    'en_prueba',
    'suspendido'
);

-- ---------------------------------------------------------------------------
-- Contract ENUMs
-- ---------------------------------------------------------------------------

CREATE TYPE contract_tipo AS ENUM (
    'principal',
    'renovacion',
    'enmienda'
);

CREATE TYPE contract_estado AS ENUM (
    'borrador',
    'en_revision',
    'activo',
    'vencido',
    'cancelado'
);

-- ---------------------------------------------------------------------------
-- Plan / Feature / Protected Resource ENUMs
-- ---------------------------------------------------------------------------

CREATE TYPE plan_estado AS ENUM (
    'activo',
    'deprecated'
);

CREATE TYPE feature_estado AS ENUM (
    'activo',
    'beta',
    'deprecated'
);

-- pr = protected resource
CREATE TYPE pr_tipo AS ENUM (
    'button',
    'endpoint',
    'view',
    'action'
);

CREATE TYPE pr_estado AS ENUM (
    'activo',
    'huerfano',   -- created in code but not yet grouped into a feature
    'deprecated'
);

CREATE TYPE criticidad AS ENUM (
    'critica',
    'alta',
    'media',
    'baja'
);

-- Modules that own protected resources
CREATE TYPE modulo AS ENUM (
    'SILIN',   -- Liquidación
    'DOS',     -- Documentos
    'SOCIA',   -- Servicio al Ciudadano
    'IAM'      -- Identity & Access Management
);

-- ---------------------------------------------------------------------------
-- Entitlement / Feature Flag ENUMs
-- ---------------------------------------------------------------------------

CREATE TYPE entitlement_estado AS ENUM (
    'activo',
    'inactivo'
);

CREATE TYPE flag_accion AS ENUM (
    'activado',
    'desactivado',
    'actualizado'
);

-- ---------------------------------------------------------------------------
-- Billing ENUMs
-- ---------------------------------------------------------------------------

CREATE TYPE invoice_estado AS ENUM (
    'borrador',
    'emitida',
    'pagada',
    'vencida',
    'anulada'
);

CREATE TYPE invoice_line_origen AS ENUM (
    'expediente',   -- charged per expedient processed
    'usuarios',     -- charged per active user
    'recaudo',      -- charged as % of revenue collected
    'fijo',         -- fixed fee line
    'minimo',       -- minimum charge applied
    'descuento'     -- discount line (negative amount)
);

CREATE TYPE forma_pago AS ENUM (
    'transferencia',
    'tdc',
    'debito'
);

-- ---------------------------------------------------------------------------
-- Revenue Model ENUMs
-- ---------------------------------------------------------------------------

CREATE TYPE revenue_model_tipo AS ENUM (
    'CAUTE',                   -- free up to N expedients, then charge
    'PERCENTAGE_REVENUE',      -- % of revenue collected
    'PER_USER',                -- fixed price per active user/month
    'PER_EXPEDIENT',           -- fixed price per expedient processed
    'CAUTE_THEN_PERCENTAGE',   -- hybrid: caute period then % revenue
    'USERS_AND_EXPEDIENTS',    -- hybrid: users (fixed) + expedients above threshold
    'TIERED'                   -- tiered pricing by volume bands
);

-- ---------------------------------------------------------------------------
-- Audit ENUMs
-- ---------------------------------------------------------------------------

CREATE TYPE audit_operacion AS ENUM (
    'INSERT',
    'UPDATE',
    'DELETE'
);

-- ---------------------------------------------------------------------------
-- User ENUMs
-- ---------------------------------------------------------------------------

CREATE TYPE user_estado AS ENUM (
    'activo',
    'inactivo',
    'bloqueado'
);

-- ---------------------------------------------------------------------------
-- Expedient ENUMs
-- ---------------------------------------------------------------------------

CREATE TYPE expediente_estado AS ENUM (
    'procesado',
    'liquidado',
    'anulado'
);
