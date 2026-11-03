-- =============================================================================
-- NAS Simulation — operational seed data
-- Scenario: "Upper Midwest Corridor" — afternoon of 23 Jun 2026 UTC
--
-- Narrative:
--   Des Moines (DSM) is the scenario hub. ILS RWY 13 is FAILED; emergency
--   maintenance is IN_PROGRESS from the Urbandale NAS depot. UA2847 (DSM→ORD)
--   is delayed on the ground. DL1920 (MSP→DSM) is on APPROACH in a hold pattern
--   due to the navaid outage and an approaching thunderstorm line over central
--   Iowa. Chicago Center (ZAU) and DSM TRACON coordinate reroutes.
--
-- Prerequisites: 01–09 DDL + 09a_seed_reference (lookups, singleton sim state, dev user).
-- Does NOT duplicate lookup rows or 09a_seed_reference operational singletons.
-- =============================================================================

ALTER SESSION SET CONTAINER = FREEPDB1;
ALTER SESSION SET CURRENT_SCHEMA = nas_sim;

-- ---------------------------------------------------------------------------
-- Users & authorization (extends dev.operator from 99_seed_reference.sql)
-- ---------------------------------------------------------------------------

INSERT INTO users (
    user_id, username, display_name, email, is_active, auth_source,
    entra_tenant_id, entra_object_id, entra_upn, entra_display_name
) VALUES (
    '20000001-0001-4001-8001-000000000001',
    'nas.admin',
    'NAS Simulation Administrator',
    'nas.admin@nas-sim.local',
    'Y', 'LOCAL_DEV',
    '11111111-1111-1111-1111-111111111111',
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    'nas.admin@nas-sim.local',
    'NAS Simulation Administrator'
);

INSERT INTO users (
    user_id, username, display_name, email, is_active, auth_source,
    entra_tenant_id, entra_object_id, entra_upn, entra_display_name
) VALUES (
    '20000002-0001-4001-8001-000000000002',
    'maint.coordinator',
    'Maintenance Coordinator',
    'maint.coordinator@nas-sim.local',
    'Y', 'LOCAL_DEV',
    '11111111-1111-1111-1111-111111111111',
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
    'maint.coordinator@nas-sim.local',
    'Maintenance Coordinator'
);

INSERT INTO users (
    user_id, username, display_name, email, is_active, auth_source,
    entra_tenant_id, entra_object_id, entra_upn, entra_display_name
) VALUES (
    '20000003-0001-4001-8001-000000000003',
    'observer.readonly',
    'NAS Observer',
    'observer@nas-sim.local',
    'Y', 'LOCAL_DEV',
    '11111111-1111-1111-1111-111111111111',
    'cccccccc-cccc-cccc-cccc-cccccccccccc',
    'observer@nas-sim.local',
    'NAS Observer'
);

INSERT INTO entra_group_role_mapping (
    entra_group_role_mapping_id, entra_tenant_id, entra_group_object_id, role_id, is_active
) VALUES (
    '20000010-0001-4001-8001-000000000010',
    '11111111-1111-1111-1111-111111111111',
    '44444444-4444-4444-4444-444444444444',
    '00000000-0000-0000-0000-000000000001', 'Y'
);

INSERT INTO entra_group_role_mapping (
    entra_group_role_mapping_id, entra_tenant_id, entra_group_object_id, role_id, is_active
) VALUES (
    '20000011-0001-4001-8001-000000000011',
    '11111111-1111-1111-1111-111111111111',
    '55555555-5555-5555-5555-555555555555',
    '00000000-0000-0000-0000-000000000003', 'Y'
);

INSERT INTO entra_group_role_mapping (
    entra_group_role_mapping_id, entra_tenant_id, entra_group_object_id, role_id, is_active
) VALUES (
    '20000012-0001-4001-8001-000000000012',
    '11111111-1111-1111-1111-111111111111',
    '66666666-6666-6666-6666-666666666666',
    '00000000-0000-0000-0000-000000000004', 'Y'
);

INSERT INTO role_permission (role_permission_id, role_id, permission_code) VALUES
    ('30000001-0001-4001-8001-000000000001', '00000000-0000-0000-0000-000000000001', 'simulation.run');
INSERT INTO role_permission (role_permission_id, role_id, permission_code) VALUES
    ('30000002-0001-4001-8001-000000000002', '00000000-0000-0000-0000-000000000001', 'simulation.pause');
INSERT INTO role_permission (role_permission_id, role_id, permission_code) VALUES
    ('30000003-0001-4001-8001-000000000003', '00000000-0000-0000-0000-000000000001', 'simulation.snapshot');
INSERT INTO role_permission (role_permission_id, role_id, permission_code) VALUES
    ('30000004-0001-4001-8001-000000000004', '00000000-0000-0000-0000-000000000001', 'maintenance.manage');
INSERT INTO role_permission (role_permission_id, role_id, permission_code) VALUES
    ('30000005-0001-4001-8001-000000000005', '00000000-0000-0000-0000-000000000001', 'flight.view');
INSERT INTO role_permission (role_permission_id, role_id, permission_code) VALUES
    ('30000006-0001-4001-8001-000000000006', '00000000-0000-0000-0000-000000000002', 'simulation.run');
INSERT INTO role_permission (role_permission_id, role_id, permission_code) VALUES
    ('30000007-0001-4001-8001-000000000007', '00000000-0000-0000-0000-000000000002', 'simulation.pause');
INSERT INTO role_permission (role_permission_id, role_id, permission_code) VALUES
    ('30000008-0001-4001-8001-000000000008', '00000000-0000-0000-0000-000000000002', 'flight.view');
INSERT INTO role_permission (role_permission_id, role_id, permission_code) VALUES
    ('30000009-0001-4001-8001-000000000009', '00000000-0000-0000-0000-000000000003', 'maintenance.manage');
INSERT INTO role_permission (role_permission_id, role_id, permission_code) VALUES
    ('3000000a-0001-4001-8001-00000000000a', '00000000-0000-0000-0000-000000000004', 'flight.view');

-- ---------------------------------------------------------------------------
-- Facilities — real US NAS nodes (Upper Midwest corridor)
-- ---------------------------------------------------------------------------

INSERT INTO facility (
    facility_id, facility_code, name, facility_type_code, parent_facility_id,
    address_line1, city, state_code, zip_code,
    latitude, longitude, elevation_ft, timezone_name, operational_status,
    icao_code, faa_lid, metadata_json, created_by, updated_by
) VALUES (
    '10000001-0001-4001-8001-000000000001',
    'KDSM', 'Des Moines International Airport', 'AIRPORT', NULL,
    '5800 Fleur Dr', 'Des Moines', 'IA', '50321',
    41.5340000, -93.6631000, 958, 'America/Chicago', 'DEGRADED',
    'KDSM', 'DSM',
    q'[{"primaryCarrier":"multiple","runwayCount":2,"scenarioNote":"ILS RWY 13 outage — primary scenario hub"}]',
    '20000001-0001-4001-8001-000000000001',
    '20000001-0001-4001-8001-000000000001'
);

