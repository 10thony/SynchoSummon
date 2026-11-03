-- =============================================================================
-- Part manufacturers (off-NAS OEM registry) + quote/order FK extensions
-- =============================================================================

ALTER SESSION SET CONTAINER = FREEPDB1;
ALTER SESSION SET CURRENT_SCHEMA = nas_sim;

CREATE TABLE part_manufacturer_lkp (
    manufacturer_id     VARCHAR2(36)  NOT NULL,
    manufacturer_code   VARCHAR2(32)  NOT NULL,
    display_name        VARCHAR2(256) NOT NULL,
    contact_email       VARCHAR2(256),
    contact_phone       VARCHAR2(32),
    address_json        CLOB
        CONSTRAINT chk_part_mfg_address_json CHECK (address_json IS JSON),
    is_active           CHAR(1)       DEFAULT 'Y' NOT NULL
        CONSTRAINT chk_part_mfg_active CHECK (is_active IN ('Y', 'N')),
    created_at          TIMESTAMP(6)  DEFAULT SYSTIMESTAMP NOT NULL,
    updated_at          TIMESTAMP(6)  DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT pk_part_manufacturer_lkp PRIMARY KEY (manufacturer_id),
    CONSTRAINT uq_part_manufacturer_code UNIQUE (manufacturer_code)
);

ALTER TABLE equipment_part_quote
    ADD (
        manufacturer_id VARCHAR2(36),
        CONSTRAINT fk_part_quote_manufacturer
            FOREIGN KEY (manufacturer_id) REFERENCES part_manufacturer_lkp (manufacturer_id)
    );

ALTER TABLE equipment_part_order
    ADD (
        origin_manufacturer_id VARCHAR2(36),
        CONSTRAINT fk_part_order_origin_manufacturer
            FOREIGN KEY (origin_manufacturer_id) REFERENCES part_manufacturer_lkp (manufacturer_id)
    );

CREATE INDEX idx_part_quote_manufacturer ON equipment_part_quote (manufacturer_id);
CREATE INDEX idx_part_order_origin_mfg ON equipment_part_order (origin_manufacturer_id);
