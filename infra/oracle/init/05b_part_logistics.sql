-- =============================================================================
-- Parts logistics: shipments, facility ground activities, lookups
-- (Runs after 05_flight.sql — equipment_part_shipment references flight_operation)
-- =============================================================================

ALTER SESSION SET CONTAINER = FREEPDB1;
ALTER SESSION SET CURRENT_SCHEMA = nas_sim;

CREATE TABLE shipment_status_lkp (
    status_code   VARCHAR2(32)  NOT NULL,
    display_name  VARCHAR2(128) NOT NULL,
    is_terminal   CHAR(1)       DEFAULT 'N' NOT NULL
        CONSTRAINT chk_shipment_status_terminal CHECK (is_terminal IN ('Y', 'N')),
    sort_order    NUMBER(5)     DEFAULT 0 NOT NULL,
    CONSTRAINT pk_shipment_status_lkp PRIMARY KEY (status_code)
);

CREATE TABLE carrier_mode_lkp (
    carrier_mode_code VARCHAR2(16) NOT NULL,
    display_name      VARCHAR2(64) NOT NULL,
    CONSTRAINT pk_carrier_mode_lkp PRIMARY KEY (carrier_mode_code)
);

CREATE TABLE facility_logistics_activity_type_lkp (
    activity_type_code      VARCHAR2(32)  NOT NULL,
    display_name            VARCHAR2(128) NOT NULL,
    default_duration_min    NUMBER(8,2)   DEFAULT 15 NOT NULL,
    sort_order              NUMBER(5)     DEFAULT 0 NOT NULL,
    description             VARCHAR2(512),
    CONSTRAINT pk_facility_logistics_act_type PRIMARY KEY (activity_type_code)
);

INSERT INTO shipment_status_lkp (status_code, display_name, is_terminal, sort_order) VALUES ('PLANNED', 'Planned', 'N', 1);
INSERT INTO shipment_status_lkp (status_code, display_name, is_terminal, sort_order) VALUES ('IN_TRANSIT', 'In Transit', 'N', 2);
INSERT INTO shipment_status_lkp (status_code, display_name, is_terminal, sort_order) VALUES ('DELIVERED', 'Delivered', 'Y', 3);
INSERT INTO shipment_status_lkp (status_code, display_name, is_terminal, sort_order) VALUES ('CANCELLED', 'Cancelled', 'Y', 4);

INSERT INTO carrier_mode_lkp (carrier_mode_code, display_name) VALUES ('AIR', 'Air Freight');
INSERT INTO carrier_mode_lkp (carrier_mode_code, display_name) VALUES ('GROUND', 'Ground Transport');

INSERT INTO facility_logistics_activity_type_lkp (activity_type_code, display_name, default_duration_min, sort_order, description)
VALUES ('PART_RECEIVING', 'Part Receiving', 20, 10, 'Inbound unload and inspection at warehouse dock');
INSERT INTO facility_logistics_activity_type_lkp (activity_type_code, display_name, default_duration_min, sort_order, description)
VALUES ('PART_STAGING', 'Part Staging', 15, 11, 'Put-away to stock shelves and bin locations');
INSERT INTO facility_logistics_activity_type_lkp (activity_type_code, display_name, default_duration_min, sort_order, description)
VALUES ('PART_LOADING', 'Part Loading', 20, 12, 'Outbound truck or air freight loading');