INSERT INTO facility (
    facility_id, facility_code, name, facility_type_code, parent_facility_id,
    address_line1, city, state_code, zip_code,
    latitude, longitude, elevation_ft, timezone_name, operational_status,
    icao_code, faa_lid, metadata_json, created_by, updated_by
) VALUES (
    '10000002-0001-4001-8001-000000000002',
    'KORD', 'Chicago O''Hare International Airport', 'AIRPORT', NULL,
    '10000 W O''Hare Ave', 'Chicago', 'IL', '60666',
    41.9742000, -87.9073000, 672, 'America/Chicago', 'OPERATIONAL',
    'KORD', 'ORD',
    q'[{"primaryCarrier":"UA/AA","annualOpsRank":1}]',
    '20000001-0001-4001-8001-000000000001',
    '20000001-0001-4001-8001-000000000001'
);

INSERT INTO facility (
    facility_id, facility_code, name, facility_type_code, parent_facility_id,
    address_line1, city, state_code, zip_code,
    latitude, longitude, elevation_ft, timezone_name, operational_status,
    icao_code, faa_lid, metadata_json, created_by, updated_by
) VALUES (
    '10000003-0001-4001-8001-000000000003',
    'KMSP', 'Minneapolis–Saint Paul International Airport', 'AIRPORT', NULL,
    '4300 Glumack Dr', 'Saint Paul', 'MN', '55111',
    44.8848000, -93.2223000, 841, 'America/Chicago', 'OPERATIONAL',
    'KMSP', 'MSP',
    q'[{"primaryCarrier":"DL","hub":true}]',
    '20000001-0001-4001-8001-000000000001',
    '20000001-0001-4001-8001-000000000001'
);

INSERT INTO facility (
    facility_id, facility_code, name, facility_type_code, parent_facility_id,
    address_line1, city, state_code, zip_code,
    latitude, longitude, elevation_ft, timezone_name, operational_status,
    icao_code, faa_lid, metadata_json, created_by, updated_by
) VALUES (
    '10000004-0001-4001-8001-000000000004',
    'ZAU', 'Chicago Air Route Traffic Control Center', 'ARTCC', NULL,
    '619 W New Indian Trail Ct', 'Aurora', 'IL', '60506',
    41.7606000, -88.3201000, 712, 'America/Chicago', 'OPERATIONAL',
    NULL, NULL,
    q'[{"artccId":"ZAU","jurisdiction":"Chicago Center airspace"}]',
    '20000001-0001-4001-8001-000000000001',
    '20000001-0001-4001-8001-000000000001'
);

INSERT INTO facility (
    facility_id, facility_code, name, facility_type_code, parent_facility_id,
    address_line1, city, state_code, zip_code,
    latitude, longitude, elevation_ft, timezone_name, operational_status,
    icao_code, faa_lid, metadata_json, created_by, updated_by
) VALUES (
    '10000005-0001-4001-8001-000000000005',
    'DSM-TRACON', 'Des Moines Terminal Radar Approach Control', 'TRACON',
    '10000004-0001-4001-8001-000000000004',
    '5800 Fleur Dr', 'Des Moines', 'IA', '50321',
    41.5340000, -93.6631000, 958, 'America/Chicago', 'OPERATIONAL',
    NULL, NULL,
    q'[{"traconId":"DSM","parentArtcc":"ZAU"}]',
    '20000001-0001-4001-8001-000000000001',
    '20000001-0001-4001-8001-000000000001'
);

INSERT INTO facility (
    facility_id, facility_code, name, facility_type_code, parent_facility_id,
    address_line1, city, state_code, zip_code,
    latitude, longitude, elevation_ft, timezone_name, operational_status,
    icao_code, faa_lid, metadata_json, created_by, updated_by
) VALUES (
    '10000006-0001-4001-8001-000000000006',
    'NAS-DEPOT-IA', 'NAS Midwest Avionics Maintenance Depot', 'MAINTENANCE_DEPOT', NULL,
    '7101 NW 70th Ave', 'Urbandale', 'IA', '50322',
    41.6275000, -93.7368000, 945, 'America/Chicago', 'OPERATIONAL',
    NULL, NULL,
    q'[{"depotCode":"NAS-MW-01","specialty":"NAVAID and ILS components"}]',
    '20000001-0001-4001-8001-000000000001',
    '20000001-0001-4001-8001-000000000001'
);

INSERT INTO facility (
    facility_id, facility_code, name, facility_type_code, parent_facility_id,
    address_line1, city, state_code, zip_code,
    latitude, longitude, elevation_ft, timezone_name, operational_status,
    icao_code, faa_lid, metadata_json, created_by, updated_by
) VALUES (
    '10000007-0001-4001-8001-000000000007',
    'DSM-ASR', 'Des Moines ASR-9 Surveillance Radar Site', 'RADAR_SITE',
    '10000001-0001-4001-8001-000000000001',
    'E Army Post Rd', 'Des Moines', 'IA', '50315',
    41.5458000, -93.6812000, 980, 'America/Chicago', 'OPERATIONAL',
    NULL, NULL,
    q'[{"radarType":"ASR-9","feedsTracon":"DSM-TRACON"}]',
    '20000001-0001-4001-8001-000000000001',
    '20000001-0001-4001-8001-000000000001'
);

INSERT INTO facility (
    facility_id, facility_code, name, facility_type_code, parent_facility_id,
    address_line1, city, state_code, zip_code,
    latitude, longitude, elevation_ft, timezone_name, operational_status,
    icao_code, faa_lid, metadata_json, created_by, updated_by
) VALUES (
    '10000008-0001-4001-8001-000000000008',
    'KAMW', 'Ames VOR/DME Facility', 'NAVAID_SITE', NULL,
    '2610 SE 5th St', 'Ames', 'IA', '50010',
    42.0086000, -93.6219000, 956, 'America/Chicago', 'OPERATIONAL',
    NULL, 'AMW',
    q'[{"navaidId":"DSM","type":"VORTAC"}]',
    '20000001-0001-4001-8001-000000000001',
    '20000001-0001-4001-8001-000000000001'
);

INSERT INTO user_permissions (user_permission_id, user_id, role_id, permission_code, facility_scope_id)
VALUES (
    '30000010-0001-4001-8001-000000000010',
    '20000002-0001-4001-8001-000000000002',
    '00000000-0000-0000-0000-000000000003',
    NULL,
    '10000001-0001-4001-8001-000000000001'
);

-- ---------------------------------------------------------------------------
-- Runways
-- ---------------------------------------------------------------------------

INSERT INTO runway (
    runway_id, facility_id, designator, length_ft, width_ft, surface_type,
    magnetic_heading_deg, operational_status, max_aircraft_category
) VALUES (
    '11000001-0001-4001-8001-000000000001',
    '10000001-0001-4001-8001-000000000001', '13/31', 9003, 150, 'CONCRETE',
    133.00, 'RESTRICTED', 'D'
);

