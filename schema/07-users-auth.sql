-- =============================================================================
-- JikkoOps Control Database - Users and Authentication
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Table: users
-- JikkoOps operators and admins. Not end-users of the tenant applications.
-- ---------------------------------------------------------------------------

CREATE TABLE users (
    id              UUID        NOT NULL DEFAULT gen_random_uuid(),
    -- NULL for global admins; set to an entity for entity-scoped operators
    entity_id       UUID,
    nombre          VARCHAR(150) NOT NULL,
    email           VARCHAR(255) NOT NULL,
    -- bcrypt hash (cost factor >= 12). Never store plaintext.
    password_hash   TEXT        NOT NULL,
    estado          user_estado NOT NULL DEFAULT 'activo',
    ultimo_acceso   TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT pk_users             PRIMARY KEY (id),
    CONSTRAINT uq_users_email       UNIQUE (email),
    CONSTRAINT fk_users_entity      FOREIGN KEY (entity_id)
                                        REFERENCES entities (id) ON DELETE RESTRICT
);

COMMENT ON TABLE users IS
    'JikkoOps platform operators and administrators. '
    'Not to be confused with end-users of the tenant government applications.';
COMMENT ON COLUMN users.password_hash IS
    'bcrypt hash with cost factor >= 12. Never store or log the plaintext password.';

CREATE TRIGGER trg_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ---------------------------------------------------------------------------
-- Table: roles
-- ---------------------------------------------------------------------------

CREATE TABLE roles (
    id          UUID        NOT NULL DEFAULT gen_random_uuid(),
    nombre      VARCHAR(100) NOT NULL,
    descripcion TEXT,
    -- Array of permission strings. e.g. ["tenants:read", "flags:write", "invoices:approve"]
    permisos    JSONB       NOT NULL DEFAULT '[]',
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT pk_roles         PRIMARY KEY (id),
    CONSTRAINT uq_roles_nombre  UNIQUE (nombre)
);

COMMENT ON TABLE roles IS 'RBAC roles for JikkoOps operators. Permissions are stored as JSON array of strings.';
COMMENT ON COLUMN roles.permisos IS
    'Array of permission strings. e.g. ["tenants:read", "flags:write", "invoices:approve", "contracts:activate"]';

CREATE TRIGGER trg_roles_updated_at
    BEFORE UPDATE ON roles
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ---------------------------------------------------------------------------
-- Table: user_roles
-- ---------------------------------------------------------------------------

CREATE TABLE user_roles (
    user_id     UUID        NOT NULL,
    role_id     UUID        NOT NULL,
    -- Scope: NULL = global; set to a tenant_id for tenant-scoped role assignment
    tenant_id   UUID,
    granted_by  UUID        NOT NULL,
    granted_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT pk_user_roles        PRIMARY KEY (user_id, role_id, COALESCE(tenant_id, '00000000-0000-0000-0000-000000000000'::UUID)),
    CONSTRAINT fk_ur_user           FOREIGN KEY (user_id)
                                        REFERENCES users (id) ON DELETE CASCADE,
    CONSTRAINT fk_ur_role           FOREIGN KEY (role_id)
                                        REFERENCES roles (id) ON DELETE CASCADE,
    CONSTRAINT fk_ur_tenant         FOREIGN KEY (tenant_id)
                                        REFERENCES tenants (id) ON DELETE CASCADE,
    CONSTRAINT fk_ur_granted_by     FOREIGN KEY (granted_by)
                                        REFERENCES users (id) ON DELETE RESTRICT
);

COMMENT ON TABLE user_roles IS
    'Assigns roles to users, optionally scoped to a specific tenant. '
    'NULL tenant_id = global role valid across all tenants.';

-- ---------------------------------------------------------------------------
-- Table: mfa_credentials
-- TOTP-based MFA for operators accessing critical endpoints.
-- ---------------------------------------------------------------------------

CREATE TABLE mfa_credentials (
    id                  UUID        NOT NULL DEFAULT gen_random_uuid(),
    user_id             UUID        NOT NULL,
    -- AES-256-GCM encrypted TOTP secret. Must be decrypted at application layer only.
    -- Never log, serialize, or expose in API responses.
    secret              TEXT        NOT NULL,
    habilitado          BOOLEAN     NOT NULL DEFAULT false,
    -- Counter for failed TOTP attempts. Locked after 5 consecutive failures.
    intentos_fallidos   INT         NOT NULL DEFAULT 0,
    -- NULL = not locked; set to a future timestamp to enforce lockout duration
    bloqueado_hasta     TIMESTAMPTZ,
    ultimo_uso          TIMESTAMPTZ,
    -- AES-256-GCM encrypted backup codes (one-time use for account recovery)
    backup_codes        TEXT[]      NOT NULL DEFAULT '{}',
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    -- FK to audit_log for the event that created/updated these credentials
    audit_log_id        UUID,

    CONSTRAINT pk_mfa_credentials       PRIMARY KEY (id),
    CONSTRAINT uq_mfa_credentials_user  UNIQUE (user_id),
    CONSTRAINT fk_mfa_user              FOREIGN KEY (user_id)
                                            REFERENCES users (id) ON DELETE CASCADE,
    CONSTRAINT chk_mfa_intentos         CHECK (intentos_fallidos >= 0 AND intentos_fallidos <= 10)
);

COMMENT ON TABLE mfa_credentials IS
    'TOTP MFA credentials for JikkoOps operators. Required for critical endpoints: '
    'POST /liquidaciones, PUT /feature-flags, POST /contracts/activate, DELETE /invoices.';
COMMENT ON COLUMN mfa_credentials.secret IS
    'AES-256-GCM encrypted TOTP secret. Application-layer decryption only. Never log.';
COMMENT ON COLUMN mfa_credentials.backup_codes IS
    'AES-256-GCM encrypted one-time recovery codes. Each code consumed on use.';
