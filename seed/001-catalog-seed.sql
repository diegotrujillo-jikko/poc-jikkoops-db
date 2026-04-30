-- =============================================================================
-- JikkoOps Seed Data - Initial Catalog
-- =============================================================================
-- Seeds the minimum catalog so JikkoOps is usable on a fresh install:
--   - 3 features (Liquidacion, Documentos, Servicio Ciudadano)
--   - 8 protected resources (per spec inventory)
--   - 2 products (Basico, Completo)
--   - 3 plans (Basico, Estandar, Premium)
--   - 1 revenue model config per type
-- =============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- Features
-- ---------------------------------------------------------------------------
INSERT INTO features (id, nombre, descripcion, modulo, criticidad, estado) VALUES
    ('11111111-1111-1111-1111-000000000001', 'Liquidacion',         'Calculo y emision de liquidaciones tributarias',          'SILIN', 'critica', 'activo'),
    ('11111111-1111-1111-1111-000000000002', 'Gestion Documental',  'Creacion, firma y archivo de documentos digitales',       'DOS',   'alta',    'activo'),
    ('11111111-1111-1111-1111-000000000003', 'Servicio Ciudadano',  'Notificaciones y atencion al ciudadano',                  'SOCIA', 'alta',    'activo');

-- ---------------------------------------------------------------------------
-- Protected Resources (matches inventory in 01-arquitectura/02-protected-resources.md)
-- ---------------------------------------------------------------------------
INSERT INTO protected_resources (id, codigo, nombre, tipo, modulo, feature_id, descripcion, criticidad, estado) VALUES
    -- SILIN
    ('22222222-2222-2222-2222-000000000001', 'LIQ-001', 'Boton Liquidar',                'button',   'SILIN', '11111111-1111-1111-1111-000000000001', 'Permite ejecutar liquidacion sobre un expediente seleccionado', 'critica', 'activo'),
    ('22222222-2222-2222-2222-000000000002', 'LIQ-002', 'Endpoint POST /liquidaciones',  'endpoint', 'SILIN', '11111111-1111-1111-1111-000000000001', 'Crea una liquidacion via API',                                  'critica', 'activo'),
    ('22222222-2222-2222-2222-000000000003', 'LIQ-003', 'Endpoint GET /liquidaciones',   'endpoint', 'SILIN', '11111111-1111-1111-1111-000000000001', 'Consulta detalle de liquidaciones',                             'critica', 'activo'),
    ('22222222-2222-2222-2222-000000000004', 'LIQ-004', 'Vista Dashboard Liquidacion',   'view',     'SILIN', '11111111-1111-1111-1111-000000000001', 'Dashboard con KPIs de liquidacion',                              'alta',    'activo'),
    -- DOS
    ('22222222-2222-2222-2222-000000000005', 'DOC-001', 'Crear Documento',               'button',   'DOS',   '11111111-1111-1111-1111-000000000002', 'Crear documento digital nuevo',                                  'alta',    'activo'),
    ('22222222-2222-2222-2222-000000000006', 'DOC-003', 'Firma Digital',                 'action',   'DOS',   '11111111-1111-1111-1111-000000000002', 'Aplicar firma digital a un documento',                          'critica', 'activo'),
    -- SOCIA
    ('22222222-2222-2222-2222-000000000007', 'SOC-001', 'Notificacion Manual',           'button',   'SOCIA', '11111111-1111-1111-1111-000000000003', 'Enviar notificacion manual al ciudadano',                       'alta',    'activo'),
    ('22222222-2222-2222-2222-000000000008', 'SOC-002', 'Porcentaje de Recaudo',         'action',   'SOCIA', '11111111-1111-1111-1111-000000000003', 'Activador automatico del modelo de % de recaudo',               'critica', 'activo');

-- Link features → protected_resources
INSERT INTO feature_protected_resources (feature_id, protected_resource_id)
SELECT pr.feature_id, pr.id FROM protected_resources pr WHERE pr.feature_id IS NOT NULL;

-- ---------------------------------------------------------------------------
-- Products
-- ---------------------------------------------------------------------------
INSERT INTO products (id, nombre, descripcion, estado) VALUES
    ('33333333-3333-3333-3333-000000000001', 'JikkoOps Basico',   'Producto basico: liquidacion (SILIN)',                          'activo'),
    ('33333333-3333-3333-3333-000000000002', 'JikkoOps Completo', 'Producto integral: SILIN + DOS + SOCIA',                        'activo');

