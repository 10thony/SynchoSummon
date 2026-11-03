-- =============================================================================
-- Flight operations
-- =============================================================================

ALTER SESSION SET CONTAINER = FREEPDB1;
ALTER SESSION SET CURRENT_SCHEMA = nas_sim;

CREATE TABLE flight_request (
    flight_request_id       VARCHAR2(36)  NOT NULL,
    request_number          VARCHAR2(32)  NOT NULL,
    origin_facility_id      VARCHAR2(36)  NOT NULL,
    destination_facility_id VARCHAR2(36)  NOT NULL,
    requested_departure_at  TIMESTAMP(6)  NOT NULL,
    requested_arrival_at    TIMESTAMP(6),
    aircraft_id             VARCHAR2(36),
    passenger_count         NUMBER(5),
    request_status          VARCHAR2(32)  DEFAULT 'SUBMITTED' NOT NULL,
    requested_by_user_id    VARCHAR2(36),
    notes                   VARCHAR2(2000),
    metadata_json           CLOB
        CONSTRAINT chk_flight_req_metadata_json CHECK (metadata_json IS JSON),
    created_at              TIMESTAMP(6)  DEFAULT SYSTIMESTAMP NOT NULL,
    updated_at              TIMESTAMP(6)  DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT pk_flight_request PRIMARY KEY (flight_request_id),
    CONSTRAINT uq_flight_request_number UNIQUE (request_number),
    CONSTRAINT fk_flight_req_origin
        FOREIGN KEY (origin_facility_id) REFERENCES facility (facility_id),
    CONSTRAINT fk_flight_req_destination
        FOREIGN KEY (destination_facility_id) REFERENCES facility (facility_id),
    CONSTRAINT fk_flight_req_aircraft
        FOREIGN KEY (aircraft_id) REFERENCES aircraft (aircraft_id)
);

CREATE TABLE flight_operation (
    flight_operation_id     VARCHAR2(36)  NOT NULL,
    flight_request_id       VARCHAR2(36),
    flight_number           VARCHAR2(16)  NOT NULL,
    origin_facility_id      VARCHAR2(36)  NOT NULL,
    destination_facility_id VARCHAR2(36)  NOT NULL,
    departure_runway_id     VARCHAR2(36),
    arrival_runway_id       VARCHAR2(36),
    current_phase           VARCHAR2(32)  DEFAULT 'SCHEDULED' NOT NULL,
    operation_status        VARCHAR2(32)  DEFAULT 'ACTIVE' NOT NULL,
    scheduled_departure_at  TIMESTAMP(6)  NOT NULL,
    scheduled_arrival_at    TIMESTAMP(6)  NOT NULL,
    actual_departure_at     TIMESTAMP(6),
    actual_arrival_at       TIMESTAMP(6),
    aircraft_id             VARCHAR2(36)  NOT NULL,
    delay_minutes           NUMBER(6)     DEFAULT 0 NOT NULL,
    progress_pct            NUMBER(5,2)   DEFAULT 0 NOT NULL
        CONSTRAINT chk_flight_op_progress CHECK (progress_pct BETWEEN 0 AND 100),
    metadata_json           CLOB
        CONSTRAINT chk_flight_op_metadata_json CHECK (metadata_json IS JSON),
    created_at              TIMESTAMP(6)  DEFAULT SYSTIMESTAMP NOT NULL,
    updated_at              TIMESTAMP(6)  DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT pk_flight_operation PRIMARY KEY (flight_operation_id),
    CONSTRAINT uq_flight_operation_number UNIQUE (flight_number),
    CONSTRAINT fk_flight_op_request
        FOREIGN KEY (flight_request_id) REFERENCES flight_request (flight_request_id),
    CONSTRAINT fk_flight_op_origin
        FOREIGN KEY (origin_facility_id) REFERENCES facility (facility_id),
    CONSTRAINT fk_flight_op_destination
        FOREIGN KEY (destination_facility_id) REFERENCES facility (facility_id),
    CONSTRAINT fk_flight_op_dep_runway
        FOREIGN KEY (departure_runway_id) REFERENCES runway (runway_id),
    CONSTRAINT fk_flight_op_arr_runway
        FOREIGN KEY (arrival_runway_id) REFERENCES runway (runway_id),
    CONSTRAINT fk_flight_op_phase
        FOREIGN KEY (current_phase) REFERENCES flight_phase_lkp (phase_code),
    CONSTRAINT fk_flight_op_aircraft
        FOREIGN KEY (aircraft_id) REFERENCES aircraft (aircraft_id)
);

CREATE TABLE flight_path (
    flight_path_id          VARCHAR2(36)  NOT NULL,
    flight_operation_id     VARCHAR2(36)  NOT NULL,
    sequence_order          NUMBER(5)     NOT NULL,
    waypoint_name           VARCHAR2(64),
    latitude                NUMBER(10, 7) NOT NULL,
    longitude               NUMBER(10, 7) NOT NULL,
    altitude_ft             NUMBER(7),
    estimated_time_at       TIMESTAMP(6),
    is_active               CHAR(1)       DEFAULT 'Y' NOT NULL
        CONSTRAINT chk_flight_path_active CHECK (is_active IN ('Y', 'N')),
    created_at              TIMESTAMP(6)  DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT pk_flight_path PRIMARY KEY (flight_path_id),
    CONSTRAINT uq_flight_path_seq UNIQUE (flight_operation_id, sequence_order),
    CONSTRAINT fk_flight_path_operation
        FOREIGN KEY (flight_operation_id) REFERENCES flight_operation (flight_operation_id),
    CONSTRAINT chk_flight_path_lat CHECK (latitude BETWEEN -90 AND 90),
    CONSTRAINT chk_flight_path_lon CHECK (longitude BETWEEN -180 AND 180)
);

