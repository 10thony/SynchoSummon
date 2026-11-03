-- =============================================================================
-- Facility types (FAA-aligned), personnel roles, Unity asset profiles,
-- and per-type equipment requirements.
-- =============================================================================

ALTER SESSION SET CONTAINER = FREEPDB1;
ALTER SESSION SET CURRENT_SCHEMA = nas_sim;
SET DEFINE OFF;

-- ---------------------------------------------------------------------------
-- Extended facility types (public FAA taxonomy + sim types)
-- ---------------------------------------------------------------------------

MERGE INTO facility_type_lkp t
USING (SELECT 'ATCT' AS facility_type_code, 'Air Traffic Control Tower' AS display_name,
              'Staffed airport tower providing local ATC services' AS description FROM dual) s
ON (t.facility_type_code = s.facility_type_code)
WHEN NOT MATCHED THEN INSERT (facility_type_code, display_name, description)
    VALUES (s.facility_type_code, s.display_name, s.description);

MERGE INTO facility_type_lkp t
USING (SELECT 'COMBINED_TRACON_TOWER' AS facility_type_code, 'Combined TRACON & Tower' AS display_name,
              'Co-located terminal radar approach and tower control (OPSNET type 3)' AS description FROM dual) s
ON (t.facility_type_code = s.facility_type_code)
WHEN NOT MATCHED THEN INSERT (facility_type_code, display_name, description)
    VALUES (s.facility_type_code, s.display_name, s.description);

MERGE INTO facility_type_lkp t
USING (SELECT 'CCF' AS facility_type_code, 'Combined Control Facility' AS display_name,
              'Combined en-route and terminal control facility' AS description FROM dual) s
ON (t.facility_type_code = s.facility_type_code)
WHEN NOT MATCHED THEN INSERT (facility_type_code, display_name, description)
    VALUES (s.facility_type_code, s.display_name, s.description);

MERGE INTO facility_type_lkp t
USING (SELECT 'FSS' AS facility_type_code, 'Flight Service Station' AS display_name,
              'Flight briefing and advisory services' AS description FROM dual) s
ON (t.facility_type_code = s.facility_type_code)
WHEN NOT MATCHED THEN INSERT (facility_type_code, display_name, description)
    VALUES (s.facility_type_code, s.display_name, s.description);

MERGE INTO facility_type_lkp t
USING (SELECT 'REMOTE_COM_OUTLET' AS facility_type_code, 'Remote Communication Outlet (RCO)' AS display_name,
              'Unstaffed ground radio outlet for pilot-to-controller relay' AS description FROM dual) s
ON (t.facility_type_code = s.facility_type_code)
WHEN NOT MATCHED THEN INSERT (facility_type_code, display_name, description)
    VALUES (s.facility_type_code, s.display_name, s.description);

MERGE INTO facility_type_lkp t
USING (SELECT 'REMOTE_CENTER_AG' AS facility_type_code, 'Remote Center Air-to-Ground' AS display_name,
              'ARTCC-associated remote air-to-ground communication site' AS description FROM dual) s
ON (t.facility_type_code = s.facility_type_code)
WHEN NOT MATCHED THEN INSERT (facility_type_code, display_name, description)
    VALUES (s.facility_type_code, s.display_name, s.description);

MERGE INTO facility_type_lkp t
USING (SELECT 'REMOTE_TRANS_REC' AS facility_type_code, 'Remote Transmitter/Receiver' AS display_name,
              'Unstaffed remote radio transmitter/receiver relay site' AS description FROM dual) s
ON (t.facility_type_code = s.facility_type_code)
WHEN NOT MATCHED THEN INSERT (facility_type_code, display_name, description)
    VALUES (s.facility_type_code, s.display_name, s.description);

MERGE INTO facility_type_lkp t
USING (SELECT 'ENROUTE_RADAR' AS facility_type_code, 'En Route Radar Facility' AS display_name,
              'En-route surveillance radar installation' AS description FROM dual) s
ON (t.facility_type_code = s.facility_type_code)
WHEN NOT MATCHED THEN INSERT (facility_type_code, display_name, description)
    VALUES (s.facility_type_code, s.display_name, s.description);

MERGE INTO facility_type_lkp t
USING (SELECT 'PART_WAREHOUSE' AS facility_type_code, 'Parts Warehouse' AS display_name,
              'Regional parts distribution center — storage and outbound logistics' AS description FROM dual) s
ON (t.facility_type_code = s.facility_type_code)
WHEN NOT MATCHED THEN INSERT (facility_type_code, display_name, description)
    VALUES (s.facility_type_code, s.display_name, s.description);

