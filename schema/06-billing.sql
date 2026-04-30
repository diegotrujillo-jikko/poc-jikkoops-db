-- =============================================================================
-- JikkoOps Control Database - Billing
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Table: invoices
-- ---------------------------------------------------------------------------

CREATE TABLE invoices (
    id                  UUID            NOT NULL DEFAULT gen_random_uuid(),
    tenant_id           UUID            NOT NULL,
    contract_id         UUID            NOT NULL,
    -- Format: FACT-{YYYY}-{MM}-{TENANT_SLUG}. e.g. FACT-2026-04-CALI
    numero_factura      VARCHAR(60)     NOT NULL,
    periodo_inicio      DATE            NOT NULL,
    periodo_fin         DATE            NOT NULL,
    fecha_emision       DATE,
    fecha_vencimiento   DATE,
    estado              invoice_estado  NOT NULL DEFAULT 'borrador',
    subtotal            NUMERIC(15,2)   NOT NULL DEFAULT 0,
    iva                 NUMERIC(15,2)   NOT NULL DEFAULT 0,
    descuentos          NUMERIC(15,2)   NOT NULL DEFAULT 0,
    total               NUMERIC(15,2)   NOT NULL DEFAULT 0,
    -- URL to the generated PDF document stored externally (e.g. S3)
    documento_url       TEXT,
    enviado_al_cliente  TIMESTAMPTZ,
    fecha_pago          DATE,
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),

    CONSTRAINT pk_invoices                  PRIMARY KEY (id),
    CONSTRAINT uq_invoices_numero           UNIQUE (numero_factura),
    CONSTRAINT fk_invoices_tenant           FOREIGN KEY (tenant_id)
                                                REFERENCES tenants (id) ON DELETE RESTRICT,
    CONSTRAINT fk_invoices_contract         FOREIGN KEY (contract_id)
                                                REFERENCES contracts (id) ON DELETE RESTRICT,
    CONSTRAINT chk_invoices_periodo         CHECK (periodo_fin > periodo_inicio),
    CONSTRAINT chk_invoices_totals          CHECK (subtotal >= 0 AND iva >= 0 AND total >= 0)
);

COMMENT ON TABLE invoices IS
    'Monthly billing documents for each tenant. '
    'Totals are computed from invoice_lines; subtotal/iva/total are cached aggregates.';

CREATE TRIGGER trg_invoices_updated_at
    BEFORE UPDATE ON invoices
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ---------------------------------------------------------------------------
-- Table: invoice_lines
-- Individual line items composing an invoice.
-- Using a separate table (not JSONB array) enables querying and indexing.
-- ---------------------------------------------------------------------------

CREATE TABLE invoice_lines (
    id                  UUID                    NOT NULL DEFAULT gen_random_uuid(),
    invoice_id          UUID                    NOT NULL,
    descripcion         VARCHAR(255)            NOT NULL,
    cantidad            NUMERIC(15,4)           NOT NULL,
    precio_unitario     NUMERIC(15,2)           NOT NULL,
    subtotal            NUMERIC(15,2)           NOT NULL,
    origen              invoice_line_origen     NOT NULL,
    periodo_inicio      DATE,
    periodo_fin         DATE,
    -- Audit trail for this line (source data used in calculation)
    -- Expected shape: {"expedientes_contados": 1050, "recaudo_cop": 1000000,
    --                  "usuarios_activos": 45, "formula": "1050 * 500"}
    metadata            JSONB,
    created_at          TIMESTAMPTZ             NOT NULL DEFAULT NOW(),

    CONSTRAINT pk_invoice_lines         PRIMARY KEY (id),
    CONSTRAINT fk_invoice_lines_inv     FOREIGN KEY (invoice_id)
                                            REFERENCES invoices (id) ON DELETE CASCADE,
    CONSTRAINT chk_invoice_lines_qty    CHECK (cantidad > 0),
    CONSTRAINT chk_invoice_lines_sub    CHECK (subtotal = ROUND(cantidad * precio_unitario, 2)
                                               OR origen = 'descuento')
);

COMMENT ON TABLE invoice_lines IS
    'Individual line items for an invoice. Each line corresponds to one billing component '
    '(expedientes, usuarios, recaudo, descuento, etc.).';
COMMENT ON COLUMN invoice_lines.metadata IS
    'Source data used for the calculation. Enables audit verification. '
    'Shape: {"expedientes_contados": 1050, "recaudo_cop": 1000000, "formula": "1050 * 500"}';

-- ---------------------------------------------------------------------------
-- Table: expedientes_sync
-- Tracks individual expedients reported by SILIN for each tenant.
-- Used to count monthly volume for CAUTE and PER_EXPEDIENT revenue models.
-- ---------------------------------------------------------------------------

CREATE TABLE expedientes_sync (
    id                      UUID                NOT NULL DEFAULT gen_random_uuid(),
    tenant_id               UUID                NOT NULL,
    -- External ID from SILIN system. Unique per tenant to prevent double-counting.
    expediente_id_externo   VARCHAR(100)        NOT NULL,
    fecha                   DATE                NOT NULL,
    estado                  expediente_estado   NOT NULL DEFAULT 'procesado',
    -- When JikkoOps received this sync event from SILIN
    reported_at             TIMESTAMPTZ         NOT NULL DEFAULT NOW(),
    -- Source system that reported this expedient (e.g. 'silin_webhook', 'manual_import')
    sync_source             VARCHAR(50)         NOT NULL DEFAULT 'silin_webhook',

    CONSTRAINT pk_expedientes_sync              PRIMARY KEY (id),
    CONSTRAINT uq_expedientes_sync_tenant_ext   UNIQUE (tenant_id, expediente_id_externo),
    CONSTRAINT fk_expedientes_sync_tenant       FOREIGN KEY (tenant_id)
                                                    REFERENCES tenants (id) ON DELETE RESTRICT
);

COMMENT ON TABLE expedientes_sync IS
    'Expedients reported by SILIN for each tenant. Used to count monthly volume '
    'for CAUTE limit detection and PER_EXPEDIENT billing. '
    'Unique constraint (tenant_id, expediente_id_externo) prevents double-counting.';
