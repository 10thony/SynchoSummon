-- =============================================================================
-- WebGPU live simulation assets v3: activity slots, manufacturer staging sites,
-- KORD-ATCT geo, NAVAID_SITE profile, shipment origin wiring.
-- =============================================================================

ALTER SESSION SET CONTAINER = FREEPDB1;
ALTER SESSION SET CURRENT_SCHEMA = nas_sim;
SET DEFINE OFF;

-- ---------------------------------------------------------------------------
-- Profile v3: activitySlots + pathHints
-- ---------------------------------------------------------------------------

MERGE INTO facility_type_asset_profile t
USING (SELECT 'AIRPORT' AS facility_type_code, 3 AS profile_version,
              q'[{"structureBlocks":[{"name":"Terminal","primitive":"cube","position":[-2.8,0,2.2],"scale":[6.5,5,5],"color":[0.55,0.58,0.62],"smoothness":0.55,"metallic":0.12},{"name":"Ramp","primitive":"cube","position":[3.2,0.4,2],"scale":[5.5,0.12,5],"color":[0.3,0.31,0.33],"smoothness":0.22,"metallic":0},{"name":"Tower","primitive":"tower","position":[-3.5,0,-3.2],"scale":[2.4,10,2.4],"color":[0.58,0.62,0.68],"smoothness":0.6,"metallic":0.15}],"runwayMarkings":true,"beacon":{"position":[0,22,0],"airportColor":[0.35,0.85,1],"pulseHz":0.5},"overviewCamera":{"offset":[0,45,-55],"scaleFactor":1.0},"activitySlots":[{"id":"gate-a","kind":"AIRCRAFT_PARKING","position":{"x":3,"y":0,"z":2},"capacity":1},{"id":"gate-b","kind":"AIRCRAFT_PARKING","position":{"x":-1,"y":0,"z":3.5},"capacity":1},{"id":"fuel-pad","kind":"SERVICE_VEHICLE","position":{"x":4.5,"y":0,"z":0.5},"capacity":1},{"id":"crew-door","kind":"PERSONNEL_ENTRY","position":{"x":0,"y":0,"z":-5}}],"pathHints":{"taxiOut":["gate-a","junction"],"workerInbound":["junction","crew-door"]}}]' AS asset_profile_json,
              q'[{"minManagers":1,"typicalRoles":["FACILITY_MANAGER","TECHNICIAN"]}]' AS personnel_defaults_json FROM dual) s
ON (t.facility_type_code = s.facility_type_code)
WHEN MATCHED THEN UPDATE SET t.profile_version = s.profile_version, t.asset_profile_json = s.asset_profile_json, t.updated_at = SYSTIMESTAMP
WHEN NOT MATCHED THEN INSERT (facility_type_code, profile_version, asset_profile_json, personnel_defaults_json)
    VALUES (s.facility_type_code, s.profile_version, s.asset_profile_json, s.personnel_defaults_json);

MERGE INTO facility_type_asset_profile t
USING (SELECT 'PART_WAREHOUSE' AS facility_type_code, 3 AS profile_version,
              q'[{"structureBlocks":[{"name":"MainWarehouse","primitive":"cube","position":[0,5,0],"scale":[16,10,12],"color":[0.52,0.54,0.58],"smoothness":0.38,"metallic":0.12},{"name":"DockA","primitive":"cube","position":[-6,2.5,6],"scale":[5,5,4],"color":[0.48,0.46,0.42],"smoothness":0.35,"metallic":0.08,"emission":0.35,"emissionColor":[1.0,0.72,0.25]},{"name":"DockB","primitive":"cube","position":[6,2.5,6],"scale":[5,5,4],"color":[0.48,0.46,0.42],"smoothness":0.35,"metallic":0.08,"emission":0.35,"emissionColor":[1.0,0.72,0.25]}],"beacon":{"position":[-6,6.5,6],"airportColor":[1.0,0.75,0.3],"pulseHz":0.4},"overviewCamera":{"offset":[0,45,-65],"scaleFactor":1.05},"activitySlots":[{"id":"dock-a","kind":"PART_DOCK","position":{"x":-3.5,"y":0,"z":4},"roles":["PARTS_CLERK","LOGISTICS_COORDINATOR"]},{"id":"dock-b","kind":"PART_DOCK","position":{"x":3.5,"y":0,"z":4},"roles":["PARTS_CLERK"]},{"id":"staging","kind":"PART_DOCK","position":{"x":0,"y":0,"z":2},"roles":["WAREHOUSE_MANAGER"]},{"id":"cargo-a","kind":"AIRCRAFT_PARKING","position":{"x":-5.5,"y":0,"z":6.8},"capacity":1},{"id":"cargo-b","kind":"AIRCRAFT_PARKING","position":{"x":0,"y":0,"z":7.2},"capacity":1},{"id":"cargo-c","kind":"AIRCRAFT_PARKING","position":{"x":5.5,"y":0,"z":6.8},"capacity":1},{"id":"crew-door","kind":"PERSONNEL_ENTRY","position":{"x":0,"y":0,"z":-4.5}}],"pathHints":{"workerInbound":["junction","crew-door"]}}]' AS asset_profile_json,
              q'[{"minManagers":1,"typicalRoles":["WAREHOUSE_MANAGER","LOGISTICS_COORDINATOR","PARTS_CLERK"]}]' AS personnel_defaults_json FROM dual) s