-- ---------------------------------------------------------------------------
-- Personnel roles (multiple FACILITY_MANAGER assignments allowed per facility)
-- ---------------------------------------------------------------------------

MERGE INTO facility_personnel_role_lkp t
USING (SELECT 'FACILITY_MANAGER' AS role_code, 'Facility Manager' AS display_name,
              'Operational manager with staffing and escalation authority' AS description,
              'Y' AS is_manager_role, 10 AS sort_order FROM dual) s
ON (t.role_code = s.role_code)
WHEN NOT MATCHED THEN INSERT (role_code, display_name, description, is_manager_role, sort_order)
    VALUES (s.role_code, s.display_name, s.description, s.is_manager_role, s.sort_order);

MERGE INTO facility_personnel_role_lkp t
USING (SELECT 'ATC_SUPERVISOR' AS role_code, 'ATC Supervisor' AS display_name,
              'Supervisory controller or operations supervisor' AS description,
              'N' AS is_manager_role, 20 AS sort_order FROM dual) s
ON (t.role_code = s.role_code)
WHEN NOT MATCHED THEN INSERT (role_code, display_name, description, is_manager_role, sort_order)
    VALUES (s.role_code, s.display_name, s.description, s.is_manager_role, s.sort_order);

MERGE INTO facility_personnel_role_lkp t
USING (SELECT 'CONTROLLER' AS role_code, 'Controller' AS display_name,
              'Air traffic controller on position' AS description,
              'N' AS is_manager_role, 30 AS sort_order FROM dual) s
ON (t.role_code = s.role_code)
WHEN NOT MATCHED THEN INSERT (role_code, display_name, description, is_manager_role, sort_order)
    VALUES (s.role_code, s.display_name, s.description, s.is_manager_role, s.sort_order);

MERGE INTO facility_personnel_role_lkp t
USING (SELECT 'TECHNICIAN' AS role_code, 'Technician' AS display_name,
              'NAS equipment maintenance technician' AS description,
              'N' AS is_manager_role, 40 AS sort_order FROM dual) s
ON (t.role_code = s.role_code)
WHEN NOT MATCHED THEN INSERT (role_code, display_name, description, is_manager_role, sort_order)
    VALUES (s.role_code, s.display_name, s.description, s.is_manager_role, s.sort_order);

MERGE INTO facility_personnel_role_lkp t
USING (SELECT 'MAINTENANCE_LEAD' AS role_code, 'Maintenance Lead' AS display_name,
              'Depot or site maintenance lead' AS description,
              'Y' AS is_manager_role, 50 AS sort_order FROM dual) s
ON (t.role_code = s.role_code)
WHEN NOT MATCHED THEN INSERT (role_code, display_name, description, is_manager_role, sort_order)
    VALUES (s.role_code, s.display_name, s.description, s.is_manager_role, s.sort_order);

MERGE INTO facility_personnel_role_lkp t
USING (SELECT 'FSS_SPECIALIST' AS role_code, 'FSS Specialist' AS display_name,
              'Flight service specialist' AS description,
              'N' AS is_manager_role, 60 AS sort_order FROM dual) s
ON (t.role_code = s.role_code)
WHEN NOT MATCHED THEN INSERT (role_code, display_name, description, is_manager_role, sort_order)
    VALUES (s.role_code, s.display_name, s.description, s.is_manager_role, s.sort_order);

MERGE INTO facility_personnel_role_lkp t
USING (SELECT 'WAREHOUSE_MANAGER' AS role_code, 'Warehouse Manager' AS display_name,
              'Parts warehouse operations manager' AS description,
              'Y' AS is_manager_role, 70 AS sort_order FROM dual) s
ON (t.role_code = s.role_code)
WHEN NOT MATCHED THEN INSERT (role_code, display_name, description, is_manager_role, sort_order)
    VALUES (s.role_code, s.display_name, s.description, s.is_manager_role, s.sort_order);

MERGE INTO facility_personnel_role_lkp t
USING (SELECT 'LOGISTICS_COORDINATOR' AS role_code, 'Logistics Coordinator' AS display_name,
              'Coordinates inbound and outbound parts shipments' AS description,
              'N' AS is_manager_role, 80 AS sort_order FROM dual) s
ON (t.role_code = s.role_code)
WHEN NOT MATCHED THEN INSERT (role_code, display_name, description, is_manager_role, sort_order)
    VALUES (s.role_code, s.display_name, s.description, s.is_manager_role, s.sort_order);

MERGE INTO facility_personnel_role_lkp t
USING (SELECT 'PARTS_CLERK' AS role_code, 'Parts Clerk' AS display_name,
              'Warehouse receiving, staging, and inventory clerk' AS description,
              'N' AS is_manager_role, 90 AS sort_order FROM dual) s
