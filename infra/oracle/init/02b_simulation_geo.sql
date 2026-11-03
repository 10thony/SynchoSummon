-- =============================================================================
-- Simulation geography — real-world addresses mapped to virtual render space
-- =============================================================================

ALTER SESSION SET CONTAINER = FREEPDB1;
ALTER SESSION SET CURRENT_SCHEMA = nas_sim;

-- Active test/render profile (only one should be active; enforced in application code)
CREATE TABLE simulation_render_context (
    render_context_id       VARCHAR2(36)  NOT NULL,
    context_code            VARCHAR2(64)  NOT NULL,
    name                    VARCHAR2(256) NOT NULL,
    description             VARCHAR2(2000),
    is_active               CHAR(1)       DEFAULT 'N' NOT NULL
        CONSTRAINT chk_render_context_active CHECK (is_active IN ('Y', 'N')),
    grid_config_json        CLOB
        CONSTRAINT chk_render_context_grid_json CHECK (grid_config_json IS JSON),
    created_at              TIMESTAMP(6)  DEFAULT SYSTIMESTAMP NOT NULL,
    updated_at              TIMESTAMP(6)  DEFAULT SYSTIMESTAMP NOT NULL,
    created_by_user_id      VARCHAR2(36),
    CONSTRAINT pk_simulation_render_context PRIMARY KEY (render_context_id),
    CONSTRAINT uq_render_context_code UNIQUE (context_code)
);

-- Maps a facility's real US location to virtual coordinates for the active render context.
-- Unity reads the active context + enabled rows to place facilities in the virtual world.
CREATE TABLE simulation_geo_location_lookup (
    simulation_geo_location_id VARCHAR2(36)  NOT NULL,
    render_context_id          VARCHAR2(36)  NOT NULL,
    facility_id                VARCHAR2(36)  NOT NULL,
    real_city                  VARCHAR2(128) NOT NULL,
    real_state_code            CHAR(2)       NOT NULL,
    real_zip_code              VARCHAR2(10)  NOT NULL,
    virtual_latitude           NUMBER(10, 7) NOT NULL,
    virtual_longitude          NUMBER(10, 7) NOT NULL,
    virtual_elevation_ft       NUMBER(7),
    -- Organized-grid placement: when both are set, clients place the facility at
    -- (grid_col * cellSizeUnits, 0, grid_row * cellSizeUnits) and derive runway
    -- connections from row/col adjacency. Overrides transform_json positioning.
    grid_row                   NUMBER(6),
    grid_col                   NUMBER(6),
    transform_json             CLOB
        CONSTRAINT chk_sim_geo_transform_json CHECK (transform_json IS JSON),
    is_enabled                 CHAR(1)       DEFAULT 'Y' NOT NULL
        CONSTRAINT chk_sim_geo_enabled CHECK (is_enabled IN ('Y', 'N')),
    notes                      VARCHAR2(1024),
    created_at                 TIMESTAMP(6)  DEFAULT SYSTIMESTAMP NOT NULL,
    updated_at                 TIMESTAMP(6)  DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT pk_simulation_geo_location_lookup PRIMARY KEY (simulation_geo_location_id),
    CONSTRAINT uq_sim_geo_context_facility UNIQUE (render_context_id, facility_id),
    CONSTRAINT fk_sim_geo_render_context
        FOREIGN KEY (render_context_id) REFERENCES simulation_render_context (render_context_id),
    CONSTRAINT fk_sim_geo_facility
        FOREIGN KEY (facility_id) REFERENCES facility (facility_id),
    CONSTRAINT fk_sim_geo_real_state
        FOREIGN KEY (real_state_code) REFERENCES us_state_lkp (state_code),
    CONSTRAINT chk_sim_geo_real_zip CHECK (REGEXP_LIKE(real_zip_code, '^\d{5}(-\d{4})?$')),
    CONSTRAINT chk_sim_geo_virt_lat CHECK (virtual_latitude BETWEEN -90 AND 90),
    CONSTRAINT chk_sim_geo_virt_lon CHECK (virtual_longitude BETWEEN -180 AND 180)
);