ON (t.facility_type_code = s.facility_type_code)
WHEN MATCHED THEN UPDATE SET t.profile_version = s.profile_version, t.asset_profile_json = s.asset_profile_json, t.personnel_defaults_json = s.personnel_defaults_json, t.updated_at = SYSTIMESTAMP
WHEN NOT MATCHED THEN INSERT (facility_type_code, profile_version, asset_profile_json, personnel_defaults_json)
    VALUES (s.facility_type_code, s.profile_version, s.asset_profile_json, s.personnel_defaults_json);

MERGE INTO facility_type_asset_profile t
USING (SELECT 'MAINTENANCE_DEPOT' AS facility_type_code, 3 AS profile_version,
              q'[{"structureBlocks":[{"name":"Depot","primitive":"cube","position":[0,4,-2],"scale":[14,8,10],"color":[0.45,0.42,0.38],"smoothness":0.35,"metallic":0.05},{"name":"BayA","primitive":"cube","position":[-5,2,4],"scale":[4,4,6],"color":[0.55,0.52,0.48],"smoothness":0.4,"metallic":0.08},{"name":"BayB","primitive":"cube","position":[5,2,4],"scale":[4,4,6],"color":[0.55,0.52,0.48],"smoothness":0.4,"metallic":0.08}],"overviewCamera":{"offset":[0,40,-60],"scaleFactor":1.0},"activitySlots":[{"id":"bay-a","kind":"MAINTENANCE_BAY","position":{"x":-4,"y":0,"z":3}},{"id":"bay-b","kind":"MAINTENANCE_BAY","position":{"x":4,"y":0,"z":3}},{"id":"crew-door","kind":"PERSONNEL_ENTRY","position":{"x":0,"y":0,"z":-5}}],"pathHints":{"workerOutbound":["crew-door","junction"]}}]' AS asset_profile_json,
              q'[{"minManagers":1,"typicalRoles":["FACILITY_MANAGER","MAINTENANCE_LEAD","TECHNICIAN"]}]' AS personnel_defaults_json FROM dual) s
ON (t.facility_type_code = s.facility_type_code)
WHEN MATCHED THEN UPDATE SET t.profile_version = s.profile_version, t.asset_profile_json = s.asset_profile_json, t.updated_at = SYSTIMESTAMP
WHEN NOT MATCHED THEN INSERT (facility_type_code, profile_version, asset_profile_json, personnel_defaults_json)
    VALUES (s.facility_type_code, s.profile_version, s.asset_profile_json, s.personnel_defaults_json);

MERGE INTO facility_type_asset_profile t
USING (SELECT 'NAVAID_SITE' AS facility_type_code, 1 AS profile_version,
              q'[{"structureBlocks":[{"name":"EquipmentShelter","primitive":"cube","position":[0,1.5,0],"scale":[3,3,3],"color":[0.5,0.52,0.56],"smoothness":0.4,"metallic":0.08},{"name":"VorMast","primitive":"cylinder","position":[0,5,0],"scale":[0.4,5,0.4],"color":[0.72,0.74,0.78],"smoothness":0.55,"metallic":0.3},{"name":"DmeArray","primitive":"ring","position":[0,2.2,0],"scale":[2.2,0.2,2.2],"color":[0.8,0.82,0.86],"smoothness":0.7,"metallic":0.2}],"overviewCamera":{"offset":[0,30,-40],"scaleFactor":0.9},"activitySlots":[{"id":"equip-pad","kind":"MAINTENANCE_BAY","position":{"x":0,"y":0,"z":1.5}}],"unstaffed":true}]' AS asset_profile_json,
              q'[{"minManagers":0,"typicalRoles":["TECHNICIAN"]}]' AS personnel_defaults_json FROM dual) s
