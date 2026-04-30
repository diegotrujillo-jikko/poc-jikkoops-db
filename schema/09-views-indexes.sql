-- =============================================================================
-- JikkoOps Control Database - Indexes and Views
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Indexes
-- ---------------------------------------------------------------------------

-- entities
CREATE INDEX idx_entities_nit           ON entities (nit);
CREATE INDEX idx_entities_estado        ON entities (estado);

-- tenants
CREATE INDEX idx_tenants_entity_id      ON tenants (entity_id);
CREATE INDEX idx_tenants_estado         ON tenants (estado);
CREATE INDEX idx_tenants_plan_id        ON tenants (plan_id);

-- contracts
CREATE INDEX idx_contracts_tenant_estado    ON contracts (tenant_id, estado);
CREATE INDEX idx_contracts_vencimiento      ON contracts (fecha_vencimiento) WHERE estado = 'activo';
CREATE INDEX idx_contracts_tenant_id        ON contracts (tenant_id);

-- feature_flags — most performance-critical: checked on every authenticated request
CREATE INDEX idx_feature_flags_tenant_activo
    ON feature_flags (tenant_id, activo);
-- Covering index: satisfies the common "is resource X active for tenant Y?" query with index-only scan
CREATE INDEX idx_feature_flags_tenant_resource
    ON feature_flags (tenant_id, protected_resource_id, activo);
CREATE INDEX idx_feature_flags_codigo
    ON feature_flags (codigo_recurso);

-- protected_resources
CREATE INDEX idx_protected_resources_codigo
    ON protected_resources (codigo);
CREATE INDEX idx_protected_resources_feature_id
    ON protected_resources (feature_id);
CREATE INDEX idx_protected_resources_modulo
    ON protected_resources (modulo);

-- invoices
CREATE INDEX idx_invoices_tenant_periodo
    ON invoices (tenant_id, periodo_inicio, periodo_fin);
CREATE INDEX idx_invoices_estado
    ON invoices (estado);
CREATE INDEX idx_invoices_vencimiento
    ON invoices (fecha_vencimiento) WHERE estado IN ('emitida', 'vencida');

-- audit_log
CREATE INDEX idx_audit_log_tenant_timestamp
    ON audit_log (tenant_id, timestamp DESC);
CREATE INDEX idx_audit_log_tabla_registro
    ON audit_log (tabla_afectada, registro_id);
CREATE INDEX idx_audit_log_timestamp
    ON audit_log (timestamp DESC);

-- sdk_metrics (on default partition; repeat for each monthly partition)
CREATE INDEX idx_sdk_metrics_tenant_timestamp
    ON sdk_metrics (tenant_id, timestamp DESC);
CREATE INDEX idx_sdk_metrics_resource_codigo
    ON sdk_metrics (resource_codigo, timestamp DESC);

-- expedientes_sync
CREATE INDEX idx_expedientes_sync_tenant_fecha
    ON expedientes_sync (tenant_id, fecha);
CREATE INDEX idx_expedientes_sync_estado
    ON expedientes_sync (tenant_id, estado);

-- users
CREATE INDEX idx_users_email            ON users (email);
CREATE INDEX idx_users_entity_id        ON users (entity_id);

-- feature_flag_audit
CREATE INDEX idx_ffa_tenant_timestamp   ON feature_flag_audit (tenant_id, timestamp DESC);
CREATE INDEX idx_ffa_flag_id            ON feature_flag_audit (flag_id);

-- ---------------------------------------------------------------------------
-- View: v_tenant_active_flags
-- Quick lookup of every active/inactive resource for a tenant.
-- ---------------------------------------------------------------------------

CREATE OR REPLACE VIEW v_tenant_active_flags AS
SELECT
    ff.tenant_id,
    pr.codigo                   AS codigo_recurso,
    pr.nombre                   AS nombre_recurso,
    pr.tipo                     AS tipo_recurso,
    pr.modulo,
    f.nombre                    AS funcionalidad,
    ff.activo,
    ff.fecha_activacion,
    ff.fecha_desactivacion,
    ff.razon                    AS ultima_razon_cambio
FROM feature_flags ff
JOIN protected_resources pr ON ff.protected_resource_id = pr.id
LEFT JOIN features f        ON pr.feature_id = f.id
ORDER BY ff.tenant_id, pr.modulo, pr.codigo;

