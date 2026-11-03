-- =============================================================================
-- Scenario facility split: AIRPORT + child ATCT, remote comm sites, multi-manager
-- staffing. Uses facility IDs 10000014+ (10000009–0d reserved by 101 extended corridor).
-- =============================================================================

ALTER SESSION SET CONTAINER = FREEPDB1;
ALTER SESSION SET CURRENT_SCHEMA = nas_sim;
SET DEFINE OFF;

-- Remove mistaken ATCT staffing rows if a prior 113 run targeted 10000009 (KOMA).
DELETE FROM facility_staff_assignment
WHERE assignment_id IN (
    '33000001-0001-4001-8001-000000000001',
    '33000002-0001-4001-8001-000000000002',
    '33000003-0001-4001-8001-000000000003'
);

-- ---------------------------------------------------------------------------
-- Additional operator users for multi-manager staffing demos
-- ---------------------------------------------------------------------------

MERGE INTO users t
USING (SELECT '20000004-0001-4001-8001-000000000004' AS user_id, 'atc.supervisor.dsm' AS username,
              'DSM ATC Operations Supervisor' AS display_name, 'atc.supervisor.dsm@nas-sim.local' AS email FROM dual) s
ON (t.user_id = s.user_id)
WHEN NOT MATCHED THEN INSERT (user_id, username, display_name, email, is_active, auth_source, entra_tenant_id, entra_object_id, entra_upn, entra_display_name)
    VALUES (s.user_id, s.username, s.display_name, s.email, 'Y', 'LOCAL_DEV',
            '11111111-1111-1111-1111-111111111111', 'dddddddd-dddd-dddd-dddd-dddddddddddd',
            s.email, s.display_name);

MERGE INTO users t
USING (SELECT '20000005-0001-4001-8001-000000000005' AS user_id, 'atc.manager.dsm' AS username,
              'DSM Tower Facility Manager' AS display_name, 'atc.manager.dsm@nas-sim.local' AS email FROM dual) s
ON (t.user_id = s.user_id)
WHEN NOT MATCHED THEN INSERT (user_id, username, display_name, email, is_active, auth_source, entra_tenant_id, entra_object_id, entra_upn, entra_display_name)
    VALUES (s.user_id, s.username, s.display_name, s.email, 'Y', 'LOCAL_DEV',
            '11111111-1111-1111-1111-111111111111', 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee',
            s.email, s.display_name);

MERGE INTO users t
USING (SELECT '20000006-0001-4001-8001-000000000006' AS user_id, 'atc.manager.zau' AS username,
              'Chicago Center Facility Manager' AS display_name, 'atc.manager.zau@nas-sim.local' AS email FROM dual) s
ON (t.user_id = s.user_id)
WHEN NOT MATCHED THEN INSERT (user_id, username, display_name, email, is_active, auth_source, entra_tenant_id, entra_object_id, entra_upn, entra_display_name)
    VALUES (s.user_id, s.username, s.display_name, s.email, 'Y', 'LOCAL_DEV',
            '11111111-1111-1111-1111-111111111111', 'ffffffff-ffff-ffff-ffff-ffffffffffff',
            s.email, s.display_name);

-- ---------------------------------------------------------------------------
-- Child ATCT facilities (parent = AIRPORT)
-- ---------------------------------------------------------------------------

MERGE INTO facility t
USING (SELECT '10000014-0001-4001-8001-000000000014' AS facility_id, 'KDSM-ATCT' AS facility_code,
              'Des Moines Air Traffic Control Tower' AS name, 'ATCT' AS facility_type_code,
              '10000001-0001-4001-8001-000000000001' AS parent_facility_id,
              '5800 Fleur Dr' AS address_line1, 'Des Moines' AS city, 'IA' AS state_code, '50321' AS zip_code,
              41.5345000 AS latitude, -93.6628000 AS longitude, 965 AS elevation_ft,
              'America/Chicago' AS timezone_name, 'OPERATIONAL' AS operational_status,
              q'[{"coLocatedWith":"KDSM","faaFacilityClass":"Tower with Radar","parentRelationship":"CO_LOCATED_WITH_AIRPORT"}]' AS metadata_json FROM dual) s
