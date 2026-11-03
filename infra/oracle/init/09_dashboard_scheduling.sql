-- =============================================================================
-- Operator dashboards (shared layouts) + simulation event schedules
-- =============================================================================

ALTER SESSION SET CONTAINER = FREEPDB1;
ALTER SESSION SET CURRENT_SCHEMA = nas_sim;

CREATE TABLE dashboard_definition (
    dashboard_id        VARCHAR2(36)   NOT NULL,
    dashboard_code      VARCHAR2(64)   NOT NULL,
    title               VARCHAR2(128)  NOT NULL,
    description         VARCHAR2(512),
    sort_order          NUMBER(6)      DEFAULT 0 NOT NULL,
    is_active           CHAR(1)        DEFAULT 'Y' NOT NULL
        CONSTRAINT chk_dashboard_def_active CHECK (is_active IN ('Y', 'N')),
    created_at          TIMESTAMP(6)   DEFAULT SYSTIMESTAMP NOT NULL,
    updated_at          TIMESTAMP(6)   DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT pk_dashboard_definition PRIMARY KEY (dashboard_id),
    CONSTRAINT uq_dashboard_definition_code UNIQUE (dashboard_code)
);

CREATE TABLE dashboard_key_mapping (
    key_mapping_id      VARCHAR2(36)   NOT NULL,
    dashboard_id        VARCHAR2(36)   NOT NULL,
    key_chord           VARCHAR2(64)   NOT NULL,
    platform_code       VARCHAR2(32)   DEFAULT 'UNITY' NOT NULL,
    is_active           CHAR(1)        DEFAULT 'Y' NOT NULL
        CONSTRAINT chk_dashboard_key_active CHECK (is_active IN ('Y', 'N')),
    CONSTRAINT pk_dashboard_key_mapping PRIMARY KEY (key_mapping_id),
    CONSTRAINT fk_dashboard_key_dashboard
        FOREIGN KEY (dashboard_id) REFERENCES dashboard_definition (dashboard_id),
    CONSTRAINT uq_dashboard_key_chord UNIQUE (key_chord, platform_code)
);

CREATE TABLE dashboard_panel (
    panel_id            VARCHAR2(36)   NOT NULL,
    dashboard_id        VARCHAR2(36)   NOT NULL,
    title               VARCHAR2(128)  NOT NULL,
    entity_slug         VARCHAR2(128)  NOT NULL,
    grid_row            NUMBER(6)      DEFAULT 0 NOT NULL,
    grid_column         NUMBER(6)      DEFAULT 0 NOT NULL,
    grid_row_span       NUMBER(6)      DEFAULT 1 NOT NULL,
    grid_column_span    NUMBER(6)      DEFAULT 1 NOT NULL,
    page_size           NUMBER(6)      DEFAULT 50 NOT NULL,
    sort_order          NUMBER(6)      DEFAULT 0 NOT NULL,
    filter_json         CLOB
        CONSTRAINT chk_dashboard_panel_filter_json CHECK (filter_json IS JSON),
    CONSTRAINT pk_dashboard_panel PRIMARY KEY (panel_id),
    CONSTRAINT fk_dashboard_panel_dashboard
        FOREIGN KEY (dashboard_id) REFERENCES dashboard_definition (dashboard_id)
);

CREATE TABLE simulation_schedule (
    schedule_id         VARCHAR2(36)   NOT NULL,
    schedule_code       VARCHAR2(64)   NOT NULL,
    title               VARCHAR2(128)  NOT NULL,
    description         VARCHAR2(512),
    is_active           CHAR(1)        DEFAULT 'Y' NOT NULL
        CONSTRAINT chk_sim_schedule_active CHECK (is_active IN ('Y', 'N')),
    created_at          TIMESTAMP(6)   DEFAULT SYSTIMESTAMP NOT NULL,
    updated_at          TIMESTAMP(6)   DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT pk_simulation_schedule PRIMARY KEY (schedule_id),
    CONSTRAINT uq_simulation_schedule_code UNIQUE (schedule_code)
);

CREATE TABLE simulation_schedule_event (
    schedule_event_id   VARCHAR2(36)   NOT NULL,
    schedule_id         VARCHAR2(36)   NOT NULL,
    occurred_at_sim_utc TIMESTAMP(6)   NOT NULL,
    action_code         VARCHAR2(32)   NOT NULL,
    entity_slug         VARCHAR2(128),
    summary             VARCHAR2(512)   NOT NULL,
    payload_json        CLOB
        CONSTRAINT chk_sim_schedule_event_payload CHECK (payload_json IS JSON),
    sort_order          NUMBER(6)      DEFAULT 0 NOT NULL,
    CONSTRAINT pk_simulation_schedule_event PRIMARY KEY (schedule_event_id),
    CONSTRAINT fk_sim_schedule_event_schedule
        FOREIGN KEY (schedule_id) REFERENCES simulation_schedule (schedule_id),
    CONSTRAINT chk_sim_schedule_event_action CHECK (
        action_code IN ('ENTITY_UPSERT', 'ENTITY_DELETE', 'TIMELINE_NOTE', 'WORKFLOW'))
);

CREATE TABLE simulation_schedule_run (
    schedule_id             VARCHAR2(36)   NOT NULL,
    last_fired_at_sim_utc   TIMESTAMP(6),
    updated_at              TIMESTAMP(6)   DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT pk_simulation_schedule_run PRIMARY KEY (schedule_id),
    CONSTRAINT fk_sim_schedule_run_schedule
        FOREIGN KEY (schedule_id) REFERENCES simulation_schedule (schedule_id)
);

CREATE INDEX idx_dashboard_panel_dashboard ON dashboard_panel (dashboard_id, sort_order);
CREATE INDEX idx_sim_schedule_event_time ON simulation_schedule_event (schedule_id, occurred_at_sim_utc);
