-- =============================================================================
-- Equipment & Parts
-- =============================================================================

ALTER SESSION SET CONTAINER = FREEPDB1;
ALTER SESSION SET CURRENT_SCHEMA = nas_sim;

CREATE TABLE equipment (
    equipment_id               VARCHAR2(36)  NOT NULL,
    facility_id                VARCHAR2(36)  NOT NULL,
    equipment_type_code        VARCHAR2(32)  NOT NULL,
    identifier                 VARCHAR2(64)  NOT NULL,
    name                       VARCHAR2(256) NOT NULL,
    operational_status         VARCHAR2(32)  DEFAULT 'OPERATIONAL' NOT NULL,
    installed_at               TIMESTAMP(6),
    last_inspection_at         TIMESTAMP(6),
    next_inspection_due_at     TIMESTAMP(6),
    mean_time_between_failure_hrs NUMBER(10, 2),
    mean_time_to_repair_hrs    NUMBER(10, 2),
    serial_number              VARCHAR2(64),
    manufacturer               VARCHAR2(128),
    model                      VARCHAR2(128),
    metadata_json              CLOB
        CONSTRAINT chk_equipment_metadata_json CHECK (metadata_json IS JSON),
    created_at                 TIMESTAMP(6)  DEFAULT SYSTIMESTAMP NOT NULL,
    updated_at                 TIMESTAMP(6)  DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT pk_equipment PRIMARY KEY (equipment_id),
    CONSTRAINT uq_equipment_facility_identifier UNIQUE (facility_id, identifier),
    CONSTRAINT fk_equipment_facility
        FOREIGN KEY (facility_id) REFERENCES facility (facility_id),
    CONSTRAINT fk_equipment_type
        FOREIGN KEY (equipment_type_code) REFERENCES equipment_type_lkp (equipment_type_code)
);

-- Deferred FK from runway_equipment
ALTER TABLE runway_equipment
    ADD CONSTRAINT fk_runway_equip_equipment
        FOREIGN KEY (equipment_id) REFERENCES equipment (equipment_id);

-- Equipment dependency graph (failure propagation)
CREATE TABLE equipment_dependency (
    equipment_dependency_id VARCHAR2(36) NOT NULL,
    parent_equipment_id     VARCHAR2(36) NOT NULL,
    child_equipment_id      VARCHAR2(36) NOT NULL,
    dependency_type         VARCHAR2(32) NOT NULL,  -- REQUIRES, BACKUP_FOR, FEEDS
    created_at              TIMESTAMP(6) DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT pk_equipment_dependency PRIMARY KEY (equipment_dependency_id),
    CONSTRAINT uq_equipment_dependency UNIQUE (parent_equipment_id, child_equipment_id, dependency_type),
    CONSTRAINT fk_equip_dep_parent FOREIGN KEY (parent_equipment_id) REFERENCES equipment (equipment_id),
    CONSTRAINT fk_equip_dep_child  FOREIGN KEY (child_equipment_id)  REFERENCES equipment (equipment_id),
    CONSTRAINT chk_equip_dep_not_self CHECK (parent_equipment_id <> child_equipment_id)
);

CREATE TABLE equipment_part (
    equipment_part_id    VARCHAR2(36)  NOT NULL,
    part_number          VARCHAR2(64)  NOT NULL,
    name                 VARCHAR2(256) NOT NULL,
    description          VARCHAR2(1024),
    equipment_type_code  VARCHAR2(32),             -- compatible type (nullable = universal)
    unit_of_measure      VARCHAR2(16)  DEFAULT 'EA' NOT NULL,
    stock_quantity       NUMBER(12, 2) DEFAULT 0 NOT NULL,
    reorder_threshold    NUMBER(12, 2) DEFAULT 0 NOT NULL,
    storage_facility_id  VARCHAR2(36),             -- depot / stock location
    metadata_json        CLOB
        CONSTRAINT chk_equip_part_metadata_json CHECK (metadata_json IS JSON),
    created_at           TIMESTAMP(6)  DEFAULT SYSTIMESTAMP NOT NULL,
    updated_at           TIMESTAMP(6)  DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT pk_equipment_part PRIMARY KEY (equipment_part_id),
    CONSTRAINT uq_equipment_part_number UNIQUE (part_number),
    CONSTRAINT fk_equip_part_type
        FOREIGN KEY (equipment_type_code) REFERENCES equipment_type_lkp (equipment_type_code),
    CONSTRAINT fk_equip_part_storage_facility
        FOREIGN KEY (storage_facility_id) REFERENCES facility (facility_id)
);

CREATE TABLE equipment_part_quote (
    equipment_part_quote_id VARCHAR2(36)  NOT NULL,
    equipment_part_id       VARCHAR2(36)  NOT NULL,
    vendor_name             VARCHAR2(256) NOT NULL,
    quoted_unit_cost        NUMBER(14, 4) NOT NULL,
    currency_code           VARCHAR2(3)   DEFAULT 'USD' NOT NULL,
    lead_time_days          NUMBER(5),
    quote_status            VARCHAR2(32)  DEFAULT 'PENDING' NOT NULL,
    quoted_at               TIMESTAMP(6)  NOT NULL,
    valid_until             TIMESTAMP(6),
    notes                   VARCHAR2(1024),
    created_at              TIMESTAMP(6)  DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT pk_equipment_part_quote PRIMARY KEY (equipment_part_quote_id),
    CONSTRAINT fk_part_quote_part
        FOREIGN KEY (equipment_part_id) REFERENCES equipment_part (equipment_part_id),
    CONSTRAINT fk_part_quote_status
        FOREIGN KEY (quote_status) REFERENCES quote_status_lkp (status_code)
);

CREATE TABLE equipment_part_order (
    equipment_part_order_id VARCHAR2(36)  NOT NULL,
    equipment_part_id       VARCHAR2(36)  NOT NULL,
    equipment_part_quote_id VARCHAR2(36),
    receiving_facility_id   VARCHAR2(36)  NOT NULL,
    maintenance_activity_id VARCHAR2(36),          -- FK added in maintenance script
    quantity_ordered        NUMBER(12, 2) NOT NULL,
    unit_cost               NUMBER(14, 4),
    order_status            VARCHAR2(32)  DEFAULT 'DRAFT' NOT NULL,
    ordered_at              TIMESTAMP(6),
    expected_delivery_at    TIMESTAMP(6),
    received_at             TIMESTAMP(6),
    notes                   VARCHAR2(1024),
    created_at              TIMESTAMP(6)  DEFAULT SYSTIMESTAMP NOT NULL,
    updated_at              TIMESTAMP(6)  DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT pk_equipment_part_order PRIMARY KEY (equipment_part_order_id),
    CONSTRAINT fk_part_order_part
        FOREIGN KEY (equipment_part_id) REFERENCES equipment_part (equipment_part_id),
    CONSTRAINT fk_part_order_quote
        FOREIGN KEY (equipment_part_quote_id) REFERENCES equipment_part_quote (equipment_part_quote_id),
    CONSTRAINT fk_part_order_facility
        FOREIGN KEY (receiving_facility_id) REFERENCES facility (facility_id),
    CONSTRAINT fk_part_order_status
        FOREIGN KEY (order_status) REFERENCES order_status_lkp (status_code),
    CONSTRAINT chk_part_order_qty CHECK (quantity_ordered > 0)
);

CREATE INDEX idx_equipment_facility ON equipment (facility_id);
CREATE INDEX idx_equipment_type ON equipment (equipment_type_code);
CREATE INDEX idx_equipment_status ON equipment (operational_status);
CREATE INDEX idx_equip_part_storage ON equipment_part (storage_facility_id);
