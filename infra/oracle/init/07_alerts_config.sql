-- =============================================================================
-- Alerts & global configuration
-- =============================================================================

ALTER SESSION SET CONTAINER = FREEPDB1;
ALTER SESSION SET CURRENT_SCHEMA = nas_sim;

CREATE TABLE equipment_alert (
    equipment_alert_id      VARCHAR2(36)  NOT NULL,
    equipment_id            VARCHAR2(36)  NOT NULL,
    alert_type              VARCHAR2(32)  NOT NULL,  -- FAILURE, DEGRADED, INSPECTION_DUE, etc.
    severity                VARCHAR2(16)  NOT NULL,
    title                   VARCHAR2(256) NOT NULL,
    message                 VARCHAR2(2000),
    raised_at               TIMESTAMP(6)  DEFAULT SYSTIMESTAMP NOT NULL,
    acknowledged_at         TIMESTAMP(6),
    acknowledged_by_user_id VARCHAR2(36),
    resolved_at             TIMESTAMP(6),
    resolved_by_user_id     VARCHAR2(36),
    related_maintenance_activity_id VARCHAR2(36),
    metadata_json           CLOB
        CONSTRAINT chk_equip_alert_metadata_json CHECK (metadata_json IS JSON),
    CONSTRAINT pk_equipment_alert PRIMARY KEY (equipment_alert_id),
    CONSTRAINT fk_equip_alert_equipment
        FOREIGN KEY (equipment_id) REFERENCES equipment (equipment_id),
    CONSTRAINT fk_equip_alert_severity
        FOREIGN KEY (severity) REFERENCES alert_severity_lkp (severity_code),
    CONSTRAINT fk_equip_alert_maint_activity
        FOREIGN KEY (related_maintenance_activity_id) REFERENCES maintenance_activity (maintenance_activity_id)
);

CREATE TABLE global_configuration (
    config_key              VARCHAR2(128) NOT NULL,
    config_value            CLOB          NOT NULL,
    value_type              VARCHAR2(16)  DEFAULT 'STRING' NOT NULL,  -- STRING, NUMBER, JSON, BOOL
    description             VARCHAR2(512),
    is_sensitive            CHAR(1)       DEFAULT 'N' NOT NULL
        CONSTRAINT chk_global_config_sensitive CHECK (is_sensitive IN ('Y', 'N')),
    updated_at              TIMESTAMP(6)  DEFAULT SYSTIMESTAMP NOT NULL,
    updated_by_user_id      VARCHAR2(36),
    CONSTRAINT pk_global_configuration PRIMARY KEY (config_key),
    CONSTRAINT chk_global_config_value_type CHECK (value_type IN ('STRING', 'NUMBER', 'JSON', 'BOOL'))
);

CREATE INDEX idx_equip_alert_equipment ON equipment_alert (equipment_id);
CREATE INDEX idx_equip_alert_unresolved ON equipment_alert (resolved_at, raised_at);
