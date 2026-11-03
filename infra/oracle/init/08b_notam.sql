-- =============================================================================
-- NOTAM (Notice to Air Missions) — FAA restriction publications
-- No triggers; status managed in NasSim.Api
-- =============================================================================

ALTER SESSION SET CONTAINER = FREEPDB1;
ALTER SESSION SET CURRENT_SCHEMA = nas_sim;

CREATE TABLE notam (
    notam_id              VARCHAR2(36)   NOT NULL,
    notam_number          VARCHAR2(32)   NOT NULL,
    facility_id           VARCHAR2(36),
    equipment_id          VARCHAR2(36),
    runway_id             VARCHAR2(36),
    classification        VARCHAR2(32)   DEFAULT 'DOMESTIC' NOT NULL,
    feature               VARCHAR2(32),
    notam_text            VARCHAR2(2000) NOT NULL,
    effective_start_utc   TIMESTAMP(6)   NOT NULL,
    effective_end_utc     TIMESTAMP(6),
    is_active             CHAR(1)        DEFAULT 'Y' NOT NULL
        CONSTRAINT chk_notam_active CHECK (is_active IN ('Y', 'N')),
    metadata_json         CLOB
        CONSTRAINT chk_notam_metadata_json CHECK (metadata_json IS JSON),
    created_at            TIMESTAMP(6)   DEFAULT SYSTIMESTAMP NOT NULL,
    updated_at            TIMESTAMP(6)   DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT pk_notam PRIMARY KEY (notam_id),
    CONSTRAINT uq_notam_number UNIQUE (notam_number),
    CONSTRAINT fk_notam_facility FOREIGN KEY (facility_id) REFERENCES facility (facility_id),
    CONSTRAINT fk_notam_equipment FOREIGN KEY (equipment_id) REFERENCES equipment (equipment_id),
    CONSTRAINT fk_notam_runway FOREIGN KEY (runway_id) REFERENCES runway (runway_id)
);

CREATE INDEX idx_notam_facility_active ON notam (facility_id, is_active);
CREATE INDEX idx_notam_effective ON notam (effective_start_utc, effective_end_utc);