ON (t.role_code = s.role_code)
WHEN NOT MATCHED THEN INSERT (role_code, display_name, description, is_manager_role, sort_order)
    VALUES (s.role_code, s.display_name, s.description, s.is_manager_role, s.sort_order);

-- ---------------------------------------------------------------------------
-- Unity asset profiles (structureBlocks consumed by FacilitySiteView)
-- Profile v2 vocabulary: primitive cube|sphere|cylinder|dish|tower|ring|aircraft,
-- optional rotation (euler deg), emissionColor (RGB), spin {axis, degPerSec},
-- beacon.pulseHz. All new fields are optional and default to v1 behavior.
-- WHEN MATCHED updates let existing databases pick up the v2 profiles.
-- ---------------------------------------------------------------------------

MERGE INTO facility_type_asset_profile t
USING (SELECT 'AIRPORT' AS facility_type_code, 2 AS profile_version,
              q'[{"structureBlocks":[{"name":"Runway","primitive":"cube","position":[0,0.25,0],"scale":[3.5,0.15,24],"color":[0.13,0.13,0.15],"smoothness":0.3,"metallic":0},{"name":"Terminal","primitive":"cube","position":[-8,3.5,8],"scale":[11,7,7],"color":[0.55,0.58,0.62],"smoothness":0.52,"metallic":0.12},{"name":"TerminalGlass","primitive":"cube","position":[-8,5.2,11.6],"scale":[10.2,2.2,0.35],"color":[0.4,0.62,0.82],"smoothness":0.9,"metallic":0.2,"emission":0.5,"emissionColor":[0.45,0.75,1]},{"name":"Ramp","primitive":"cube","position":[6,0.35,6],"scale":[13,0.25,11],"color":[0.3,0.31,0.33],"smoothness":0.22,"metallic":0},{"name":"Tower","primitive":"tower","position":[10,0,-8],"scale":[3.2,12,3.2],"color":[0.58,0.62,0.68],"smoothness":0.6,"metallic":0.15}],"runwayMarkings":true,"beacon":{"position":[0,22,0],"airportColor":[0.35,0.85,1],"pulseHz":0.5},"overviewCamera":{"offset":[0,45,-55],"scaleFactor":1.0}}]' AS asset_profile_json,
              q'[{"minManagers":1,"typicalRoles":["FACILITY_MANAGER","TECHNICIAN"]}]' AS personnel_defaults_json FROM dual) s
ON (t.facility_type_code = s.facility_type_code)
WHEN MATCHED THEN UPDATE SET t.profile_version = s.profile_version, t.asset_profile_json = s.asset_profile_json, t.updated_at = SYSTIMESTAMP
WHEN NOT MATCHED THEN INSERT (facility_type_code, profile_version, asset_profile_json, personnel_defaults_json)
    VALUES (s.facility_type_code, s.profile_version, s.asset_profile_json, s.personnel_defaults_json);

MERGE INTO facility_type_asset_profile t
USING (SELECT 'ATCT' AS facility_type_code, 2 AS profile_version,
              q'[{"structureBlocks":[{"name":"Tower","primitive":"tower","position":[0,0,0],"scale":[4,14,4],"color":[0.5,0.54,0.6],"smoothness":0.55,"metallic":0.12},{"name":"CabBand","primitive":"ring","position":[0,10.9,0],"rotation":[0,0,0],"scale":[5.6,0.6,5.6],"color":[0.35,0.55,0.72],"smoothness":0.85,"metallic":0.1,"emission":0.6,"emissionColor":[0.45,0.8,1]}],"beacon":{"position":[0,16,0],"airportColor":[0.35,0.85,1],"pulseHz":0.75},"overviewCamera":{"offset":[0,55,-65],"scaleFactor":1.0},"coLocatedParentType":"AIRPORT"}]' AS asset_profile_json,
              q'[{"minManagers":1,"typicalRoles":["FACILITY_MANAGER","ATC_SUPERVISOR","CONTROLLER"]}]' AS personnel_defaults_json FROM dual) s
ON (t.facility_type_code = s.facility_type_code)
WHEN MATCHED THEN UPDATE SET t.profile_version = s.profile_version, t.asset_profile_json = s.asset_profile_json, t.updated_at = SYSTIMESTAMP
WHEN NOT MATCHED THEN INSERT (facility_type_code, profile_version, asset_profile_json, personnel_defaults_json)
    VALUES (s.facility_type_code, s.profile_version, s.asset_profile_json, s.personnel_defaults_json);