INSERT INTO runway (
    runway_id, facility_id, designator, length_ft, width_ft, surface_type,
    magnetic_heading_deg, operational_status, max_aircraft_category
) VALUES (
    '11000002-0001-4001-8001-000000000002',
    '10000001-0001-4001-8001-000000000001', '05/23', 6425, 100, 'CONCRETE',
    55.00, 'OPEN', 'C'
);

INSERT INTO runway (
    runway_id, facility_id, designator, length_ft, width_ft, surface_type,
    magnetic_heading_deg, operational_status, max_aircraft_category
) VALUES (
    '11000003-0001-4001-8001-000000000003',
    '10000002-0001-4001-8001-000000000002', '10L/28R', 13000, 200, 'CONCRETE',
    103.00, 'OPEN', 'E'
);

INSERT INTO runway (
    runway_id, facility_id, designator, length_ft, width_ft, surface_type,
    magnetic_heading_deg, operational_status, max_aircraft_category
) VALUES (
    '11000004-0001-4001-8001-000000000004',
    '10000002-0001-4001-8001-000000000002', '09R/27L', 7967, 150, 'CONCRETE',
    93.00, 'OPEN', 'D'
);

INSERT INTO runway (
    runway_id, facility_id, designator, length_ft, width_ft, surface_type,
    magnetic_heading_deg, operational_status, max_aircraft_category
) VALUES (
    '11000005-0001-4001-8001-000000000005',
    '10000003-0001-4001-8001-000000000003', '12R/30L', 11006, 150, 'CONCRETE',
    123.00, 'OPEN', 'E'
);

-- ---------------------------------------------------------------------------
-- Equipment
-- ---------------------------------------------------------------------------

INSERT INTO equipment (
    equipment_id, facility_id, equipment_type_code, identifier, name,
    operational_status, installed_at, last_inspection_at, next_inspection_due_at,
    mean_time_between_failure_hrs, mean_time_to_repair_hrs,
    serial_number, manufacturer, model
) VALUES (
    '12000001-0001-4001-8001-000000000001',
    '10000001-0001-4001-8001-000000000001', 'ILS', 'ILS-13-DSM',
    'ILS Category I — Runway 13 (Localizer/GS)',
    'FAILED',
    TIMESTAMP '2018-04-12 00:00:00', TIMESTAMP '2026-05-15 08:00:00', TIMESTAMP '2026-11-15 08:00:00',
    8760, 8,
    'ILS-DSM-13-2018', 'Thales', 'ILS-420'
);

INSERT INTO equipment (
    equipment_id, facility_id, equipment_type_code, identifier, name,
    operational_status, installed_at, serial_number, manufacturer, model
) VALUES (
    '12000002-0001-4001-8001-000000000002',
    '10000001-0001-4001-8001-000000000001', 'PAPI', 'PAPI-13-DSM',
    'PAPI — Runway 13',
    'OPERATIONAL',
    TIMESTAMP '2019-06-01 00:00:00', 'PAPI-DSM-13', 'ADB Safegate', 'PAPI-2'
);

INSERT INTO equipment (
    equipment_id, facility_id, equipment_type_code, identifier, name,
    operational_status, installed_at, serial_number, manufacturer, model
) VALUES (
    '12000003-0001-4001-8001-000000000003',
    '10000001-0001-4001-8001-000000000001', 'RWY_LIGHTING', 'RWY-LGT-13-DSM',
    'Runway 13 High-Intensity Approach Lighting',
    'OPERATIONAL',
    TIMESTAMP '2017-03-20 00:00:00', 'RALS-DSM-13', 'Honeywell', 'ALS-F-2'
);

INSERT INTO equipment (
    equipment_id, facility_id, equipment_type_code, identifier, name,
    operational_status, installed_at, serial_number, manufacturer, model
) VALUES (
    '12000004-0001-4001-8001-000000000004',
    '10000001-0001-4001-8001-000000000001', 'COM_VHF', 'COM-DSM-TWR',
    'Tower VHF Communications (121.9 MHz)',
    'OPERATIONAL',
    TIMESTAMP '2016-01-10 00:00:00', 'COM-DSM-01', 'Park Air', 'T6 VHF'
);

INSERT INTO equipment (
    equipment_id, facility_id, equipment_type_code, identifier, name,
    operational_status, installed_at, serial_number, manufacturer, model
) VALUES (
    '12000005-0001-4001-8001-000000000005',
    '10000007-0001-4001-8001-000000000007', 'RADAR_ASR', 'ASR9-DSM',
    'ASR-9 Airport Surveillance Radar',
    'OPERATIONAL',
    TIMESTAMP '2015-09-01 00:00:00', 'ASR9-DSM-01', 'Raytheon', 'ASR-9'
);

INSERT INTO equipment (
    equipment_id, facility_id, equipment_type_code, identifier, name,
    operational_status, installed_at, serial_number, manufacturer, model
) VALUES (
    '12000006-0001-4001-8001-000000000006',
    '10000008-0001-4001-8001-000000000008', 'VOR', 'VOR-DSM',
    'Des Moines VORTAC (DSM)',
    'OPERATIONAL',
    TIMESTAMP '2010-11-01 00:00:00', 'VOR-DSM-01', 'Selex', 'DVOR-1150'
);

INSERT INTO equipment (
    equipment_id, facility_id, equipment_type_code, identifier, name,
    operational_status, installed_at, serial_number, manufacturer, model
) VALUES (
    '12000007-0001-4001-8001-000000000007',
    '10000008-0001-4001-8001-000000000008', 'DME', 'DME-DSM',
    'Des Moines DME (DSM)',
    'OPERATIONAL',
    TIMESTAMP '2010-11-01 00:00:00', 'DME-DSM-01', 'Selex', 'DME-415'
);

INSERT INTO equipment (
    equipment_id, facility_id, equipment_type_code, identifier, name,
    operational_status, installed_at, serial_number, manufacturer, model
) VALUES (
    '12000008-0001-4001-8001-000000000008',
    '10000002-0001-4001-8001-000000000002', 'ILS', 'ILS-10L-ORD',
    'ILS Category III — Runway 10L',
    'OPERATIONAL',
    TIMESTAMP '2014-02-01 00:00:00', 'ILS-ORD-10L', 'Thales', 'ILS-450'
);

INSERT INTO equipment (
    equipment_id, facility_id, equipment_type_code, identifier, name,
    operational_status, installed_at, serial_number, manufacturer, model
) VALUES (
    '12000009-0001-4001-8001-000000000009',
    '10000005-0001-4001-8001-000000000005', 'COM_VHF', 'COM-ZAU-1',
    'Chicago Center VHF Sector 42',
    'OPERATIONAL',
    TIMESTAMP '2018-08-01 00:00:00', 'COM-ZAU-42', 'Park Air', 'T6 VHF'
);

