-- =============================================================================
-- JikkoOps Control Database - Revenue Models & Contracts
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Table: revenue_model_configs
-- Reusable, named revenue model definitions. A contract references one.
-- ---------------------------------------------------------------------------
CREATE TABLE revenue_model_configs (
    id          UUID                PRIMARY KEY DEFAULT gen_random_uuid(),
    nombre      VARCHAR(255)        NOT NULL,
    tipo        revenue_model_tipo  NOT NULL,
    -- Validated at application layer. Keys by type:
    -- CAUTE:                  {"limite_expedientes": 1000, "precio_excedente": 50.00}
    -- PERCENTAGE_REVENUE:     {"porcentaje": 0.1000, "minimo_mensual": 50000.00}
    -- PER_USER:               {"precio_usuario": 2000.00}
    -- PER_EXPEDIENT:          {"precio_expediente": 50.00, "minimo_mensual": 10000.00}
    -- CAUTE_THEN_PERCENTAGE:  {"limite_expedientes": 5000, "meses_caute": 6, "porcentaje": 0.1000, "minimo_mensual": 50000.00}
    -- USERS_AND_EXPEDIENTS:   {"precio_usuario": 1000.00, "umbral_expedientes": 500, "precio_excedente": 100.00}
    -- TIERED:                 {"tramos": [{"hasta": 500, "precio": 0}, {"hasta": 1000, "precio": 50}, {"precio": 30}]}
    parametros  JSONB               NOT NULL DEFAULT '{}',
    activo      BOOLEAN             NOT NULL DEFAULT true,
    created_at  TIMESTAMPTZ         NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ         NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE  revenue_model_configs           IS 'Reusable revenue model templates. Contracts reference one of these.';
COMMENT ON COLUMN revenue_model_configs.parametros IS 'Model parameters. Structure validated at app layer — see column comment for keys by type.';

CREATE TRIGGER trg_revenue_model_configs_updated_at
    BEFORE UPDATE ON revenue_model_configs
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ---------------------------------------------------------------------------
-- Table: contracts
-- Formal service agreement between JikkoOps and a tenant.
-- Contains all commercial terms including the revenue model applied.
-- ---------------------------------------------------------------------------
CREATE TABLE contracts (
    id                       UUID                PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id                UUID                NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    plan_id                  UUID                REFERENCES plans(id) ON DELETE RESTRICT,
    revenue_model_id         UUID                REFERENCES revenue_model_configs(id) ON DELETE RESTRICT,
    numero                   VARCHAR(60)         NOT NULL UNIQUE,  -- e.g. 'CONTRATO-2026-CALI-001'

    -- Timeline
    fecha_firma              DATE,
    fecha_inicio             DATE,
    fecha_vencimiento        DATE,

    tipo_contrato            contract_tipo       NOT NULL DEFAULT 'principal',
    estado                   contract_estado     NOT NULL DEFAULT 'borrador',

    -- Revenue model snapshot values (denormalized for billing calculations)
    limite_expedientes       INT,               -- caute/per-expedient threshold
    porcentaje_recaudo       NUMERIC(5,4),      -- 0.1000 = 10%

    -- Escalation tracking (caute → percentage automatic upgrade)
    escalado_tipo            revenue_model_tipo,
    escalado_fecha           DATE,
    escalado_activado_por    UUID,              -- FK → users (set at app layer)

    valor_total_cop          NUMERIC(15,2),
    forma_pago               forma_pago,

    -- PDF stored externally (S3/GCS). This field holds the signed URL or object key.
    documento_pdf_ref        TEXT,

    created_at               TIMESTAMPTZ        NOT NULL DEFAULT NOW(),
    updated_at               TIMESTAMPTZ        NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_contracts_dates CHECK (
        fecha_vencimiento IS NULL OR fecha_vencimiento > fecha_inicio
    ),
    CONSTRAINT chk_porcentaje_range CHECK (
        porcentaje_recaudo IS NULL OR (porcentaje_recaudo > 0 AND porcentaje_recaudo <= 1)
    )
);

COMMENT ON TABLE  contracts                    IS 'Service agreement between JikkoOps and a tenant. Source of truth for commercial terms.';
COMMENT ON COLUMN contracts.numero             IS 'Human-readable contract number. Pattern: CONTRATO-{YYYY}-{CLIENTE}-{NNN}.';
COMMENT ON COLUMN contracts.escalado_tipo      IS 'Revenue model type after automatic escalation (caute limit exceeded).';
COMMENT ON COLUMN contracts.documento_pdf_ref  IS 'Reference to signed PDF stored in object storage (not stored in DB).';
COMMENT ON COLUMN contracts.porcentaje_recaudo IS 'Stored as decimal fraction: 0.1000 = 10%.';

CREATE TRIGGER trg_contracts_updated_at
    BEFORE UPDATE ON contracts
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
