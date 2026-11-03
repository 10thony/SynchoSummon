-- =============================================================================
-- Performance test result tables (promoted from former 116_* seed-band DDL)
-- =============================================================================

ALTER SESSION SET CONTAINER = FREEPDB1;
ALTER SESSION SET CURRENT_SCHEMA = nas_sim;

CREATE TABLE perf_test_run (
    run_id            VARCHAR2(36)   NOT NULL,
    started_at        TIMESTAMP(6)   NOT NULL,
    finished_at       TIMESTAMP(6),
    profile_name      VARCHAR2(32)   NOT NULL,
    tag               VARCHAR2(128),
    git_sha           VARCHAR2(64),
    machine_name      VARCHAR2(128),
    run_host          VARCHAR2(128),
    renderer_backend  VARCHAR2(128),
    budget_verdict    VARCHAR2(16)   DEFAULT 'RECORD' NOT NULL,
    clock_config_json CLOB
        CONSTRAINT chk_perf_run_clock_json CHECK (clock_config_json IS JSON),
    manifest_json     CLOB
        CONSTRAINT chk_perf_run_manifest_json CHECK (manifest_json IS JSON),
    created_at        TIMESTAMP(6)   DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT pk_perf_test_run PRIMARY KEY (run_id),
    CONSTRAINT chk_perf_run_verdict
        CHECK (budget_verdict IN ('PASS', 'WARN', 'FAIL', 'RECORD'))
);

CREATE INDEX idx_perf_run_started ON perf_test_run (started_at);
CREATE INDEX idx_perf_run_profile ON perf_test_run (profile_name);

CREATE TABLE perf_test_metric (
    metric_id      VARCHAR2(36)   NOT NULL,
    run_id         VARCHAR2(36)   NOT NULL,
    suite          VARCHAR2(64)   NOT NULL,
    test_name      VARCHAR2(128)  NOT NULL,
    metric_name    VARCHAR2(128)  NOT NULL,
    unit           VARCHAR2(32)   NOT NULL,
    sample_count   NUMBER(9)      NOT NULL,
    min_value      NUMBER(18, 4),
    mean_value     NUMBER(18, 4),
    p50_value      NUMBER(18, 4),
    p95_value      NUMBER(18, 4),
    p99_value      NUMBER(18, 4),
    max_value      NUMBER(18, 4),
    budget_status  VARCHAR2(16)   DEFAULT 'NONE' NOT NULL,
    created_at     TIMESTAMP(6)   DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT pk_perf_test_metric PRIMARY KEY (metric_id),
    CONSTRAINT fk_perf_metric_run
        FOREIGN KEY (run_id) REFERENCES perf_test_run (run_id) ON DELETE CASCADE,
    CONSTRAINT chk_perf_metric_status
        CHECK (budget_status IN ('PASS', 'WARN', 'FAIL', 'NONE'))
);

CREATE INDEX idx_perf_metric_run ON perf_test_metric (run_id);
CREATE INDEX idx_perf_metric_lookup ON perf_test_metric (suite, test_name, metric_name);