ON (t.facility_id = s.facility_id)
WHEN NOT MATCHED THEN INSERT (
    facility_id, facility_code, name, facility_type_code, parent_facility_id,
    address_line1, city, state_code, zip_code, latitude, longitude, elevation_ft,
    timezone_name, operational_status, metadata_json, created_by, updated_by
) VALUES (
    s.facility_id, s.facility_code, s.name, s.facility_type_code, s.parent_facility_id,
    s.address_line1, s.city, s.state_code, s.zip_code, s.latitude, s.longitude, s.elevation_ft,
    s.timezone_name, s.operational_status, s.metadata_json,
    '20000001-0001-4001-8001-000000000001', '20000001-0001-4001-8001-000000000001'
);

MERGE INTO facility t
USING (SELECT '10000015-0001-4001-8001-000000000015' AS facility_id, 'KORD-ATCT' AS facility_code,
              'O''Hare Air Traffic Control Tower' AS name, 'ATCT' AS facility_type_code,
              '10000002-0001-4001-8001-000000000002' AS parent_facility_id,
              '10000 W O''Hare Ave' AS address_line1, 'Chicago' AS city, 'IL' AS state_code, '60666' AS zip_code,
              41.9780000 AS latitude, -87.9045000 AS longitude, 680 AS elevation_ft,
              'America/Chicago' AS timezone_name, 'OPERATIONAL' AS operational_status,
              q'[{"coLocatedWith":"KORD","faaFacilityClass":"Combined TRACON and Tower with Radar"}]' AS metadata_json FROM dual) s
ON (t.facility_id = s.facility_id)
WHEN NOT MATCHED THEN INSERT (
    facility_id, facility_code, name, facility_type_code, parent_facility_id,
    address_line1, city, state_code, zip_code, latitude, longitude, elevation_ft,
    timezone_name, operational_status, metadata_json, created_by, updated_by
) VALUES (
    s.facility_id, s.facility_code, s.name, s.facility_type_code, s.parent_facility_id,
    s.address_line1, s.city, s.state_code, s.zip_code, s.latitude, s.longitude, s.elevation_ft,
    s.timezone_name, s.operational_status, s.metadata_json,
    '20000001-0001-4001-8001-000000000001', '20000001-0001-4001-8001-000000000001'
);

-- ---------------------------------------------------------------------------
-- Remote communication facilities (v1: all three FAA NOTAM comm types)
-- ---------------------------------------------------------------------------

MERGE INTO facility t
USING (SELECT '10000016-0001-4001-8001-000000000016' AS facility_id, 'DSM-RCO-01' AS facility_code,
              'Des Moines Remote Communication Outlet' AS name, 'REMOTE_COM_OUTLET' AS facility_type_code,
              '10000005-0001-4001-8001-000000000005' AS parent_facility_id,
              'NW 62nd Ave' AS address_line1, 'Des Moines' AS city, 'IA' AS state_code, '50313' AS zip_code,
              41.6120000 AS latitude, -93.7890000 AS longitude, 920 AS elevation_ft,
              'America/Chicago' AS timezone_name, 'OPERATIONAL' AS operational_status,
              q'[{"remoteType":"RCO","servesTracon":"DSM-TRACON"}]' AS metadata_json FROM dual) s
ON (t.facility_id = s.facility_id)
WHEN NOT MATCHED THEN INSERT (
    facility_id, facility_code, name, facility_type_code, parent_facility_id,
    address_line1, city, state_code, zip_code, latitude, longitude, elevation_ft,
    timezone_name, operational_status, metadata_json, created_by, updated_by
) VALUES (
    s.facility_id, s.facility_code, s.name, s.facility_type_code, s.parent_facility_id,
    s.address_line1, s.city, s.state_code, s.zip_code, s.latitude, s.longitude, s.elevation_ft,
    s.timezone_name, s.operational_status, s.metadata_json,
    '20000001-0001-4001-8001-000000000001', '20000001-0001-4001-8001-000000000001'
);

MERGE INTO facility t
USING (SELECT '10000017-0001-4001-8001-000000000017' AS facility_id, 'ZAU-RCAG-01' AS facility_code,
              'Aurora Remote Center Air-to-Ground' AS name, 'REMOTE_CENTER_AG' AS facility_type_code,
              '10000004-0001-4001-8001-000000000004' AS parent_facility_id,
              'E Indian Trail Rd' AS address_line1, 'Aurora' AS city, 'IL' AS state_code, '60504' AS zip_code,
              41.7420000 AS latitude, -88.2650000 AS longitude, 705 AS elevation_ft,
              'America/Chicago' AS timezone_name, 'OPERATIONAL' AS operational_status,
              q'[{"remoteType":"REMOTE_CENTER_A/G","parentArtcc":"ZAU"}]' AS metadata_json FROM dual) s
