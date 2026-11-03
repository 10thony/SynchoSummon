-- =============================================================================
-- Facility staff assignment (depends on users from 08_users_auth.sql)
-- Split from 02c so first-boot alphabetical order satisfies FKs.
-- =============================================================================

ALTER SESSION SET CONTAINER = FREEPDB1;
ALTER SESSION SET CURRENT_SCHEMA = nas_sim;

CREATE TABLE facility_staff_assignment (
    assignment_id          VARCHAR2(36)  NOT NULL,
    facility_id            VARCHAR2(36)  NOT NULL,
    user_id                VARCHAR2(36)  NOT NULL,
    role_code              VARCHAR2(32)  NOT NULL,
    is_lead                CHAR(1)       DEFAULT 'N' NOT NULL
        CONSTRAINT chk_fac_staff_lead CHECK (is_lead IN ('Y', 'N')),
    shift_metadata_json    CLOB
        CONSTRAINT chk_fac_staff_shift_json CHECK (shift_metadata_json IS JSON),
    assigned_at            TIMESTAMP(6)  DEFAULT SYSTIMESTAMP NOT NULL,
    assigned_by_user_id    VARCHAR2(36),
    CONSTRAINT pk_facility_staff_assignment PRIMARY KEY (assignment_id),
    CONSTRAINT uq_facility_staff_assignment UNIQUE (facility_id, user_id, role_code),
    CONSTRAINT fk_fac_staff_facility
        FOREIGN KEY (facility_id) REFERENCES facility (facility_id),
    CONSTRAINT fk_fac_staff_user
        FOREIGN KEY (user_id) REFERENCES users (user_id),
    CONSTRAINT fk_fac_staff_role
        FOREIGN KEY (role_code) REFERENCES facility_personnel_role_lkp (role_code),
    CONSTRAINT fk_fac_staff_assigned_by
        FOREIGN KEY (assigned_by_user_id) REFERENCES users (user_id)
);

CREATE INDEX idx_fac_staff_facility ON facility_staff_assignment (facility_id);
CREATE INDEX idx_fac_staff_user ON facility_staff_assignment (user_id);
CREATE INDEX idx_fac_staff_role ON facility_staff_assignment (role_code);
