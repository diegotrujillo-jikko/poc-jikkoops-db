-- =============================================================================
-- JikkoOps Control Database - Tenant Entitlements & Feature Flags
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Table: tenant_entitlements
-- Records what each tenant has been granted (feature or specific resource).
-- The source of truth for "what has been sold" vs feature_flags ("what is on").
-- ---------------------------------------------------------------------------
CREATE TABLE tenant_entitlements (
    id                    UUID                PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id             UUID                NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    -- Either feature_id OR protected_resource_id must be set, not both.
    feature_id            UUID                REFERENCES features(id) ON DELETE RESTRICT,
    protected_resource_id UUID                REFERENCES protected_resources(id) ON DELETE RESTRICT,
    estado                entitlement_estado  NOT NULL DEFAULT 'activo',
    fecha_activacion      DATE,
    fecha_vencimiento     DATE,               -- NULL = permanent
    motivo                VARCHAR(255),       -- e.g. 'renovacion anual', 'upgrade de plan'
    aprobado_por          UUID,               -- FK → users (set at app layer)
    created_at            TIMESTAMPTZ         NOT NULL DEFAULT NOW(),
    updated_at            TIMESTAMPTZ         NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_entitlement_scope CHECK (
        (feature_id IS NOT NULL AND protected_resource_id IS NULL)
        OR
        (feature_id IS NULL AND protected_resource_id IS NOT NULL)
    )
);

COMMENT ON TABLE  tenant_entitlements IS 'What each tenant has contractually been granted. Drives feature_flags sync.';
COMMENT ON COLUMN tenant_entitlements.feature_id IS 'Set when granting an entire feature. Mutually exclusive with protected_resource_id.';
COMMENT ON COLUMN tenant_entitlements.protected_resource_id IS 'Set for granular resource grants. Mutually exclusive with feature_id.';

CREATE TRIGGER trg_tenant_entitlements_updated_at
    BEFORE UPDATE ON tenant_entitlements
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ---------------------------------------------------------------------------
-- Table: feature_flags
-- Runtime ON/OFF state per tenant per protected resource.
-- Synced from entitlements every 5 minutes. Cached in Redis (TTL 5 min).
-- NEVER edit directly in DB — always use JikkoOps UI or API.
-- ---------------------------------------------------------------------------
CREATE TABLE feature_flags (
    id                    UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id             UUID        NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    protected_resource_id UUID        NOT NULL REFERENCES protected_resources(id) ON DELETE RESTRICT,
    -- Denormalized for fast WHERE queries without JOIN (e.g. Redis fallback lookups)
    codigo_recurso        VARCHAR(20) NOT NULL,
    activo                BOOLEAN     NOT NULL DEFAULT false,
    fecha_activacion      TIMESTAMPTZ,
    fecha_desactivacion   TIMESTAMPTZ,
    activado_por          UUID,       -- FK → users or NULL if system-automated
    razon                 TEXT,       -- e.g. 'renovacion anual', 'escalado automatico'
    -- Extra context: {"sync_source": "contract_activation", "contract_id": "..."}
    metadata              JSONB       NOT NULL DEFAULT '{}',
    created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    UNIQUE (tenant_id, protected_resource_id)
);

COMMENT ON TABLE  feature_flags               IS 'Runtime access control. ON/OFF per (tenant, resource). Cached Redis TTL 5min. Never edit directly.';
COMMENT ON COLUMN feature_flags.codigo_recurso IS 'Denormalized PR code for fast cache key lookups without JOIN.';

CREATE TRIGGER trg_feature_flags_updated_at
    BEFORE UPDATE ON feature_flags
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ---------------------------------------------------------------------------
-- Table: feature_flag_audit
-- Insert-only log of every flag change. Required for compliance.
-- ---------------------------------------------------------------------------
CREATE TABLE feature_flag_audit (
    id            UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    flag_id       UUID         NOT NULL REFERENCES feature_flags(id) ON DELETE RESTRICT,
    tenant_id     UUID         NOT NULL,
    accion        flag_accion  NOT NULL,
    codigo_recurso VARCHAR(20) NOT NULL,
    valor_anterior BOOLEAN,
    valor_nuevo   BOOLEAN     NOT NULL,
    activado_por  UUID,        -- user UUID or NULL for system
    razon         TEXT,
    -- {"contract_id": "...", "sync_job_id": "...", "ip": "..."}
    contexto      JSONB        NOT NULL DEFAULT '{}',
    timestamp     TIMESTAMPTZ  NOT NULL DEFAULT NOW()
    -- NO updated_at — this table is insert-only
);

COMMENT ON TABLE feature_flag_audit IS 'Immutable audit log for feature flag changes. Insert-only — never UPDATE or DELETE rows.';