ON (t.facility_id = s.facility_id)
WHEN NOT MATCHED THEN INSERT (
    facility_id, facility_code, name, facility_type_code, parent_facility_id,
    address_line1, city, state_code, zip_code, latitude, longitude, elevation_ft,
    timezone_name, operational_status, metadata_json, created_by, updated_by
) VALUES (
    s.facility_id, s.facility_code, s.name, s.facility_type_code, s.parent_facility_id,
    s.address_line1, s.city, s.state_code, s.zip_code, s.latitude, s.longitude, s.elevation_ft,
    s.timezone_name, s.operational_status, s.metadata_json,
    '20000001-0001-4001-8001-000000000001', '20000001-0001-4001-8001-000000000001'
);

MERGE INTO facility t
USING (SELECT '10000018-0001-4001-8001-000000000018' AS facility_id, 'ZAU-RTR-01' AS facility_code,
              'Plano Remote Transmitter/Receiver' AS name, 'REMOTE_TRANS_REC' AS facility_type_code,
              '10000004-0001-4001-8001-000000000004' AS parent_facility_id,
              'S Route 59' AS address_line1, 'Plano' AS city, 'IL' AS state_code, '60545' AS zip_code,
              41.6580000 AS latitude, -88.5380000 AS longitude, 680 AS elevation_ft,
              'America/Chicago' AS timezone_name, 'OPERATIONAL' AS operational_status,
              q'[{"remoteType":"REMOTE_TRANS/REC","parentArtcc":"ZAU"}]' AS metadata_json FROM dual) s
ON (t.facility_id = s.facility_id)
WHEN NOT MATCHED THEN INSERT (
    facility_id, facility_code, name, facility_type_code, parent_facility_id,
    address_line1, city, state_code, zip_code, latitude, longitude, elevation_ft,
    timezone_name, operational_status, metadata_json, created_by, updated_by
) VALUES (
    s.facility_id, s.facility_code, s.name, s.facility_type_code, s.parent_facility_id,
    s.address_line1, s.city, s.state_code, s.zip_code, s.latitude, s.longitude, s.elevation_ft,
    s.timezone_name, s.operational_status, s.metadata_json,
    '20000001-0001-4001-8001-000000000001', '20000001-0001-4001-8001-000000000001'
);

-- Move tower comm equipment from airport to child ATCT
UPDATE equipment
SET facility_id = '10000014-0001-4001-8001-000000000014', updated_at = SYSTIMESTAMP
WHERE identifier = 'COM-DSM-TWR'
  AND facility_id = '10000001-0001-4001-8001-000000000001';

-- Remote site equipment
MERGE INTO equipment t
USING (SELECT '12000030-0001-4001-8001-000000000030' AS equipment_id,
              '10000016-0001-4001-8001-000000000016' AS facility_id,
              'COM_VHF' AS equipment_type_code, 'RCO-DSM-01' AS identifier,
              'RCO VHF — Des Moines outlet' AS name, 'OPERATIONAL' AS operational_status FROM dual) s
ON (t.equipment_id = s.equipment_id)
WHEN NOT MATCHED THEN INSERT (equipment_id, facility_id, equipment_type_code, identifier, name, operational_status, installed_at)
    VALUES (s.equipment_id, s.facility_id, s.equipment_type_code, s.identifier, s.name, s.operational_status, SYSTIMESTAMP);

MERGE INTO equipment t
USING (SELECT '12000031-0001-4001-8001-000000000031' AS equipment_id,
              '10000017-0001-4001-8001-000000000017' AS facility_id,
              'COM_UHF' AS equipment_type_code, 'RCAG-ZAU-01' AS identifier,
              'Remote Center A/G UHF — Aurora' AS name, 'OPERATIONAL' AS operational_status FROM dual) s
ON (t.equipment_id = s.equipment_id)
WHEN NOT MATCHED THEN INSERT (equipment_id, facility_id, equipment_type_code, identifier, name, operational_status, installed_at)
    VALUES (s.equipment_id, s.facility_id, s.equipment_type_code, s.identifier, s.name, s.operational_status, SYSTIMESTAMP);

