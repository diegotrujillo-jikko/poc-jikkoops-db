-- =============================================================================
-- JikkoOps Control Database - Catalog Seed Data
-- =============================================================================
-- Inserts the foundational catalog: features, protected resources, products,
-- plans, and one revenue model config per type.
-- Safe to re-run (uses ON CONFLICT DO NOTHING).
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Features (3)
-- ---------------------------------------------------------------------------

INSERT INTO features (id, nombre, descripcion, modulo, criticidad, estado) VALUES
(
    'f1000000-0000-0000-0000-000000000001',
    'Liquidación',
    'Funcionalidades del módulo de liquidación tributaria y de servicios',
    'SILIN', 'critica', 'activo'
),
(
    'f1000000-0000-0000-0000-000000000002',
    'Gestión Documental',
    'Funcionalidades para creación, firma y gestión de documentos oficiales',
    'DOS', 'alta', 'activo'
),
(
    'f1000000-0000-0000-0000-000000000003',
    'Servicio al Ciudadano',
    'Funcionalidades para notificaciones y atención a ciudadanos',
    'SOCIA', 'alta', 'activo'
)
ON CONFLICT (nombre, modulo) DO NOTHING;

-- ---------------------------------------------------------------------------
-- Protected Resources (8)
-- ---------------------------------------------------------------------------

INSERT INTO protected_resources (id, codigo, nombre, tipo, modulo, feature_id, descripcion, criticidad, estado) VALUES
-- SILIN resources
(
    'a1000000-0000-0000-0000-000000000001',
    'LIQ-001', 'Botón Liquidar', 'button', 'SILIN',
    'f1000000-0000-0000-0000-000000000001',
    'Permite al usuario iniciar el proceso de liquidación de un expediente',
    'critica', 'activo'
),
(
    'a1000000-0000-0000-0000-000000000002',
    'LIQ-002', 'Endpoint POST /liquidaciones', 'endpoint', 'SILIN',
    'f1000000-0000-0000-0000-000000000001',
    'API endpoint para crear una nueva liquidación',
    'critica', 'activo'
),
(
    'a1000000-0000-0000-0000-000000000003',
    'LIQ-003', 'Endpoint GET /liquidaciones/{id}', 'endpoint', 'SILIN',
    'f1000000-0000-0000-0000-000000000001',
    'API endpoint para consultar una liquidación específica',
    'critica', 'activo'
),
(
    'a1000000-0000-0000-0000-000000000004',
    'LIQ-004', 'Dashboard de Liquidación', 'view', 'SILIN',
    'f1000000-0000-0000-0000-000000000001',
    'Vista del dashboard con métricas y estado de liquidaciones',
    'alta', 'activo'
),
-- DOS resources
(
    'a1000000-0000-0000-0000-000000000005',
    'DOC-001', 'Crear Documento', 'button', 'DOS',
    'f1000000-0000-0000-0000-000000000002',
    'Permite crear un nuevo documento oficial en el sistema',
    'alta', 'activo'
),
(
    'a1000000-0000-0000-0000-000000000006',
    'DOC-003', 'Firma Digital', 'action', 'DOS',
    'f1000000-0000-0000-0000-000000000002',
    'Permite aplicar firma digital a documentos oficiales',
    'critica', 'activo'
),
-- SOCIA resources
(
    'a1000000-0000-0000-0000-000000000007',
    'SOC-001', 'Enviar Notificación Manual', 'button', 'SOCIA',
    'f1000000-0000-0000-0000-000000000003',
    'Permite enviar una notificación manual a un ciudadano',
    'alta', 'activo'
),
(
    'a1000000-0000-0000-0000-000000000008',
    'SOC-002', 'Enviar Notificación Digital', 'action', 'SOCIA',
    'f1000000-0000-0000-0000-000000000003',
    'Envía notificación digital automática (SMS, email, app)',
    'media', 'activo'
)
ON CONFLICT (codigo) DO NOTHING;

-- ---------------------------------------------------------------------------
-- feature_protected_resources junctions
-- ---------------------------------------------------------------------------

INSERT INTO feature_protected_resources (feature_id, protected_resource_id) VALUES
('f1000000-0000-0000-0000-000000000001', 'a1000000-0000-0000-0000-000000000001'),
('f1000000-0000-0000-0000-000000000001', 'a1000000-0000-0000-0000-000000000002'),
('f1000000-0000-0000-0000-000000000001', 'a1000000-0000-0000-0000-000000000003'),
('f1000000-0000-0000-0000-000000000001', 'a1000000-0000-0000-0000-000000000004'),
('f1000000-0000-0000-0000-000000000002', 'a1000000-0000-0000-0000-000000000005'),
('f1000000-0000-0000-0000-000000000002', 'a1000000-0000-0000-0000-000000000006'),
('f1000000-0000-0000-0000-000000000003', 'a1000000-0000-0000-0000-000000000007'),
('f1000000-0000-0000-0000-000000000003', 'a1000000-0000-0000-0000-000000000008')
ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- Products (2)
-- ---------------------------------------------------------------------------

