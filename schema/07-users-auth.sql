-- =============================================================================
-- JikkoOps Control Database - Users, Roles, MFA
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Table: users
-- Operators of JikkoOps (admins, comerciales, finanzas) and tenant-scoped users.
-- ---------------------------------------------------------------------------
CREATE TABLE users (
    id            UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    -- NULL for JikkoOps internal staff; set for tenant-scoped users
    entity_id     UUID         REFERENCES entities(id) ON DELETE RESTRICT,
    nombre        VARCHAR(255) NOT NULL,
    email         VARCHAR(255) NOT NULL UNIQUE,
    -- bcrypt/argon2 hash. Stored hash only — never plaintext.
    password_hash TEXT         NOT NULL,
    estado        user_estado  NOT NULL DEFAULT 'activo',
    ultimo_acceso TIMESTAMPTZ,
    -- Optional contact/profile data: {"telefono": "...", "cargo": "...", "departamento": "..."}
    perfil        JSONB        NOT NULL DEFAULT '{}',
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE  users           IS 'JikkoOps operators and tenant-scoped users. NULL entity_id = JikkoOps internal staff.';
COMMENT ON COLUMN users.password_hash IS 'Hashed password (bcrypt/argon2). Never stores plaintext.';

CREATE TRIGGER trg_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ---------------------------------------------------------------------------
-- Table: roles
-- Named permission bundles (e.g. 'admin', 'comercial', 'finanzas', 'soporte').
-- ---------------------------------------------------------------------------
CREATE TABLE roles (
    id          UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    nombre      VARCHAR(100) NOT NULL UNIQUE,
    descripcion TEXT,
    -- List of permission strings: ["contracts:read", "contracts:write", "flags:toggle"]
    permisos    JSONB        NOT NULL DEFAULT '[]',
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE  roles          IS 'Named permission bundles. Users get one or more roles via user_roles.';
COMMENT ON COLUMN roles.permisos IS 'JSON array of permission strings: ["resource:action", ...]';

CREATE TRIGGER trg_roles_updated_at
    BEFORE UPDATE ON roles
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ---------------------------------------------------------------------------
-- Junction: user_roles
-- Assigns roles to users, optionally scoped to a specific tenant.
-- ---------------------------------------------------------------------------
CREATE TABLE user_roles (
    id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role_id     UUID        NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
    -- NULL = role applies globally; set = role only for this tenant
    tenant_id   UUID        REFERENCES tenants(id) ON DELETE CASCADE,
    granted_by  UUID        REFERENCES users(id) ON DELETE SET NULL,
    granted_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Uniqueness: a role cannot be granted twice for the same (user, tenant_scope).
-- COALESCE turns NULL tenant_id into a sentinel zero UUID so global vs tenant-scoped
-- grants are distinguishable. PostgreSQL allows function expressions only in indexes,
-- not in PRIMARY KEY / UNIQUE constraints — hence CREATE UNIQUE INDEX.
CREATE UNIQUE INDEX uq_user_roles_scope
    ON user_roles (user_id, role_id, COALESCE(tenant_id, '00000000-0000-0000-0000-000000000000'::UUID));

COMMENT ON TABLE  user_roles           IS 'M:N user↔role assignment. Optional tenant scope for per-tenant role grants.';
COMMENT ON COLUMN user_roles.tenant_id IS 'NULL = global role; set = role only valid for this tenant.';

-- ---------------------------------------------------------------------------
-- Table: mfa_credentials
-- TOTP-based multi-factor authentication per user.
-- Used for critical operations (revenue changes, high-value liquidations).
-- ---------------------------------------------------------------------------
CREATE TABLE mfa_credentials (
    id                  UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             UUID        NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    -- TOTP secret. MUST be encrypted at rest (AES-256-GCM via app layer).
    secret              TEXT        NOT NULL,
    habilitado          BOOLEAN     NOT NULL DEFAULT false,
    intentos_fallidos   INT         NOT NULL DEFAULT 0,
    bloqueado_hasta     TIMESTAMPTZ,
    ultimo_uso          TIMESTAMPTZ,
    -- Recovery codes (one-time-use). Encrypted at rest at app layer.
    backup_codes        TEXT[]      NOT NULL DEFAULT '{}',
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    -- Reference to most recent audit_log entry related to this credential
    last_audit_log_id   UUID,

    CONSTRAINT chk_mfa_attempts CHECK (intentos_fallidos >= 0)
);

COMMENT ON TABLE  mfa_credentials              IS 'Per-user TOTP MFA. Required for critical actions. Lockout after 5 failures.';
COMMENT ON COLUMN mfa_credentials.secret       IS 'TOTP shared secret. MUST be AES-256-GCM encrypted at rest by app layer.';
COMMENT ON COLUMN mfa_credentials.backup_codes IS 'One-time recovery codes. Encrypted at rest by app layer.';

CREATE TRIGGER trg_mfa_credentials_updated_at
    BEFORE UPDATE ON mfa_credentials
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
