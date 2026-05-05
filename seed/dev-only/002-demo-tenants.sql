-- =============================================================================
-- JikkoOps Demo Data - DEVELOPMENT ENVIRONMENTS ONLY
-- =============================================================================
--
--   ⚠️  WARNING: DEV / STAGING ENVIRONMENTS ONLY  ⚠️
--   ⚠️  DO NOT RUN IN PRODUCTION                  ⚠️
--
-- Populates runtime/transactional tables with synthetic data so developers
-- can exercise the system end-to-end without manually creating entities,
-- contracts, users, etc.
--
-- Assumes 001-catalog-seed.sql has been applied (references its UUIDs).
-- All synthetic UUIDs use prefix 'aaaaaaaa-...' to distinguish from real data.
-- =============================================================================

BEGIN;

-- Safety guard: refuse to run if non-demo entities already exist.
DO $$
DECLARE
    real_count INT;
BEGIN
    SELECT COUNT(*) INTO real_count
    FROM entities
    WHERE id::TEXT NOT LIKE 'aaaaaaaa-%';

    IF real_count > 0 THEN
        RAISE EXCEPTION
            'Refusing to seed demo data: % non-demo entities already exist. This file is for fresh dev environments only.',
            real_count;
    END IF;
END $$;

-- ---------------------------------------------------------------------------
-- Entities (2 demo municipios)
-- ---------------------------------------------------------------------------
INSERT INTO entities (id, nombre, nit, tipo, region, email, telefono, direccion, estado, metadata) VALUES
    ('aaaaaaaa-aaaa-aaaa-aaaa-000000000001',
     'Municipio Demo Cali', '900123456-1', 'municipio', 'Valle del Cauca',
     'demo@cali.gov.co', '+57 2 1234567', 'Calle Demo 123, Cali',
     'activo',
     '{"sigia_id": "DEMO-CALI", "codigo_dane": "76001", "notas": "Demo data — DEV ONLY"}'),

    ('aaaaaaaa-aaaa-aaaa-aaaa-000000000002',
     'Municipio Demo Medellin', '900123456-2', 'municipio', 'Antioquia',
     'demo@medellin.gov.co', '+57 4 7654321', 'Carrera Demo 45, Medellin',
     'activo',
     '{"sigia_id": "DEMO-MED", "codigo_dane": "05001", "notas": "Demo data — DEV ONLY"}');

-- ---------------------------------------------------------------------------
-- Tenants
-- ---------------------------------------------------------------------------
INSERT INTO tenants (id, entity_id, nombre_tecnico, db_connection_string, region,
                     plan_id, usuarios_limite, expedientes_mes_limite, estado,
                     fecha_activacion, fecha_vencimiento, metadata) VALUES
    ('aaaaaaaa-aaaa-aaaa-aaaa-100000000001',
     'aaaaaaaa-aaaa-aaaa-aaaa-000000000001',
     'demo_cali',
     '[ENCRYPTED-DEV-PLACEHOLDER]', 'Valle del Cauca',
     '55555555-5555-5555-5555-000000000002',
     100, 5000, 'activo',
     '2026-01-01', '2026-12-31',
     '{"db_host": "demo-db", "redis_namespace": "demo:cali", "timezone": "America/Bogota"}'),

    ('aaaaaaaa-aaaa-aaaa-aaaa-100000000002',
     'aaaaaaaa-aaaa-aaaa-aaaa-000000000002',
     'demo_medellin',
     '[ENCRYPTED-DEV-PLACEHOLDER]', 'Antioquia',
     '55555555-5555-5555-5555-000000000001',
     50, 1000, 'en_prueba',
     '2026-04-01', '2026-06-30',
     '{"db_host": "demo-db", "redis_namespace": "demo:medellin", "timezone": "America/Bogota"}');