ON (t.facility_type_code = s.facility_type_code)
WHEN MATCHED THEN UPDATE SET t.profile_version = s.profile_version, t.asset_profile_json = s.asset_profile_json, t.updated_at = SYSTIMESTAMP
WHEN NOT MATCHED THEN INSERT (facility_type_code, profile_version, asset_profile_json, personnel_defaults_json)
    VALUES (s.facility_type_code, s.profile_version, s.asset_profile_json, s.personnel_defaults_json);

-- ---------------------------------------------------------------------------
-- Virtual manufacturer staging sites (off-grid west of corridor)
-- ---------------------------------------------------------------------------

MERGE INTO facility t
USING (SELECT '10000030-0001-4001-8001-000000000030' AS facility_id, 'OEM-THALES' AS facility_code,
              'Thales Avionics Staging' AS name, 'PART_WAREHOUSE' AS facility_type_code,
              NULL AS parent_facility_id, 'Off-NAS OEM' AS address_line1, 'Remote' AS city, 'IA' AS state_code,
              '00000' AS zip_code, 41.5000000 AS latitude, -95.0000000 AS longitude, 900 AS elevation_ft,
              'America/Chicago' AS timezone_name, 'OPERATIONAL' AS operational_status,
              q'[{"manufacturerCode":"THALES","virtualStaging":true}]' AS metadata_json FROM dual) s
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
USING (SELECT '10000031-0001-4001-8001-000000000031' AS facility_id, 'OEM-RAYTHEON' AS facility_code,
              'Raytheon OEM Staging' AS name, 'PART_WAREHOUSE' AS facility_type_code,
              NULL AS parent_facility_id, 'Off-NAS OEM' AS address_line1, 'Remote' AS city, 'MA' AS state_code,
              '00000' AS zip_code, 42.5000000 AS latitude, -94.5000000 AS longitude, 900 AS elevation_ft,
              'America/Chicago' AS timezone_name, 'OPERATIONAL' AS operational_status,
              q'[{"manufacturerCode":"RAYTHEON","virtualStaging":true}]' AS metadata_json FROM dual) s
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
USING (SELECT '10000032-0001-4001-8001-000000000032' AS facility_id, 'OEM-HONEYWELL' AS facility_code,
              'Honeywell OEM Staging' AS name, 'PART_WAREHOUSE' AS facility_type_code,
              NULL AS parent_facility_id, 'Off-NAS OEM' AS address_line1, 'Remote' AS city, 'AZ' AS state_code,
              '00000' AS zip_code, 41.2000000 AS latitude, -94.0000000 AS longitude, 900 AS elevation_ft,
              'America/Chicago' AS timezone_name, 'OPERATIONAL' AS operational_status,
              q'[{"manufacturerCode":"HONEYWELL","virtualStaging":true}]' AS metadata_json FROM dual) s
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

MERGE INTO simulation_geo_location_lookup t
USING (SELECT '2a000030-0001-4001-8001-000000000030' AS simulation_geo_location_id,
              '00000000-0000-0000-0000-000000000010' AS render_context_id,
              '10000030-0001-4001-8001-000000000030' AS facility_id,
              'Remote' AS real_city, 'IA' AS real_state_code, '00000' AS real_zip_code,
              0.0000000 AS virtual_latitude, -120.0000000 AS virtual_longitude, 900 AS virtual_elevation_ft,
              NULL AS grid_row, NULL AS grid_col, 'Y' AS is_enabled,
              q'[{"unityPosition":{"x":-420,"y":0,"z":0},"scale":0.85,"notes":"Virtual OEM staging west of corridor"}]' AS transform_json,
              'Thales OEM virtual staging' AS notes FROM dual) s
ON (t.simulation_geo_location_id = s.simulation_geo_location_id)
WHEN NOT MATCHED THEN INSERT (
    simulation_geo_location_id, render_context_id, facility_id,
    real_city, real_state_code, real_zip_code,
    virtual_latitude, virtual_longitude, virtual_elevation_ft,
    grid_row, grid_col, is_enabled, transform_json, notes
) VALUES (
    s.simulation_geo_location_id, s.render_context_id, s.facility_id,
    s.real_city, s.real_state_code, s.real_zip_code,
    s.virtual_latitude, s.virtual_longitude, s.virtual_elevation_ft,
    s.grid_row, s.grid_col, s.is_enabled, s.transform_json, s.notes
);