MERGE INTO equipment t
USING (SELECT '12000032-0001-4001-8001-000000000032' AS equipment_id,
              '10000018-0001-4001-8001-000000000018' AS facility_id,
              'COM_VHF' AS equipment_type_code, 'RTR-ZAU-VHF' AS identifier,
              'Remote Transceiver VHF — Plano' AS name, 'OPERATIONAL' AS operational_status FROM dual) s
ON (t.equipment_id = s.equipment_id)
WHEN NOT MATCHED THEN INSERT (equipment_id, facility_id, equipment_type_code, identifier, name, operational_status, installed_at)
    VALUES (s.equipment_id, s.facility_id, s.equipment_type_code, s.identifier, s.name, s.operational_status, SYSTIMESTAMP);

MERGE INTO equipment t
USING (SELECT '12000033-0001-4001-8001-000000000033' AS equipment_id,
              '10000018-0001-4001-8001-000000000018' AS facility_id,
              'COM_UHF' AS equipment_type_code, 'RTR-ZAU-UHF' AS identifier,
              'Remote Transceiver UHF — Plano' AS name, 'OPERATIONAL' AS operational_status FROM dual) s
ON (t.equipment_id = s.equipment_id)
WHEN NOT MATCHED THEN INSERT (equipment_id, facility_id, equipment_type_code, identifier, name, operational_status, installed_at)
    VALUES (s.equipment_id, s.facility_id, s.equipment_type_code, s.identifier, s.name, s.operational_status, SYSTIMESTAMP);

-- ---------------------------------------------------------------------------
-- Multi-manager staffing (multiple FACILITY_MANAGER rows per facility allowed)
-- ---------------------------------------------------------------------------

MERGE INTO facility_staff_assignment t
USING (SELECT '33000001-0001-4001-8001-000000000001' AS assignment_id,
              '10000014-0001-4001-8001-000000000014' AS facility_id,
              '20000005-0001-4001-8001-000000000005' AS user_id,
              'FACILITY_MANAGER' AS role_code, 'Y' AS is_lead FROM dual) s
ON (t.assignment_id = s.assignment_id)
WHEN NOT MATCHED THEN INSERT (assignment_id, facility_id, user_id, role_code, is_lead, assigned_by_user_id)
    VALUES (s.assignment_id, s.facility_id, s.user_id, s.role_code, s.is_lead, '20000001-0001-4001-8001-000000000001');

MERGE INTO facility_staff_assignment t
USING (SELECT '33000002-0001-4001-8001-000000000002' AS assignment_id,
              '10000014-0001-4001-8001-000000000014' AS facility_id,
              '20000004-0001-4001-8001-000000000004' AS user_id,
              'FACILITY_MANAGER' AS role_code, 'N' AS is_lead FROM dual) s
ON (t.assignment_id = s.assignment_id)
WHEN NOT MATCHED THEN INSERT (assignment_id, facility_id, user_id, role_code, is_lead, assigned_by_user_id)
    VALUES (s.assignment_id, s.facility_id, s.user_id, s.role_code, s.is_lead, '20000001-0001-4001-8001-000000000001');

MERGE INTO facility_staff_assignment t
USING (SELECT '33000003-0001-4001-8001-000000000003' AS assignment_id,
              '10000014-0001-4001-8001-000000000014' AS facility_id,
              '20000004-0001-4001-8001-000000000004' AS user_id,
              'ATC_SUPERVISOR' AS role_code, 'Y' AS is_lead FROM dual) s
ON (t.assignment_id = s.assignment_id)
WHEN NOT MATCHED THEN INSERT (assignment_id, facility_id, user_id, role_code, is_lead, assigned_by_user_id)
    VALUES (s.assignment_id, s.facility_id, s.user_id, s.role_code, s.is_lead, '20000001-0001-4001-8001-000000000001');

MERGE INTO facility_staff_assignment t
USING (SELECT '33000004-0001-4001-8001-000000000004' AS assignment_id,
              '10000004-0001-4001-8001-000000000004' AS facility_id,
              '20000006-0001-4001-8001-000000000006' AS user_id,
              'FACILITY_MANAGER' AS role_code, 'Y' AS is_lead FROM dual) s
