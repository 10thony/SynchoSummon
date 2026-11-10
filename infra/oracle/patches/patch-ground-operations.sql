-- Apply ground operations schema to an existing nas_sim database.
-- Run: docker exec -i syncengine-oracle sqlplus -s nas_sim/<ORACLE_APP_PASSWORD>@//localhost:1522/FREEPDB1 @/path/to/patch-ground-operations.sql

ALTER SESSION SET CONTAINER = FREEPDB1;
ALTER SESSION SET CURRENT_SCHEMA = nas_sim;

BEGIN
    EXECUTE IMMEDIATE 'ALTER TABLE incident_type_lkp ADD (
        behavior_json CLOB
            CONSTRAINT chk_incident_type_behavior_json CHECK (behavior_json IS JSON)
    )';
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE != -1430 THEN RAISE; END IF;
END;
/

BEGIN EXECUTE IMMEDIATE q'[
CREATE TABLE ground_operation_activity_type_lkp (
    activity_type_code       VARCHAR2(32)  NOT NULL,
    display_name             VARCHAR2(128) NOT NULL,
    default_duration_min     NUMBER(8,2)   DEFAULT 30 NOT NULL,
    required_for_departure   CHAR(1)       DEFAULT 'Y' NOT NULL,
    sort_order               NUMBER(5)     DEFAULT 0 NOT NULL,
    description              VARCHAR2(512),
    CONSTRAINT pk_ground_op_activity_type_lkp PRIMARY KEY (activity_type_code),
    CONSTRAINT chk_ground_op_type_required CHECK (required_for_departure IN ('Y', 'N'))
)]'; EXCEPTION WHEN OTHERS THEN IF SQLCODE != -955 THEN RAISE; END IF; END;
/

BEGIN EXECUTE IMMEDIATE q'[
CREATE TABLE ground_operation_status_lkp (
    status_code          VARCHAR2(32)  NOT NULL,
    display_name         VARCHAR2(128) NOT NULL,
    is_terminal          CHAR(1)       DEFAULT 'N' NOT NULL,
    CONSTRAINT pk_ground_operation_status_lkp PRIMARY KEY (status_code),
    CONSTRAINT chk_ground_op_status_terminal CHECK (is_terminal IN ('Y', 'N'))
)]'; EXCEPTION WHEN OTHERS THEN IF SQLCODE != -955 THEN RAISE; END IF; END;
/

BEGIN EXECUTE IMMEDIATE q'[
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
    metadata_json                CLOB,
    created_at                   TIMESTAMP(6)  DEFAULT SYSTIMESTAMP NOT NULL,
    updated_at                   TIMESTAMP(6)  DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT pk_ground_operation_activity PRIMARY KEY (ground_operation_activity_id),
    CONSTRAINT fk_ground_op_act_flight FOREIGN KEY (flight_operation_id) REFERENCES flight_operation (flight_operation_id),
    CONSTRAINT fk_ground_op_act_aircraft FOREIGN KEY (aircraft_id) REFERENCES aircraft (aircraft_id),
    CONSTRAINT fk_ground_op_act_facility FOREIGN KEY (facility_id) REFERENCES facility (facility_id),
    CONSTRAINT fk_ground_op_act_type FOREIGN KEY (activity_type_code) REFERENCES ground_operation_activity_type_lkp (activity_type_code),
    CONSTRAINT fk_ground_op_act_status FOREIGN KEY (activity_status) REFERENCES ground_operation_status_lkp (status_code),
    CONSTRAINT chk_ground_op_progress CHECK (progress_pct BETWEEN 0 AND 100),
    CONSTRAINT chk_ground_op_priority CHECK (priority BETWEEN 1 AND 5),
    CONSTRAINT chk_ground_op_activity_metadata_json CHECK (metadata_json IS JSON)
)]'; EXCEPTION WHEN OTHERS THEN IF SQLCODE != -955 THEN RAISE; END IF; END;
/

BEGIN EXECUTE IMMEDIATE q'[
CREATE TABLE ground_operation_log (
    ground_operation_log_id      VARCHAR2(36)  NOT NULL,
    ground_operation_activity_id VARCHAR2(36)  NOT NULL,
    log_entry_type               VARCHAR2(32)  NOT NULL,
    message                      VARCHAR2(4000) NOT NULL,
    logged_at                    TIMESTAMP(6)  DEFAULT SYSTIMESTAMP NOT NULL,
    logged_by_user_id            VARCHAR2(36),
    metadata_json                CLOB,
    CONSTRAINT pk_ground_operation_log PRIMARY KEY (ground_operation_log_id),
    CONSTRAINT fk_ground_op_log_activity FOREIGN KEY (ground_operation_activity_id) REFERENCES ground_operation_activity (ground_operation_activity_id),
    CONSTRAINT chk_ground_op_log_metadata_json CHECK (metadata_json IS JSON)
)]'; EXCEPTION WHEN OTHERS THEN IF SQLCODE != -955 THEN RAISE; END IF; END;
/

COMMIT;
