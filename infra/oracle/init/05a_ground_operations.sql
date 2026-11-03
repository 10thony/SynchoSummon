-- =============================================================================
-- Ground operations (parallel turn activities: boarding, fueling, loading)
-- =============================================================================

ALTER SESSION SET CONTAINER = FREEPDB1;
ALTER SESSION SET CURRENT_SCHEMA = nas_sim;

CREATE TABLE ground_operation_activity (
    ground_operation_activity_id VARCHAR2(36)  NOT NULL,
    flight_operation_id          VARCHAR2(36)  NOT NULL,
    aircraft_id                  VARCHAR2(36)  NOT NULL,
    facility_id                  VARCHAR2(36)  NOT NULL,
    activity_type_code           VARCHAR2(32)  NOT NULL,
    activity_status              VARCHAR2(32)  DEFAULT 'PLANNED' NOT NULL,
    title                        VARCHAR2(256) NOT NULL,
    description                  VARCHAR2(2000),
    progress_pct                 NUMBER(5,2)   DEFAULT 0 NOT NULL,
    scheduled_start_at           TIMESTAMP(6),
    scheduled_end_at             TIMESTAMP(6),
    actual_start_at              TIMESTAMP(6),
    actual_end_at                TIMESTAMP(6),
    estimated_duration_min       NUMBER(8,2),
    priority                     NUMBER(2)     DEFAULT 3 NOT NULL,
    metadata_json                CLOB
        CONSTRAINT chk_ground_op_activity_metadata_json CHECK (metadata_json IS JSON),
    created_at                   TIMESTAMP(6)  DEFAULT SYSTIMESTAMP NOT NULL,
    updated_at                   TIMESTAMP(6)  DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT pk_ground_operation_activity PRIMARY KEY (ground_operation_activity_id),
    CONSTRAINT fk_ground_op_act_flight
        FOREIGN KEY (flight_operation_id) REFERENCES flight_operation (flight_operation_id),
    CONSTRAINT fk_ground_op_act_aircraft
        FOREIGN KEY (aircraft_id) REFERENCES aircraft (aircraft_id),
    CONSTRAINT fk_ground_op_act_facility
        FOREIGN KEY (facility_id) REFERENCES facility (facility_id),
    CONSTRAINT fk_ground_op_act_type
        FOREIGN KEY (activity_type_code) REFERENCES ground_operation_activity_type_lkp (activity_type_code),
    CONSTRAINT fk_ground_op_act_status
        FOREIGN KEY (activity_status) REFERENCES ground_operation_status_lkp (status_code),
    CONSTRAINT chk_ground_op_progress CHECK (progress_pct BETWEEN 0 AND 100),
    CONSTRAINT chk_ground_op_priority CHECK (priority BETWEEN 1 AND 5)
);

CREATE TABLE ground_operation_log (
    ground_operation_log_id      VARCHAR2(36)  NOT NULL,
    ground_operation_activity_id VARCHAR2(36)  NOT NULL,
    log_entry_type               VARCHAR2(32)  NOT NULL,
    message                      VARCHAR2(4000) NOT NULL,
    logged_at                    TIMESTAMP(6)  DEFAULT SYSTIMESTAMP NOT NULL,
    logged_by_user_id            VARCHAR2(36),
    facility_id                  VARCHAR2(36),
    equipment_id                 VARCHAR2(36),
    runway_id                    VARCHAR2(36),
    location_label               VARCHAR2(64),
    metadata_json                CLOB
        CONSTRAINT chk_ground_op_log_metadata_json CHECK (metadata_json IS JSON),
    CONSTRAINT pk_ground_operation_log PRIMARY KEY (ground_operation_log_id),
    CONSTRAINT fk_ground_op_log_activity
        FOREIGN KEY (ground_operation_activity_id) REFERENCES ground_operation_activity (ground_operation_activity_id),
    CONSTRAINT fk_ground_op_log_entry_type
        FOREIGN KEY (log_entry_type) REFERENCES log_entry_type_lkp (log_entry_type_code),
    CONSTRAINT fk_ground_op_log_facility
        FOREIGN KEY (facility_id) REFERENCES facility (facility_id),
    CONSTRAINT fk_ground_op_log_equipment
        FOREIGN KEY (equipment_id) REFERENCES equipment (equipment_id),
    CONSTRAINT fk_ground_op_log_runway
        FOREIGN KEY (runway_id) REFERENCES runway (runway_id)
);

CREATE INDEX idx_ground_op_act_flight ON ground_operation_activity (flight_operation_id);
CREATE INDEX idx_ground_op_act_status ON ground_operation_activity (activity_status);
CREATE INDEX idx_ground_op_act_type ON ground_operation_activity (activity_type_code);
CREATE INDEX idx_ground_op_act_sched_start ON ground_operation_activity (scheduled_start_at);
CREATE INDEX idx_ground_op_log_activity ON ground_operation_log (ground_operation_activity_id);
CREATE INDEX idx_ground_op_log_facility_logged ON ground_operation_log (facility_id, logged_at);
CREATE INDEX idx_ground_op_log_equipment_logged ON ground_operation_log (equipment_id, logged_at);
CREATE INDEX idx_ground_op_log_type_logged ON ground_operation_log (log_entry_type, logged_at);
