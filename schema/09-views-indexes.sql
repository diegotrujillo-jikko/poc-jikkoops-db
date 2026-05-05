-- =============================================================================
-- JikkoOps Control Database - Indexes and Reporting Views
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Indexes
-- ---------------------------------------------------------------------------

-- entities
CREATE INDEX idx_entities_nit            ON entities(nit);
CREATE INDEX idx_entities_estado         ON entities(estado) WHERE estado != 'cancelado';

-- tenants
CREATE INDEX idx_tenants_entity_id       ON tenants(entity_id);
CREATE INDEX idx_tenants_estado          ON tenants(estado);
CREATE INDEX idx_tenants_plan_id         ON tenants(plan_id);
CREATE INDEX idx_tenants_vencimiento     ON tenants(fecha_vencimiento) WHERE estado = 'activo';

-- catalog
CREATE INDEX idx_protected_resources_codigo     ON protected_resources(codigo);
CREATE INDEX idx_protected_resources_feature_id ON protected_resources(feature_id);
CREATE INDEX idx_protected_resources_modulo     ON protected_resources(modulo);
CREATE INDEX idx_features_modulo                ON features(modulo);

-- contracts
CREATE INDEX idx_contracts_tenant_id     ON contracts(tenant_id);
CREATE INDEX idx_contracts_tenant_estado ON contracts(tenant_id, estado);
CREATE INDEX idx_contracts_vencimiento   ON contracts(fecha_vencimiento) WHERE estado = 'activo';
CREATE INDEX idx_contracts_plan_id       ON contracts(plan_id);

-- entitlements & flags
CREATE INDEX idx_tenant_entitlements_tenant_id  ON tenant_entitlements(tenant_id);
CREATE INDEX idx_feature_flags_tenant_activo    ON feature_flags(tenant_id, activo);
-- Covering index for "is this resource on for this tenant?" hot query
CREATE INDEX idx_feature_flags_tenant_resource  ON feature_flags(tenant_id, protected_resource_id, activo);
CREATE INDEX idx_feature_flag_audit_tenant_ts   ON feature_flag_audit(tenant_id, "timestamp");

-- billing
CREATE INDEX idx_invoices_tenant_periodo        ON invoices(tenant_id, periodo_inicio, periodo_fin);
CREATE INDEX idx_invoices_estado                ON invoices(estado);
CREATE INDEX idx_invoices_vencimiento           ON invoices(fecha_vencimiento) WHERE estado IN ('emitida', 'vencida');
CREATE INDEX idx_invoice_lines_invoice_id       ON invoice_lines(invoice_id);
CREATE INDEX idx_expedientes_sync_tenant_fecha  ON expedientes_sync(tenant_id, fecha);
-- Cast to TIMESTAMP (not TIMESTAMPTZ) so the IMMUTABLE overload of date_trunc is
-- selected — required for index expressions. fecha is a DATE so this cast is safe.
CREATE INDEX idx_expedientes_sync_tenant_month  ON expedientes_sync(tenant_id, DATE_TRUNC('month', fecha::TIMESTAMP));

-- users / auth
CREATE INDEX idx_users_email             ON users(email);
CREATE INDEX idx_users_entity_id         ON users(entity_id);
CREATE INDEX idx_user_roles_role_id      ON user_roles(role_id);
CREATE INDEX idx_user_roles_tenant_id    ON user_roles(tenant_id) WHERE tenant_id IS NOT NULL;

-- audit & metrics
CREATE INDEX idx_audit_log_tenant_ts     ON audit_log(tenant_id, "timestamp");
CREATE INDEX idx_audit_log_tabla_registro ON audit_log(tabla_afectada, registro_id);
CREATE INDEX idx_audit_log_usuario_ts    ON audit_log(usuario_id, "timestamp");
CREATE INDEX idx_sdk_metrics_tenant_ts   ON sdk_metrics(tenant_id, "timestamp");
CREATE INDEX idx_sdk_metrics_resource_ts ON sdk_metrics(resource_codigo, "timestamp");