-- ---------------------------------------------------------------------------
-- Users (1 admin + 1 operator per tenant)
-- ---------------------------------------------------------------------------
INSERT INTO users (id, entity_id, nombre, email, password_hash, estado, perfil) VALUES
    ('aaaaaaaa-aaaa-aaaa-aaaa-200000000001',
     NULL, 'Admin Demo', 'admin@jikkoops.demo',
     '$2b$12$DEMO.HASH.PLACEHOLDER.NEVER.USE.IN.PROD.OR.STAGING.AAAAAAAAA',
     'activo',
     '{"cargo": "Plataforma", "departamento": "JikkoOps Staff"}'),

    ('aaaaaaaa-aaaa-aaaa-aaaa-200000000002',
     'aaaaaaaa-aaaa-aaaa-aaaa-000000000001',
     'Operador Cali Demo', 'operador@cali.demo',
     '$2b$12$DEMO.HASH.PLACEHOLDER.NEVER.USE.IN.PROD.OR.STAGING.BBBBBBBBB',
     'activo',
     '{"cargo": "Operador", "departamento": "Tesoreria Cali"}'),

    ('aaaaaaaa-aaaa-aaaa-aaaa-200000000003',
     'aaaaaaaa-aaaa-aaaa-aaaa-000000000002',
     'Operador Medellin Demo', 'operador@medellin.demo',
     '$2b$12$DEMO.HASH.PLACEHOLDER.NEVER.USE.IN.PROD.OR.STAGING.CCCCCCCCC',
     'activo',
     '{"cargo": "Operador", "departamento": "Tesoreria Medellin"}');

INSERT INTO user_roles (user_id, role_id, tenant_id, granted_by) VALUES
    ('aaaaaaaa-aaaa-aaaa-aaaa-200000000001',
     '66666666-6666-6666-6666-000000000001',
     NULL,
     'aaaaaaaa-aaaa-aaaa-aaaa-200000000001'),

    ('aaaaaaaa-aaaa-aaaa-aaaa-200000000002',
     '66666666-6666-6666-6666-000000000002',
     'aaaaaaaa-aaaa-aaaa-aaaa-100000000001',
     'aaaaaaaa-aaaa-aaaa-aaaa-200000000001'),

    ('aaaaaaaa-aaaa-aaaa-aaaa-200000000003',
     '66666666-6666-6666-6666-000000000004',
     'aaaaaaaa-aaaa-aaaa-aaaa-100000000002',
     'aaaaaaaa-aaaa-aaaa-aaaa-200000000001');

INSERT INTO mfa_credentials (id, user_id, secret, habilitado, intentos_fallidos, backup_codes) VALUES
    ('aaaaaaaa-aaaa-aaaa-aaaa-300000000001',
     'aaaaaaaa-aaaa-aaaa-aaaa-200000000001',
     '[ENCRYPTED-AES256-DEV-PLACEHOLDER]',
     true, 0,
     ARRAY['[ENCRYPTED-CODE-1]', '[ENCRYPTED-CODE-2]', '[ENCRYPTED-CODE-3]']);

-- ---------------------------------------------------------------------------
-- Contracts
-- ---------------------------------------------------------------------------
INSERT INTO contracts (id, tenant_id, plan_id, revenue_model_id, numero, fecha_firma,
                       fecha_inicio, fecha_vencimiento, tipo_contrato, estado,
                       limite_expedientes, porcentaje_recaudo, valor_total_cop, forma_pago) VALUES
    ('aaaaaaaa-aaaa-aaaa-aaaa-400000000001',
     'aaaaaaaa-aaaa-aaaa-aaaa-100000000001',
     '55555555-5555-5555-5555-000000000002',
     '44444444-4444-4444-4444-000000000002',
     'CONTRATO-2026-CALI-001',
     '2025-12-15', '2026-01-01', '2026-12-31',
     'principal', 'activo',
     5000, 0.1000, 120000000.00, 'transferencia'),

    ('aaaaaaaa-aaaa-aaaa-aaaa-400000000002',
     'aaaaaaaa-aaaa-aaaa-aaaa-100000000002',
     '55555555-5555-5555-5555-000000000001',
     '44444444-4444-4444-4444-000000000001',
     'CONTRATO-2026-MED-001',
     '2026-03-20', '2026-04-01', '2026-06-30',
     'principal', 'activo',
     1000, NULL, 0.00, 'transferencia');