-- ---------------------------------------------------------------------------
-- Revenue Model Configs (one per type)
-- ---------------------------------------------------------------------------
INSERT INTO revenue_model_configs (id, nombre, tipo, parametros) VALUES
    ('44444444-4444-4444-4444-000000000001', 'Caute - 1000 expedientes',         'CAUTE',
     '{"limite_expedientes": 1000, "precio_excedente": 50.00}'),

    ('44444444-4444-4444-4444-000000000002', 'Recaudo 10%',                      'PERCENTAGE_REVENUE',
     '{"porcentaje": 0.1000, "minimo_mensual": 50000.00}'),

    ('44444444-4444-4444-4444-000000000003', 'Por Usuario - Estandar',           'PER_USER',
     '{"precio_usuario": 2000.00}'),

    ('44444444-4444-4444-4444-000000000004', 'Por Expediente - Estandar',        'PER_EXPEDIENT',
     '{"precio_expediente": 50.00, "minimo_mensual": 10000.00}'),

    ('44444444-4444-4444-4444-000000000005', 'Caute + Recaudo Hibrido',          'CAUTE_THEN_PERCENTAGE',
     '{"limite_expedientes": 5000, "meses_caute": 6, "porcentaje": 0.1000, "minimo_mensual": 50000.00}'),

    ('44444444-4444-4444-4444-000000000006', 'Usuarios + Expedientes',           'USERS_AND_EXPEDIENTS',
     '{"precio_usuario": 1000.00, "umbral_expedientes": 500, "precio_excedente": 100.00}'),

    ('44444444-4444-4444-4444-000000000007', 'Tarifa Escalonada',                'TIERED',
     '{"tramos": [{"hasta": 500, "precio": 0}, {"hasta": 1000, "precio": 50.00}, {"hasta": 5000, "precio": 30.00}, {"precio": 20.00}]}');

-- ---------------------------------------------------------------------------
-- Plans
-- ---------------------------------------------------------------------------
INSERT INTO plans (id, nombre, descripcion, producto_id, usuario_limite, expediente_limite_mes, modelo_revenue_config, estado) VALUES
    ('55555555-5555-5555-5555-000000000001', 'Plan Basico',
     'Solo modulo de liquidacion (SILIN). Ideal para municipios pequenos.',
     '33333333-3333-3333-3333-000000000001', 50, 1000,
     '{"revenue_model_id": "44444444-4444-4444-4444-000000000001"}', 'activo'),

    ('55555555-5555-5555-5555-000000000002', 'Plan Estandar',
     'SILIN + DOS. Liquidacion y gestion documental.',
     '33333333-3333-3333-3333-000000000002', 100, 5000,
     '{"revenue_model_id": "44444444-4444-4444-4444-000000000002"}', 'activo'),

    ('55555555-5555-5555-5555-000000000003', 'Plan Premium',
     'Producto integral: SILIN + DOS + SOCIA. Sin limites.',
     '33333333-3333-3333-3333-000000000002', NULL, NULL,
     '{"revenue_model_id": "44444444-4444-4444-4444-000000000005"}', 'activo');

-- ---------------------------------------------------------------------------
-- Plan ↔ Feature mapping
-- ---------------------------------------------------------------------------
INSERT INTO plan_features (plan_id, feature_id) VALUES
    -- Plan Basico: only Liquidacion
    ('55555555-5555-5555-5555-000000000001', '11111111-1111-1111-1111-000000000001'),
    -- Plan Estandar: Liquidacion + Documental
    ('55555555-5555-5555-5555-000000000002', '11111111-1111-1111-1111-000000000001'),
    ('55555555-5555-5555-5555-000000000002', '11111111-1111-1111-1111-000000000002'),
    -- Plan Premium: all three features
    ('55555555-5555-5555-5555-000000000003', '11111111-1111-1111-1111-000000000001'),
    ('55555555-5555-5555-5555-000000000003', '11111111-1111-1111-1111-000000000002'),
    ('55555555-5555-5555-5555-000000000003', '11111111-1111-1111-1111-000000000003');

-- ---------------------------------------------------------------------------
-- Default Roles
-- ---------------------------------------------------------------------------
INSERT INTO roles (id, nombre, descripcion, permisos) VALUES
    ('66666666-6666-6666-6666-000000000001', 'admin',     'Administrador con acceso total',
     '["*:*"]'),
    ('66666666-6666-6666-6666-000000000002', 'comercial', 'Equipo comercial — contratos y planes',
     '["entities:read", "tenants:read", "contracts:*", "plans:read", "invoices:read"]'),
    ('66666666-6666-6666-6666-000000000003', 'finanzas',  'Equipo financiero — facturacion y revenue',
     '["invoices:*", "contracts:read", "tenants:read", "revenue_models:*"]'),
    ('66666666-6666-6666-6666-000000000004', 'soporte',   'Soporte tecnico — flags y operacion',
     '["feature_flags:*", "tenants:read", "audit_log:read", "sdk_metrics:read"]');

COMMIT;