-- ---------------------------------------------------------------------------
-- View: v_tenant_active_flags
-- Per-tenant view of which protected resources are currently active.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_tenant_active_flags AS
SELECT
    ff.tenant_id,
    t.nombre_tecnico                        AS tenant_nombre,
    pr.codigo                               AS recurso_codigo,
    pr.nombre                               AS recurso_nombre,
    pr.modulo,
    f.nombre                                AS funcionalidad,
    ff.activo,
    ff.fecha_activacion,
    ff.fecha_desactivacion
FROM feature_flags ff
JOIN protected_resources pr ON ff.protected_resource_id = pr.id
JOIN tenants t              ON ff.tenant_id = t.id
LEFT JOIN features f        ON pr.feature_id = f.id
WHERE ff.activo = true
ORDER BY ff.tenant_id, pr.modulo, pr.codigo;

COMMENT ON VIEW v_tenant_active_flags IS 'Active feature flags per tenant with resource and feature context.';

-- ---------------------------------------------------------------------------
-- View: v_contracts_expiring_90d
-- Contracts expiring within the next 90 days. Drives renewal pipeline.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_contracts_expiring_90d AS
SELECT
    c.id                                    AS contract_id,
    c.numero,
    c.tenant_id,
    t.nombre_tecnico                        AS tenant_nombre,
    e.nombre                                AS entity_nombre,
    e.nit,
    c.fecha_inicio,
    c.fecha_vencimiento,
    (c.fecha_vencimiento - CURRENT_DATE)    AS dias_para_vencer,
    c.valor_total_cop,
    c.estado
FROM contracts c
JOIN tenants  t ON c.tenant_id = t.id
JOIN entities e ON t.entity_id = e.id
WHERE c.estado = 'activo'
  AND c.fecha_vencimiento BETWEEN CURRENT_DATE AND (CURRENT_DATE + INTERVAL '90 days')
ORDER BY c.fecha_vencimiento ASC;

COMMENT ON VIEW v_contracts_expiring_90d IS 'Active contracts expiring in the next 90 days. Used by renewal pipeline.';

-- ---------------------------------------------------------------------------
-- View: v_revenue_summary
-- Revenue projection per active contract, joining contract + revenue model.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_revenue_summary AS
SELECT
    c.id                                    AS contract_id,
    c.numero,
    c.tenant_id,
    e.nombre                                AS entity_nombre,
    rm.tipo                                 AS revenue_tipo,
    rm.nombre                               AS revenue_modelo_nombre,
    rm.parametros                           AS revenue_params,
    c.limite_expedientes,
    c.porcentaje_recaudo,
    c.valor_total_cop,
    c.fecha_inicio,
    c.fecha_vencimiento,
    c.escalado_tipo,
    c.escalado_fecha
FROM contracts c
JOIN tenants t                  ON c.tenant_id = t.id
JOIN entities e                 ON t.entity_id = e.id
LEFT JOIN revenue_model_configs rm ON c.revenue_model_id = rm.id
WHERE c.estado = 'activo';

COMMENT ON VIEW v_revenue_summary IS 'Active-contract revenue posture: model, params, current escalation state.';

-- ---------------------------------------------------------------------------
-- View: v_invoice_totals
-- Per-tenant invoice aggregates: paid, pending, overdue.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_invoice_totals AS
SELECT
    i.tenant_id,
    e.nombre                                AS entity_nombre,
    t.nombre_tecnico                        AS tenant_nombre,
    COUNT(*)                                                                    AS facturas_total,
    COUNT(*) FILTER (WHERE i.estado = 'pagada')                                AS facturas_pagadas,
    COUNT(*) FILTER (WHERE i.estado = 'emitida')                               AS facturas_pendientes,
    COUNT(*) FILTER (WHERE i.estado = 'vencida')                               AS facturas_vencidas,
    COALESCE(SUM(i.total) FILTER (WHERE i.estado = 'pagada'),  0)              AS total_pagado,
    COALESCE(SUM(i.total) FILTER (WHERE i.estado = 'emitida'), 0)              AS total_pendiente,
    COALESCE(SUM(i.total) FILTER (WHERE i.estado = 'vencida'), 0)              AS total_vencido
FROM invoices i
JOIN tenants t  ON i.tenant_id = t.id
JOIN entities e ON t.entity_id = e.id
GROUP BY i.tenant_id, e.nombre, t.nombre_tecnico;

COMMENT ON VIEW v_invoice_totals IS 'Per-tenant invoice aggregates: paid, pending, overdue.';