-- Volatile simulation clock state (singleton row; application maintains run_state_id = 'CURRENT')
CREATE TABLE simulation_run_state (
    run_state_id            VARCHAR2(36)  NOT NULL,
    clock_mode_code         VARCHAR2(16)  DEFAULT 'REALTIME' NOT NULL,
    time_scale              NUMBER(8, 4)  DEFAULT 1 NOT NULL,
    run_status_code         VARCHAR2(16)  DEFAULT 'PAUSED' NOT NULL,
    current_sim_time_utc    TIMESTAMP(6)  NOT NULL,
    last_tick_wall_time_utc TIMESTAMP(6),
    step_sequence           NUMBER(12)    DEFAULT 0 NOT NULL,
    active_render_context_id VARCHAR2(36),
    updated_at              TIMESTAMP(6)  DEFAULT SYSTIMESTAMP NOT NULL,
    updated_by_user_id      VARCHAR2(36),
    CONSTRAINT pk_simulation_run_state PRIMARY KEY (run_state_id),
    CONSTRAINT fk_sim_run_clock_mode
        FOREIGN KEY (clock_mode_code) REFERENCES simulation_clock_mode_lkp (clock_mode_code),
    CONSTRAINT fk_sim_run_status
        FOREIGN KEY (run_status_code) REFERENCES simulation_run_status_lkp (run_status_code),
    CONSTRAINT fk_sim_run_render_context
        FOREIGN KEY (active_render_context_id) REFERENCES simulation_render_context (render_context_id),
    CONSTRAINT chk_sim_run_time_scale CHECK (time_scale > 0)
);

-- Point-in-time NAS world snapshots (pause/step capture)
CREATE TABLE simulation_snapshot (
    simulation_snapshot_id  VARCHAR2(36)  NOT NULL,
    snapshot_label          VARCHAR2(256) NOT NULL,
    render_context_id       VARCHAR2(36),
    sim_time_utc            TIMESTAMP(6)  NOT NULL,
    clock_mode_code         VARCHAR2(16)  NOT NULL,
    time_scale              NUMBER(8, 4)  NOT NULL,
    run_status_code         VARCHAR2(16)  NOT NULL,
    step_sequence           NUMBER(12)    NOT NULL,
    state_json              CLOB          NOT NULL
        CONSTRAINT chk_sim_snapshot_state_json CHECK (state_json IS JSON),
    created_at              TIMESTAMP(6)  DEFAULT SYSTIMESTAMP NOT NULL,
    created_by_user_id      VARCHAR2(36),
    CONSTRAINT pk_simulation_snapshot PRIMARY KEY (simulation_snapshot_id),
    CONSTRAINT fk_sim_snapshot_render_context
        FOREIGN KEY (render_context_id) REFERENCES simulation_render_context (render_context_id),
    CONSTRAINT fk_sim_snapshot_clock_mode
        FOREIGN KEY (clock_mode_code) REFERENCES simulation_clock_mode_lkp (clock_mode_code),
    CONSTRAINT fk_sim_snapshot_run_status
        FOREIGN KEY (run_status_code) REFERENCES simulation_run_status_lkp (run_status_code)
);

CREATE INDEX idx_sim_geo_facility ON simulation_geo_location_lookup (facility_id);
CREATE INDEX idx_sim_geo_context ON simulation_geo_location_lookup (render_context_id);
CREATE INDEX idx_sim_snapshot_time ON simulation_snapshot (sim_time_utc);
CREATE INDEX idx_render_context_active ON simulation_render_context (is_active);

-- Scenario wall-clock anchor for seed scripts (change once; reload seeds to shift the day).
CREATE TABLE scenario_clock (
    clock_id          VARCHAR2(32)  NOT NULL,
    scenario_day      DATE          NOT NULL,
    anchor_ts         TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    description       VARCHAR2(512),
    updated_at        TIMESTAMP(6)  DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT pk_scenario_clock PRIMARY KEY (clock_id)
);