MERGE INTO facility_type_asset_profile t
USING (SELECT 'ARTCC' AS facility_type_code, 2 AS profile_version,
              q'[{"structureBlocks":[{"name":"ControlVolume","primitive":"cube","position":[0,25,0],"scale":[8,50,8],"color":[0.25,0.45,0.75],"smoothness":0.45,"metallic":0.15},{"name":"OpsBand","primitive":"cube","position":[0,42,0],"scale":[8.4,1.2,8.4],"color":[0.18,0.3,0.42],"smoothness":0.7,"metallic":0.1,"emission":0.7,"emissionColor":[0.3,0.8,1]},{"name":"RadarDome","primitive":"sphere","position":[0,53,0],"scale":[6,4,6],"color":[0.82,0.86,0.9],"smoothness":0.45,"metallic":0.1},{"name":"CommMast","primitive":"cylinder","position":[5.5,54,3.5],"scale":[0.3,4,0.3],"color":[0.7,0.72,0.76],"smoothness":0.6,"metallic":0.4}],"beacon":{"position":[0,22,0],"pulseHz":0.4},"overviewCamera":{"offset":[0,120,-140],"scaleFactor":1.0}}]' AS asset_profile_json,
              q'[{"minManagers":2,"typicalRoles":["FACILITY_MANAGER","ATC_SUPERVISOR","CONTROLLER"]}]' AS personnel_defaults_json FROM dual) s
ON (t.facility_type_code = s.facility_type_code)
WHEN MATCHED THEN UPDATE SET t.profile_version = s.profile_version, t.asset_profile_json = s.asset_profile_json, t.updated_at = SYSTIMESTAMP
WHEN NOT MATCHED THEN INSERT (facility_type_code, profile_version, asset_profile_json, personnel_defaults_json)
    VALUES (s.facility_type_code, s.profile_version, s.asset_profile_json, s.personnel_defaults_json);

MERGE INTO facility_type_asset_profile t
USING (SELECT 'TRACON' AS facility_type_code, 2 AS profile_version,
              q'[{"structureBlocks":[{"name":"RadarRoom","primitive":"cube","position":[0,12,0],"scale":[6,24,6],"color":[0.3,0.5,0.7],"smoothness":0.4,"metallic":0.1},{"name":"Mast","primitive":"cylinder","position":[0,26,0],"scale":[0.6,3,0.6],"color":[0.72,0.74,0.78],"smoothness":0.65,"metallic":0.35},{"name":"Dish","primitive":"dish","position":[0,30,0],"rotation":[0,30,0],"scale":[5,1.6,5],"color":[0.84,0.86,0.9],"smoothness":0.8,"metallic":0.35,"spin":{"axis":[0,1,0],"degPerSec":30}}],"beacon":{"position":[0,22,0],"pulseHz":0.5},"overviewCamera":{"offset":[0,45,-55],"scaleFactor":1.0}}]' AS asset_profile_json,
              q'[{"minManagers":1,"typicalRoles":["FACILITY_MANAGER","ATC_SUPERVISOR","CONTROLLER"]}]' AS personnel_defaults_json FROM dual) s
ON (t.facility_type_code = s.facility_type_code)
WHEN MATCHED THEN UPDATE SET t.profile_version = s.profile_version, t.asset_profile_json = s.asset_profile_json, t.updated_at = SYSTIMESTAMP
WHEN NOT MATCHED THEN INSERT (facility_type_code, profile_version, asset_profile_json, personnel_defaults_json)
    VALUES (s.facility_type_code, s.profile_version, s.asset_profile_json, s.personnel_defaults_json);

MERGE INTO facility_type_asset_profile t
USING (SELECT 'RADAR_SITE' AS facility_type_code, 2 AS profile_version,
              q'[{"structureBlocks":[{"name":"Mast","primitive":"cylinder","position":[0,8,0],"scale":[2.2,8,2.2],"color":[0.65,0.65,0.68],"smoothness":0.55,"metallic":0.2},{"name":"Dish","primitive":"dish","position":[0,17,0],"scale":[9,2.6,9],"color":[0.86,0.88,0.92],"smoothness":0.82,"metallic":0.35,"spin":{"axis":[0,1,0],"degPerSec":20}}],"beacon":{"position":[0,22,0],"pulseHz":0.5},"overviewCamera":{"offset":[0,55,-70],"scaleFactor":1.0}}]' AS asset_profile_json,
              q'[{"minManagers":1,"typicalRoles":["FACILITY_MANAGER","TECHNICIAN"]}]' AS personnel_defaults_json FROM dual) s
ON (t.facility_type_code = s.facility_type_code)
WHEN MATCHED THEN UPDATE SET t.profile_version = s.profile_version, t.asset_profile_json = s.asset_profile_json, t.updated_at = SYSTIMESTAMP
WHEN NOT MATCHED THEN INSERT (facility_type_code, profile_version, asset_profile_json, personnel_defaults_json)
    VALUES (s.facility_type_code, s.profile_version, s.asset_profile_json, s.personnel_defaults_json);