ON (t.assignment_id = s.assignment_id)
WHEN NOT MATCHED THEN INSERT (assignment_id, facility_id, user_id, role_code, is_lead, assigned_by_user_id)
    VALUES (s.assignment_id, s.facility_id, s.user_id, s.role_code, s.is_lead, '20000001-0001-4001-8001-000000000001');

MERGE INTO facility_staff_assignment t
USING (SELECT '33000005-0001-4001-8001-000000000005' AS assignment_id,
              '10000004-0001-4001-8001-000000000004' AS facility_id,
              '20000001-0001-4001-8001-000000000001' AS user_id,
              'FACILITY_MANAGER' AS role_code, 'N' AS is_lead FROM dual) s
ON (t.assignment_id = s.assignment_id)
WHEN NOT MATCHED THEN INSERT (assignment_id, facility_id, user_id, role_code, is_lead, assigned_by_user_id)
    VALUES (s.assignment_id, s.facility_id, s.user_id, s.role_code, s.is_lead, '20000001-0001-4001-8001-000000000001');

MERGE INTO facility_staff_assignment t
USING (SELECT '33000006-0001-4001-8001-000000000006' AS assignment_id,
              '10000001-0001-4001-8001-000000000001' AS facility_id,
              '20000005-0001-4001-8001-000000000005' AS user_id,
              'FACILITY_MANAGER' AS role_code, 'Y' AS is_lead FROM dual) s
ON (t.assignment_id = s.assignment_id)
WHEN NOT MATCHED THEN INSERT (assignment_id, facility_id, user_id, role_code, is_lead, assigned_by_user_id)
    VALUES (s.assignment_id, s.facility_id, s.user_id, s.role_code, s.is_lead, '20000001-0001-4001-8001-000000000001');

MERGE INTO facility_staff_assignment t
USING (SELECT '33000007-0001-4001-8001-000000000007' AS assignment_id,
              '10000006-0001-4001-8001-000000000006' AS facility_id,
              '20000002-0001-4001-8001-000000000002' AS user_id,
              'MAINTENANCE_LEAD' AS role_code, 'Y' AS is_lead FROM dual) s
ON (t.assignment_id = s.assignment_id)
WHEN NOT MATCHED THEN INSERT (assignment_id, facility_id, user_id, role_code, is_lead, assigned_by_user_id)
    VALUES (s.assignment_id, s.facility_id, s.user_id, s.role_code, s.is_lead, '20000001-0001-4001-8001-000000000001');

-- ---------------------------------------------------------------------------
-- Unity geo lookups for new facilities (alpha-midwest render context)
-- ---------------------------------------------------------------------------

MERGE INTO simulation_geo_location_lookup t
USING (SELECT '2a000010-0001-4001-8001-000000000010' AS simulation_geo_location_id,
              '00000000-0000-0000-0000-000000000010' AS render_context_id,
              '10000014-0001-4001-8001-000000000014' AS facility_id,
              'Des Moines' AS real_city, 'IA' AS real_state_code, '50321' AS real_zip_code,
              0.0020000 AS virtual_latitude, 0.0010000 AS virtual_longitude, 0 AS virtual_elevation_ft,
              q'[{"unityPosition":{"x":2,"y":0,"z":1},"scale":0.85,"rotationYDegrees":0,"mapLayer":"alpha-midwest","facilityType":"ATCT","coLocatedFacilityId":"10000001-0001-4001-8001-000000000001"}]' AS transform_json,
              'DSM tower — co-located offset from airport field' AS notes FROM dual) s
ON (t.simulation_geo_location_id = s.simulation_geo_location_id)
WHEN NOT MATCHED THEN INSERT (
    simulation_geo_location_id, render_context_id, facility_id,
    real_city, real_state_code, real_zip_code,
    virtual_latitude, virtual_longitude, virtual_elevation_ft, transform_json, notes, is_enabled
) VALUES (
    s.simulation_geo_location_id, s.render_context_id, s.facility_id,
    s.real_city, s.real_state_code, s.real_zip_code,
    s.virtual_latitude, s.virtual_longitude, s.virtual_elevation_ft, s.transform_json, s.notes, 'Y'
);

