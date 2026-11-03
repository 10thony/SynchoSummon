ALTER SESSION SET CONTAINER = FREEPDB1;
ALTER SESSION SET CURRENT_SCHEMA = nas_sim;

MERGE INTO users u
USING (SELECT '00000000-0000-0000-0000-000000000100' AS user_id FROM dual) s
ON (u.user_id = s.user_id)
WHEN NOT MATCHED THEN INSERT (
    user_id, username, display_name, email, is_active, auth_source,
    entra_tenant_id, entra_object_id, entra_upn, entra_display_name
) VALUES (
    '00000000-0000-0000-0000-000000000100', 'dev.operator', 'Dev Operator',
    'dev.operator@nas-sim.local', 'Y', 'LOCAL_DEV',
    '11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222',
    'dev.operator@nas-sim.local', 'Dev Operator'
);

MERGE INTO entra_group_role_mapping e
USING (SELECT '00000000-0000-0000-0000-000000000200' AS id FROM dual) s
ON (e.entra_group_role_mapping_id = s.id)
WHEN NOT MATCHED THEN INSERT (
    entra_group_role_mapping_id, entra_tenant_id, entra_group_object_id, role_id, is_active
) VALUES (
    '00000000-0000-0000-0000-000000000200',
    '11111111-1111-1111-1111-111111111111',
    '33333333-3333-3333-3333-333333333333',
    '00000000-0000-0000-0000-000000000002', 'Y'
);

COMMIT;