MERGE INTO facility_type_asset_profile t
USING (SELECT 'ENROUTE_RADAR' AS facility_type_code, 2 AS profile_version,
              q'[{"structureBlocks":[{"name":"RadarTower","primitive":"cylinder","position":[0,10,0],"scale":[3,10,3],"color":[0.62,0.64,0.68],"smoothness":0.5,"metallic":0.25},{"name":"Array","primitive":"dish","position":[0,21,0],"scale":[11,3,11],"color":[0.84,0.86,0.9],"smoothness":0.8,"metallic":0.4,"spin":{"axis":[0,1,0],"degPerSec":14}}],"beacon":{"position":[0,26,0],"pulseHz":0.4},"overviewCamera":{"offset":[0,65,-80],"scaleFactor":1.0}}]' AS asset_profile_json,
              q'[{"minManagers":1,"typicalRoles":["FACILITY_MANAGER","TECHNICIAN"]}]' AS personnel_defaults_json FROM dual) s
ON (t.facility_type_code = s.facility_type_code)
WHEN MATCHED THEN UPDATE SET t.profile_version = s.profile_version, t.asset_profile_json = s.asset_profile_json, t.updated_at = SYSTIMESTAMP
WHEN NOT MATCHED THEN INSERT (facility_type_code, profile_version, asset_profile_json, personnel_defaults_json)
    VALUES (s.facility_type_code, s.profile_version, s.asset_profile_json, s.personnel_defaults_json);

MERGE INTO facility_type_asset_profile t
USING (SELECT 'REMOTE_COM_OUTLET' AS facility_type_code, 2 AS profile_version,
              q'[{"structureBlocks":[{"name":"Shed","primitive":"cube","position":[0,1.5,0],"scale":[3,3,3],"color":[0.45,0.48,0.52],"smoothness":0.35,"metallic":0.05},{"name":"AntennaMast","primitive":"cylinder","position":[0,4.5,0],"scale":[0.25,3,0.25],"color":[0.7,0.72,0.76],"smoothness":0.6,"metallic":0.3}],"overviewCamera":{"offset":[0,25,-35],"scaleFactor":0.85},"unstaffed":true}]' AS asset_profile_json,
              q'[{"minManagers":0,"typicalRoles":["TECHNICIAN"]}]' AS personnel_defaults_json FROM dual) s
ON (t.facility_type_code = s.facility_type_code)
WHEN MATCHED THEN UPDATE SET t.profile_version = s.profile_version, t.asset_profile_json = s.asset_profile_json, t.updated_at = SYSTIMESTAMP
WHEN NOT MATCHED THEN INSERT (facility_type_code, profile_version, asset_profile_json, personnel_defaults_json)
    VALUES (s.facility_type_code, s.profile_version, s.asset_profile_json, s.personnel_defaults_json);

MERGE INTO facility_type_asset_profile t
USING (SELECT 'REMOTE_CENTER_AG' AS facility_type_code, 2 AS profile_version,
              q'[{"structureBlocks":[{"name":"CommShelter","primitive":"cube","position":[0,2,0],"scale":[4,4,5],"color":[0.42,0.46,0.5],"smoothness":0.35,"metallic":0.08},{"name":"ArrayPole","primitive":"cylinder","position":[0,6,0],"scale":[0.3,4,0.3],"color":[0.68,0.7,0.74],"smoothness":0.55,"metallic":0.28}],"overviewCamera":{"offset":[0,30,-40],"scaleFactor":0.9},"unstaffed":true}]' AS asset_profile_json,
              q'[{"minManagers":0,"typicalRoles":["TECHNICIAN"]}]' AS personnel_defaults_json FROM dual) s
ON (t.facility_type_code = s.facility_type_code)
WHEN MATCHED THEN UPDATE SET t.profile_version = s.profile_version, t.asset_profile_json = s.asset_profile_json, t.updated_at = SYSTIMESTAMP
WHEN NOT MATCHED THEN INSERT (facility_type_code, profile_version, asset_profile_json, personnel_defaults_json)
    VALUES (s.facility_type_code, s.profile_version, s.asset_profile_json, s.personnel_defaults_json);

