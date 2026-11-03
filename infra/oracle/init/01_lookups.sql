-- =============================================================================
-- NAS Simulation — schema bootstrap
-- Runs as SYS on first container start (gvenzl/oracle-free).
-- All objects live in the APP_USER schema (nas_sim).
-- No triggers, no stored procedures — application owns all business logic.
-- =============================================================================

ALTER SESSION SET CONTAINER = FREEPDB1;
ALTER SESSION SET CURRENT_SCHEMA = nas_sim;

-- ---------------------------------------------------------------------------
-- Lookup / reference tables (stable codes; seed data in 99_seed_reference.sql)
-- ---------------------------------------------------------------------------

CREATE TABLE facility_type_lkp (
    facility_type_code   VARCHAR2(32)  NOT NULL,
    display_name         VARCHAR2(128) NOT NULL,
    description          VARCHAR2(512),
    is_active            CHAR(1)       DEFAULT 'Y' NOT NULL
        CONSTRAINT chk_facility_type_active CHECK (is_active IN ('Y', 'N')),
    CONSTRAINT pk_facility_type_lkp PRIMARY KEY (facility_type_code)
);

CREATE TABLE operational_status_lkp (
    status_code          VARCHAR2(32)  NOT NULL,
    display_name         VARCHAR2(128) NOT NULL,
    applies_to_entity    VARCHAR2(32)  NOT NULL,  -- FACILITY, RUNWAY, EQUIPMENT, FLIGHT, etc.
    sort_order           NUMBER(5)     DEFAULT 0 NOT NULL,
    CONSTRAINT pk_operational_status_lkp PRIMARY KEY (status_code, applies_to_entity)
);

CREATE TABLE equipment_type_lkp (
    equipment_type_code  VARCHAR2(32)  NOT NULL,
    display_name         VARCHAR2(128) NOT NULL,
    category             VARCHAR2(64),             -- NAVAID, RADAR, COMMS, LIGHTING, etc.
    description          VARCHAR2(512),
    CONSTRAINT pk_equipment_type_lkp PRIMARY KEY (equipment_type_code)
);

CREATE TABLE maintenance_activity_type_lkp (
    activity_type_code   VARCHAR2(32)  NOT NULL,
    display_name         VARCHAR2(128) NOT NULL,
    description          VARCHAR2(512),
    CONSTRAINT pk_maint_activity_type_lkp PRIMARY KEY (activity_type_code)
);

CREATE TABLE maintenance_status_lkp (
    status_code          VARCHAR2(32)  NOT NULL,
    display_name         VARCHAR2(128) NOT NULL,
    is_terminal          CHAR(1)       DEFAULT 'N' NOT NULL
        CONSTRAINT chk_maint_status_terminal CHECK (is_terminal IN ('Y', 'N')),
    CONSTRAINT pk_maintenance_status_lkp PRIMARY KEY (status_code)
);

CREATE TABLE flight_phase_lkp (
    phase_code           VARCHAR2(32)  NOT NULL,
    display_name         VARCHAR2(128) NOT NULL,
    sort_order           NUMBER(5)     NOT NULL,
    CONSTRAINT pk_flight_phase_lkp PRIMARY KEY (phase_code)
);

CREATE TABLE flight_event_type_lkp (
    event_type_code      VARCHAR2(64)  NOT NULL,
    display_name         VARCHAR2(128) NOT NULL,
    category             VARCHAR2(32)  NOT NULL,  -- OPERATIONAL, DELAY, DIVERSION, ATC, etc.
    CONSTRAINT pk_flight_event_type_lkp PRIMARY KEY (event_type_code)
);

CREATE TABLE incident_type_lkp (
    incident_type_code   VARCHAR2(32)  NOT NULL,
    display_name         VARCHAR2(128) NOT NULL,
    default_severity     VARCHAR2(16)  NOT NULL,
    behavior_json        CLOB
        CONSTRAINT chk_incident_type_behavior_json CHECK (behavior_json IS JSON),
    CONSTRAINT pk_incident_type_lkp PRIMARY KEY (incident_type_code)
);

