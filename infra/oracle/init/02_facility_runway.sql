-- =============================================================================
-- Facility & Runway
-- =============================================================================

ALTER SESSION SET CONTAINER = FREEPDB1;
ALTER SESSION SET CURRENT_SCHEMA = nas_sim;

CREATE TABLE facility (
    facility_id          VARCHAR2(36)  NOT NULL,
    facility_code        VARCHAR2(16)  NOT NULL,
    name                 VARCHAR2(256) NOT NULL,
    facility_type_code   VARCHAR2(32)  NOT NULL,
    parent_facility_id   VARCHAR2(36),
    address_line1        VARCHAR2(256),
    city                 VARCHAR2(128) NOT NULL,
    state_code           CHAR(2)       NOT NULL,
    zip_code             VARCHAR2(10)  NOT NULL,
    latitude             NUMBER(10, 7) NOT NULL,
    longitude            NUMBER(10, 7) NOT NULL,
    elevation_ft         NUMBER(7),
    timezone_name        VARCHAR2(64)  DEFAULT 'UTC' NOT NULL,
    operational_status   VARCHAR2(32)  DEFAULT 'OPERATIONAL' NOT NULL,
    icao_code            VARCHAR2(4),
    faa_lid              VARCHAR2(8),
    metadata_json        CLOB
        CONSTRAINT chk_facility_metadata_json CHECK (metadata_json IS JSON),
    created_at           TIMESTAMP(6)  DEFAULT SYSTIMESTAMP NOT NULL,
    updated_at           TIMESTAMP(6)  DEFAULT SYSTIMESTAMP NOT NULL,
    created_by           VARCHAR2(36),
    updated_by           VARCHAR2(36),
    CONSTRAINT pk_facility PRIMARY KEY (facility_id),
    CONSTRAINT uq_facility_code UNIQUE (facility_code),
    CONSTRAINT fk_facility_type
        FOREIGN KEY (facility_type_code) REFERENCES facility_type_lkp (facility_type_code),
    CONSTRAINT fk_facility_parent
        FOREIGN KEY (parent_facility_id) REFERENCES facility (facility_id),
    CONSTRAINT fk_facility_state
        FOREIGN KEY (state_code) REFERENCES us_state_lkp (state_code),
    CONSTRAINT chk_facility_lat CHECK (latitude BETWEEN -90 AND 90),
    CONSTRAINT chk_facility_lon CHECK (longitude BETWEEN -180 AND 180),
    CONSTRAINT chk_facility_zip CHECK (REGEXP_LIKE(zip_code, '^\d{5}(-\d{4})?$'))
);

CREATE INDEX idx_facility_geo ON facility (city, state_code, zip_code);

CREATE TABLE runway (
    runway_id            VARCHAR2(36)  NOT NULL,
    facility_id          VARCHAR2(36)  NOT NULL,
    designator           VARCHAR2(8)   NOT NULL,   -- e.g. 09/27, 18L/36R
    length_ft            NUMBER(6)     NOT NULL,
    width_ft             NUMBER(5),
    surface_type         VARCHAR2(32),
    magnetic_heading_deg NUMBER(5, 2),
    operational_status   VARCHAR2(32)  DEFAULT 'OPEN' NOT NULL,
    occupancy_status     VARCHAR2(16)  DEFAULT 'CLEAR' NOT NULL
        CONSTRAINT chk_runway_occupancy CHECK (occupancy_status IN ('CLEAR', 'OCCUPIED', 'CLOSED')),
    occupied_by_flight_operation_id VARCHAR2(36),
    max_aircraft_category VARCHAR2(8),
    metadata_json        CLOB
        CONSTRAINT chk_runway_metadata_json CHECK (metadata_json IS JSON),
    created_at           TIMESTAMP(6)  DEFAULT SYSTIMESTAMP NOT NULL,
    updated_at           TIMESTAMP(6)  DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT pk_runway PRIMARY KEY (runway_id),
    CONSTRAINT uq_runway_facility_designator UNIQUE (facility_id, designator),
    CONSTRAINT fk_runway_facility
        FOREIGN KEY (facility_id) REFERENCES facility (facility_id)
    -- fk_runway_occupied_flight added after flight_operation exists (see 123 / post-flight alter)
);

-- Which equipment supports or constrains a runway (e.g. ILS for precision approach)
CREATE TABLE runway_equipment (
    runway_equipment_id  VARCHAR2(36)  NOT NULL,
    runway_id            VARCHAR2(36)  NOT NULL,
    equipment_id         VARCHAR2(36)  NOT NULL,  -- FK added after equipment table
    relationship_type    VARCHAR2(32)  NOT NULL,  -- SUPPORTS, RESTRICTS, MONITORS
    is_required          CHAR(1)       DEFAULT 'N' NOT NULL
        CONSTRAINT chk_runway_equip_required CHECK (is_required IN ('Y', 'N')),
    created_at           TIMESTAMP(6)  DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT pk_runway_equipment PRIMARY KEY (runway_equipment_id),
    CONSTRAINT uq_runway_equipment UNIQUE (runway_id, equipment_id, relationship_type),
    CONSTRAINT fk_runway_equip_runway
        FOREIGN KEY (runway_id) REFERENCES runway (runway_id)
);

CREATE INDEX idx_facility_type ON facility (facility_type_code);
CREATE INDEX idx_facility_parent ON facility (parent_facility_id);
CREATE INDEX idx_facility_status ON facility (operational_status);
CREATE INDEX idx_runway_facility ON runway (facility_id);
