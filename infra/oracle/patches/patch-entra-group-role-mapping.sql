-- =============================================================================
-- Patch: create entra_group_role_mapping on databases initialized before
--        08_users_auth.sql included this table. Safe to re-run (idempotent).
-- =============================================================================

ALTER SESSION SET CONTAINER = FREEPDB1;
ALTER SESSION SET CURRENT_SCHEMA = nas_sim;

DECLARE
    v_count NUMBER;
BEGIN
    SELECT COUNT(*)
    INTO v_count
    FROM user_tables
    WHERE table_name = 'ENTRA_GROUP_ROLE_MAPPING';

    IF v_count = 0 THEN
        EXECUTE IMMEDIATE q'[
            CREATE TABLE entra_group_role_mapping (
                entra_group_role_mapping_id VARCHAR2(36) NOT NULL,
                entra_tenant_id             VARCHAR2(36) NOT NULL,
                entra_group_object_id       VARCHAR2(36) NOT NULL,
                role_id                     VARCHAR2(36) NOT NULL,
                is_active                   CHAR(1)    DEFAULT 'Y' NOT NULL
                    CONSTRAINT chk_entra_group_role_active CHECK (is_active IN ('Y', 'N')),
                created_at                  TIMESTAMP(6) DEFAULT SYSTIMESTAMP NOT NULL,
                CONSTRAINT pk_entra_group_role_mapping PRIMARY KEY (entra_group_role_mapping_id),
                CONSTRAINT uq_entra_group_role UNIQUE (entra_tenant_id, entra_group_object_id, role_id),
                CONSTRAINT fk_entra_group_role_role
                    FOREIGN KEY (role_id) REFERENCES user_role_lookup (role_id)
            )
        ]';

        EXECUTE IMMEDIATE 'CREATE INDEX idx_entra_group_role_role ON entra_group_role_mapping (role_id)';
    END IF;
END;
/

-- Dev operator group (99_seed_reference.sql)
MERGE INTO entra_group_role_mapping t
USING (
    SELECT
        '00000000-0000-0000-0000-000000000200' AS entra_group_role_mapping_id,
        '11111111-1111-1111-1111-111111111111' AS entra_tenant_id,
        '33333333-3333-3333-3333-333333333333' AS entra_group_object_id,
        '00000000-0000-0000-0000-000000000002' AS role_id
    FROM dual
) s
ON (t.entra_group_role_mapping_id = s.entra_group_role_mapping_id)
WHEN NOT MATCHED THEN INSERT (
    entra_group_role_mapping_id, entra_tenant_id, entra_group_object_id, role_id, is_active
) VALUES (
    s.entra_group_role_mapping_id, s.entra_tenant_id, s.entra_group_object_id, s.role_id, 'Y'
);

-- Admin, maintenance, observer groups (100_seed_operational_nas.sql)
MERGE INTO entra_group_role_mapping t
USING (
    SELECT '20000010-0001-4001-8001-000000000010' AS entra_group_role_mapping_id,
           '11111111-1111-1111-1111-111111111111' AS entra_tenant_id,
           '44444444-4444-4444-4444-444444444444' AS entra_group_object_id,
           '00000000-0000-0000-0000-000000000001' AS role_id
    FROM dual
) s
ON (t.entra_group_role_mapping_id = s.entra_group_role_mapping_id)
WHEN NOT MATCHED THEN INSERT (
    entra_group_role_mapping_id, entra_tenant_id, entra_group_object_id, role_id, is_active
) VALUES (
    s.entra_group_role_mapping_id, s.entra_tenant_id, s.entra_group_object_id, s.role_id, 'Y'
);

MERGE INTO entra_group_role_mapping t
USING (
    SELECT '20000011-0001-4001-8001-000000000011' AS entra_group_role_mapping_id,
           '11111111-1111-1111-1111-111111111111' AS entra_tenant_id,
           '55555555-5555-5555-5555-555555555555' AS entra_group_object_id,
           '00000000-0000-0000-0000-000000000003' AS role_id
    FROM dual
) s
ON (t.entra_group_role_mapping_id = s.entra_group_role_mapping_id)
WHEN NOT MATCHED THEN INSERT (
    entra_group_role_mapping_id, entra_tenant_id, entra_group_object_id, role_id, is_active
) VALUES (
    s.entra_group_role_mapping_id, s.entra_tenant_id, s.entra_group_object_id, s.role_id, 'Y'
);

MERGE INTO entra_group_role_mapping t
USING (
    SELECT '20000012-0001-4001-8001-000000000012' AS entra_group_role_mapping_id,
           '11111111-1111-1111-1111-111111111111' AS entra_tenant_id,
           '66666666-6666-6666-6666-666666666666' AS entra_group_object_id,
           '00000000-0000-0000-0000-000000000004' AS role_id
    FROM dual
) s
ON (t.entra_group_role_mapping_id = s.entra_group_role_mapping_id)
WHEN NOT MATCHED THEN INSERT (
    entra_group_role_mapping_id, entra_tenant_id, entra_group_object_id, role_id, is_active
) VALUES (
    s.entra_group_role_mapping_id, s.entra_tenant_id, s.entra_group_object_id, s.role_id, 'Y'
);

COMMIT;

SELECT egm.entra_group_object_id, url.role_code
FROM entra_group_role_mapping egm
INNER JOIN user_role_lookup url ON url.role_id = egm.role_id
WHERE egm.is_active = 'Y'
ORDER BY url.role_code;