MERGE INTO simulation_geo_location_lookup t
USING (SELECT '2a000011-0001-4001-8001-000000000011' AS simulation_geo_location_id,
              '00000000-0000-0000-0000-000000000010' AS render_context_id,
              '10000016-0001-4001-8001-000000000016' AS facility_id,
              'Des Moines' AS real_city, 'IA' AS real_state_code, '50313' AS real_zip_code,
              -0.0800000 AS virtual_latitude, -0.1200000 AS virtual_longitude, 0 AS virtual_elevation_ft,
              q'[{"unityPosition":{"x":-12,"y":0,"z":-8},"scale":0.7,"rotationYDegrees":0,"mapLayer":"alpha-midwest","facilityType":"REMOTE_COM_OUTLET"}]' AS transform_json,
              'DSM RCO — west of corridor hub' AS notes FROM dual) s
ON (t.simulation_geo_location_id = s.simulation_geo_location_id)
WHEN NOT MATCHED THEN INSERT (
    simulation_geo_location_id, render_context_id, facility_id,
    real_city, real_state_code, real_zip_code,
    virtual_latitude, virtual_longitude, virtual_elevation_ft, transform_json, notes, is_enabled
) VALUES (
    s.simulation_geo_location_id, s.render_context_id, s.facility_id,
    s.real_city, s.real_state_code, s.real_zip_code,
    s.virtual_latitude, s.virtual_longitude, s.virtual_elevation_ft, s.transform_json, s.notes, 'Y'
);

MERGE INTO simulation_geo_location_lookup t
USING (SELECT '2a000012-0001-4001-8001-000000000012' AS simulation_geo_location_id,
              '00000000-0000-0000-0000-000000000010' AS render_context_id,
              '10000017-0001-4001-8001-000000000017' AS facility_id,
              'Aurora' AS real_city, 'IL' AS real_state_code, '60504' AS real_zip_code,
              0.0000000 AS virtual_latitude, 2.3500000 AS virtual_longitude, 0 AS virtual_elevation_ft,
              q'[{"unityPosition":{"x":235,"y":0,"z":0},"scale":0.75,"rotationYDegrees":0,"mapLayer":"alpha-midwest","facilityType":"REMOTE_CENTER_AG"}]' AS transform_json,
              'ZAU remote center A/G' AS notes FROM dual) s
ON (t.simulation_geo_location_id = s.simulation_geo_location_id)
WHEN NOT MATCHED THEN INSERT (
    simulation_geo_location_id, render_context_id, facility_id,
    real_city, real_state_code, real_zip_code,
    virtual_latitude, virtual_longitude, virtual_elevation_ft, transform_json, notes, is_enabled
) VALUES (
    s.simulation_geo_location_id, s.render_context_id, s.facility_id,
    s.real_city, s.real_state_code, s.real_zip_code,
    s.virtual_latitude, s.virtual_longitude, s.virtual_elevation_ft, s.transform_json, s.notes, 'Y'
);

MERGE INTO simulation_geo_location_lookup t
USING (SELECT '2a000013-0001-4001-8001-000000000013' AS simulation_geo_location_id,
              '00000000-0000-0000-0000-000000000010' AS render_context_id,
              '10000018-0001-4001-8001-000000000018' AS facility_id,
              'Plano' AS real_city, 'IL' AS real_state_code, '60545' AS real_zip_code,
              -0.0500000 AS virtual_latitude, 2.2800000 AS virtual_longitude, 0 AS virtual_elevation_ft,
              q'[{"unityPosition":{"x":228,"y":0,"z":-5},"scale":0.75,"rotationYDegrees":0,"mapLayer":"alpha-midwest","facilityType":"REMOTE_TRANS_REC"}]' AS transform_json,
              'ZAU remote transceiver' AS notes FROM dual) s
ON (t.simulation_geo_location_id = s.simulation_geo_location_id)
WHEN NOT MATCHED THEN INSERT (
    simulation_geo_location_id, render_context_id, facility_id,
    real_city, real_state_code, real_zip_code,
    virtual_latitude, virtual_longitude, virtual_elevation_ft, transform_json, notes, is_enabled
) VALUES (
    s.simulation_geo_location_id, s.render_context_id, s.facility_id,
    s.real_city, s.real_state_code, s.real_zip_code,
    s.virtual_latitude, s.virtual_longitude, s.virtual_elevation_ft, s.transform_json, s.notes, 'Y'
);
