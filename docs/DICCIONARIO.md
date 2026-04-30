# Diccionario de Datos - JikkoOps Control DB

> **Version**: 0.1 (primer enfoque, evolutivo)
> **Idioma**: Español (es-CO) para campos comerciales, inglés para términos técnicos consolidados.

Documenta cada tabla del esquema con: propósito, campos clave, reglas de negocio, y patrones de consulta típicos.

---

## 1. `entities`

**Propósito**: Cliente físico (municipio, gobernación, DIAN). Una entidad puede tener múltiples tenants.

**Campos clave**:
- `id` (UUID) — PK
- `nit` (VARCHAR) — NIT colombiano. Único.
- `tipo` — `municipio | gobernacion | dian | otro`
- `estado` — `activo | inactivo | cancelado`
- `metadata` (JSONB) — claves esperadas: `sigia_id`, `codigo_dane`

**Reglas**:
- Cancelar una entidad NO borra sus tenants (FK RESTRICT).
- NIT debe validarse formato antes de insertar (módulo dígito de verificación).

**Consultas típicas**:
- Buscar por NIT (índice `idx_entities_nit`).
- Listar activos por región.

---

## 2. `tenants`

**Propósito**: Instancia de JikkoOps por entidad. Cada tenant tiene su propia BD operativa aislada.

**Campos clave**:
- `entity_id` (FK) — dueño físico
- `nombre_tecnico` — slug único (ej. `municipio_cali`)
- `db_connection_string` — DSN de su BD aislada (encriptado en reposo)
- `plan_id` — plan vigente
- `estado` — `activo | inactivo | en_prueba | suspendido`
- `usuarios_limite`, `expedientes_mes_limite` — desnormalizados del plan/contrato

**Reglas**:
- `fecha_vencimiento > fecha_activacion` (CHECK).
- Cambio de plan dispara resync de feature_flags (job).
- Suspender un tenant NO borra datos — sólo bloquea acceso.

**Consultas típicas**:
- Tenants activos venciendo en 90 días (`idx_tenants_vencimiento`).
- Lookup por `nombre_tecnico` para routing de API.

---

## 3. `features`

**Propósito**: Agrupación lógica de protected_resources que se vende como funcionalidad.

**Campos clave**:
- `nombre` — ej. "Liquidación", "Gestión Documental"
- `modulo` — `SILIN | DOS | SOCIA | IAM`
- `criticidad` — para priorización de incidentes

**Reglas**:
- Agrupa recursos via `feature_protected_resources` (junction).
- Eliminar feature pone los PRs en `estado = 'huerfano'` (FK SET NULL).

---

## 4. `protected_resources`

**Propósito**: Inventario granular: cada botón, endpoint, vista, acción del sistema.

**Campos clave**:
- `codigo` — único, patrón `{MODULE}-{NNN}` (ej. `LIQ-001`)
- `tipo` — `button | endpoint | view | action`
- `feature_id` — feature padre (NULL = huérfano)
- `dependencias` (TEXT[]) — códigos de PRs requeridos
- `estado` — `activo | huerfano | deprecated`

**Reglas**:
- `codigo` es **inmutable** una vez publicado (referencias en planes/tenants).
- Recursos nuevos en código entran como `huerfano` hasta ser asignados a una feature.
- Cambio de criticidad requiere code review.

**Consultas típicas**:
- Lookup por código (`idx_protected_resources_codigo`).
- Listar huérfanos para revisión periódica.

---

## 5. `products`

**Propósito**: Bundle comercial nombrado de features (ej. "JikkoOps Básico").

**Campos clave**: `nombre`, `descripcion`, `estado`

**Reglas**: Productos en `deprecated` no se ofrecen a clientes nuevos pero siguen siendo válidos para clientes con planes basados en ellos.

---

## 6. `plans`

**Propósito**: Oferta comercial concreta. Define límites y modelo de revenue.

**Campos clave**:
- `producto_id` — producto al que pertenece
- `usuario_limite`, `expediente_limite_mes` — NULL = ilimitado
- `precio_fijo` — opcional
- `modelo_revenue_config` (JSONB) — apunta a un `revenue_model_configs.id`

