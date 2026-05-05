-- =============================================================================
-- JikkoOps Control Database - Product Catalog
-- =============================================================================
-- Tables: features, protected_resources, products, plans and their junctions.
-- Dependency order: features → protected_resources → products → plans → junctions
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Table: features
-- Logical grouping of protected resources into a sellable functionality.
-- e.g. "Liquidación" groups all LIQ-* resources.
-- ---------------------------------------------------------------------------
CREATE TABLE features (
    id           UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    nombre       VARCHAR(255) NOT NULL,
    descripcion  TEXT,
    modulo       modulo       NOT NULL,
    criticidad   criticidad   NOT NULL DEFAULT 'media',
    estado       feature_estado NOT NULL DEFAULT 'activo',
    created_at   TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at   TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE features IS 'Logical feature grouping (e.g. Liquidacion, Gestion Documental). Bundles protected resources for plan assignment.';

CREATE TRIGGER trg_features_updated_at
    BEFORE UPDATE ON features
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ---------------------------------------------------------------------------
-- Table: protected_resources
-- Granular inventory of every button, endpoint, view, and action in the system.
-- Each resource has a unique code: {MODULE}-{NNN} e.g. LIQ-001, DOC-003.
-- ---------------------------------------------------------------------------
CREATE TABLE protected_resources (
    id           UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    codigo       VARCHAR(20)  NOT NULL UNIQUE,    -- e.g. 'LIQ-001'
    nombre       VARCHAR(255) NOT NULL,
    tipo         pr_tipo      NOT NULL,
    modulo       modulo       NOT NULL,
    feature_id   UUID         REFERENCES features(id) ON DELETE SET NULL,  -- NULL = huerfano
    descripcion  TEXT,
    criticidad   criticidad   NOT NULL DEFAULT 'media',
    -- Array of PR codes this resource depends on (e.g. ['LIQ-002', 'IAM-001'])
    dependencias TEXT[]       NOT NULL DEFAULT '{}',
    estado       pr_estado    NOT NULL DEFAULT 'huerfano',
    created_at   TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at   TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE  protected_resources            IS 'Exhaustive inventory of every controllable element (buttons, endpoints, views). Feature flags reference these.';
COMMENT ON COLUMN protected_resources.codigo     IS 'Unique code following pattern {MODULE}-{NNN}. Immutable once published.';
COMMENT ON COLUMN protected_resources.dependencias IS 'Array of PR codes that must also be active for this resource to work.';
COMMENT ON COLUMN protected_resources.estado     IS 'huerfano = exists in code but not yet assigned to a feature.';

CREATE TRIGGER trg_protected_resources_updated_at
    BEFORE UPDATE ON protected_resources
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ---------------------------------------------------------------------------
-- Table: products
-- A named combination of features sold as a unit (e.g. "JikkoOps Basico").
-- ---------------------------------------------------------------------------
CREATE TABLE products (
    id          UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    nombre      VARCHAR(255) NOT NULL,
    descripcion TEXT,
    estado      plan_estado  NOT NULL DEFAULT 'activo',
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE products IS 'Named product bundles (e.g. JikkoOps Basico, JikkoOps Completo). Contains features via product_features junction.';

CREATE TRIGGER trg_products_updated_at
    BEFORE UPDATE ON products
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ---------------------------------------------------------------------------
-- Table: plans
-- Commercial offering with limits and revenue model configuration.
-- e.g. "Plan Estandar" = SILIN + DOS, 100 users, 10% revenue.
-- ---------------------------------------------------------------------------
CREATE TABLE plans (
    id                     UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
    nombre                 VARCHAR(255)  NOT NULL,
    descripcion            TEXT,
    producto_id            UUID          REFERENCES products(id) ON DELETE RESTRICT,
    usuario_limite         INT,          -- NULL = unlimited
    expediente_limite_mes  INT,          -- NULL = unlimited
    precio_fijo            NUMERIC(15,2),-- NULL if revenue-model only
    -- Revenue model config JSON. Structure depends on tipo. Validated at app layer.
    -- Example: {"tipo": "CAUTE", "limite_expedientes": 1000, "porcentaje_post_caute": 0.10}
    modelo_revenue_config  JSONB         NOT NULL DEFAULT '{}',
    estado                 plan_estado   NOT NULL DEFAULT 'activo',
    created_at             TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    updated_at             TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE  plans                       IS 'Commercial offering sold to tenants. Defines feature access and revenue model.';
COMMENT ON COLUMN plans.modelo_revenue_config IS 'Revenue model params. Keys vary by type: limite_expedientes, porcentaje, precio_usuario, etc.';

CREATE TRIGGER trg_plans_updated_at
    BEFORE UPDATE ON plans
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ---------------------------------------------------------------------------
-- Junction: feature_protected_resources
-- Which protected resources belong to each feature.
-- ---------------------------------------------------------------------------
CREATE TABLE feature_protected_resources (
    feature_id            UUID NOT NULL REFERENCES features(id)            ON DELETE CASCADE,
    protected_resource_id UUID NOT NULL REFERENCES protected_resources(id) ON DELETE CASCADE,
    PRIMARY KEY (feature_id, protected_resource_id)
);

COMMENT ON TABLE feature_protected_resources IS 'M:N — which protected resources compose each feature.';

-- ---------------------------------------------------------------------------
-- Junction: plan_features
-- Which features a plan grants access to.
-- ---------------------------------------------------------------------------
CREATE TABLE plan_features (
    plan_id    UUID NOT NULL REFERENCES plans(id)    ON DELETE CASCADE,
    feature_id UUID NOT NULL REFERENCES features(id) ON DELETE CASCADE,
    PRIMARY KEY (plan_id, feature_id)
);

COMMENT ON TABLE plan_features IS 'M:N — which features are included in each plan.';

-- ---------------------------------------------------------------------------
-- Junction: plan_protected_resources
-- Explicit override list: which specific resources a plan enables.
-- (Supplements plan_features for granular per-resource overrides.)
-- ---------------------------------------------------------------------------
CREATE TABLE plan_protected_resources (
    plan_id               UUID NOT NULL REFERENCES plans(id)              ON DELETE CASCADE,
    protected_resource_id UUID NOT NULL REFERENCES protected_resources(id) ON DELETE CASCADE,
    PRIMARY KEY (plan_id, protected_resource_id)
);

COMMENT ON TABLE plan_protected_resources IS 'M:N — granular override: specific resources explicitly included/excluded per plan.';

-- ---------------------------------------------------------------------------
-- Deferred FK: tenants.plan_id -> plans(id)
-- 02-tenants.sql declares plan_id without an inline FK because plans is
-- created in this file. Adding the constraint here closes the forward reference.
-- ---------------------------------------------------------------------------
ALTER TABLE tenants
    ADD CONSTRAINT fk_tenants_plan_id
    FOREIGN KEY (plan_id) REFERENCES plans(id) ON DELETE RESTRICT;