MERGE INTO simulation_geo_location_lookup t
USING (SELECT '2a000031-0001-4001-8001-000000000031' AS simulation_geo_location_id,
              '00000000-0000-0000-0000-000000000010' AS render_context_id,
              '10000031-0001-4001-8001-000000000031' AS facility_id,
              'Remote' AS real_city, 'MA' AS real_state_code, '00000' AS real_zip_code,
              0.0000000 AS virtual_latitude, -110.0000000 AS virtual_longitude, 900 AS virtual_elevation_ft,
              NULL AS grid_row, NULL AS grid_col, 'Y' AS is_enabled,
              q'[{"unityPosition":{"x":-340,"y":0,"z":40},"scale":0.85,"notes":"Virtual OEM staging west of corridor"}]' AS transform_json,
              'Raytheon OEM virtual staging' AS notes FROM dual) s
ON (t.simulation_geo_location_id = s.simulation_geo_location_id)
WHEN NOT MATCHED THEN INSERT (
    simulation_geo_location_id, render_context_id, facility_id,
    real_city, real_state_code, real_zip_code,
    virtual_latitude, virtual_longitude, virtual_elevation_ft,
    grid_row, grid_col, is_enabled, transform_json, notes
) VALUES (
    s.simulation_geo_location_id, s.render_context_id, s.facility_id,
    s.real_city, s.real_state_code, s.real_zip_code,
    s.virtual_latitude, s.virtual_longitude, s.virtual_elevation_ft,
    s.grid_row, s.grid_col, s.is_enabled, s.transform_json, s.notes
);

MERGE INTO simulation_geo_location_lookup t
USING (SELECT '2a000032-0001-4001-8001-000000000032' AS simulation_geo_location_id,
              '00000000-0000-0000-0000-000000000010' AS render_context_id,
              '10000032-0001-4001-8001-000000000032' AS facility_id,
              'Remote' AS real_city, 'AZ' AS real_state_code, '00000' AS real_zip_code,
              0.0000000 AS virtual_latitude, -100.0000000 AS virtual_longitude, 900 AS virtual_elevation_ft,
              NULL AS grid_row, NULL AS grid_col, 'Y' AS is_enabled,
              q'[{"unityPosition":{"x":-260,"y":0,"z":-20},"scale":0.85,"notes":"Virtual OEM staging west of corridor"}]' AS transform_json,
              'Honeywell OEM virtual staging' AS notes FROM dual) s
ON (t.simulation_geo_location_id = s.simulation_geo_location_id)
WHEN NOT MATCHED THEN INSERT (
    simulation_geo_location_id, render_context_id, facility_id,
    real_city, real_state_code, real_zip_code,
    virtual_latitude, virtual_longitude, virtual_elevation_ft,
    grid_row, grid_col, is_enabled, transform_json, notes
) VALUES (
    s.simulation_geo_location_id, s.render_context_id, s.facility_id,
    s.real_city, s.real_state_code, s.real_zip_code,
    s.virtual_latitude, s.virtual_longitude, s.virtual_elevation_ft,
    s.grid_row, s.grid_col, s.is_enabled, s.transform_json, s.notes
);

-- KORD-ATCT tower site (adjacent to KORD on grid)
MERGE INTO simulation_geo_location_lookup t
USING (SELECT '2a000015-0001-4001-8001-000000000015' AS simulation_geo_location_id,
              '00000000-0000-0000-0000-000000000010' AS render_context_id,
              '10000015-0001-4001-8001-000000000015' AS facility_id,
              'Chicago' AS real_city, 'IL' AS real_state_code, '60666' AS real_zip_code,
              41.9780000 AS virtual_latitude, 120.0000000 AS virtual_longitude, 680 AS virtual_elevation_ft,
              0 AS grid_row, 4 AS grid_col, 'Y' AS is_enabled,
              q'[{"coLocatedWith":"KORD","notes":"O''Hare ATCT visual site"}]' AS transform_json,
              'KORD ATCT visual site' AS notes FROM dual) s
ON (t.simulation_geo_location_id = s.simulation_geo_location_id)
WHEN NOT MATCHED THEN INSERT (
    simulation_geo_location_id, render_context_id, facility_id,
    real_city, real_state_code, real_zip_code,
    virtual_latitude, virtual_longitude, virtual_elevation_ft,
    grid_row, grid_col, is_enabled, transform_json, notes
) VALUES (
    s.simulation_geo_location_id, s.render_context_id, s.facility_id,
    s.real_city, s.real_state_code, s.real_zip_code,
    s.virtual_latitude, s.virtual_longitude, s.virtual_elevation_ft,
    s.grid_row, s.grid_col, s.is_enabled, s.transform_json, s.notes
);

-- Wire manufacturer shipment to virtual origin facility
UPDATE equipment_part_shipment
SET origin_facility_id = '10000030-0001-4001-8001-000000000030',
    updated_at = SYSTIMESTAMP
WHERE equipment_part_shipment_id = '1e000001-0001-4001-8001-000000000001'
  AND origin_facility_id IS NULL;

COMMIT;
