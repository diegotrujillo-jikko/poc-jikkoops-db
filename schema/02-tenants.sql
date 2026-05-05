-- =============================================================================
-- JikkoOps Control Database - Tenants
-- =============================================================================
-- A tenant is one JikkoOps instance for an entity. One entity can have
-- multiple tenants (e.g., different environments or sub-organizations).
-- Each tenant has its OWN isolated PostgreSQL database for operational data.
-- =============================================================================

CREATE TABLE tenants (
    id                      UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
    entity_id               UUID          NOT NULL REFERENCES entities(id) ON DELETE RESTRICT,
    nombre_tecnico          VARCHAR(100)  NOT NULL UNIQUE,  -- e.g. 'municipio_cali'

    -- Connection to this tenant's isolated operational DB.
    -- MUST be encrypted at rest (AES-256-GCM) before storage.
    db_connection_string    TEXT,

    region                  VARCHAR(100),
    -- FK to plans is added at the end of 03-catalog.sql (forward reference resolved there)
    plan_id                 UUID,

    -- Commercial limits from active contract
    usuarios_limite         INT,
    expedientes_mes_limite  INT,

    estado                  tenant_estado NOT NULL DEFAULT 'en_prueba',
    fecha_activacion        DATE,
    fecha_vencimiento       DATE,

    -- Technical config: {"db_host": "...", "redis_namespace": "...", "timezone": "America/Bogota"}
    metadata                JSONB         NOT NULL DEFAULT '{}',

    created_at              TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ   NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_tenants_dates CHECK (
        fecha_vencimiento IS NULL OR fecha_vencimiento > fecha_activacion
    )
);

COMMENT ON TABLE  tenants                     IS 'JikkoOps instance per entity. Each tenant has an isolated DB and its own plan/flags.';
COMMENT ON COLUMN tenants.nombre_tecnico      IS 'Slug used as Redis namespace key prefix and tenant DB identifier.';
COMMENT ON COLUMN tenants.db_connection_string IS 'Connection DSN to tenant operational DB. Must be encrypted at rest.';
COMMENT ON COLUMN tenants.metadata            IS 'Technical config. Keys: db_host, redis_namespace, timezone.';

CREATE TRIGGER trg_tenants_updated_at
    BEFORE UPDATE ON tenants
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