MERGE INTO facility_type_asset_profile t
USING (SELECT 'REMOTE_TRANS_REC' AS facility_type_code, 2 AS profile_version,
              q'[{"structureBlocks":[{"name":"RelayCabinet","primitive":"cube","position":[0,1.2,0],"scale":[2.5,2.4,2.5],"color":[0.5,0.52,0.56],"smoothness":0.4,"metallic":0.1},{"name":"AntennaA","primitive":"cylinder","position":[-0.6,4.6,0],"scale":[0.18,2.5,0.18],"color":[0.72,0.74,0.78],"smoothness":0.65,"metallic":0.32},{"name":"AntennaB","primitive":"cylinder","position":[0.6,4.2,0],"scale":[0.18,2.1,0.18],"color":[0.72,0.74,0.78],"smoothness":0.65,"metallic":0.32}],"overviewCamera":{"offset":[0,28,-38],"scaleFactor":0.85},"unstaffed":true}]' AS asset_profile_json,
              q'[{"minManagers":0,"typicalRoles":["TECHNICIAN"]}]' AS personnel_defaults_json FROM dual) s
ON (t.facility_type_code = s.facility_type_code)
WHEN MATCHED THEN UPDATE SET t.profile_version = s.profile_version, t.asset_profile_json = s.asset_profile_json, t.updated_at = SYSTIMESTAMP
WHEN NOT MATCHED THEN INSERT (facility_type_code, profile_version, asset_profile_json, personnel_defaults_json)
    VALUES (s.facility_type_code, s.profile_version, s.asset_profile_json, s.personnel_defaults_json);

MERGE INTO facility_type_asset_profile t
USING (SELECT 'MAINTENANCE_DEPOT' AS facility_type_code, 2 AS profile_version,
              q'[{"structureBlocks":[{"name":"Depot","primitive":"cube","position":[0,4,-2],"scale":[14,8,10],"color":[0.45,0.42,0.38],"smoothness":0.35,"metallic":0.05},{"name":"BayA","primitive":"cube","position":[-5,2,4],"scale":[4,4,6],"color":[0.55,0.52,0.48],"smoothness":0.4,"metallic":0.08},{"name":"BayB","primitive":"cube","position":[5,2,4],"scale":[4,4,6],"color":[0.55,0.52,0.48],"smoothness":0.4,"metallic":0.08},{"name":"Yard","primitive":"cube","position":[0,0.35,8],"scale":[12,0.2,8],"color":[0.32,0.34,0.36],"smoothness":0.25,"metallic":0}],"overviewCamera":{"offset":[0,40,-60],"scaleFactor":1.0}}]' AS asset_profile_json,
              q'[{"minManagers":1,"typicalRoles":["FACILITY_MANAGER","MAINTENANCE_LEAD","TECHNICIAN"]}]' AS personnel_defaults_json FROM dual) s
ON (t.facility_type_code = s.facility_type_code)
WHEN MATCHED THEN UPDATE SET t.profile_version = s.profile_version, t.asset_profile_json = s.asset_profile_json, t.updated_at = SYSTIMESTAMP
WHEN NOT MATCHED THEN INSERT (facility_type_code, profile_version, asset_profile_json, personnel_defaults_json)
    VALUES (s.facility_type_code, s.profile_version, s.asset_profile_json, s.personnel_defaults_json);

MERGE INTO facility_type_asset_profile t
USING (SELECT 'PART_WAREHOUSE' AS facility_type_code, 1 AS profile_version,
              q'[{"structureBlocks":[{"name":"MainWarehouse","primitive":"cube","position":[0,5,0],"scale":[16,10,12],"color":[0.52,0.54,0.58],"smoothness":0.38,"metallic":0.12},{"name":"DockA","primitive":"cube","position":[-6,2.5,6],"scale":[5,5,4],"color":[0.48,0.46,0.42],"smoothness":0.35,"metallic":0.08,"emission":0.35,"emissionColor":[1.0,0.72,0.25]},{"name":"DockB","primitive":"cube","position":[6,2.5,6],"scale":[5,5,4],"color":[0.48,0.46,0.42],"smoothness":0.35,"metallic":0.08,"emission":0.35,"emissionColor":[1.0,0.72,0.25]},{"name":"Helipad","primitive":"ring","position":[0,10.2,0],"scale":[4,0.15,4],"color":[0.35,0.38,0.42],"smoothness":0.5,"metallic":0.2},{"name":"YardLane","primitive":"cube","position":[0,0.2,10],"scale":[14,0.15,3],"color":[0.28,0.30,0.32],"smoothness":0.2,"metallic":0},{"name":"BeaconDock","primitive":"sphere","position":[-6,6.5,6],"scale":[0.8,0.8,0.8],"color":[1.0,0.75,0.3],"smoothness":0.7,"metallic":0.1,"emission":0.8,"emissionColor":[1.0,0.75,0.3]}],"beacon":{"position":[-6,6.5,6],"airportColor":[1.0,0.75,0.3],"pulseHz":0.4},"overviewCamera":{"offset":[0,45,-65],"scaleFactor":1.05}}]' AS asset_profile_json,
              q'[{"minManagers":1,"typicalRoles":["WAREHOUSE_MANAGER","LOGISTICS_COORDINATOR","PARTS_CLERK"]}]' AS personnel_defaults_json FROM dual) s