INSERT INTO equipment (
    equipment_id, facility_id, equipment_type_code, identifier, name,
    operational_status, installed_at, last_inspection_at, next_inspection_due_at,
    serial_number, manufacturer, model
) VALUES (
    '1200000a-0001-4001-8001-00000000000a',
    '10000007-0001-4001-8001-000000000007', 'RADAR_ASR', 'ASR9-DSM-BKP',
    'ASR-9 Hot Standby Channel',
    'DEGRADED',
    TIMESTAMP '2015-09-01 00:00:00',
    TIMESTAMP '2026-06-01 08:00:00', TIMESTAMP '2026-12-01 08:00:00',
    'ASR9-DSM-02', 'Raytheon', 'ASR-9'
);

-- Runway ↔ equipment relationships
INSERT INTO runway_equipment (runway_equipment_id, runway_id, equipment_id, relationship_type, is_required)
VALUES ('13000001-0001-4001-8001-000000000001', '11000001-0001-4001-8001-000000000001', '12000001-0001-4001-8001-000000000001', 'SUPPORTS', 'Y');

INSERT INTO runway_equipment (runway_equipment_id, runway_id, equipment_id, relationship_type, is_required)
VALUES ('13000002-0001-4001-8001-000000000002', '11000001-0001-4001-8001-000000000001', '12000002-0001-4001-8001-000000000002', 'SUPPORTS', 'N');

INSERT INTO runway_equipment (runway_equipment_id, runway_id, equipment_id, relationship_type, is_required)
VALUES ('13000003-0001-4001-8001-000000000003', '11000003-0001-4001-8001-000000000003', '12000008-0001-4001-8001-000000000008', 'SUPPORTS', 'Y');

-- Equipment dependency graph (failure propagation)
INSERT INTO equipment_dependency (equipment_dependency_id, parent_equipment_id, child_equipment_id, dependency_type)
VALUES ('14000001-0001-4001-8001-000000000001', '12000005-0001-4001-8001-000000000005', '1200000a-0001-4001-8001-00000000000a', 'BACKUP_FOR');

INSERT INTO equipment_dependency (equipment_dependency_id, parent_equipment_id, child_equipment_id, dependency_type)
VALUES ('14000002-0001-4001-8001-000000000002', '12000001-0001-4001-8001-000000000001', '12000003-0001-4001-8001-000000000003', 'FEEDS');

INSERT INTO equipment_dependency (equipment_dependency_id, parent_equipment_id, child_equipment_id, dependency_type)
VALUES ('14000003-0001-4001-8001-000000000003', '12000006-0001-4001-8001-000000000006', '12000007-0001-4001-8001-000000000007', 'REQUIRES');

-- ---------------------------------------------------------------------------
-- Aircraft
-- ---------------------------------------------------------------------------

INSERT INTO aircraft (
    aircraft_id, tail_number, aircraft_type_code, home_facility_id,
    operational_status, seating_capacity, max_takeoff_weight_lbs, metadata_json
) VALUES (
    '15000001-0001-4001-8001-000000000001', 'N738DS', 'B738',
    '10000001-0001-4001-8001-000000000001', 'AVAILABLE', 162, 174200,
    q'[{"operator":"United Airlines","fleetId":"UA-738-041"}]'
);

INSERT INTO aircraft (
    aircraft_id, tail_number, aircraft_type_code, home_facility_id,
    operational_status, seating_capacity, max_takeoff_weight_lbs, metadata_json
) VALUES (
    '15000002-0001-4001-8001-000000000002', 'N320NA', 'A320',
    '10000002-0001-4001-8001-000000000002', 'IN_FLIGHT', 150, 169800,
    q'[{"operator":"American Airlines","fleetId":"AA-320-118"}]'
);

INSERT INTO aircraft (
    aircraft_id, tail_number, aircraft_type_code, home_facility_id,
    operational_status, seating_capacity, max_takeoff_weight_lbs, metadata_json
) VALUES (
    '15000003-0001-4001-8001-000000000003', 'N175MQ', 'E175',
    '10000003-0001-4001-8001-000000000003', 'IN_FLIGHT', 76, 85500,
    q'[{"operator":"Delta Connection","fleetId":"DL-175-022"}]'
);

INSERT INTO aircraft (
    aircraft_id, tail_number, aircraft_type_code, home_facility_id,
    operational_status, seating_capacity, max_takeoff_weight_lbs, metadata_json
) VALUES (
    '15000004-0001-4001-8001-000000000004', 'N172CF', 'C172',
    '10000001-0001-4001-8001-000000000001', 'AVAILABLE', 3, 2550,
    q'[{"operator":"Cedar Flight Academy","base":"DSM"}]'
);

INSERT INTO aircraft (
    aircraft_id, tail_number, aircraft_type_code, home_facility_id,
    operational_status, seating_capacity, max_takeoff_weight_lbs, metadata_json
) VALUES (
    '15000005-0001-4001-8001-000000000005', 'N77WF', 'B77W',
    '10000002-0001-4001-8001-000000000002', 'AVAILABLE', 350, 775000,
    q'[{"operator":"United Airlines","fleetId":"UA-77W-009"}]'
);

-- ---------------------------------------------------------------------------
-- Maintenance — active ILS emergency + completed radar inspection
-- ---------------------------------------------------------------------------

INSERT INTO maintenance_activity (
    maintenance_activity_id, equipment_id, originating_facility_id,
    activity_type_code, maintenance_status, priority, title, description,
    scheduled_start_at, actual_start_at, assigned_user_id, estimated_duration_hrs,
    created_by
) VALUES (
    '16000001-0001-4001-8001-000000000001',
    '12000001-0001-4001-8001-000000000001',
    '10000001-0001-4001-8001-000000000001',
    'EMERGENCY', 'IN_PROGRESS', 1,
    'Restore ILS RWY 13 — Glide Slope Signal Loss',
    'Glide slope transmitter offline since 11:42 UTC. Localizer nominal. Cat I approaches suspended on RWY 13. Depot crew dispatched with replacement GS module.',
    TIMESTAMP '2026-06-23 12:00:00', TIMESTAMP '2026-06-23 12:45:00',
    '20000002-0001-4001-8001-000000000002', 6,
    '20000002-0001-4001-8001-000000000002'
);

INSERT INTO maintenance_activity (
    maintenance_activity_id, equipment_id, originating_facility_id,
    activity_type_code, maintenance_status, priority, title, description,
    scheduled_start_at, scheduled_end_at, actual_start_at, actual_end_at,
    assigned_user_id, estimated_duration_hrs, created_by
) VALUES (
    '16000002-0001-4001-8001-000000000002',
    '1200000a-0001-4001-8001-00000000000a',
    '10000007-0001-4001-8001-000000000007',
    'INSPECTION', 'COMPLETED', 3,
    'ASR-9 Standby Channel Quarterly Inspection',
    'Routine inspection identified degraded magnetron on standby channel. Primary ASR-9 operational.',
    TIMESTAMP '2026-06-20 08:00:00', TIMESTAMP '2026-06-20 16:00:00',
    TIMESTAMP '2026-06-20 08:30:00', TIMESTAMP '2026-06-20 14:15:00',
    '20000002-0001-4001-8001-000000000002', 8,
    '20000002-0001-4001-8001-000000000002'
);