CREATE TABLE ground_operation_activity_type_lkp (
    activity_type_code       VARCHAR2(32)  NOT NULL,
    display_name             VARCHAR2(128) NOT NULL,
    default_duration_min     NUMBER(8,2)   DEFAULT 30 NOT NULL,
    required_for_departure   CHAR(1)       DEFAULT 'Y' NOT NULL
        CONSTRAINT chk_ground_op_type_required CHECK (required_for_departure IN ('Y', 'N')),
    sort_order               NUMBER(5)     DEFAULT 0 NOT NULL,
    description              VARCHAR2(512),
    CONSTRAINT pk_ground_op_activity_type_lkp PRIMARY KEY (activity_type_code)
);

CREATE TABLE ground_operation_status_lkp (
    status_code          VARCHAR2(32)  NOT NULL,
    display_name         VARCHAR2(128) NOT NULL,
    is_terminal          CHAR(1)       DEFAULT 'N' NOT NULL
        CONSTRAINT chk_ground_op_status_terminal CHECK (is_terminal IN ('Y', 'N')),
    CONSTRAINT pk_ground_operation_status_lkp PRIMARY KEY (status_code)
);

CREATE TABLE weather_event_type_lkp (
    weather_type_code    VARCHAR2(32)  NOT NULL,
    display_name         VARCHAR2(128) NOT NULL,
    CONSTRAINT pk_weather_event_type_lkp PRIMARY KEY (weather_type_code)
);

CREATE TABLE alert_severity_lkp (
    severity_code        VARCHAR2(16)  NOT NULL,
    display_name         VARCHAR2(64)  NOT NULL,
    sort_order           NUMBER(3)     NOT NULL,
    CONSTRAINT pk_alert_severity_lkp PRIMARY KEY (severity_code)
);

CREATE TABLE order_status_lkp (
    status_code          VARCHAR2(32)  NOT NULL,
    display_name         VARCHAR2(128) NOT NULL,
    CONSTRAINT pk_order_status_lkp PRIMARY KEY (status_code)
);

CREATE TABLE quote_status_lkp (
    status_code          VARCHAR2(32)  NOT NULL,
    display_name         VARCHAR2(128) NOT NULL,
    CONSTRAINT pk_quote_status_lkp PRIMARY KEY (status_code)
);

CREATE TABLE us_state_lkp (
    state_code           CHAR(2)       NOT NULL,
    state_name           VARCHAR2(64)  NOT NULL,
    CONSTRAINT pk_us_state_lkp PRIMARY KEY (state_code)
);

CREATE TABLE aircraft_type_lkp (
    aircraft_type_code   VARCHAR2(32)  NOT NULL,
    display_name         VARCHAR2(128) NOT NULL,
    icao_designator      VARCHAR2(8),
    wake_category        VARCHAR2(8),   -- LIGHT, MEDIUM, HEAVY, SUPER
    typical_cruise_kts   NUMBER(5),
    max_seating          NUMBER(4),
    CONSTRAINT pk_aircraft_type_lkp PRIMARY KEY (aircraft_type_code)
);

CREATE TABLE simulation_clock_mode_lkp (
    clock_mode_code      VARCHAR2(16)  NOT NULL,
    display_name         VARCHAR2(64)  NOT NULL,
    description          VARCHAR2(256),
    CONSTRAINT pk_simulation_clock_mode_lkp PRIMARY KEY (clock_mode_code)
);

CREATE TABLE simulation_run_status_lkp (
    run_status_code      VARCHAR2(16)  NOT NULL,
    display_name         VARCHAR2(64)  NOT NULL,
    allows_tick          CHAR(1)       DEFAULT 'Y' NOT NULL
        CONSTRAINT chk_sim_run_status_tick CHECK (allows_tick IN ('Y', 'N')),
    CONSTRAINT pk_simulation_run_status_lkp PRIMARY KEY (run_status_code)
);

-- Shared across maintenance / ground-ops / logistics log streams.
-- applies_to_domain is informational (comma list or ALL); PK is the code alone
-- so the same NOTE / STATUS_CHANGE / PART_USED can be reused across domains.
CREATE TABLE log_entry_type_lkp (
    log_entry_type_code  VARCHAR2(32)  NOT NULL,
    display_name         VARCHAR2(128) NOT NULL,
    applies_to_domain    VARCHAR2(64)  DEFAULT 'ALL' NOT NULL,
    description          VARCHAR2(512),
    CONSTRAINT pk_log_entry_type_lkp PRIMARY KEY (log_entry_type_code)
);