CREATE TABLE flight_path_request (
    flight_path_request_id  VARCHAR2(36)  NOT NULL,
    flight_operation_id     VARCHAR2(36)  NOT NULL,
    request_reason          VARCHAR2(512) NOT NULL,
    request_status          VARCHAR2(32)  DEFAULT 'PENDING' NOT NULL,
    requested_path_json     CLOB          NOT NULL
        CONSTRAINT chk_flight_path_req_json CHECK (requested_path_json IS JSON),
    requested_by_user_id    VARCHAR2(36),
    reviewed_by_user_id     VARCHAR2(36),
    requested_at            TIMESTAMP(6)  DEFAULT SYSTIMESTAMP NOT NULL,
    resolved_at             TIMESTAMP(6),
    resolution_notes        VARCHAR2(2000),
    CONSTRAINT pk_flight_path_request PRIMARY KEY (flight_path_request_id),
    CONSTRAINT fk_flight_path_req_operation
        FOREIGN KEY (flight_operation_id) REFERENCES flight_operation (flight_operation_id)
);

CREATE TABLE flight_incident (
    flight_incident_id      VARCHAR2(36)  NOT NULL,
    flight_operation_id     VARCHAR2(36)  NOT NULL,
    incident_type_code      VARCHAR2(32)  NOT NULL,
    severity                VARCHAR2(16)  NOT NULL,
    title                   VARCHAR2(256) NOT NULL,
    description             VARCHAR2(4000),
    occurred_at             TIMESTAMP(6)  NOT NULL,
    resolved_at             TIMESTAMP(6),
    related_equipment_id    VARCHAR2(36),
    related_facility_id     VARCHAR2(36),
    metadata_json           CLOB
        CONSTRAINT chk_flight_incident_metadata_json CHECK (metadata_json IS JSON),
    created_at              TIMESTAMP(6)  DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT pk_flight_incident PRIMARY KEY (flight_incident_id),
    CONSTRAINT fk_flight_incident_operation
        FOREIGN KEY (flight_operation_id) REFERENCES flight_operation (flight_operation_id),
    CONSTRAINT fk_flight_incident_type
        FOREIGN KEY (incident_type_code) REFERENCES incident_type_lkp (incident_type_code),
    CONSTRAINT fk_flight_incident_severity
        FOREIGN KEY (severity) REFERENCES alert_severity_lkp (severity_code),
    CONSTRAINT fk_flight_incident_equipment
        FOREIGN KEY (related_equipment_id) REFERENCES equipment (equipment_id),
    CONSTRAINT fk_flight_incident_facility
        FOREIGN KEY (related_facility_id) REFERENCES facility (facility_id)
);

-- Append-only event stream for simulation replay and SignalR fan-out
CREATE TABLE flight_event (
    flight_event_id         VARCHAR2(36)  NOT NULL,
    flight_operation_id     VARCHAR2(36)  NOT NULL,
    event_type_code         VARCHAR2(64)  NOT NULL,
    occurred_at             TIMESTAMP(6)  DEFAULT SYSTIMESTAMP NOT NULL,
    sequence_number         NUMBER(12)    NOT NULL,
    payload_json            CLOB
        CONSTRAINT chk_flight_event_payload_json CHECK (payload_json IS JSON),
    correlation_id          VARCHAR2(36),
    created_at              TIMESTAMP(6)  DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT pk_flight_event PRIMARY KEY (flight_event_id),
    CONSTRAINT uq_flight_event_seq UNIQUE (flight_operation_id, sequence_number),
    CONSTRAINT fk_flight_event_operation
        FOREIGN KEY (flight_operation_id) REFERENCES flight_operation (flight_operation_id),
    CONSTRAINT fk_flight_event_type
        FOREIGN KEY (event_type_code) REFERENCES flight_event_type_lkp (event_type_code)
);

CREATE INDEX idx_flight_req_aircraft ON flight_request (aircraft_id);
CREATE INDEX idx_flight_req_origin ON flight_request (origin_facility_id);
CREATE INDEX idx_flight_req_status ON flight_request (request_status);
CREATE INDEX idx_flight_op_aircraft ON flight_operation (aircraft_id);
CREATE INDEX idx_flight_op_phase ON flight_operation (current_phase);
CREATE INDEX idx_flight_op_status ON flight_operation (operation_status);
CREATE INDEX idx_flight_op_sched_dep ON flight_operation (scheduled_departure_at);
CREATE INDEX idx_flight_path_operation ON flight_path (flight_operation_id);
CREATE INDEX idx_flight_event_operation ON flight_event (flight_operation_id);
CREATE INDEX idx_flight_event_occurred ON flight_event (occurred_at);

-- Occupancy FK deferred from runway create (02) until flight_operation exists.
ALTER TABLE runway ADD CONSTRAINT fk_runway_occupied_flight
    FOREIGN KEY (occupied_by_flight_operation_id) REFERENCES flight_operation (flight_operation_id);