INSERT INTO facility_maintenance_activity (
    facility_maintenance_activity_id, facility_id, maintenance_activity_id, role_type
) VALUES (
    '17000001-0001-4001-8001-000000000001',
    '10000001-0001-4001-8001-000000000001',
    '16000001-0001-4001-8001-000000000001', 'SITE'
);

INSERT INTO facility_maintenance_activity (
    facility_maintenance_activity_id, facility_id, maintenance_activity_id, role_type
) VALUES (
    '17000002-0001-4001-8001-000000000002',
    '10000006-0001-4001-8001-000000000006',
    '16000001-0001-4001-8001-000000000001', 'DISPATCH_FROM'
);

INSERT INTO maintenance_log (
    maintenance_log_id, maintenance_activity_id, log_entry_type, message, logged_at, logged_by_user_id
) VALUES (
    '18000001-0001-4001-8001-000000000001',
    '16000001-0001-4001-8001-000000000001', 'STATUS_CHANGE',
    'Activity status changed PLANNED → DISPATCHED. Crew ETA 45 minutes.',
    TIMESTAMP '2026-06-23 12:15:00', '20000002-0001-4001-8001-000000000002'
);

INSERT INTO maintenance_log (
    maintenance_log_id, maintenance_activity_id, log_entry_type, message, logged_at, logged_by_user_id
) VALUES (
    '18000002-0001-4001-8001-000000000002',
    '16000001-0001-4001-8001-000000000001', 'NOTE',
    'On-site: glide slope cabinet shows fault code GS-TX-07. Replacement module ILS-GS-739 in transit from depot.',
    TIMESTAMP '2026-06-23 13:30:00', '20000002-0001-4001-8001-000000000002'
);

INSERT INTO maintenance_report (
    maintenance_report_id, maintenance_activity_id, findings, actions_taken,
    parts_consumed_json, equipment_restored, completed_at, completed_by_user_id
) VALUES (
    '19000001-0001-4001-8001-000000000001',
    '16000002-0001-4001-8001-000000000002',
    'Standby magnetron output 12% below nominal. Primary channel within tolerance.',
    'Replaced magnetron on standby transmitter. Aligned power output to spec. Verified failover test.',
    q'[{"partNumber":"RAD-MAG-ASR9","quantity":1,"description":"ASR-9 Magnetron"}]',
    'N',
    TIMESTAMP '2026-06-20 14:15:00',
    '20000002-0001-4001-8001-000000000002'
);

-- ---------------------------------------------------------------------------
-- Parts catalog, quotes, and orders
-- ---------------------------------------------------------------------------

INSERT INTO equipment_part (
    equipment_part_id, part_number, name, description, equipment_type_code,
    unit_of_measure, stock_quantity, reorder_threshold, storage_facility_id
) VALUES (
    '1a000001-0001-4001-8001-000000000001',
    'ILS-GS-739', 'ILS Glide Slope Transmitter Module',
    'Replacement GS transmitter module for Thales ILS-420 series',
    'ILS', 'EA', 2, 1, '10000006-0001-4001-8001-000000000006'
);

INSERT INTO equipment_part (
    equipment_part_id, part_number, name, description, equipment_type_code,
    unit_of_measure, stock_quantity, reorder_threshold, storage_facility_id
) VALUES (
    '1a000002-0001-4001-8001-000000000002',
    'RAD-MAG-ASR9', 'ASR-9 Magnetron Assembly',
    'Surveillance radar magnetron for Raytheon ASR-9',
    'RADAR_ASR', 'EA', 4, 2, '10000006-0001-4001-8001-000000000006'
);

INSERT INTO equipment_part_quote (
    equipment_part_quote_id, equipment_part_id, vendor_name,
    quoted_unit_cost, currency_code, lead_time_days, quote_status,
    quoted_at, valid_until, notes
) VALUES (
    '1b000001-0001-4001-8001-000000000001',
    '1a000001-0001-4001-8001-000000000001',
    'Thales Avionics OEM',
    42850.00, 'USD', 14, 'ACCEPTED',
    TIMESTAMP '2026-03-10 10:00:00', TIMESTAMP '2026-09-10 10:00:00',
    'Annual contract pricing for NAS depot'
);

INSERT INTO equipment_part_order (
    equipment_part_order_id, equipment_part_id, equipment_part_quote_id,
    receiving_facility_id, maintenance_activity_id,
    quantity_ordered, unit_cost, order_status,
    ordered_at, expected_delivery_at, notes
) VALUES (
    '1c000001-0001-4001-8001-000000000001',
    '1a000001-0001-4001-8001-000000000001',
    '1b000001-0001-4001-8001-000000000001',
    '10000001-0001-4001-8001-000000000001',
    '16000001-0001-4001-8001-000000000001',
    1, 42850.00, 'SHIPPED',
    TIMESTAMP '2026-06-23 12:20:00', TIMESTAMP '2026-06-23 14:30:00',
    'Emergency dispatch — ILS GS module for RWY 13 outage'
);

-- ---------------------------------------------------------------------------
-- Equipment alerts
-- ---------------------------------------------------------------------------

INSERT INTO equipment_alert (
    equipment_alert_id, equipment_id, alert_type, severity, title, message,
    raised_at, acknowledged_at, acknowledged_by_user_id,
    related_maintenance_activity_id
) VALUES (
    '1d000001-0001-4001-8001-000000000001',
    '12000001-0001-4001-8001-000000000001', 'FAILURE', 'CRITICAL',
    'ILS RWY 13 Glide Slope Offline',
    'GS transmitter signal lost. Cat I ILS approaches to RWY 13 unavailable. NOTAM 6/234 issued.',
    TIMESTAMP '2026-06-23 11:42:00',
    TIMESTAMP '2026-06-23 11:55:00',
    '00000000-0000-0000-0000-000000000100',
    '16000001-0001-4001-8001-000000000001'
);

INSERT INTO equipment_alert (
    equipment_alert_id, equipment_id, alert_type, severity, title, message,
    raised_at, resolved_at, resolved_by_user_id
) VALUES (
    '1d000002-0001-4001-8001-000000000002',
    '1200000a-0001-4001-8001-00000000000a', 'DEGRADED', 'MEDIUM',
    'ASR-9 Standby Channel Below Spec',
    'Standby magnetron output degraded during quarterly inspection.',
    TIMESTAMP '2026-06-20 10:00:00',
    TIMESTAMP '2026-06-20 14:15:00',
    '20000002-0001-4001-8001-000000000002'
);

-- ---------------------------------------------------------------------------
-- Flight requests & operations
-- ---------------------------------------------------------------------------