COMMENT ON VIEW v_tenant_active_flags IS
    'All feature flag states per tenant, enriched with resource and feature metadata. '
    'Use for runtime checks and operator dashboards.';

-- ---------------------------------------------------------------------------
-- View: v_contracts_expiring_90d
-- Contracts expiring within 90 days — for renewal pipeline.
-- ---------------------------------------------------------------------------

CREATE OR REPLACE VIEW v_contracts_expiring_90d AS
SELECT
    c.id                                    AS contract_id,
    c.numero                                AS numero_contrato,
    c.tipo,
    c.estado,
    c.fecha_vencimiento,
    (c.fecha_vencimiento - CURRENT_DATE)    AS dias_para_vencer,
    t.id                                    AS tenant_id,
    t.nombre_tecnico,
    e.id                                    AS entity_id,
    e.nombre                                AS entity_nombre,
    e.nit,
    p.nombre                                AS plan_nombre
FROM contracts c
JOIN tenants  t ON c.tenant_id   = t.id
JOIN entities e ON t.entity_id   = e.id
JOIN plans    p ON c.plan_id     = p.id
WHERE c.estado = 'activo'
  AND c.fecha_vencimiento BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '90 days'
ORDER BY c.fecha_vencimiento ASC;

COMMENT ON VIEW v_contracts_expiring_90d IS
    'Active contracts expiring within 90 days. Used by the commercial dashboard renewal pipeline.';

-- ---------------------------------------------------------------------------
-- View: v_revenue_summary
-- Per-contract revenue model overview for financial reporting.
-- ---------------------------------------------------------------------------

CREATE OR REPLACE VIEW v_revenue_summary AS
SELECT
    c.id                                AS contract_id,
    c.numero                            AS numero_contrato,
    c.estado                            AS contrato_estado,
    c.fecha_inicio,
    c.fecha_vencimiento,
    c.porcentaje_recaudo,
    c.limite_expedientes,
    c.escalado_tipo,
    c.escalado_fecha,
    rmc.nombre                          AS modelo_nombre,
    rmc.tipo                            AS modelo_tipo,
    rmc.parametros                      AS modelo_parametros,
    t.id                                AS tenant_id,
    t.nombre_tecnico,
    e.nombre                            AS entity_nombre,
    p.nombre                            AS plan_nombre
FROM contracts c
JOIN revenue_model_configs  rmc ON c.revenue_model_id = rmc.id
JOIN tenants                t   ON c.tenant_id        = t.id
JOIN entities               e   ON t.entity_id        = e.id
JOIN plans                  p   ON c.plan_id           = p.id
ORDER BY e.nombre, t.nombre_tecnico;

COMMENT ON VIEW v_revenue_summary IS
    'Per-contract revenue model details. Used for financial planning and escalado monitoring.';

-- ---------------------------------------------------------------------------
-- View: v_invoice_totals
-- Invoice summary with payment status per tenant/entity.
-- ---------------------------------------------------------------------------

CREATE OR REPLACE VIEW v_invoice_totals AS
SELECT
    i.id                AS invoice_id,
    i.numero_factura,
    i.periodo_inicio,
    i.periodo_fin,
    i.fecha_emision,
    i.fecha_vencimiento,
    i.fecha_pago,
    i.estado,
    i.subtotal,
    i.iva,
    i.descuentos,
    i.total,
    CASE
        WHEN i.estado = 'pagada'  THEN i.total
        ELSE 0
    END                 AS total_pagado,
    CASE
        WHEN i.estado IN ('emitida', 'borrador') THEN i.total
        ELSE 0
    END                 AS total_pendiente,
    CASE
        WHEN i.estado = 'vencida' THEN i.total
        ELSE 0
    END                 AS total_vencido,
    t.id                AS tenant_id,
    t.nombre_tecnico,
    e.nombre            AS entity_nombre,
    e.nit
FROM invoices i
JOIN tenants  t ON i.tenant_id   = t.id
JOIN entities e ON t.entity_id   = e.id
ORDER BY i.fecha_emision DESC;

COMMENT ON VIEW v_invoice_totals IS
    'Invoice summary with paid/pending/overdue breakdown per tenant. '
    'Used for the collections dashboard and CFO financial reports.';
