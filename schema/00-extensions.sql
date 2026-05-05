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

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'entity_tipo') THEN
        CREATE TYPE entity_tipo AS ENUM (
            'municipio',
            'gobernacion',
            'dian',
            'otro'
        );
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'entity_estado') THEN
        CREATE TYPE entity_estado AS ENUM (
            'activo',
            'inactivo',
            'cancelado'
        );
    END IF;
END $$;

-- ---------------------------------------------------------------------------
-- Tenant ENUMs
-- ---------------------------------------------------------------------------

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'tenant_estado') THEN
        CREATE TYPE tenant_estado AS ENUM (
            'activo',
            'inactivo',
            'en_prueba',
            'suspendido'
        );
    END IF;
END $$;

-- ---------------------------------------------------------------------------
-- Contract ENUMs
-- ---------------------------------------------------------------------------

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'contract_tipo') THEN
        CREATE TYPE contract_tipo AS ENUM (
            'principal',
            'renovacion',
            'enmienda'
        );
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'contract_estado') THEN
        CREATE TYPE contract_estado AS ENUM (
            'borrador',
            'en_revision',
            'activo',
            'vencido',
            'cancelado'
        );
    END IF;
END $$;

-- ---------------------------------------------------------------------------
-- Plan / Feature / Protected Resource ENUMs
-- ---------------------------------------------------------------------------

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'plan_estado') THEN
        CREATE TYPE plan_estado AS ENUM (
            'activo',
            'deprecated'
        );
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'feature_estado') THEN
        CREATE TYPE feature_estado AS ENUM (
            'activo',
            'beta',
            'deprecated'
        );
    END IF;
END $$;

-- pr = protected resource
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'pr_tipo') THEN
        CREATE TYPE pr_tipo AS ENUM (
            'button',
            'endpoint',
            'view',
            'action'
        );
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'pr_estado') THEN
        CREATE TYPE pr_estado AS ENUM (
            'activo',
            'huerfano',   -- created in code but not yet grouped into a feature
            'deprecated'
        );
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'criticidad') THEN
        CREATE TYPE criticidad AS ENUM (
            'critica',
            'alta',
            'media',
            'baja'
        );
    END IF;
END $$;

-- Modules that own protected resources
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'modulo') THEN
        CREATE TYPE modulo AS ENUM (
            'SILIN',   -- Liquidación
            'DOS',     -- Documentos
            'SOCIA',   -- Servicio al Ciudadano
            'IAM'      -- Identity & Access Management
        );
    END IF;
END $$;

-- ---------------------------------------------------------------------------
-- Entitlement / Feature Flag ENUMs
-- ---------------------------------------------------------------------------

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'entitlement_estado') THEN
        CREATE TYPE entitlement_estado AS ENUM (
            'activo',
            'inactivo'
        );
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'flag_accion') THEN
        CREATE TYPE flag_accion AS ENUM (
            'activado',
            'desactivado',
            'actualizado'
        );
    END IF;
END $$;

-- ---------------------------------------------------------------------------
-- Billing ENUMs
-- ---------------------------------------------------------------------------

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'invoice_estado') THEN
        CREATE TYPE invoice_estado AS ENUM (
            'borrador',
            'emitida',
            'pagada',
            'vencida',
            'anulada'
        );
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'invoice_line_origen') THEN
        CREATE TYPE invoice_line_origen AS ENUM (
            'expediente',   -- charged per expedient processed
            'usuarios',     -- charged per active user
            'recaudo',      -- charged as % of revenue collected
            'fijo',         -- fixed fee line
            'minimo',       -- minimum charge applied
            'descuento'     -- discount line (negative amount)
        );
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'forma_pago') THEN
        CREATE TYPE forma_pago AS ENUM (
            'transferencia',
            'tdc',
            'debito'
        );
    END IF;
END $$;

-- ---------------------------------------------------------------------------
-- Revenue Model ENUMs
-- ---------------------------------------------------------------------------

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'revenue_model_tipo') THEN
        CREATE TYPE revenue_model_tipo AS ENUM (
            'CAUTE',                   -- free up to N expedients, then charge
            'PERCENTAGE_REVENUE',      -- % of revenue collected
            'PER_USER',                -- fixed price per active user/month
            'PER_EXPEDIENT',           -- fixed price per expedient processed
            'CAUTE_THEN_PERCENTAGE',   -- hybrid: caute period then % revenue
            'USERS_AND_EXPEDIENTS',    -- hybrid: users (fixed) + expedients above threshold
            'TIERED'                   -- tiered pricing by volume bands
        );
    END IF;
END $$;

-- ---------------------------------------------------------------------------
-- Audit ENUMs
-- ---------------------------------------------------------------------------

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'audit_operacion') THEN
        CREATE TYPE audit_operacion AS ENUM (
            'INSERT',
            'UPDATE',
            'DELETE'
        );
    END IF;
END $$;

-- ---------------------------------------------------------------------------
-- User ENUMs
-- ---------------------------------------------------------------------------

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'user_estado') THEN
        CREATE TYPE user_estado AS ENUM (
            'activo',
            'inactivo',
            'bloqueado'
        );
    END IF;
END $$;

-- ---------------------------------------------------------------------------
-- Expedient ENUMs
-- ---------------------------------------------------------------------------

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'expediente_estado') THEN
        CREATE TYPE expediente_estado AS ENUM (
            'procesado',
            'liquidado',
            'anulado'
        );
    END IF;
END $$;