INSERT INTO flight_request (
    flight_request_id, request_number, origin_facility_id, destination_facility_id,
    requested_departure_at, requested_arrival_at, aircraft_id, passenger_count,
    request_status, requested_by_user_id, notes
) VALUES (
    '21000001-0001-4001-8001-000000000001',
    'FR-2026-0623-001',
    '10000001-0001-4001-8001-000000000001',
    '10000002-0001-4001-8001-000000000002',
    TIMESTAMP '2026-06-23 13:00:00', TIMESTAMP '2026-06-23 13:55:00',
    '15000001-0001-4001-8001-000000000001', 148,
    'APPROVED', '00000000-0000-0000-0000-000000000100',
    'United 2847 DSM→ORD — delayed pending RWY 13 ILS restoration or alternate departure plan'
);

INSERT INTO flight_request (
    flight_request_id, request_number, origin_facility_id, destination_facility_id,
    requested_departure_at, requested_arrival_at, aircraft_id, passenger_count,
    request_status, requested_by_user_id, notes
) VALUES (
    '21000002-0001-4001-8001-000000000002',
    'FR-2026-0623-002',
    '10000002-0001-4001-8001-000000000002',
    '10000003-0001-4001-8001-000000000003',
    TIMESTAMP '2026-06-23 16:00:00', TIMESTAMP '2026-06-23 17:30:00',
    '15000005-0001-4001-8001-000000000005', 310,
    'SUBMITTED', '00000000-0000-0000-0000-000000000100',
    'Planned UA heavy ORD→MSP evening rotation'
);

INSERT INTO flight_operation (
    flight_operation_id, flight_request_id, flight_number,
    origin_facility_id, destination_facility_id,
    departure_runway_id, arrival_runway_id,
    current_phase, operation_status,
    scheduled_departure_at, scheduled_arrival_at,
    actual_departure_at, aircraft_id, delay_minutes, metadata_json
) VALUES (
    '22000001-0001-4001-8001-000000000001',
    '21000001-0001-4001-8001-000000000001', 'UA2847',
    '10000001-0001-4001-8001-000000000001',
    '10000002-0001-4001-8001-000000000002',
    '11000001-0001-4001-8001-000000000001', '11000003-0001-4001-8001-000000000003',
    'DELAYED', 'ACTIVE',
    TIMESTAMP '2026-06-23 13:00:00', TIMESTAMP '2026-06-23 13:55:00',
    NULL, '15000001-0001-4001-8001-000000000001', 75,
    q'[{"delayReason":"NAVAID_OUTAGE","gate":"B12","alternateRunwayConsidered":"05/23","adsbxBlockNote":"STA tightened to ~55m airborne block (ADSBX DSM-ORD median ~50-53m on 2026-06-01)"}]'
);

INSERT INTO flight_operation (
    flight_operation_id, flight_request_id, flight_number,
    origin_facility_id, destination_facility_id,
    arrival_runway_id, current_phase, operation_status,
    scheduled_departure_at, scheduled_arrival_at,
    actual_departure_at, aircraft_id, delay_minutes, metadata_json
) VALUES (
    '22000002-0001-4001-8001-000000000002',
    NULL, 'DL1920',
    '10000003-0001-4001-8001-000000000003',
    '10000001-0001-4001-8001-000000000001',
    '11000001-0001-4001-8001-000000000001',
    'APPROACH', 'ACTIVE',
    TIMESTAMP '2026-06-23 12:30:00', TIMESTAMP '2026-06-23 14:00:00',
    TIMESTAMP '2026-06-23 12:45:00', '15000003-0001-4001-8001-000000000003', 30,
    q'[{"holdingFix":"DSM","holdReason":"WEATHER_AND_NAVAID"}]'
);

INSERT INTO flight_operation (
    flight_operation_id, flight_request_id, flight_number,
    origin_facility_id, destination_facility_id,
    departure_runway_id, arrival_runway_id,
    current_phase, operation_status,
    scheduled_departure_at, scheduled_arrival_at,
    actual_departure_at, actual_arrival_at,
    aircraft_id, delay_minutes
) VALUES (
    '22000003-0001-4001-8001-000000000003',
    NULL, 'AA451',
    '10000002-0001-4001-8001-000000000002',
    '10000003-0001-4001-8001-000000000003',
    '11000004-0001-4001-8001-000000000004', '11000005-0001-4001-8001-000000000005',
    'COMPLETE', 'COMPLETED',
    TIMESTAMP '2026-06-23 10:00:00', TIMESTAMP '2026-06-23 11:35:00',
    TIMESTAMP '2026-06-23 10:05:00', TIMESTAMP '2026-06-23 11:40:00',
    '15000002-0001-4001-8001-000000000002', 5
);

-- Flight paths (UA2847 planned route — not yet airborne)
-- ETAs scaled to ~55m DSM→ORD block (ADSBX 2026-06-01 median ~50–53m).
INSERT INTO flight_path (flight_path_id, flight_operation_id, sequence_order, waypoint_name, latitude, longitude, altitude_ft, estimated_time_at)
VALUES ('23000001-0001-4001-8001-000000000001', '22000001-0001-4001-8001-000000000001', 1, 'DSM', 41.5340000, -93.6631000, 0, TIMESTAMP '2026-06-23 13:00:00');

INSERT INTO flight_path (flight_path_id, flight_operation_id, sequence_order, waypoint_name, latitude, longitude, altitude_ft, estimated_time_at)
VALUES ('23000002-0001-4001-8001-000000000002', '22000001-0001-4001-8001-000000000001', 2, 'IOW', 41.5330000, -91.7250000, 10000, TIMESTAMP '2026-06-23 13:14:00');

INSERT INTO flight_path (flight_path_id, flight_operation_id, sequence_order, waypoint_name, latitude, longitude, altitude_ft, estimated_time_at)
VALUES ('23000003-0001-4001-8001-000000000003', '22000001-0001-4001-8001-000000000001', 3, 'BVT', 41.7000000, -90.3500000, 24000, TIMESTAMP '2026-06-23 13:32:00');

INSERT INTO flight_path (flight_path_id, flight_operation_id, sequence_order, waypoint_name, latitude, longitude, altitude_ft, estimated_time_at)
VALUES ('23000004-0001-4001-8001-000000000004', '22000001-0001-4001-8001-000000000001', 4, 'ORD', 41.9742000, -87.9073000, 0, TIMESTAMP '2026-06-23 13:55:00');

-- DL1920 approach path (holding then ILS 13)
INSERT INTO flight_path (flight_path_id, flight_operation_id, sequence_order, waypoint_name, latitude, longitude, altitude_ft, estimated_time_at)
VALUES ('23000005-0001-4001-8001-000000000005', '22000002-0001-4001-8001-000000000002', 1, 'DSM-HOLD', 41.6500000, -93.9000000, 5000, TIMESTAMP '2026-06-23 13:45:00');

