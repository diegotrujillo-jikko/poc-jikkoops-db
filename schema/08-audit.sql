-- =============================================================================
-- JikkoOps Control Database - Audit Log and SDK Metrics
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Table: audit_log
-- Immutable insert-only table. Records every significant state change.
-- Retention: 7 years (Colombian fiscal compliance requirement).
-- IMPORTANT: Application must prevent UPDATE and DELETE on this table via:
--   1. RLS policy (recommended): RESTRICT to INSERT for non-superuser roles
--   2. Application-level enforcement in the repository layer
-- ---------------------------------------------------------------------------

CREATE TABLE audit_log (
    id                  UUID            NOT NULL DEFAULT gen_random_uuid(),
    -- NULL for system-initiated events (cron jobs, automated escalado)
    tenant_id           UUID,
    -- NULL for system-initiated events
    usuario_id          UUID,
    -- Name of the table that was modified (e.g. 'contracts', 'feature_flags')
    tabla_afectada      VARCHAR(100)    NOT NULL,
    -- UUID of the specific row that changed
    registro_id         UUID            NOT NULL,
    operacion           audit_operacion NOT NULL,
    -- Full row state before the operation (NULL for INSERT)
    valores_anterior    JSONB,
    -- Full row state after the operation (NULL for DELETE)
    valores_nuevo       JSONB,
    timestamp           TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    ip_address          INET,
    user_agent          TEXT,
    -- Free-text reason provided by the operator (required for manual changes)
    razon               TEXT,
    -- Session identifier for correlating multiple events from one user session
    session_id          TEXT,

    CONSTRAINT pk_audit_log             PRIMARY KEY (id),
    CONSTRAINT fk_audit_tenant          FOREIGN KEY (tenant_id)
                                            REFERENCES tenants (id) ON DELETE RESTRICT,
    CONSTRAINT fk_audit_usuario         FOREIGN KEY (usuario_id)
                                            REFERENCES users (id) ON DELETE RESTRICT
);

-- RLS: Restrict to INSERT for application roles.
-- Superuser / DBA role may SELECT for compliance reporting.
-- Run as superuser after creating the app role:
--
-- ALTER TABLE audit_log ENABLE ROW LEVEL SECURITY;
-- CREATE POLICY audit_log_insert_only ON audit_log
--     FOR INSERT TO app_role WITH CHECK (true);
-- CREATE POLICY audit_log_select ON audit_log
--     FOR SELECT TO app_role USING (true);
-- (No UPDATE or DELETE policy = those operations are denied for app_role)

COMMENT ON TABLE audit_log IS
    'INSERT-ONLY immutable audit trail. Retention: 7 years (fiscal compliance). '
    'Enforce via RLS — no UPDATE or DELETE allowed for app role. '
    'Archive rows older than 2 years to audit_log_archive table (same schema).';

-- ---------------------------------------------------------------------------
-- Table: sdk_metrics
-- Records performance and cost data for every Protected Resource invocation.
-- Partitioned by month for efficient querying and archiving.
-- NOTE: Monthly child partitions must be created in advance or automatically
--       via pg_partman. See docs/PARTITIONS.md for management instructions.
-- ---------------------------------------------------------------------------

CREATE TABLE sdk_metrics (
    id                  UUID            NOT NULL DEFAULT gen_random_uuid(),
    tenant_id           UUID            NOT NULL,
    -- Protected resource code (denormalized for partition-local queries without join)
    resource_codigo     VARCHAR(20)     NOT NULL,
    -- Optional FK — may be NULL if resource was deleted/deprecated
    resource_id         UUID,
    execution_time_ms   INT             NOT NULL,
    tokens_used         INT             NOT NULL DEFAULT 0,
    -- Computed cost: tokens_used × per-token rate
    cost_usd            NUMERIC(10,6)   NOT NULL DEFAULT 0,
    success             BOOLEAN         NOT NULL DEFAULT true,
    -- Error code if success = false (e.g. 'TIMEOUT', 'AUTH_FAILED', 'LIMIT_EXCEEDED')
    error_code          VARCHAR(50),
    timestamp           TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    -- Additional context for debugging
    -- Expected shape: {"endpoint": "/liquidaciones", "method": "POST", "trace_id": "..."}
    metadata            JSONB,

    CONSTRAINT pk_sdk_metrics               PRIMARY KEY (id, timestamp),
    CONSTRAINT fk_sdk_metrics_tenant        FOREIGN KEY (tenant_id)
                                                REFERENCES tenants (id) ON DELETE RESTRICT,
    CONSTRAINT fk_sdk_metrics_resource      FOREIGN KEY (resource_id)
                                                REFERENCES protected_resources (id) ON DELETE SET NULL,
    CONSTRAINT chk_sdk_metrics_exec_time    CHECK (execution_time_ms >= 0),
    CONSTRAINT chk_sdk_metrics_cost         CHECK (cost_usd >= 0)
) PARTITION BY RANGE (timestamp);

-- Default partition catches any rows that fall outside defined monthly ranges.
-- Replace with monthly partitions managed by pg_partman in production.
CREATE TABLE sdk_metrics_default PARTITION OF sdk_metrics DEFAULT;

COMMENT ON TABLE sdk_metrics IS
    'Performance and cost metrics per Protected Resource invocation. '
    'Partitioned by timestamp (monthly). Use pg_partman for automated partition management. '
    'Retention: 24 months online; archive older partitions to cold storage.';
COMMENT ON COLUMN sdk_metrics.cost_usd IS
    'Monetary cost in USD: tokens_used × current per-token rate. '
    'Used for observability dashboards and cost-per-function reporting.';