ON (t.facility_type_code = s.facility_type_code)
WHEN MATCHED THEN UPDATE SET t.profile_version = s.profile_version, t.asset_profile_json = s.asset_profile_json, t.personnel_defaults_json = s.personnel_defaults_json, t.updated_at = SYSTIMESTAMP
WHEN NOT MATCHED THEN INSERT (facility_type_code, profile_version, asset_profile_json, personnel_defaults_json)
    VALUES (s.facility_type_code, s.profile_version, s.asset_profile_json, s.personnel_defaults_json);

-- ---------------------------------------------------------------------------
-- Equipment requirements by facility type
-- ---------------------------------------------------------------------------

MERGE INTO facility_type_equipment_requirement t
USING (SELECT '32000001-0001-4001-8001-000000000001' AS requirement_id, 'ATCT' AS facility_type_code,
              'COM_VHF' AS equipment_type_code, 'REQUIRED' AS requirement_code, 1 AS min_quantity,
              'TWR_PRIMARY' AS slot_code, 'Tower primary VHF frequency' AS description, 10 AS sort_order FROM dual) s
ON (t.requirement_id = s.requirement_id)
WHEN NOT MATCHED THEN INSERT (requirement_id, facility_type_code, equipment_type_code, requirement_code, min_quantity, slot_code, description, sort_order)
    VALUES (s.requirement_id, s.facility_type_code, s.equipment_type_code, s.requirement_code, s.min_quantity, s.slot_code, s.description, s.sort_order);

MERGE INTO facility_type_equipment_requirement t
USING (SELECT '32000002-0001-4001-8001-000000000002' AS requirement_id, 'ATCT' AS facility_type_code,
              'RADAR_ASR' AS equipment_type_code, 'OPTIONAL' AS requirement_code, 1 AS min_quantity,
              'TWR_RADAR' AS slot_code, 'Tower radar display feed (radar-equipped towers)' AS description, 20 AS sort_order FROM dual) s
ON (t.requirement_id = s.requirement_id)
WHEN NOT MATCHED THEN INSERT (requirement_id, facility_type_code, equipment_type_code, requirement_code, min_quantity, slot_code, description, sort_order)
    VALUES (s.requirement_id, s.facility_type_code, s.equipment_type_code, s.requirement_code, s.min_quantity, s.slot_code, s.description, s.sort_order);

MERGE INTO facility_type_equipment_requirement t
USING (SELECT '32000003-0001-4001-8001-000000000003' AS requirement_id, 'ARTCC' AS facility_type_code,
              'RADAR_ARR' AS equipment_type_code, 'REQUIRED' AS requirement_code, 1 AS min_quantity,
              'ENROUTE_RADAR' AS slot_code, 'En-route surveillance radar' AS description, 10 AS sort_order FROM dual) s
ON (t.requirement_id = s.requirement_id)
WHEN NOT MATCHED THEN INSERT (requirement_id, facility_type_code, equipment_type_code, requirement_code, min_quantity, slot_code, description, sort_order)
    VALUES (s.requirement_id, s.facility_type_code, s.equipment_type_code, s.requirement_code, s.min_quantity, s.slot_code, s.description, s.sort_order);

MERGE INTO facility_type_equipment_requirement t
USING (SELECT '32000004-0001-4001-8001-000000000004' AS requirement_id, 'ARTCC' AS facility_type_code,
              'COM_UHF' AS equipment_type_code, 'REQUIRED' AS requirement_code, 1 AS min_quantity,
              'CENTER_UHF' AS slot_code, 'Center UHF communications' AS description, 20 AS sort_order FROM dual) s
ON (t.requirement_id = s.requirement_id)
WHEN NOT MATCHED THEN INSERT (requirement_id, facility_type_code, equipment_type_code, requirement_code, min_quantity, slot_code, description, sort_order)
    VALUES (s.requirement_id, s.facility_type_code, s.equipment_type_code, s.requirement_code, s.min_quantity, s.slot_code, s.description, s.sort_order);

MERGE INTO facility_type_equipment_requirement t
USING (SELECT '32000005-0001-4001-8001-000000000005' AS requirement_id, 'TRACON' AS facility_type_code,
              'RADAR_ASR' AS equipment_type_code, 'REQUIRED' AS requirement_code, 1 AS min_quantity,
              'TRACON_RADAR' AS slot_code, 'Terminal surveillance radar' AS description, 10 AS sort_order FROM dual) s