-- ---------------------------------------------------------------------------
-- Tenant Entitlements
-- ---------------------------------------------------------------------------
INSERT INTO tenant_entitlements (id, tenant_id, feature_id, estado, fecha_activacion, motivo, aprobado_por) VALUES
    ('aaaaaaaa-aaaa-aaaa-aaaa-500000000001',
     'aaaaaaaa-aaaa-aaaa-aaaa-100000000001',
     '11111111-1111-1111-1111-000000000001', 'activo', '2026-01-01',
     'activacion contrato CONTRATO-2026-CALI-001', 'aaaaaaaa-aaaa-aaaa-aaaa-200000000001'),

    ('aaaaaaaa-aaaa-aaaa-aaaa-500000000002',
     'aaaaaaaa-aaaa-aaaa-aaaa-100000000001',
     '11111111-1111-1111-1111-000000000002', 'activo', '2026-01-01',
     'activacion contrato CONTRATO-2026-CALI-001', 'aaaaaaaa-aaaa-aaaa-aaaa-200000000001'),

    ('aaaaaaaa-aaaa-aaaa-aaaa-500000000003',
     'aaaaaaaa-aaaa-aaaa-aaaa-100000000002',
     '11111111-1111-1111-1111-000000000001', 'activo', '2026-04-01',
     'activacion contrato CONTRATO-2026-MED-001', 'aaaaaaaa-aaaa-aaaa-aaaa-200000000001');

-- ---------------------------------------------------------------------------
-- Feature Flags (synced from entitlements)
-- ---------------------------------------------------------------------------
INSERT INTO feature_flags (id, tenant_id, protected_resource_id, codigo_recurso, activo,
                           fecha_activacion, activado_por, razon)
SELECT
    gen_random_uuid(),
    'aaaaaaaa-aaaa-aaaa-aaaa-100000000001',
    pr.id, pr.codigo,
    pr.modulo IN ('SILIN', 'DOS'),
    CASE WHEN pr.modulo IN ('SILIN', 'DOS') THEN '2026-01-01 00:00:00+00'::TIMESTAMPTZ END,
    'aaaaaaaa-aaaa-aaaa-aaaa-200000000001',
    'sync inicial Plan Estandar'
FROM protected_resources pr
WHERE pr.codigo IN ('LIQ-001','LIQ-002','LIQ-003','LIQ-004','DOC-001','DOC-003','SOC-001','SOC-002');

INSERT INTO feature_flags (id, tenant_id, protected_resource_id, codigo_recurso, activo,
                           fecha_activacion, activado_por, razon)
SELECT
    gen_random_uuid(),
    'aaaaaaaa-aaaa-aaaa-aaaa-100000000002',
    pr.id, pr.codigo,
    pr.modulo = 'SILIN',
    CASE WHEN pr.modulo = 'SILIN' THEN '2026-04-01 00:00:00+00'::TIMESTAMPTZ END,
    'aaaaaaaa-aaaa-aaaa-aaaa-200000000001',
    'sync inicial Plan Basico'
FROM protected_resources pr
WHERE pr.codigo IN ('LIQ-001','LIQ-002','LIQ-003','LIQ-004','DOC-001','DOC-003','SOC-001','SOC-002');

-- ---------------------------------------------------------------------------
-- Sample expedientes (Cali processes 250 in April)
-- ---------------------------------------------------------------------------
INSERT INTO expedientes_sync (id, tenant_id, expediente_id_externo, fecha, estado, sync_source, metadata)
SELECT
    gen_random_uuid(),
    'aaaaaaaa-aaaa-aaaa-aaaa-100000000001',
    'EXP-DEMO-' || LPAD(g::TEXT, 5, '0'),
    '2026-04-01'::DATE + ((g % 30) || ' days')::INTERVAL,
    'liquidado',
    'SILIN',
    json_build_object('valor_recaudo', 1000000 + (g * 1000), 'tipo_tributo', 'predial')
