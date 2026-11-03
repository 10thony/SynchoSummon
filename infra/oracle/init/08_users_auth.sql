-- =============================================================================
-- Users & authorization
-- =============================================================================

ALTER SESSION SET CONTAINER = FREEPDB1;
ALTER SESSION SET CURRENT_SCHEMA = nas_sim;

CREATE TABLE users (
    user_id                 VARCHAR2(36)  NOT NULL,
    username                VARCHAR2(64)  NOT NULL,
    display_name            VARCHAR2(256) NOT NULL,
    email                   VARCHAR2(256),
    is_active               CHAR(1)       DEFAULT 'Y' NOT NULL
        CONSTRAINT chk_users_active CHECK (is_active IN ('Y', 'N')),
    auth_source             VARCHAR2(16)  DEFAULT 'ENTRA' NOT NULL
        CONSTRAINT chk_users_auth_source CHECK (auth_source IN ('ENTRA', 'LOCAL_DEV')),
    entra_tenant_id         VARCHAR2(36)  NOT NULL,
    entra_object_id         VARCHAR2(36)  NOT NULL,
    entra_upn               VARCHAR2(256),
    entra_display_name      VARCHAR2(256),
    created_at              TIMESTAMP(6)  DEFAULT SYSTIMESTAMP NOT NULL,
    updated_at              TIMESTAMP(6)  DEFAULT SYSTIMESTAMP NOT NULL,
    last_login_at           TIMESTAMP(6),
    CONSTRAINT pk_users PRIMARY KEY (user_id),
    CONSTRAINT uq_users_username UNIQUE (username),
    CONSTRAINT uq_users_entra_object UNIQUE (entra_object_id),
    CONSTRAINT uq_users_entra_upn UNIQUE (entra_upn)
);

