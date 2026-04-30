-- =============================================================================
-- JikkoOps Control Database - Audit Log & SDK Metrics
-- =============================================================================
-- These tables track every change for compliance (7-year retention required by
-- Colombian fiscal law) and resource execution metrics for cost analytics.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Table: audit_log
-- Insert-only log of every business-data change in the system.
-- Required for fiscal compliance — retention 7 years minimum.
-- WARNING: UPDATE and DELETE on this table MUST be prevented at the
-- application layer and ideally via PostgreSQL row-level security policies.
-- ---------------------------------------------------------------------------
CREATE TABLE audit_log (
    id              UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id       UUID            REFERENCES tenants(id) ON DELETE RESTRICT,
    usuario_id      UUID            REFERENCES users(id)   ON DELETE RESTRICT,

    tabla_afectada  VARCHAR(100)    NOT NULL,        -- e.g. 'contracts', 'feature_flags'
    registro_id     UUID            NOT NULL,        -- PK of affected row
    operacion       audit_operacion NOT NULL,
    valores_anterior JSONB,                          -- NULL on INSERT
    valores_nuevo   JSONB,                          -- NULL on DELETE

    "timestamp"     TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    ip_address      INET,
    user_agent      TEXT,
    session_id      TEXT,
    razon           TEXT
    -- NO updated_at — this table is insert-only
);

COMMENT ON TABLE  audit_log                  IS 'IMMUTABLE insert-only audit trail. 7-year retention. UPDATE/DELETE MUST be blocked.';
COMMENT ON COLUMN audit_log.valores_anterior IS 'Snapshot before change. NULL for INSERT operations.';
COMMENT ON COLUMN audit_log.valores_nuevo    IS 'Snapshot after change. NULL for DELETE operations.';
COMMENT ON COLUMN audit_log.razon            IS 'Optional human-readable reason for manual operations.';

-- Enable row-level security and DENY UPDATE/DELETE for everyone (recommended).
-- Application layer should ALSO enforce insert-only. Run after grants are set up:
--
--   ALTER TABLE audit_log ENABLE ROW LEVEL SECURITY;
--   CREATE POLICY audit_log_no_update ON audit_log FOR UPDATE USING (false);
--   CREATE POLICY audit_log_no_delete ON audit_log FOR DELETE USING (false);
--
-- These are commented because they depend on role grants that vary by environment.

-- ---------------------------------------------------------------------------
-- Table: sdk_metrics
-- Per-execution metrics for every protected resource invocation.
-- Used for cost analytics and SLA monitoring.
-- High volume — partition by month at scale (commented stub below).
-- ---------------------------------------------------------------------------
CREATE TABLE sdk_metrics (
    id                UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id         UUID          REFERENCES tenants(id) ON DELETE RESTRICT,
    -- Denormalized PR code for fast filtering without JOIN
    resource_codigo   VARCHAR(20)   NOT NULL,
    resource_id       UUID          REFERENCES protected_resources(id) ON DELETE SET NULL,
    execution_time_ms INT           NOT NULL,
    tokens_used       INT,
    cost_usd          NUMERIC(10,6),    -- 6-decimal USD for fractional token costs
    success           BOOLEAN       NOT NULL,
    error_code        VARCHAR(60),
    "timestamp"       TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    -- {"endpoint": "...", "method": "POST", "request_size_bytes": 1234, "extras": {}}
    metadata          JSONB         NOT NULL DEFAULT '{}'
);

COMMENT ON TABLE  sdk_metrics                 IS 'Per-execution metrics. High volume — plan for monthly partitioning at scale.';
COMMENT ON COLUMN sdk_metrics.resource_codigo IS 'Denormalized PR code for fast filtering without JOIN.';
COMMENT ON COLUMN sdk_metrics.cost_usd        IS 'Computed cost (tokens * tariff). Stored at insert time for stability.';

-- Future partitioning at scale (run when sdk_metrics > 50M rows):
--
--   ALTER TABLE sdk_metrics ... PARTITION BY RANGE ("timestamp");
--   CREATE TABLE sdk_metrics_202604 PARTITION OF sdk_metrics
--     FOR VALUES FROM ('2026-04-01') TO ('2026-05-01');
--
-- Same applies to audit_log and expedientes_sync once those reach scale.