INSERT INTO flight_path (flight_path_id, flight_operation_id, sequence_order, waypoint_name, latitude, longitude, altitude_ft, estimated_time_at)
VALUES ('23000006-0001-4001-8001-000000000006', '22000002-0001-4001-8001-000000000002', 2, 'DSM-FAF', 41.4800000, -93.7500000, 3000, TIMESTAMP '2026-06-23 14:05:00');

INSERT INTO flight_path (flight_path_id, flight_operation_id, sequence_order, waypoint_name, latitude, longitude, altitude_ft, estimated_time_at)
VALUES ('23000007-0001-4001-8001-000000000007', '22000002-0001-4001-8001-000000000002', 3, 'DSM-RWY13', 41.5340000, -93.6631000, 0, TIMESTAMP '2026-06-23 14:15:00');

INSERT INTO flight_path_request (
    flight_path_request_id, flight_operation_id, request_reason, request_status,
    requested_path_json, requested_by_user_id, requested_at
) VALUES (
    '24000001-0001-4001-8001-000000000001',
    '22000002-0001-4001-8001-000000000002',
    'Request RNAV approach RWY 05 due to ILS 13 outage and thunderstorm west of field',
    'PENDING',
    q'[{"waypoints":[{"name":"DSM-HOLD","lat":41.65,"lon":-93.90,"altFt":5000},{"name":"DSM-RWY05","lat":41.53,"lon":-93.68,"altFt":0}]}]',
    '00000000-0000-0000-0000-000000000100',
    TIMESTAMP '2026-06-23 13:50:00'
);

INSERT INTO flight_incident (
    flight_incident_id, flight_operation_id, incident_type_code, severity,
    title, description, occurred_at,
    related_equipment_id, related_facility_id
) VALUES (
    '25000001-0001-4001-8001-000000000001',
    '22000002-0001-4001-8001-000000000002', 'WEATHER_HOLD', 'MEDIUM',
    'DL1920 Holding — Convective Weather and ILS Outage',
    'Aircraft entered holding at DSM due to thunderstorm cell 15 NM west and unavailable ILS RWY 13.',
    TIMESTAMP '2026-06-23 13:40:00',
    '12000001-0001-4001-8001-000000000001',
    '10000001-0001-4001-8001-000000000001'
);

-- Flight event stream (append-only simulation replay)
INSERT INTO flight_event (flight_event_id, flight_operation_id, event_type_code, occurred_at, sequence_number, payload_json, correlation_id)
VALUES ('26000001-0001-4001-8001-000000000001', '22000001-0001-4001-8001-000000000001', 'FLIGHT_SCHEDULED', TIMESTAMP '2026-06-23 08:00:00', 1, q'[{"gate":"B12"}]', 'corr-ua2847-001');

INSERT INTO flight_event (flight_event_id, flight_operation_id, event_type_code, occurred_at, sequence_number, payload_json, correlation_id)
VALUES ('26000002-0001-4001-8001-000000000002', '22000001-0001-4001-8001-000000000001', 'DELAYED', TIMESTAMP '2026-06-23 11:45:00', 2, q'[{"delayMinutes":75,"reason":"ILS_OUTAGE"}]', 'corr-ua2847-001');

INSERT INTO flight_event (flight_event_id, flight_operation_id, event_type_code, occurred_at, sequence_number, payload_json, correlation_id)
VALUES ('26000003-0001-4001-8001-000000000003', '22000001-0001-4001-8001-000000000001', 'EQUIPMENT_IMPACT', TIMESTAMP '2026-06-23 11:42:00', 3, q'[{"equipmentId":"12000001-0001-4001-8001-000000000001","impact":"RWY13_ILS_UNAVAILABLE"}]', 'corr-ua2847-001');

INSERT INTO flight_event (flight_event_id, flight_operation_id, event_type_code, occurred_at, sequence_number, payload_json, correlation_id)
VALUES ('26000004-0001-4001-8001-000000000004', '22000002-0001-4001-8001-000000000002', 'PHASE_CHANGED', TIMESTAMP '2026-06-23 13:35:00', 1, q'[{"from":"ENROUTE","to":"APPROACH"}]', 'corr-dl1920-001');

INSERT INTO flight_event (flight_event_id, flight_operation_id, event_type_code, occurred_at, sequence_number, payload_json, correlation_id)
VALUES ('26000005-0001-4001-8001-000000000005', '22000002-0001-4001-8001-000000000002', 'WEATHER_IMPACT', TIMESTAMP '2026-06-23 13:40:00', 2, q'[{"weatherEventId":"27000001-0001-4001-8001-000000000001","action":"HOLD"}]', 'corr-dl1920-001');

-- ---------------------------------------------------------------------------
-- Weather — convective line moving east across Iowa
-- ---------------------------------------------------------------------------

INSERT INTO weather_event (
    weather_event_id, weather_type_code, name, severity,
    started_at, ended_at, max_wind_kts, visibility_sm, ceiling_ft, precipitation_rate,
    metadata_json
) VALUES (
    '27000001-0001-4001-8001-000000000001',
    'THUNDERSTORM', 'Central Iowa Convective Line', 'HIGH',
    TIMESTAMP '2026-06-23 12:30:00', TIMESTAMP '2026-06-23 18:00:00',
    45.0, 2.0, 1200, 0.8,
    q'[{"movement":"ENE","kts":25,"hailRisk":"MODERATE"}]'
);

INSERT INTO weather_event_path (
    weather_event_path_id, weather_event_id, sequence_order,
    latitude, longitude, radius_nm, effective_at, intensity_factor
) VALUES (
    '28000001-0001-4001-8001-000000000001', '27000001-0001-4001-8001-000000000001', 1,
    41.8500000, -94.2000000, 25.0, TIMESTAMP '2026-06-23 12:30:00', 0.7
);

INSERT INTO weather_event_path (
    weather_event_path_id, weather_event_id, sequence_order,
    latitude, longitude, radius_nm, effective_at, intensity_factor
) VALUES (
    '28000002-0001-4001-8001-000000000002', '27000001-0001-4001-8001-000000000001', 2,
    41.7000000, -93.8500000, 30.0, TIMESTAMP '2026-06-23 14:00:00', 1.0
);

INSERT INTO weather_event_path (
    weather_event_path_id, weather_event_id, sequence_order,
    latitude, longitude, radius_nm, effective_at, intensity_factor
) VALUES (
    '28000003-0001-4001-8001-000000000003', '27000001-0001-4001-8001-000000000001', 3,
    41.5500000, -93.5000000, 28.0, TIMESTAMP '2026-06-23 15:30:00', 0.8
);

INSERT INTO weather_event_alert (
    weather_event_alert_id, weather_event_id, facility_id, flight_operation_id,
    alert_level, message, issued_at, expires_at
) VALUES (
    '29000001-0001-4001-8001-000000000001',
    '27000001-0001-4001-8001-000000000001',
    '10000001-0001-4001-8001-000000000001', NULL,
    'HIGH',
    'Convective SIGMET: thunderstorm line 15 NM west of DSM moving ENE. Expect wind shear and reduced visibility.',
    TIMESTAMP '2026-06-23 13:00:00', TIMESTAMP '2026-06-23 17:00:00'
);

