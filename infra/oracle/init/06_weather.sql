-- =============================================================================
-- Weather
-- =============================================================================

ALTER SESSION SET CONTAINER = FREEPDB1;
ALTER SESSION SET CURRENT_SCHEMA = nas_sim;

CREATE TABLE weather_event (
    weather_event_id        VARCHAR2(36)  NOT NULL,
    weather_type_code       VARCHAR2(32)  NOT NULL,
    name                    VARCHAR2(256),
    severity                VARCHAR2(16)  NOT NULL,
    started_at              TIMESTAMP(6)  NOT NULL,
    ended_at                TIMESTAMP(6),
    max_wind_kts            NUMBER(6, 2),
    visibility_sm             NUMBER(6, 2),
    ceiling_ft              NUMBER(7),
    precipitation_rate      NUMBER(6, 2),
    metadata_json           CLOB
        CONSTRAINT chk_weather_event_metadata_json CHECK (metadata_json IS JSON),
    created_at              TIMESTAMP(6)  DEFAULT SYSTIMESTAMP NOT NULL,
    updated_at              TIMESTAMP(6)  DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT pk_weather_event PRIMARY KEY (weather_event_id),
    CONSTRAINT fk_weather_event_type
        FOREIGN KEY (weather_type_code) REFERENCES weather_event_type_lkp (weather_type_code),
    CONSTRAINT fk_weather_event_severity
        FOREIGN KEY (severity) REFERENCES alert_severity_lkp (severity_code)
);

CREATE TABLE weather_event_path (
    weather_event_path_id   VARCHAR2(36)  NOT NULL,
    weather_event_id        VARCHAR2(36)  NOT NULL,
    sequence_order          NUMBER(5)     NOT NULL,
    latitude                NUMBER(10, 7) NOT NULL,
    longitude               NUMBER(10, 7) NOT NULL,
    radius_nm               NUMBER(8, 2)  NOT NULL,
    effective_at            TIMESTAMP(6)  NOT NULL,
    intensity_factor        NUMBER(5, 2)  DEFAULT 1.0 NOT NULL,
    created_at              TIMESTAMP(6)  DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT pk_weather_event_path PRIMARY KEY (weather_event_path_id),
    CONSTRAINT uq_weather_path_seq UNIQUE (weather_event_id, sequence_order),
    CONSTRAINT fk_weather_path_event
        FOREIGN KEY (weather_event_id) REFERENCES weather_event (weather_event_id),
    CONSTRAINT chk_weather_path_lat CHECK (latitude BETWEEN -90 AND 90),
    CONSTRAINT chk_weather_path_lon CHECK (longitude BETWEEN -180 AND 180),
    CONSTRAINT chk_weather_path_radius CHECK (radius_nm > 0)
);

CREATE TABLE weather_event_alert (
    weather_event_alert_id  VARCHAR2(36)  NOT NULL,
    weather_event_id        VARCHAR2(36)  NOT NULL,
    facility_id             VARCHAR2(36),
    flight_operation_id     VARCHAR2(36),
    alert_level             VARCHAR2(16)  NOT NULL,
    message                 VARCHAR2(2000) NOT NULL,
    issued_at               TIMESTAMP(6)  DEFAULT SYSTIMESTAMP NOT NULL,
    expires_at              TIMESTAMP(6),
    acknowledged_at         TIMESTAMP(6),
    acknowledged_by_user_id VARCHAR2(36),
    CONSTRAINT pk_weather_event_alert PRIMARY KEY (weather_event_alert_id),
    CONSTRAINT fk_weather_alert_event
        FOREIGN KEY (weather_event_id) REFERENCES weather_event (weather_event_id),
    CONSTRAINT fk_weather_alert_facility
        FOREIGN KEY (facility_id) REFERENCES facility (facility_id),
    CONSTRAINT fk_weather_alert_flight
        FOREIGN KEY (flight_operation_id) REFERENCES flight_operation (flight_operation_id),
    CONSTRAINT fk_weather_alert_level
        FOREIGN KEY (alert_level) REFERENCES alert_severity_lkp (severity_code),
    CONSTRAINT chk_weather_alert_target CHECK (
        facility_id IS NOT NULL OR flight_operation_id IS NOT NULL
    )
);

CREATE INDEX idx_weather_event_active ON weather_event (started_at, ended_at);
CREATE INDEX idx_weather_path_event ON weather_event_path (weather_event_id);
CREATE INDEX idx_weather_alert_facility ON weather_event_alert (facility_id);
CREATE INDEX idx_weather_alert_flight ON weather_event_alert (flight_operation_id);
