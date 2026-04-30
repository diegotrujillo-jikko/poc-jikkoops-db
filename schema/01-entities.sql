-- =============================================================================
-- JikkoOps Control Database - Entities (Physical Clients)
-- =============================================================================

-- Reusable trigger function to auto-update updated_at on every table.
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ---------------------------------------------------------------------------
-- Table: entities
-- Top-level commercial entity. Each entity can own multiple tenants.
-- ---------------------------------------------------------------------------
CREATE TABLE entities (
    id         UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
    nombre     VARCHAR(255)  NOT NULL,
    nit        VARCHAR(20)   NOT NULL UNIQUE,   -- Colombian tax ID
    tipo       entity_tipo   NOT NULL,
    region     VARCHAR(100),                    -- Departamento
    email      VARCHAR(255),
    telefono   VARCHAR(20),
    direccion  TEXT,
    estado     entity_estado NOT NULL DEFAULT 'activo',
    -- Expected keys: {"sigia_id": "...", "codigo_dane": "05001"}
    metadata   JSONB         NOT NULL DEFAULT '{}',
    created_at TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE  entities           IS 'Physical public-sector clients (municipios, gobernaciones) that contract JikkoOps.';
COMMENT ON COLUMN entities.nit       IS 'Colombian tax identification number. Unique per entity.';
COMMENT ON COLUMN entities.metadata  IS 'Flexible extra data. Expected keys: sigia_id, codigo_dane.';

CREATE TRIGGER trg_entities_updated_at
    BEFORE UPDATE ON entities
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