**Reglas**:
- Cambios en pricing requieren aprobación CFO + Legal.
- Plan en `deprecated` no se asigna a nuevos tenants.
- Acceso a features: vía `plan_features` (junction).
- Acceso explícito por recurso: vía `plan_protected_resources` (override granular).

---

## 7. `revenue_model_configs`

**Propósito**: Configuración reutilizable de modelo de revenue.

**Campos clave**:
- `tipo` — `CAUTE | PERCENTAGE_REVENUE | PER_USER | PER_EXPEDIENT | CAUTE_THEN_PERCENTAGE | USERS_AND_EXPEDIENTS | TIERED`
- `parametros` (JSONB) — varía por tipo (ver comment de columna en `04-contracts.sql`)

**Reglas**:
- Validación de schema JSONB se hace en capa de aplicación.
- No se borra: si se descontinúa, se marca `activo = false`.

---

## 8. `contracts`

**Propósito**: Acuerdo formal entre JikkoOps y un tenant.

**Campos clave**:
- `tenant_id`, `plan_id`, `revenue_model_id`
- `numero` — único, patrón `CONTRATO-{YYYY}-{CLIENTE}-{NNN}`
- `tipo_contrato` — `principal | renovacion | enmienda`
- `estado` — `borrador | en_revision | activo | vencido | cancelado`
- `limite_expedientes`, `porcentaje_recaudo` — snapshot del modelo
- `escalado_tipo`, `escalado_fecha` — track del escalado automático

**Reglas**:
- `porcentaje_recaudo` ∈ (0, 1] (CHECK).
- `fecha_vencimiento > fecha_inicio` (CHECK).
- Activación dispara sync de entitlements y flags.
- Cambios en `valor_total_cop` o `revenue_model_id` requieren MFA + audit_log.

**Consultas típicas**:
- Activos venciendo en 90 días (vista `v_contracts_expiring_90d`).
- Por tenant + estado (`idx_contracts_tenant_estado`).

---

## 9. `tenant_entitlements`

**Propósito**: Qué se le ha **otorgado** a un tenant (origen comercial). Distinto de `feature_flags` (qué está **prendido** ahora).

**Campos clave**:
- `tenant_id` — receptor
- Exactamente uno de `feature_id` o `protected_resource_id` (CHECK)
- `motivo` — ej. "renovación anual", "upgrade de plan"
- `aprobado_por` — usuario que aprobó

**Reglas**: Sincroniza con `feature_flags` mediante job cada 5 min.

---

## 10. `feature_flags`

**Propósito**: Estado runtime ON/OFF de cada protected_resource por tenant.

**Campos clave**:
- `(tenant_id, protected_resource_id)` — UNIQUE
- `codigo_recurso` — desnormalizado para lookups rápidos
- `activo` (BOOLEAN)
- `razon` — auditable

**Reglas**:
- ⚠️ **NUNCA editar directamente en BD** — usar UI/API de JikkoOps.
- Cada cambio se replica en `feature_flag_audit`.
- Cacheado en Redis con TTL 5 min — fallback a BD si Redis cae.
- Si `entitlement` y `flag` divergen, prevalece `entitlement` (resync).

**Consultas típicas**:
- "¿está prendido X recurso para Y tenant?" (`idx_feature_flags_tenant_resource`).

---

## 11. `feature_flag_audit`

**Propósito**: Log inmutable de cada cambio de flag.

**Campos clave**: `flag_id`, `accion`, `valor_anterior`, `valor_nuevo`, `activado_por`, `razon`, `contexto`

**Reglas**:
- **Insert-only**. UPDATE/DELETE prohibidos a nivel app + recomendado RLS.
- Retención mínima: 7 años (compliance fiscal).

---

## 12. `invoices`

**Propósito**: Documento de facturación emitido a un tenant por un período.

**Campos clave**:
- `numero_factura` — único
- `periodo_inicio`, `periodo_fin`
- `estado` — `borrador | emitida | pagada | vencida | anulada`
- `subtotal`, `iva`, `descuentos`, `total` — CHECK: `total = subtotal + iva - descuentos`
- `documento_pdf_ref` — referencia a PDF en object storage

