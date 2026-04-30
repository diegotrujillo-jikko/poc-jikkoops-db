-- =============================================================================
-- JikkoOps Control Database - Billing (Invoices, Lines, Expedient Sync)
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Table: invoices
-- Billing document issued to a tenant for a service period.
-- ---------------------------------------------------------------------------
CREATE TABLE invoices (
    id                    UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id             UUID            NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    contract_id           UUID            REFERENCES contracts(id) ON DELETE RESTRICT,
    numero_factura        VARCHAR(60)     NOT NULL UNIQUE,    -- e.g. 'FACT-2026-04-CALI'

    -- Period covered
    periodo_inicio        DATE            NOT NULL,
    periodo_fin           DATE            NOT NULL,

    -- Issue/payment timeline
    fecha_emision         DATE,
    fecha_vencimiento     DATE,
    fecha_pago            DATE,

    estado                invoice_estado  NOT NULL DEFAULT 'borrador',

    -- Totals (lines stored separately in invoice_lines)
    subtotal              NUMERIC(15,2)   NOT NULL DEFAULT 0,
    iva                   NUMERIC(15,2)   NOT NULL DEFAULT 0,
    descuentos            NUMERIC(15,2)   NOT NULL DEFAULT 0,
    total                 NUMERIC(15,2)   NOT NULL DEFAULT 0,

    -- PDF stored externally
    documento_pdf_ref     TEXT,
    enviado_al_cliente    TIMESTAMPTZ,

    created_at            TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at            TIMESTAMPTZ     NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_invoice_period CHECK (periodo_fin >= periodo_inicio),
    CONSTRAINT chk_invoice_total  CHECK (total = subtotal + iva - descuentos)
);

COMMENT ON TABLE  invoices                  IS 'Billing document. Lines in invoice_lines table. PDF stored externally.';
COMMENT ON COLUMN invoices.documento_pdf_ref IS 'Reference to issued PDF in object storage.';

CREATE TRIGGER trg_invoices_updated_at
    BEFORE UPDATE ON invoices
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ---------------------------------------------------------------------------
-- Table: invoice_lines
-- Detailed line items per invoice (extracted from JSONB array for queryability).
-- ---------------------------------------------------------------------------
CREATE TABLE invoice_lines (
    id              UUID                PRIMARY KEY DEFAULT gen_random_uuid(),
    invoice_id      UUID                NOT NULL REFERENCES invoices(id) ON DELETE CASCADE,
    descripcion     TEXT                NOT NULL,
    cantidad        NUMERIC(15,4)       NOT NULL DEFAULT 1,
    precio_unitario NUMERIC(15,2)       NOT NULL DEFAULT 0,
    subtotal        NUMERIC(15,2)       NOT NULL,
    origen          invoice_line_origen NOT NULL,
    -- Period this line covers (may be subset of invoice period)
    periodo_inicio  DATE,
    periodo_fin     DATE,
    -- Audit context: {"resource_codigo": "LIQ-001", "expedientes_count": 50, "calculo": "50 * 50.00"}
    metadata        JSONB               NOT NULL DEFAULT '{}',
    created_at      TIMESTAMPTZ         NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE  invoice_lines          IS 'Detailed line items. Separate table for queryability and aggregation by origen.';
COMMENT ON COLUMN invoice_lines.metadata IS 'Audit trail of calculation: source resource, expedient count, formula used.';

-- ---------------------------------------------------------------------------
-- Table: expedientes_sync
-- Records each expedient processed by SILIN, used for caute/per-expedient billing.
-- High volume: target 50M rows/month — partitioning recommended once volume grows.
-- ---------------------------------------------------------------------------
CREATE TABLE expedientes_sync (
    id                    UUID              PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id             UUID              NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    expediente_id_externo VARCHAR(100)      NOT NULL,
    fecha                 DATE              NOT NULL,
    estado                expediente_estado NOT NULL,
    -- Source system that reported this expedient (typically 'SILIN')
    sync_source           VARCHAR(50)       NOT NULL DEFAULT 'SILIN',
    reported_at           TIMESTAMPTZ       NOT NULL DEFAULT NOW(),
    -- {"valor_recaudo": 1500000, "tipo_tributo": "...", "detalles": {}}
    metadata              JSONB             NOT NULL DEFAULT '{}',

    -- Same external expedient cannot be reported twice for same tenant
    UNIQUE (tenant_id, expediente_id_externo)
);

COMMENT ON TABLE  expedientes_sync IS 'Expedient ingestion log from SILIN. Source for caute/per-expedient billing. Partition by month at scale.';
COMMENT ON COLUMN expedientes_sync.expediente_id_externo IS 'Unique identifier of expedient in source system.';