-- Maps Microsoft Entra ID group object IDs to application roles (evaluated at login in C#)
CREATE TABLE entra_group_role_mapping (
    entra_group_role_mapping_id VARCHAR2(36) NOT NULL,
    entra_tenant_id             VARCHAR2(36) NOT NULL,
    entra_group_object_id       VARCHAR2(36) NOT NULL,
    role_id                     VARCHAR2(36) NOT NULL,
    is_active                   CHAR(1)    DEFAULT 'Y' NOT NULL
        CONSTRAINT chk_entra_group_role_active CHECK (is_active IN ('Y', 'N')),
    created_at                  TIMESTAMP(6) DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT pk_entra_group_role_mapping PRIMARY KEY (entra_group_role_mapping_id),
    CONSTRAINT uq_entra_group_role UNIQUE (entra_tenant_id, entra_group_object_id, role_id),
    CONSTRAINT fk_entra_group_role_role
        FOREIGN KEY (role_id) REFERENCES user_role_lookup (role_id)
);

CREATE TABLE user_role_lookup (
    role_id                 VARCHAR2(36)  NOT NULL,
    role_code               VARCHAR2(32)  NOT NULL,
    role_name               VARCHAR2(128) NOT NULL,
    description             VARCHAR2(512),
    is_system_role          CHAR(1)       DEFAULT 'N' NOT NULL
        CONSTRAINT chk_user_role_system CHECK (is_system_role IN ('Y', 'N')),
    created_at              TIMESTAMP(6)  DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT pk_user_role_lookup PRIMARY KEY (role_id),
    CONSTRAINT uq_user_role_code UNIQUE (role_code)
);

CREATE TABLE user_permissions (
    user_permission_id      VARCHAR2(36)  NOT NULL,
    user_id                 VARCHAR2(36)  NOT NULL,
    role_id                 VARCHAR2(36),
    permission_code         VARCHAR2(64),              -- direct grant when role_id is null
    facility_scope_id       VARCHAR2(36),              -- optional row-level facility scope
    granted_at              TIMESTAMP(6)  DEFAULT SYSTIMESTAMP NOT NULL,
    granted_by_user_id      VARCHAR2(36),
    expires_at              TIMESTAMP(6),
    CONSTRAINT pk_user_permissions PRIMARY KEY (user_permission_id),
    CONSTRAINT fk_user_perm_user
        FOREIGN KEY (user_id) REFERENCES users (user_id),
    CONSTRAINT fk_user_perm_role
        FOREIGN KEY (role_id) REFERENCES user_role_lookup (role_id),
    CONSTRAINT fk_user_perm_facility_scope
        FOREIGN KEY (facility_scope_id) REFERENCES facility (facility_id),
    CONSTRAINT fk_user_perm_granted_by
        FOREIGN KEY (granted_by_user_id) REFERENCES users (user_id),
    CONSTRAINT chk_user_perm_grant CHECK (
        role_id IS NOT NULL OR permission_code IS NOT NULL
    )
);

-- Role → permission matrix (permissions as codes, not DB triggers)
CREATE TABLE role_permission (
    role_permission_id      VARCHAR2(36)  NOT NULL,
    role_id                 VARCHAR2(36)  NOT NULL,
    permission_code         VARCHAR2(64)  NOT NULL,
    created_at              TIMESTAMP(6)  DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT pk_role_permission PRIMARY KEY (role_permission_id),
    CONSTRAINT uq_role_permission UNIQUE (role_id, permission_code),
    CONSTRAINT fk_role_permission_role
        FOREIGN KEY (role_id) REFERENCES user_role_lookup (role_id)
);

-- Deferred FKs from other tables
ALTER TABLE maintenance_activity
    ADD CONSTRAINT fk_maint_act_assigned_user
        FOREIGN KEY (assigned_user_id) REFERENCES users (user_id);

ALTER TABLE maintenance_log
    ADD CONSTRAINT fk_maint_log_user
        FOREIGN KEY (logged_by_user_id) REFERENCES users (user_id);

ALTER TABLE maintenance_report
    ADD CONSTRAINT fk_maint_report_user
        FOREIGN KEY (completed_by_user_id) REFERENCES users (user_id);

ALTER TABLE flight_request
    ADD CONSTRAINT fk_flight_req_user
        FOREIGN KEY (requested_by_user_id) REFERENCES users (user_id);

ALTER TABLE flight_path_request
    ADD CONSTRAINT fk_flight_path_req_user
        FOREIGN KEY (requested_by_user_id) REFERENCES users (user_id);

ALTER TABLE flight_path_request
    ADD CONSTRAINT fk_flight_path_rev_user
        FOREIGN KEY (reviewed_by_user_id) REFERENCES users (user_id);

ALTER TABLE weather_event_alert
    ADD CONSTRAINT fk_weather_alert_ack_user
        FOREIGN KEY (acknowledged_by_user_id) REFERENCES users (user_id);

ALTER TABLE equipment_alert
    ADD CONSTRAINT fk_equip_alert_ack_user
        FOREIGN KEY (acknowledged_by_user_id) REFERENCES users (user_id);

ALTER TABLE equipment_alert
    ADD CONSTRAINT fk_equip_alert_res_user
        FOREIGN KEY (resolved_by_user_id) REFERENCES users (user_id);

ALTER TABLE global_configuration
    ADD CONSTRAINT fk_global_config_user
        FOREIGN KEY (updated_by_user_id) REFERENCES users (user_id);

ALTER TABLE facility
    ADD CONSTRAINT fk_facility_created_by
        FOREIGN KEY (created_by) REFERENCES users (user_id);

ALTER TABLE facility
    ADD CONSTRAINT fk_facility_updated_by
        FOREIGN KEY (updated_by) REFERENCES users (user_id);

ALTER TABLE maintenance_activity
    ADD CONSTRAINT fk_maint_act_created_by
        FOREIGN KEY (created_by) REFERENCES users (user_id);

ALTER TABLE simulation_render_context
    ADD CONSTRAINT fk_render_context_created_by
        FOREIGN KEY (created_by_user_id) REFERENCES users (user_id);

ALTER TABLE simulation_run_state
    ADD CONSTRAINT fk_sim_run_updated_by
        FOREIGN KEY (updated_by_user_id) REFERENCES users (user_id);

ALTER TABLE simulation_snapshot
    ADD CONSTRAINT fk_sim_snapshot_created_by
        FOREIGN KEY (created_by_user_id) REFERENCES users (user_id);

CREATE INDEX idx_entra_group_role_role ON entra_group_role_mapping (role_id);

CREATE INDEX idx_user_permissions_user ON user_permissions (user_id);
CREATE INDEX idx_user_permissions_role ON user_permissions (role_id);
CREATE INDEX idx_role_permission_role ON role_permission (role_id);