**Reglas**:
- Anulación requiere razón + audit_log.
- Cambios después de `emitida` requieren aprobación.

---

## 13. `invoice_lines`

**Propósito**: Líneas de detalle de cada factura (queryable, no en JSONB).

**Campos clave**:
- `origen` — `expediente | usuarios | recaudo | fijo | minimo | descuento`
- `metadata` — auditoría del cálculo (fórmula, conteos)

**Reglas**: ON DELETE CASCADE de invoice (junction de detalle).

---

## 14. `expedientes_sync`

**Propósito**: Registro de cada expediente reportado por SILIN, para facturación.

**Campos clave**:
- `(tenant_id, expediente_id_externo)` — UNIQUE
- `fecha`, `estado`, `sync_source`

**Reglas**:
- Idempotente: mismo expediente no se cuenta dos veces.
- Volumen objetivo: 50M/mes — particionar por mes cuando llegue el momento.

---

## 15. `users`

**Propósito**: Operadores de JikkoOps y usuarios scopeados a tenant.

**Campos clave**:
- `entity_id` — NULL = staff JikkoOps; set = usuario de un tenant
- `email` — único
- `password_hash` — bcrypt/argon2
- `estado` — `activo | inactivo | bloqueado`

---

## 16. `roles` + `user_roles`

**Propósito**: RBAC. `roles` define bundles de permisos; `user_roles` asigna roles a usuarios.

**Campos clave**:
- `roles.permisos` (JSONB) — array de strings `"resource:action"`
- `user_roles.tenant_id` — opcional, para roles tenant-scoped

**Reglas**:
- `permisos: ["*:*"]` = admin total.
- Un usuario puede tener múltiples roles (sumativos).

---

## 17. `mfa_credentials`

**Propósito**: TOTP MFA por usuario para acciones críticas.

**Campos clave**:
- `secret` — encriptado AES-256-GCM por capa de app
- `intentos_fallidos` — lockout tras 5
- `bloqueado_hasta` — timestamp del lockout
- `backup_codes` — códigos de un solo uso, encriptados

**Reglas**: 
- Requerido en endpoints críticos: liquidación >$50M, cambio de pricing, anulación de factura.

---

## 18. `audit_log`

**Propósito**: Log inmutable de todo cambio en datos de negocio.

**Campos clave**: `tabla_afectada`, `registro_id`, `operacion`, `valores_anterior`, `valores_nuevo`, `timestamp`, `ip_address`, `razon`

**Reglas**:
- ⚠️ **Insert-only**. Bloquear UPDATE/DELETE a nivel app y RLS.
- Retención mínima: **7 años** (Colombia, requisito fiscal).
- Particionar mensualmente cuando supere ~10M filas.

**Consultas típicas**:
- Por tabla + registro (`idx_audit_log_tabla_registro`).
- Por tenant + rango de tiempo.

---

## 19. `sdk_metrics`

**Propósito**: Métricas de cada ejecución de un protected_resource (latencia, costo, success).

**Campos clave**:
- `resource_codigo` — desnormalizado para filtrar
- `execution_time_ms`, `tokens_used`, `cost_usd`
- `success`, `error_code`

**Reglas**: Volumen alto — particionar mensualmente al escalar.

**Consultas típicas**:
- Costo total por tenant en período.
- Recursos top por latencia/costo.

---

## Tablas-Junction (sin diccionario completo)

- `feature_protected_resources` — features ↔ recursos
- `plan_features` — planes ↔ features
- `plan_protected_resources` — planes ↔ recursos (override granular)
- `user_roles` — usuarios ↔ roles (con tenant_id opcional)

Todas con CASCADE delete porque sólo representan asociaciones.

---

## Vistas

- `v_tenant_active_flags` — flags activos por tenant.
- `v_contracts_expiring_90d` — pipeline de renovación.
- `v_revenue_summary` — postura de revenue de contratos activos.
- `v_invoice_totals` — agregados de facturación por tenant.
