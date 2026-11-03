-- =============================================================================
-- Facility Unity assets — type profiles, equipment requirements, staff assignments
-- Application owns validation; no triggers.
-- =============================================================================

ALTER SESSION SET CONTAINER = FREEPDB1;
ALTER SESSION SET CURRENT_SCHEMA = nas_sim;

-- Roles that can be assigned to users at a facility (dashboard staffing).
CREATE TABLE facility_personnel_role_lkp (
    role_code            VARCHAR2(32)  NOT NULL,
    display_name         VARCHAR2(128) NOT NULL,
    description          VARCHAR2(512),
    is_manager_role      CHAR(1)       DEFAULT 'N' NOT NULL
        CONSTRAINT chk_fac_personnel_mgr CHECK (is_manager_role IN ('Y', 'N')),
    sort_order           NUMBER(5)     DEFAULT 0 NOT NULL,
    is_active            CHAR(1)       DEFAULT 'Y' NOT NULL
        CONSTRAINT chk_fac_personnel_role_active CHECK (is_active IN ('Y', 'N')),
    CONSTRAINT pk_facility_personnel_role_lkp PRIMARY KEY (role_code)
);

-- Unity/visual blueprint per facility type (replaces hardcoded FacilitySiteView blocks).
CREATE TABLE facility_type_asset_profile (
    facility_type_code   VARCHAR2(32)  NOT NULL,
    profile_version      NUMBER(5)     DEFAULT 1 NOT NULL,
    asset_profile_json   CLOB          NOT NULL
        CONSTRAINT chk_fac_type_asset_json CHECK (asset_profile_json IS JSON),
    personnel_defaults_json CLOB
        CONSTRAINT chk_fac_type_personnel_json CHECK (personnel_defaults_json IS JSON),
    created_at           TIMESTAMP(6)  DEFAULT SYSTIMESTAMP NOT NULL,
    updated_at           TIMESTAMP(6)  DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT pk_facility_type_asset_profile PRIMARY KEY (facility_type_code),
    CONSTRAINT fk_fac_type_asset_profile_type
        FOREIGN KEY (facility_type_code) REFERENCES facility_type_lkp (facility_type_code)
);

-- Required/optional equipment slots per facility type.
CREATE TABLE facility_type_equipment_requirement (
    requirement_id       VARCHAR2(36)  NOT NULL,
    facility_type_code     VARCHAR2(32)  NOT NULL,
    equipment_type_code    VARCHAR2(32)  NOT NULL,
    requirement_code       VARCHAR2(32)  NOT NULL,  -- REQUIRED, OPTIONAL, CONDITIONAL
    min_quantity           NUMBER(5)     DEFAULT 1 NOT NULL,
    slot_code              VARCHAR2(64)  DEFAULT 'DEFAULT' NOT NULL,
    description            VARCHAR2(512),
    sort_order             NUMBER(5)     DEFAULT 0 NOT NULL,
    CONSTRAINT pk_facility_type_equip_req PRIMARY KEY (requirement_id),
    CONSTRAINT uq_facility_type_equip_req UNIQUE (facility_type_code, equipment_type_code, slot_code),
    CONSTRAINT fk_fac_type_equip_req_type
        FOREIGN KEY (facility_type_code) REFERENCES facility_type_lkp (facility_type_code),
    CONSTRAINT fk_fac_type_equip_req_equip
        FOREIGN KEY (equipment_type_code) REFERENCES equipment_type_lkp (equipment_type_code),
    CONSTRAINT chk_fac_type_equip_req_code CHECK (requirement_code IN ('REQUIRED', 'OPTIONAL', 'CONDITIONAL'))
);

CREATE INDEX idx_fac_type_equip_req_type ON facility_type_equipment_requirement (facility_type_code);
