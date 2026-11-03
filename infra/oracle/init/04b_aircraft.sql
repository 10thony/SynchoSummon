-- =============================================================================
-- Aircraft
-- =============================================================================

ALTER SESSION SET CONTAINER = FREEPDB1;
ALTER SESSION SET CURRENT_SCHEMA = nas_sim;

CREATE TABLE aircraft (
    aircraft_id             VARCHAR2(36)  NOT NULL,
    tail_number             VARCHAR2(16)  NOT NULL,
    aircraft_type_code      VARCHAR2(32)  NOT NULL,
    home_facility_id        VARCHAR2(36),
    operational_status      VARCHAR2(32)  DEFAULT 'AVAILABLE' NOT NULL,
    seating_capacity        NUMBER(4),
    max_takeoff_weight_lbs  NUMBER(8),
    metadata_json           CLOB
        CONSTRAINT chk_aircraft_metadata_json CHECK (metadata_json IS JSON),
    created_at              TIMESTAMP(6)  DEFAULT SYSTIMESTAMP NOT NULL,
    updated_at              TIMESTAMP(6)  DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT pk_aircraft PRIMARY KEY (aircraft_id),
    CONSTRAINT uq_aircraft_tail_number UNIQUE (tail_number),
    CONSTRAINT fk_aircraft_type
        FOREIGN KEY (aircraft_type_code) REFERENCES aircraft_type_lkp (aircraft_type_code),
    CONSTRAINT fk_aircraft_home_facility
        FOREIGN KEY (home_facility_id) REFERENCES facility (facility_id)
);

CREATE INDEX idx_aircraft_type ON aircraft (aircraft_type_code);
CREATE INDEX idx_aircraft_home_facility ON aircraft (home_facility_id);
CREATE INDEX idx_aircraft_status ON aircraft (operational_status);