INSERT INTO products (id, nombre, descripcion, estado) VALUES
(
    'b1000000-0000-0000-0000-000000000001',
    'JikkoOps Básico',
    'Producto base con módulo de liquidación SILIN para entidades pequeñas',
    'activo'
),
(
    'b1000000-0000-0000-0000-000000000002',
    'JikkoOps Completo',
    'Producto completo con SILIN + DOS + SOCIA para entidades de mediano y gran tamaño',
    'activo'
)
ON CONFLICT (nombre) DO NOTHING;

-- ---------------------------------------------------------------------------
-- Plans (3)
-- ---------------------------------------------------------------------------

INSERT INTO plans (id, nombre, descripcion, producto_id, usuario_limite, expediente_limite_mes, precio_fijo, modelo_revenue_default, estado) VALUES
(
    'c1000000-0000-0000-0000-000000000001',
    'Plan Básico',
    'Acceso a liquidación básica. Ideal para municipios pequeños.',
    'b1000000-0000-0000-0000-000000000001',
    50, 1000, NULL,
    '{"tipo": "CAUTE", "limite_expedientes": 1000, "precio_por_excedente_cop": 5000}',
    'activo'
),
(
    'c1000000-0000-0000-0000-000000000002',
    'Plan Estándar',
    'Liquidación + Gestión Documental. Para municipios medianos.',
    'b1000000-0000-0000-0000-000000000002',
    100, 5000, NULL,
    '{"tipo": "CAUTE_THEN_PERCENTAGE", "limite_expedientes": 5000, "meses_caute": 6, "porcentaje_post_caute": 0.1000, "minimo_cop": 50000}',
    'activo'
),
(
    'c1000000-0000-0000-0000-000000000003',
    'Plan Premium',
    'Acceso completo: SILIN + DOS + SOCIA. Para gobernaciones y municipios grandes.',
    'b1000000-0000-0000-0000-000000000002',
    NULL, NULL, NULL,
    '{"tipo": "PERCENTAGE_REVENUE", "porcentaje": 0.1000, "minimo_cop": 100000}',
    'activo'
)
ON CONFLICT (nombre) DO NOTHING;

-- plan_features junctions
INSERT INTO plan_features (plan_id, feature_id) VALUES
-- Plan Básico: SILIN only
('c1000000-0000-0000-0000-000000000001', 'f1000000-0000-0000-0000-000000000001'),
-- Plan Estándar: SILIN + DOS
('c1000000-0000-0000-0000-000000000002', 'f1000000-0000-0000-0000-000000000001'),
('c1000000-0000-0000-0000-000000000002', 'f1000000-0000-0000-0000-000000000002'),
-- Plan Premium: all
('c1000000-0000-0000-0000-000000000003', 'f1000000-0000-0000-0000-000000000001'),
('c1000000-0000-0000-0000-000000000003', 'f1000000-0000-0000-0000-000000000002'),
('c1000000-0000-0000-0000-000000000003', 'f1000000-0000-0000-0000-000000000003')
ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- Revenue Model Configs — one per type
-- ---------------------------------------------------------------------------

INSERT INTO revenue_model_configs (nombre, tipo, parametros) VALUES
(
    'Caute Básico — 1000 expedientes',
    'CAUTE',
    '{"limite_expedientes": 1000, "precio_por_excedente_cop": 5000}'
),
(
    'Porcentaje Recaudo 10%',
    'PERCENTAGE_REVENUE',
    '{"porcentaje": 0.1000, "minimo_cop": 50000}'
),
(
    'Por Usuario — 20.000 COP/mes',
    'PER_USER',
    '{"precio_usuario_cop": 20000, "minimo_usuarios": 10}'
),
(
    'Por Expediente — 500 COP',
    'PER_EXPEDIENT',
    '{"precio_expediente_cop": 500, "minimo_mensual_cop": 10000}'
),
(
    'Caute 6 meses luego 10% Recaudo',
    'CAUTE_THEN_PERCENTAGE',
    '{"limite_expedientes": 1000, "meses_caute": 6, "porcentaje_post_caute": 0.1000, "minimo_cop": 50000}'
),
(
    'Usuarios + Expedientes Excedente',
    'USERS_AND_EXPEDIENTS',
    '{"precio_usuario_cop": 10000, "umbral_expedientes": 500, "precio_excedente_cop": 1000}'
),
(
    'Tarifas Escalonadas por Volumen',
    'TIERED',
    '{"bandas": [{"desde": 0, "hasta": 500, "precio_cop": 0}, {"desde": 501, "hasta": 1000, "precio_cop": 5000}, {"desde": 1001, "hasta": null, "precio_cop": 3000}]}'
)
ON CONFLICT (nombre) DO NOTHING;
