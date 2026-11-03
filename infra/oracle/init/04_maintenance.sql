-- =============================================================================
-- Maintenance
-- =============================================================================

ALTER SESSION SET CONTAINER = FREEPDB1;
ALTER SESSION SET CURRENT_SCHEMA = nas_sim;

CREATE TABLE maintenance_activity (
    maintenance_activity_id VARCHAR2(36)  NOT NULL,
    equipment_id            VARCHAR2(36)  NOT NULL,
    originating_facility_id VARCHAR2(36)  NOT NULL,
    activity_type_code      VARCHAR2(32)  NOT NULL,
    maintenance_status      VARCHAR2(32)  DEFAULT 'PLANNED' NOT NULL,
    priority                NUMBER(2)     DEFAULT 3 NOT NULL,  -- 1=critical .. 5=low
    title                   VARCHAR2(256) NOT NULL,
    description             VARCHAR2(2000),
    scheduled_start_at      TIMESTAMP(6),
    scheduled_end_at        TIMESTAMP(6),
    actual_start_at         TIMESTAMP(6),
    actual_end_at           TIMESTAMP(6),
    assigned_user_id        VARCHAR2(36),                      -- FK added in users script
    estimated_duration_hrs  NUMBER(10, 2),
    created_at              TIMESTAMP(6)  DEFAULT SYSTIMESTAMP NOT NULL,
    updated_at              TIMESTAMP(6)  DEFAULT SYSTIMESTAMP NOT NULL,
    created_by              VARCHAR2(36),
    CONSTRAINT pk_maintenance_activity PRIMARY KEY (maintenance_activity_id),
    CONSTRAINT fk_maint_act_equipment
        FOREIGN KEY (equipment_id) REFERENCES equipment (equipment_id),
    CONSTRAINT fk_maint_act_facility
        FOREIGN KEY (originating_facility_id) REFERENCES facility (facility_id),
    CONSTRAINT fk_maint_act_type
        FOREIGN KEY (activity_type_code) REFERENCES maintenance_activity_type_lkp (activity_type_code),
    CONSTRAINT fk_maint_act_status
        FOREIGN KEY (maintenance_status) REFERENCES maintenance_status_lkp (status_code),
    CONSTRAINT chk_maint_priority CHECK (priority BETWEEN 1 AND 5)
);

-- Deferred FK from equipment_part_order
ALTER TABLE equipment_part_order
    ADD CONSTRAINT fk_part_order_maint_activity
        FOREIGN KEY (maintenance_activity_id) REFERENCES maintenance_activity (maintenance_activity_id);

-- Links a maintenance activity to affected facilities (dispatch, multi-site work)
CREATE TABLE facility_maintenance_activity (
    facility_maintenance_activity_id VARCHAR2(36) NOT NULL,
    facility_id                      VARCHAR2(36) NOT NULL,
    maintenance_activity_id          VARCHAR2(36) NOT NULL,
    role_type                        VARCHAR2(32) NOT NULL,  -- SITE, DISPATCH_FROM, SUPPORT
    created_at                       TIMESTAMP(6) DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT pk_facility_maint_activity PRIMARY KEY (facility_maintenance_activity_id),
    CONSTRAINT uq_facility_maint_activity UNIQUE (facility_id, maintenance_activity_id, role_type),
    CONSTRAINT fk_fma_facility
        FOREIGN KEY (facility_id) REFERENCES facility (facility_id),
    CONSTRAINT fk_fma_maint_activity
        FOREIGN KEY (maintenance_activity_id) REFERENCES maintenance_activity (maintenance_activity_id)
);

CREATE TABLE maintenance_log (
    maintenance_log_id      VARCHAR2(36)  NOT NULL,
    maintenance_activity_id VARCHAR2(36)  NOT NULL,
    log_entry_type          VARCHAR2(32)  NOT NULL,
    message                 VARCHAR2(4000) NOT NULL,
    logged_at               TIMESTAMP(6)  DEFAULT SYSTIMESTAMP NOT NULL,
    logged_by_user_id       VARCHAR2(36),
    facility_id             VARCHAR2(36),
    equipment_id            VARCHAR2(36),
    runway_id               VARCHAR2(36),
    location_label          VARCHAR2(64),
    metadata_json           CLOB
        CONSTRAINT chk_maint_log_metadata_json CHECK (metadata_json IS JSON),
    CONSTRAINT pk_maintenance_log PRIMARY KEY (maintenance_log_id),
    CONSTRAINT fk_maint_log_activity
        FOREIGN KEY (maintenance_activity_id) REFERENCES maintenance_activity (maintenance_activity_id),
    CONSTRAINT fk_maint_log_entry_type
        FOREIGN KEY (log_entry_type) REFERENCES log_entry_type_lkp (log_entry_type_code),
    CONSTRAINT fk_maint_log_facility
        FOREIGN KEY (facility_id) REFERENCES facility (facility_id),
    CONSTRAINT fk_maint_log_equipment
        FOREIGN KEY (equipment_id) REFERENCES equipment (equipment_id),
    CONSTRAINT fk_maint_log_runway
        FOREIGN KEY (runway_id) REFERENCES runway (runway_id)
);

CREATE TABLE maintenance_report (
    maintenance_report_id   VARCHAR2(36)  NOT NULL,
    maintenance_activity_id VARCHAR2(36)  NOT NULL,
    findings                CLOB          NOT NULL,
    actions_taken           CLOB          NOT NULL,
    parts_consumed_json     CLOB
        CONSTRAINT chk_maint_report_parts_json CHECK (parts_consumed_json IS JSON),
    equipment_restored      CHAR(1)       DEFAULT 'N' NOT NULL
        CONSTRAINT chk_maint_report_restored CHECK (equipment_restored IN ('Y', 'N')),
    completed_at            TIMESTAMP(6)  NOT NULL,
    completed_by_user_id    VARCHAR2(36),
    created_at              TIMESTAMP(6)  DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT pk_maintenance_report PRIMARY KEY (maintenance_report_id),
    CONSTRAINT uq_maint_report_activity UNIQUE (maintenance_activity_id),
    CONSTRAINT fk_maint_report_activity
        FOREIGN KEY (maintenance_activity_id) REFERENCES maintenance_activity (maintenance_activity_id)
);

CREATE INDEX idx_maint_act_equipment ON maintenance_activity (equipment_id);
CREATE INDEX idx_maint_act_status ON maintenance_activity (maintenance_status);
CREATE INDEX idx_maint_act_scheduled ON maintenance_activity (scheduled_start_at);
CREATE INDEX idx_maint_log_activity ON maintenance_log (maintenance_activity_id);
CREATE INDEX idx_maint_log_facility_logged ON maintenance_log (facility_id, logged_at);
CREATE INDEX idx_maint_log_equipment_logged ON maintenance_log (equipment_id, logged_at);
CREATE INDEX idx_maint_log_type_logged ON maintenance_log (log_entry_type, logged_at);
CREATE INDEX idx_fma_facility ON facility_maintenance_activity (facility_id);
