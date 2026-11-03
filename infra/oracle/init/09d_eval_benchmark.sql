-- =============================================================================
-- Model benchmark / eval tables (promoted from former 121_* seed-band DDL)
-- Seed catalog data: 09e_seed_eval.sql
-- =============================================================================

ALTER SESSION SET CONTAINER = FREEPDB1;
ALTER SESSION SET CURRENT_SCHEMA = nas_sim;

CREATE TABLE eval_benchmark (
    benchmark_id      VARCHAR2(36)   NOT NULL,
    benchmark_code    VARCHAR2(64)   NOT NULL,
    title             VARCHAR2(128)  NOT NULL,
    description       VARCHAR2(512),
    version           VARCHAR2(32)   DEFAULT '1.0' NOT NULL,
    is_active         CHAR(1)        DEFAULT 'Y' NOT NULL
        CONSTRAINT chk_eval_benchmark_active CHECK (is_active IN ('Y', 'N')),
    created_at        TIMESTAMP(6)   DEFAULT SYSTIMESTAMP NOT NULL,
    updated_at        TIMESTAMP(6)   DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT pk_eval_benchmark PRIMARY KEY (benchmark_id),
    CONSTRAINT uq_eval_benchmark_code UNIQUE (benchmark_code)
);

CREATE TABLE eval_task (
    task_id               VARCHAR2(36)   NOT NULL,
    benchmark_id          VARCHAR2(36)   NOT NULL,
    task_code             VARCHAR2(64)   NOT NULL,
    title                 VARCHAR2(128)  NOT NULL,
    task_type             VARCHAR2(32)   NOT NULL,
    prompt_text           CLOB           NOT NULL,
    rubric_json           CLOB
        CONSTRAINT chk_eval_task_rubric_json CHECK (rubric_json IS JSON),
    expected_outcome_json CLOB
        CONSTRAINT chk_eval_task_expected_json CHECK (expected_outcome_json IS JSON),
    precondition_json     CLOB
        CONSTRAINT chk_eval_task_precondition_json CHECK (precondition_json IS JSON),
    isolation_json        CLOB
        CONSTRAINT chk_eval_task_isolation_json CHECK (isolation_json IS JSON),
    sort_order            NUMBER(6)      DEFAULT 0 NOT NULL,
    is_active             CHAR(1)        DEFAULT 'Y' NOT NULL
        CONSTRAINT chk_eval_task_active CHECK (is_active IN ('Y', 'N')),
    created_at            TIMESTAMP(6)   DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT pk_eval_task PRIMARY KEY (task_id),
    CONSTRAINT fk_eval_task_benchmark
        FOREIGN KEY (benchmark_id) REFERENCES eval_benchmark (benchmark_id) ON DELETE CASCADE,
    CONSTRAINT uq_eval_task_code UNIQUE (benchmark_id, task_code),
    CONSTRAINT chk_eval_task_type CHECK (
        task_type IN ('READ_ONLY', 'OPERATOR_WORKFLOW', 'UI_GROUNDING', 'EPISODE'))
);

CREATE INDEX idx_eval_task_benchmark ON eval_task (benchmark_id, sort_order);

CREATE TABLE eval_model_profile (
    profile_id        VARCHAR2(36)   NOT NULL,
    profile_code      VARCHAR2(64)   NOT NULL,
    display_name      VARCHAR2(128)  NOT NULL,
    provider_code     VARCHAR2(32)   NOT NULL,
    model_id          VARCHAR2(128)  NOT NULL,
    secret_ref        VARCHAR2(256),
    config_json       CLOB
        CONSTRAINT chk_eval_profile_config_json CHECK (config_json IS JSON),
    supports_tools    CHAR(1)        DEFAULT 'Y' NOT NULL,
    supports_vision   CHAR(1)        DEFAULT 'N' NOT NULL,
    is_enabled        CHAR(1)        DEFAULT 'Y' NOT NULL
        CONSTRAINT chk_eval_profile_enabled CHECK (is_enabled IN ('Y', 'N')),
    created_at        TIMESTAMP(6)   DEFAULT SYSTIMESTAMP NOT NULL,
    updated_at        TIMESTAMP(6)   DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT pk_eval_model_profile PRIMARY KEY (profile_id),
    CONSTRAINT uq_eval_model_profile_code UNIQUE (profile_code),
    CONSTRAINT chk_eval_profile_provider CHECK (
        provider_code IN ('FAKE', 'OPENAI', 'ANTHROPIC', 'BEDROCK'))
);

CREATE TABLE eval_run (
    run_id                VARCHAR2(36)   NOT NULL,
    benchmark_id          VARCHAR2(36)   NOT NULL,
    profile_id            VARCHAR2(36)   NOT NULL,
    run_tag               VARCHAR2(128),
    status                VARCHAR2(32)   DEFAULT 'QUEUED' NOT NULL,
    started_at            TIMESTAMP(6),
    finished_at           TIMESTAMP(6),
    clock_snapshot_json   CLOB
        CONSTRAINT chk_eval_run_clock_json CHECK (clock_snapshot_json IS JSON),
    manifest_json         CLOB
        CONSTRAINT chk_eval_run_manifest_json CHECK (manifest_json IS JSON),
    machine_score         NUMBER(5, 2),
    human_score           NUMBER(5, 2),
    launched_by_user_id   VARCHAR2(36),
    recovery_note         VARCHAR2(512),
    created_at            TIMESTAMP(6)   DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT pk_eval_run PRIMARY KEY (run_id),
    CONSTRAINT fk_eval_run_benchmark
        FOREIGN KEY (benchmark_id) REFERENCES eval_benchmark (benchmark_id),
    CONSTRAINT fk_eval_run_profile
        FOREIGN KEY (profile_id) REFERENCES eval_model_profile (profile_id),
    CONSTRAINT chk_eval_run_status CHECK (
        status IN ('QUEUED', 'RUNNING', 'COMPLETED', 'FAILED', 'CANCELLED'))
);