ON (t.requirement_id = s.requirement_id)
WHEN NOT MATCHED THEN INSERT (requirement_id, facility_type_code, equipment_type_code, requirement_code, min_quantity, slot_code, description, sort_order)
    VALUES (s.requirement_id, s.facility_type_code, s.equipment_type_code, s.requirement_code, s.min_quantity, s.slot_code, s.description, s.sort_order);

MERGE INTO facility_type_equipment_requirement t
USING (SELECT '32000006-0001-4001-8001-000000000006' AS requirement_id, 'RADAR_SITE' AS facility_type_code,
              'RADAR_ASR' AS equipment_type_code, 'REQUIRED' AS requirement_code, 1 AS min_quantity,
              'SITE_RADAR' AS slot_code, 'Primary surveillance radar' AS description, 10 AS sort_order FROM dual) s
ON (t.requirement_id = s.requirement_id)
WHEN NOT MATCHED THEN INSERT (requirement_id, facility_type_code, equipment_type_code, requirement_code, min_quantity, slot_code, description, sort_order)
    VALUES (s.requirement_id, s.facility_type_code, s.equipment_type_code, s.requirement_code, s.min_quantity, s.slot_code, s.description, s.sort_order);

MERGE INTO facility_type_equipment_requirement t
USING (SELECT '32000007-0001-4001-8001-000000000007' AS requirement_id, 'REMOTE_COM_OUTLET' AS facility_type_code,
              'COM_VHF' AS equipment_type_code, 'REQUIRED' AS requirement_code, 1 AS min_quantity,
              'RCO_VHF' AS slot_code, 'RCO VHF outlet' AS description, 10 AS sort_order FROM dual) s
ON (t.requirement_id = s.requirement_id)
WHEN NOT MATCHED THEN INSERT (requirement_id, facility_type_code, equipment_type_code, requirement_code, min_quantity, slot_code, description, sort_order)
    VALUES (s.requirement_id, s.facility_type_code, s.equipment_type_code, s.requirement_code, s.min_quantity, s.slot_code, s.description, s.sort_order);

MERGE INTO facility_type_equipment_requirement t
USING (SELECT '32000008-0001-4001-8001-000000000008' AS requirement_id, 'REMOTE_CENTER_AG' AS facility_type_code,
              'COM_UHF' AS equipment_type_code, 'REQUIRED' AS requirement_code, 1 AS min_quantity,
              'RCAG_UHF' AS slot_code, 'Remote center air-to-ground UHF' AS description, 10 AS sort_order FROM dual) s
ON (t.requirement_id = s.requirement_id)
WHEN NOT MATCHED THEN INSERT (requirement_id, facility_type_code, equipment_type_code, requirement_code, min_quantity, slot_code, description, sort_order)
    VALUES (s.requirement_id, s.facility_type_code, s.equipment_type_code, s.requirement_code, s.min_quantity, s.slot_code, s.description, s.sort_order);

MERGE INTO facility_type_equipment_requirement t
USING (SELECT '32000009-0001-4001-8001-000000000009' AS requirement_id, 'REMOTE_TRANS_REC' AS facility_type_code,
              'COM_VHF' AS equipment_type_code, 'REQUIRED' AS requirement_code, 1 AS min_quantity,
              'RTR_VHF' AS slot_code, 'Remote transceiver VHF' AS description, 10 AS sort_order FROM dual) s
ON (t.requirement_id = s.requirement_id)
WHEN NOT MATCHED THEN INSERT (requirement_id, facility_type_code, equipment_type_code, requirement_code, min_quantity, slot_code, description, sort_order)
    VALUES (s.requirement_id, s.facility_type_code, s.equipment_type_code, s.requirement_code, s.min_quantity, s.slot_code, s.description, s.sort_order);

MERGE INTO facility_type_equipment_requirement t
USING (SELECT '3200000a-0001-4001-8001-00000000000a' AS requirement_id, 'REMOTE_TRANS_REC' AS facility_type_code,
              'COM_UHF' AS equipment_type_code, 'REQUIRED' AS requirement_code, 1 AS min_quantity,
              'RTR_UHF' AS slot_code, 'Remote transceiver UHF' AS description, 20 AS sort_order FROM dual) s
ON (t.requirement_id = s.requirement_id)
WHEN NOT MATCHED THEN INSERT (requirement_id, facility_type_code, equipment_type_code, requirement_code, min_quantity, slot_code, description, sort_order)
    VALUES (s.requirement_id, s.facility_type_code, s.equipment_type_code, s.requirement_code, s.min_quantity, s.slot_code, s.description, s.sort_order);