FROM generate_series(1, 250) g;

-- ---------------------------------------------------------------------------
-- Sample invoice + line for Cali (April 2026)
-- ---------------------------------------------------------------------------
INSERT INTO invoices (id, tenant_id, contract_id, numero_factura, periodo_inicio, periodo_fin,
                      fecha_emision, fecha_vencimiento, estado,
                      subtotal, iva, descuentos, total) VALUES
    ('aaaaaaaa-aaaa-aaaa-aaaa-600000000001',
     'aaaaaaaa-aaaa-aaaa-aaaa-100000000001',
     'aaaaaaaa-aaaa-aaaa-aaaa-400000000001',
     'FACT-2026-04-CALI-001',
     '2026-04-01', '2026-04-30',
     '2026-05-01', '2026-05-15', 'emitida',
     31375000.00, 5961250.00, 0.00, 37336250.00);

INSERT INTO invoice_lines (id, invoice_id, descripcion, cantidad, precio_unitario, subtotal,
                           origen, periodo_inicio, periodo_fin, metadata) VALUES
    (gen_random_uuid(),
     'aaaaaaaa-aaaa-aaaa-aaaa-600000000001',
     '10% recaudo procesado en abril 2026',
     1, 31375000.00, 31375000.00,
     'recaudo', '2026-04-01', '2026-04-30',
     '{"resource_codigo": "LIQ-001", "expedientes_count": 250, "recaudo_total": 313750000, "porcentaje": 0.10}');

-- ---------------------------------------------------------------------------
-- Sample SDK metrics
-- ---------------------------------------------------------------------------
INSERT INTO sdk_metrics (id, tenant_id, resource_codigo, resource_id, execution_time_ms,
                         tokens_used, cost_usd, success, "timestamp", metadata)
SELECT
    gen_random_uuid(),
    'aaaaaaaa-aaaa-aaaa-aaaa-100000000001',
    pr.codigo, pr.id,
    50 + (random() * 200)::INT,
    100 + (random() * 500)::INT,
    (0.001 + random() * 0.01)::NUMERIC(10,6),
    random() > 0.05,
    NOW() - ((random() * 30) || ' days')::INTERVAL,
    json_build_object('endpoint', '/api/v1/' || lower(pr.codigo), 'method', 'POST')
FROM protected_resources pr, generate_series(1, 5) g
WHERE pr.codigo IN ('LIQ-001', 'LIQ-002', 'DOC-001');

-- ---------------------------------------------------------------------------
-- Sample audit_log entries
-- ---------------------------------------------------------------------------
INSERT INTO audit_log (tenant_id, usuario_id, tabla_afectada, registro_id, operacion,
                       valores_anterior, valores_nuevo, ip_address, razon) VALUES
    ('aaaaaaaa-aaaa-aaaa-aaaa-100000000001',
     'aaaaaaaa-aaaa-aaaa-aaaa-200000000001',
     'contracts', 'aaaaaaaa-aaaa-aaaa-aaaa-400000000001', 'INSERT',
     NULL,
     '{"numero": "CONTRATO-2026-CALI-001", "estado": "activo"}'::JSONB,
     '127.0.0.1'::INET,
     'Activacion inicial de contrato Cali'),

    ('aaaaaaaa-aaaa-aaaa-aaaa-100000000001',
     'aaaaaaaa-aaaa-aaaa-aaaa-200000000001',
     'invoices', 'aaaaaaaa-aaaa-aaaa-aaaa-600000000001', 'INSERT',
     NULL,
     '{"numero_factura": "FACT-2026-04-CALI-001", "estado": "emitida", "total": 37336250.00}'::JSONB,
     '127.0.0.1'::INET,
     'Emision factura mensual abril 2026');

COMMIT;

\echo '=== Demo data loaded successfully (DEV ONLY) ==='
\echo '    Cali    : Plan Estandar, 250 expedientes, 1 factura emitida'
\echo '    Medellin: Plan Basico, en prueba'
\echo '    Users   : admin@jikkoops.demo / operador@cali.demo / operador@medellin.demo'