CREATE TABLE equipment_part_shipment (
    equipment_part_shipment_id  VARCHAR2(36)  NOT NULL,
    equipment_part_order_id     VARCHAR2(36),
    equipment_part_id           VARCHAR2(36)  NOT NULL,
    origin_facility_id          VARCHAR2(36),
    origin_manufacturer_id      VARCHAR2(36),
    destination_facility_id     VARCHAR2(36)  NOT NULL,
    carrier_mode_code           VARCHAR2(16)  NOT NULL,
    carrier_flight_operation_id VARCHAR2(36),
    quantity                    NUMBER(12, 2) NOT NULL,
    shipment_status             VARCHAR2(32)  DEFAULT 'PLANNED' NOT NULL,
    scheduled_depart_at         TIMESTAMP(6),
    scheduled_arrival_at        TIMESTAMP(6),
    actual_depart_at            TIMESTAMP(6),
    actual_arrival_at           TIMESTAMP(6),
    tracking_number             VARCHAR2(64),
    notes                       VARCHAR2(1024),
    progress_pct                NUMBER(5,2)   DEFAULT 0 NOT NULL
        CONSTRAINT chk_part_shipment_progress CHECK (progress_pct BETWEEN 0 AND 100),
    metadata_json               CLOB
        CONSTRAINT chk_part_shipment_metadata_json CHECK (metadata_json IS JSON),
    created_at                  TIMESTAMP(6)  DEFAULT SYSTIMESTAMP NOT NULL,
    updated_at                  TIMESTAMP(6)  DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT pk_equipment_part_shipment PRIMARY KEY (equipment_part_shipment_id),
    CONSTRAINT fk_part_shipment_order
        FOREIGN KEY (equipment_part_order_id) REFERENCES equipment_part_order (equipment_part_order_id),
    CONSTRAINT fk_part_shipment_part
        FOREIGN KEY (equipment_part_id) REFERENCES equipment_part (equipment_part_id),
    CONSTRAINT fk_part_shipment_origin_facility
        FOREIGN KEY (origin_facility_id) REFERENCES facility (facility_id),
    CONSTRAINT fk_part_shipment_origin_mfg
        FOREIGN KEY (origin_manufacturer_id) REFERENCES part_manufacturer_lkp (manufacturer_id),
    CONSTRAINT fk_part_shipment_dest_facility
        FOREIGN KEY (destination_facility_id) REFERENCES facility (facility_id),
    CONSTRAINT fk_part_shipment_carrier_mode
        FOREIGN KEY (carrier_mode_code) REFERENCES carrier_mode_lkp (carrier_mode_code),
    CONSTRAINT fk_part_shipment_flight
        FOREIGN KEY (carrier_flight_operation_id) REFERENCES flight_operation (flight_operation_id),
    CONSTRAINT fk_part_shipment_status
        FOREIGN KEY (shipment_status) REFERENCES shipment_status_lkp (status_code),
    CONSTRAINT chk_part_shipment_qty CHECK (quantity > 0),
    CONSTRAINT chk_part_shipment_origin CHECK (
        origin_facility_id IS NOT NULL OR origin_manufacturer_id IS NOT NULL
    )
);

CREATE TABLE facility_logistics_activity (
    facility_logistics_activity_id VARCHAR2(36)  NOT NULL,
    facility_id                    VARCHAR2(36)  NOT NULL,
    equipment_part_shipment_id     VARCHAR2(36),
    activity_type_code             VARCHAR2(32)  NOT NULL,
    activity_status                VARCHAR2(32)  DEFAULT 'PLANNED' NOT NULL,
    title                          VARCHAR2(256) NOT NULL,
    description                    VARCHAR2(2000),
    progress_pct                   NUMBER(5,2)   DEFAULT 0 NOT NULL,
    scheduled_start_at             TIMESTAMP(6),
    scheduled_end_at               TIMESTAMP(6),
    actual_start_at                TIMESTAMP(6),
    actual_end_at                  TIMESTAMP(6),
    estimated_duration_min         NUMBER(8,2),
    priority                       NUMBER(2)     DEFAULT 3 NOT NULL,
    metadata_json                  CLOB
        CONSTRAINT chk_fac_logistics_act_metadata_json CHECK (metadata_json IS JSON),
    created_at                     TIMESTAMP(6)  DEFAULT SYSTIMESTAMP NOT NULL,
    updated_at                     TIMESTAMP(6)  DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT pk_facility_logistics_activity PRIMARY KEY (facility_logistics_activity_id),
    CONSTRAINT fk_fac_logistics_act_facility
        FOREIGN KEY (facility_id) REFERENCES facility (facility_id),
    CONSTRAINT fk_fac_logistics_act_shipment
        FOREIGN KEY (equipment_part_shipment_id) REFERENCES equipment_part_shipment (equipment_part_shipment_id),
    CONSTRAINT fk_fac_logistics_act_type
        FOREIGN KEY (activity_type_code) REFERENCES facility_logistics_activity_type_lkp (activity_type_code),
    CONSTRAINT fk_fac_logistics_act_status
        FOREIGN KEY (activity_status) REFERENCES ground_operation_status_lkp (status_code),
    CONSTRAINT chk_fac_logistics_progress CHECK (progress_pct BETWEEN 0 AND 100),
    CONSTRAINT chk_fac_logistics_priority CHECK (priority BETWEEN 1 AND 5)
);