CREATE INDEX idx_eval_run_started ON eval_run (started_at);
CREATE INDEX idx_eval_run_status ON eval_run (status);

CREATE TABLE eval_task_run (
    task_run_id           VARCHAR2(36)   NOT NULL,
    run_id                VARCHAR2(36)   NOT NULL,
    task_id               VARCHAR2(36)   NOT NULL,
    status                VARCHAR2(32)   DEFAULT 'PENDING' NOT NULL,
    machine_score         NUMBER(5, 2),
    human_score           NUMBER(5, 2),
    grader_notes          VARCHAR2(2000),
    model_answer          CLOB,
    final_state_json      CLOB
        CONSTRAINT chk_eval_task_run_state_json CHECK (final_state_json IS JSON),
    failure_category      VARCHAR2(64),
    started_at            TIMESTAMP(6),
    finished_at           TIMESTAMP(6),
    created_at            TIMESTAMP(6)   DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT pk_eval_task_run PRIMARY KEY (task_run_id),
    CONSTRAINT fk_eval_task_run_run
        FOREIGN KEY (run_id) REFERENCES eval_run (run_id) ON DELETE CASCADE,
    CONSTRAINT fk_eval_task_run_task
        FOREIGN KEY (task_id) REFERENCES eval_task (task_id),
    CONSTRAINT chk_eval_task_run_status CHECK (
        status IN ('PENDING', 'RUNNING', 'COMPLETED', 'FAILED', 'SKIPPED', 'CANCELLED'))
);

CREATE INDEX idx_eval_task_run_run ON eval_task_run (run_id);

CREATE TABLE eval_action_trace (
    trace_id              VARCHAR2(36)   NOT NULL,
    run_id                VARCHAR2(36)   NOT NULL,
    task_run_id           VARCHAR2(36),
    sequence_no           NUMBER(9)      NOT NULL,
    action_type           VARCHAR2(32)   NOT NULL,
    action_name           VARCHAR2(128),
    status                VARCHAR2(32)   DEFAULT 'STARTED' NOT NULL,
    summary               VARCHAR2(512),
    payload_json          CLOB
        CONSTRAINT chk_eval_trace_payload_json CHECK (payload_json IS JSON),
    raw_payload_json      CLOB
        CONSTRAINT chk_eval_trace_raw_json CHECK (raw_payload_json IS JSON),
    created_at            TIMESTAMP(6)   DEFAULT SYSTIMESTAMP NOT NULL,
    completed_at          TIMESTAMP(6),
    CONSTRAINT pk_eval_action_trace PRIMARY KEY (trace_id),
    CONSTRAINT fk_eval_trace_run
        FOREIGN KEY (run_id) REFERENCES eval_run (run_id) ON DELETE CASCADE,
    CONSTRAINT fk_eval_trace_task_run
        FOREIGN KEY (task_run_id) REFERENCES eval_task_run (task_run_id) ON DELETE CASCADE,
    CONSTRAINT chk_eval_trace_type CHECK (
        action_type IN ('MODEL_MESSAGE', 'TOOL_CALL', 'TOOL_RESULT', 'CLOCK', 'HUB_EVENT', 'VIEWER', 'SYSTEM')),
    CONSTRAINT chk_eval_trace_status CHECK (
        status IN ('STARTED', 'COMPLETED', 'FAILED', 'SKIPPED'))
);

CREATE INDEX idx_eval_trace_run ON eval_action_trace (run_id, sequence_no);

CREATE TABLE eval_artifact (
    artifact_id           VARCHAR2(36)   NOT NULL,
    run_id                VARCHAR2(36)   NOT NULL,
    task_run_id           VARCHAR2(36),
    artifact_type         VARCHAR2(32)   NOT NULL,
    label                 VARCHAR2(128),
    content_json          CLOB
        CONSTRAINT chk_eval_artifact_json CHECK (content_json IS JSON),
    raw_content_json      CLOB
        CONSTRAINT chk_eval_artifact_raw_json CHECK (raw_content_json IS JSON),
    created_at            TIMESTAMP(6)   DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT pk_eval_artifact PRIMARY KEY (artifact_id),
    CONSTRAINT fk_eval_artifact_run
        FOREIGN KEY (run_id) REFERENCES eval_run (run_id) ON DELETE CASCADE,
    CONSTRAINT fk_eval_artifact_task_run
        FOREIGN KEY (task_run_id) REFERENCES eval_task_run (task_run_id) ON DELETE CASCADE
);

CREATE INDEX idx_eval_artifact_run ON eval_artifact (run_id);

CREATE TABLE eval_audit_event (
    audit_id              VARCHAR2(36)   NOT NULL,
    event_type            VARCHAR2(64)   NOT NULL,
    run_id                VARCHAR2(36),
    task_run_id           VARCHAR2(36),
    profile_id            VARCHAR2(36),
    actor_user_id         VARCHAR2(36),
    summary               VARCHAR2(512),
    detail_json           CLOB
        CONSTRAINT chk_eval_audit_detail_json CHECK (detail_json IS JSON),
    created_at            TIMESTAMP(6)   DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT pk_eval_audit_event PRIMARY KEY (audit_id)
);

CREATE INDEX idx_eval_audit_created ON eval_audit_event (created_at);