INSERT INTO weather_event_alert (
    weather_event_alert_id, weather_event_id, facility_id, flight_operation_id,
    alert_level, message, issued_at
) VALUES (
    '29000002-0001-4001-8001-000000000002',
    '27000001-0001-4001-8001-000000000001',
    NULL, '22000002-0001-4001-8001-000000000002',
    'MEDIUM',
    'DL1920: maintain holding pattern DSM. Convective weather and ILS 13 unavailable.',
    TIMESTAMP '2026-06-23 13:42:00'
);

-- ---------------------------------------------------------------------------
-- Simulation geography — virtual placement for DEFAULT render context
-- ---------------------------------------------------------------------------

INSERT INTO simulation_render_context (
    render_context_id, context_code, name, description, is_active, created_by_user_id
) VALUES (
    '00000000-0000-0000-0000-000000000020',
    'MIDWEST_TRAINING', 'Midwest Training Environment',
    'Alternate virtual layout for scenario training — inactive by default',
    'N', '20000001-0001-4001-8001-000000000001'
);

INSERT INTO simulation_geo_location_lookup (
    simulation_geo_location_id, render_context_id, facility_id,
    real_city, real_state_code, real_zip_code,
    virtual_latitude, virtual_longitude, virtual_elevation_ft,
    transform_json, notes
) VALUES (
    '2a000001-0001-4001-8001-000000000001',
    '00000000-0000-0000-0000-000000000010',
    '10000001-0001-4001-8001-000000000001',
    'Des Moines', 'IA', '50321',
    0.0000000, 0.0000000, 0,
    q'[{"unityPosition":{"x":0,"y":0,"z":0},"scale":1.0,"rotationYDegrees":0,"mapLayer":"alpha-midwest"}]',
    'Scenario hub — origin of virtual coordinate system'
);

INSERT INTO simulation_geo_location_lookup (
    simulation_geo_location_id, render_context_id, facility_id,
    real_city, real_state_code, real_zip_code,
    virtual_latitude, virtual_longitude, virtual_elevation_ft,
    transform_json, notes
) VALUES (
    '2a000002-0001-4001-8001-000000000002',
    '00000000-0000-0000-0000-000000000010',
    '10000002-0001-4001-8001-000000000002',
    'Chicago', 'IL', '60666',
    0.0000000, 2.8500000, 0,
    q'[{"unityPosition":{"x":285,"y":0,"z":120},"scale":1.0,"rotationYDegrees":0,"mapLayer":"alpha-midwest"}]',
    'ORD — ~285 km ENE of DSM in virtual space'
);

INSERT INTO simulation_geo_location_lookup (
    simulation_geo_location_id, render_context_id, facility_id,
    real_city, real_state_code, real_zip_code,
    virtual_latitude, virtual_longitude, virtual_elevation_ft,
    transform_json, notes
) VALUES (
    '2a000003-0001-4001-8001-000000000003',
    '00000000-0000-0000-0000-000000000010',
    '10000003-0001-4001-8001-000000000003',
    'Saint Paul', 'MN', '55111',
    3.1000000, -0.3500000, 0,
    q'[{"unityPosition":{"x":-35,"y":0,"z":310},"scale":1.0,"rotationYDegrees":0,"mapLayer":"alpha-midwest"}]',
    'MSP — north of DSM corridor'
);

INSERT INTO simulation_geo_location_lookup (
    simulation_geo_location_id, render_context_id, facility_id,
    real_city, real_state_code, real_zip_code,
    virtual_latitude, virtual_longitude, virtual_elevation_ft,
    transform_json, notes
) VALUES (
    '2a000004-0001-4001-8001-000000000004',
    '00000000-0000-0000-0000-000000000010',
    '10000004-0001-4001-8001-000000000004',
    'Aurora', 'IL', '60506',
    0.0000000, 2.4000000, 0,
    q'[{"unityPosition":{"x":240,"y":50,"z":0},"scale":0.8,"rotationYDegrees":0,"mapLayer":"alpha-midwest","facilityType":"ARTCC"}]',
    'Chicago Center — elevated control volume representation'
);

INSERT INTO simulation_geo_location_lookup (
    simulation_geo_location_id, render_context_id, facility_id,
    real_city, real_state_code, real_zip_code,
    virtual_latitude, virtual_longitude, virtual_elevation_ft,
    transform_json, notes
) VALUES (
    '2a000005-0001-4001-8001-000000000005',
    '00000000-0000-0000-0000-000000000010',
    '10000006-0001-4001-8001-000000000006',
    'Urbandale', 'IA', '50322',
    -0.0500000, -0.0800000, 0,
    q'[{"unityPosition":{"x":-8,"y":0,"z":-5},"scale":1.0,"rotationYDegrees":0,"mapLayer":"alpha-midwest"}]',
    'NAS maintenance depot — west of DSM airport'
);

INSERT INTO simulation_geo_location_lookup (
    simulation_geo_location_id, render_context_id, facility_id,
    real_city, real_state_code, real_zip_code,
    virtual_latitude, virtual_longitude, virtual_elevation_ft,
    transform_json, notes
) VALUES (
    '2a000006-0001-4001-8001-000000000006',
    '00000000-0000-0000-0000-000000000010',
    '10000007-0001-4001-8001-000000000007',
    'Des Moines', 'IA', '50315',
    0.0200000, -0.0200000, 0,
    q'[{"unityPosition":{"x":-2,"y":15,"z":2},"scale":1.0,"rotationYDegrees":0,"mapLayer":"alpha-midwest","facilityType":"RADAR"}]',
    'ASR-9 site — slight offset from airport centroid'
);

-- ---------------------------------------------------------------------------
-- Simulation snapshot — baseline capture at scenario start
-- ---------------------------------------------------------------------------

INSERT INTO simulation_snapshot (
    simulation_snapshot_id, snapshot_label, render_context_id,
    sim_time_utc, clock_mode_code, time_scale, run_status_code, step_sequence,
    state_json, created_by_user_id
) VALUES (
    '2b000001-0001-4001-8001-000000000001',
    'Baseline — DSM ILS Outage Scenario Start',
    '00000000-0000-0000-0000-000000000010',
    TIMESTAMP '2026-06-23 14:00:00', 'REALTIME', 1, 'PAUSED', 0,
    q'[{"scenario":"upper-midwest-corridor","facilities":8,"activeFlights":2,"equipmentAlerts":1,"weatherEvents":1,"primaryIncident":"ILS-13-DSM-FAILED"}]',
    '20000001-0001-4001-8001-000000000001'
);

-- Align singleton clock to scenario time
UPDATE simulation_run_state
SET current_sim_time_utc = TIMESTAMP '2026-06-23 14:00:00',
    updated_at = SYSTIMESTAMP,
    updated_by_user_id = '20000001-0001-4001-8001-000000000001'
WHERE run_state_id = 'CURRENT';

COMMIT;