CREATE TABLE facility_logistics_log (
    facility_logistics_log_id      VARCHAR2(36)  NOT NULL,
    facility_logistics_activity_id VARCHAR2(36)  NOT NULL,
    log_entry_type                 VARCHAR2(32)  NOT NULL,
    message                        VARCHAR2(4000) NOT NULL,
    logged_at                      TIMESTAMP(6)  DEFAULT SYSTIMESTAMP NOT NULL,
    logged_by_user_id              VARCHAR2(36),
    facility_id                    VARCHAR2(36),
    equipment_id                   VARCHAR2(36),
    runway_id                      VARCHAR2(36),
    location_label                 VARCHAR2(64),
    metadata_json                  CLOB
        CONSTRAINT chk_fac_logistics_log_metadata_json CHECK (metadata_json IS JSON),
    CONSTRAINT pk_facility_logistics_log PRIMARY KEY (facility_logistics_log_id),
    CONSTRAINT fk_fac_logistics_log_activity
        FOREIGN KEY (facility_logistics_activity_id) REFERENCES facility_logistics_activity (facility_logistics_activity_id),
    CONSTRAINT fk_fac_logistics_log_entry_type
        FOREIGN KEY (log_entry_type) REFERENCES log_entry_type_lkp (log_entry_type_code),
    CONSTRAINT fk_fac_logistics_log_facility
        FOREIGN KEY (facility_id) REFERENCES facility (facility_id),
    CONSTRAINT fk_fac_logistics_log_equipment
        FOREIGN KEY (equipment_id) REFERENCES equipment (equipment_id),
    CONSTRAINT fk_fac_logistics_log_runway
        FOREIGN KEY (runway_id) REFERENCES runway (runway_id)
);

CREATE INDEX idx_part_shipment_order ON equipment_part_shipment (equipment_part_order_id);
CREATE INDEX idx_part_shipment_status ON equipment_part_shipment (shipment_status);
CREATE INDEX idx_part_shipment_dest ON equipment_part_shipment (destination_facility_id);
CREATE INDEX idx_part_shipment_origin_fac ON equipment_part_shipment (origin_facility_id);
CREATE INDEX idx_fac_logistics_act_facility ON facility_logistics_activity (facility_id);
CREATE INDEX idx_fac_logistics_act_status ON facility_logistics_activity (activity_status);
CREATE INDEX idx_fac_logistics_act_shipment ON facility_logistics_activity (equipment_part_shipment_id);
CREATE INDEX idx_fac_logistics_log_activity ON facility_logistics_log (facility_logistics_activity_id);
CREATE INDEX idx_fac_logistics_log_facility_logged ON facility_logistics_log (facility_id, logged_at);
CREATE INDEX idx_fac_logistics_log_equipment_logged ON facility_logistics_log (equipment_id, logged_at);
CREATE INDEX idx_fac_logistics_log_type_logged ON facility_logistics_log (log_entry_type, logged_at);
