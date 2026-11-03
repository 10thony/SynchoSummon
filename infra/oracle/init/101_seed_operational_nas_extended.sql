-- =============================================================================
-- NAS Simulation — extended operational seed (101)
-- Extends 100_seed_operational_nas.sql — new IDs only, no duplicates.
--
-- Adds: Omaha, Cedar Rapids, Quad Cities, Milwaukee; western corridor traffic;
--       MSP fog, ORD wind shear; GA/local ops; depot stock expansion; training
--       render-context placements; second snapshot.
-- =============================================================================

ALTER SESSION SET CONTAINER = FREEPDB1;
ALTER SESSION SET CURRENT_SCHEMA = nas_sim;

-- ---------------------------------------------------------------------------
-- Additional facilities — western / eastern corridor nodes
-- ---------------------------------------------------------------------------

INSERT INTO facility (
    facility_id, facility_code, name, facility_type_code, parent_facility_id,
    address_line1, city, state_code, zip_code,
    latitude, longitude, elevation_ft, timezone_name, operational_status,
    icao_code, faa_lid, metadata_json, created_by, updated_by
) VALUES (
    '10000009-0001-4001-8001-000000000009',
    'KOMA', 'Eppley Airfield', 'AIRPORT', NULL,
    '4501 Abbott Dr', 'Omaha', 'NE', '68110',
    41.3032000, -95.8941000, 984, 'America/Chicago', 'OPERATIONAL',
    'KOMA', 'OMA',
    q'[{"hub":false,"runwayCount":3}]',
    '20000001-0001-4001-8001-000000000001',
    '20000001-0001-4001-8001-000000000001'
);

INSERT INTO facility (
    facility_id, facility_code, name, facility_type_code, parent_facility_id,
    address_line1, city, state_code, zip_code,
    latitude, longitude, elevation_ft, timezone_name, operational_status,
    icao_code, faa_lid, metadata_json, created_by, updated_by
) VALUES (
    '1000000a-0001-4001-8001-00000000000a',
    'KCID', 'The Eastern Iowa Airport', 'AIRPORT', NULL,
    '2121 Arthur Collins Pkwy SW', 'Cedar Rapids', 'IA', '52404',
    41.8867000, -91.7108000, 869, 'America/Chicago', 'OPERATIONAL',
    'KCID', 'CID',
    q'[{"diversionAlternateFor":"KDSM"}]',
    '20000001-0001-4001-8001-000000000001',
    '20000001-0001-4001-8001-000000000001'
);

INSERT INTO facility (
    facility_id, facility_code, name, facility_type_code, parent_facility_id,
    address_line1, city, state_code, zip_code,
    latitude, longitude, elevation_ft, timezone_name, operational_status,
    icao_code, faa_lid, metadata_json, created_by, updated_by
) VALUES (
    '1000000b-0001-4001-8001-00000000000b',
    'KMLI', 'Quad City International Airport', 'AIRPORT', NULL,
    '2200 69th Ave', 'Moline', 'IL', '61265',
    41.4485000, -90.5075000, 590, 'America/Chicago', 'OPERATIONAL',
    'KMLI', 'MLI',
    q'[{"metro":"Quad Cities"}]',
    '20000001-0001-4001-8001-000000000001',
    '20000001-0001-4001-8001-000000000001'
);

INSERT INTO facility (
    facility_id, facility_code, name, facility_type_code, parent_facility_id,
    address_line1, city, state_code, zip_code,
    latitude, longitude, elevation_ft, timezone_name, operational_status,
    icao_code, faa_lid, metadata_json, created_by, updated_by
) VALUES (
    '1000000c-0001-4001-8001-00000000000c',
    'KMKE', 'Milwaukee Mitchell International Airport', 'AIRPORT', NULL,
    '5300 S Howell Ave', 'Milwaukee', 'WI', '53207',
    42.9472000, -87.8966000, 723, 'America/Chicago', 'OPERATIONAL',
    'KMKE', 'MKE',
    q'[{"primaryCarrier":"SWA/DAL"}]',
    '20000001-0001-4001-8001-000000000001',
    '20000001-0001-4001-8001-000000000001'
);

INSERT INTO facility (
    facility_id, facility_code, name, facility_type_code, parent_facility_id,
    address_line1, city, state_code, zip_code,
    latitude, longitude, elevation_ft, timezone_name, operational_status,
    icao_code, faa_lid, metadata_json, created_by, updated_by
) VALUES (
    '1000000d-0001-4001-8001-00000000000d',
    'ZMP', 'Minneapolis Air Route Traffic Control Center', 'ARTCC', NULL,
    '6640 34th Ave S', 'Farmington', 'MN', '55024',
    44.8400000, -93.1800000, 900, 'America/Chicago', 'OPERATIONAL',
    NULL, NULL,
    q'[{"artccId":"ZMP","jurisdiction":"Minneapolis Center"}]',
    '20000001-0001-4001-8001-000000000001',
    '20000001-0001-4001-8001-000000000001'
);

-- ---------------------------------------------------------------------------
-- Runways (new airports)
-- ---------------------------------------------------------------------------

INSERT INTO runway (runway_id, facility_id, designator, length_ft, width_ft, surface_type, magnetic_heading_deg, operational_status, max_aircraft_category)
VALUES ('11000006-0001-4001-8001-000000000006', '10000009-0001-4001-8001-000000000009', '14R/32L', 9500, 150, 'CONCRETE', 143.00, 'OPEN', 'D');

INSERT INTO runway (runway_id, facility_id, designator, length_ft, width_ft, surface_type, magnetic_heading_deg, operational_status, max_aircraft_category)
VALUES ('11000007-0001-4001-8001-000000000007', '1000000a-0001-4001-8001-00000000000a', '13/31', 8626, 150, 'CONCRETE', 133.00, 'OPEN', 'D');

INSERT INTO runway (runway_id, facility_id, designator, length_ft, width_ft, surface_type, magnetic_heading_deg, operational_status, max_aircraft_category)
VALUES ('11000008-0001-4001-8001-000000000008', '1000000b-0001-4001-8001-00000000000b', '09/27', 10000, 150, 'CONCRETE', 93.00, 'OPEN', 'D');

INSERT INTO runway (runway_id, facility_id, designator, length_ft, width_ft, surface_type, magnetic_heading_deg, operational_status, max_aircraft_category)
VALUES ('11000009-0001-4001-8001-000000000009', '1000000c-0001-4001-8001-00000000000c', '01L/19R', 9690, 150, 'CONCRETE', 13.00, 'OPEN', 'D');

-- ---------------------------------------------------------------------------
-- Equipment at new / existing sites
-- ---------------------------------------------------------------------------

INSERT INTO equipment (
    equipment_id, facility_id, equipment_type_code, identifier, name,
    operational_status, installed_at, serial_number, manufacturer, model
) VALUES (
    '1200000b-0001-4001-8001-00000000000b',
    '1000000a-0001-4001-8001-00000000000a', 'ILS', 'ILS-13-CID',
    'ILS Category I — Runway 13 Cedar Rapids',
    'OPERATIONAL', TIMESTAMP '2019-01-15 00:00:00', 'ILS-CID-13', 'Thales', 'ILS-420'
);

INSERT INTO equipment (
    equipment_id, facility_id, equipment_type_code, identifier, name,
    operational_status, installed_at, serial_number, manufacturer, model
) VALUES (
    '1200000c-0001-4001-8001-00000000000c',
    '10000009-0001-4001-8001-000000000009', 'RADAR_ASR', 'ASR9-OMA',
    'Eppley ASR-8 Approach Radar',
    'OPERATIONAL', TIMESTAMP '2012-06-01 00:00:00', 'ASR-OMA-01', 'Raytheon', 'ASR-8'
);

INSERT INTO equipment (
    equipment_id, facility_id, equipment_type_code, identifier, name,
    operational_status, installed_at, serial_number, manufacturer, model
) VALUES (
    '1200000d-0001-4001-8001-00000000000d',
    '1000000c-0001-4001-8001-00000000000c', 'ILS', 'ILS-01L-MKE',
    'ILS Category I — Runway 01L Milwaukee',
    'DEGRADED', TIMESTAMP '2016-09-01 00:00:00', 'ILS-MKE-01L', 'Thales', 'ILS-420'
);

INSERT INTO equipment (
    equipment_id, facility_id, equipment_type_code, identifier, name,
    operational_status, installed_at, serial_number, manufacturer, model
) VALUES (
    '1200000e-0001-4001-8001-00000000000e',
    '10000005-0001-4001-8001-000000000005', 'COM_UHF', 'COM-DSM-APP',
    'DSM Approach UHF Backup Net',
    'OPERATIONAL', TIMESTAMP '2020-02-01 00:00:00', 'COM-DSM-UHF', 'Park Air', 'T6 UHF'
);

INSERT INTO runway_equipment (runway_equipment_id, runway_id, equipment_id, relationship_type, is_required)
VALUES ('13000004-0001-4001-8001-000000000004', '11000007-0001-4001-8001-000000000007', '1200000b-0001-4001-8001-00000000000b', 'SUPPORTS', 'Y');

INSERT INTO runway_equipment (runway_equipment_id, runway_id, equipment_id, relationship_type, is_required)
VALUES ('13000005-0001-4001-8001-000000000005', '11000009-0001-4001-8001-000000000009', '1200000d-0001-4001-8001-00000000000d', 'SUPPORTS', 'Y');

-- ---------------------------------------------------------------------------
-- Additional aircraft
-- ---------------------------------------------------------------------------

INSERT INTO aircraft (
    aircraft_id, tail_number, aircraft_type_code, home_facility_id,
    operational_status, seating_capacity, max_takeoff_weight_lbs, metadata_json
) VALUES (
    '15000006-0001-4001-8001-000000000006', 'N832SW', 'B738',
    '10000009-0001-4001-8001-000000000009', 'IN_FLIGHT', 175, 174200,
    q'[{"operator":"Southwest Airlines","flightSeries":"SW"}]'
);

INSERT INTO aircraft (
    aircraft_id, tail_number, aircraft_type_code, home_facility_id,
    operational_status, seating_capacity, max_takeoff_weight_lbs, metadata_json
) VALUES (
    '15000007-0001-4001-8001-000000000007', 'N925FD', 'B77W',
    '1000000c-0001-4001-8001-00000000000c', 'IN_FLIGHT', 0, 775000,
    q'[{"operator":"FedEx Express","cargo":true}]'
);

INSERT INTO aircraft (
    aircraft_id, tail_number, aircraft_type_code, home_facility_id,
    operational_status, seating_capacity, max_takeoff_weight_lbs, metadata_json
) VALUES (
    '15000008-0001-4001-8001-000000000008', 'N612UX', 'E175',
    '1000000a-0001-4001-8001-00000000000a', 'AVAILABLE', 76, 85500,
    q'[{"operator":"United Express","regional":true}]'
);

-- ---------------------------------------------------------------------------
-- Maintenance — planned work at CID; Milwaukee ILS calibration
-- ---------------------------------------------------------------------------

INSERT INTO maintenance_activity (
    maintenance_activity_id, equipment_id, originating_facility_id,
    activity_type_code, maintenance_status, priority, title, description,
    scheduled_start_at, scheduled_end_at, assigned_user_id, estimated_duration_hrs, created_by
) VALUES (
    '16000003-0001-4001-8001-000000000003',
    '1200000b-0001-4001-8001-00000000000b',
    '1000000a-0001-4001-8001-00000000000a',
    'INSPECTION', 'SCHEDULED', 3,
    'CID ILS 13 Annual Flight Inspection Prep',
    'Coordinate FAA flight check window; verify localizer course width and glide path angle.',
    TIMESTAMP '2026-06-25 08:00:00', TIMESTAMP '2026-06-25 17:00:00',
    '20000002-0001-4001-8001-000000000002', 8,
    '20000002-0001-4001-8001-000000000002'
);

INSERT INTO maintenance_activity (
    maintenance_activity_id, equipment_id, originating_facility_id,
    activity_type_code, maintenance_status, priority, title, description,
    scheduled_start_at, actual_start_at, assigned_user_id, estimated_duration_hrs, created_by
) VALUES (
    '16000004-0001-4001-8001-000000000004',
    '1200000d-0001-4001-8001-00000000000d',
    '1000000c-0001-4001-8001-00000000000c',
    'CALIBRATION', 'DISPATCHED', 2,
    'MKE ILS 01L — Glide Slope Calibration Drift',
    'Glide slope angle trending 0.02° high; calibration crew en route from depot.',
    TIMESTAMP '2026-06-23 15:00:00', TIMESTAMP '2026-06-23 15:30:00',
    '20000002-0001-4001-8001-000000000002', 4,
    '20000002-0001-4001-8001-000000000002'
);

INSERT INTO facility_maintenance_activity (
    facility_maintenance_activity_id, facility_id, maintenance_activity_id, role_type
) VALUES (
    '17000003-0001-4001-8001-000000000003',
    '1000000c-0001-4001-8001-00000000000c',
    '16000004-0001-4001-8001-000000000004', 'SITE'
);

INSERT INTO facility_maintenance_activity (
    facility_maintenance_activity_id, facility_id, maintenance_activity_id, role_type
) VALUES (
    '17000004-0001-4001-8001-000000000004',
    '10000006-0001-4001-8001-000000000006',
    '16000004-0001-4001-8001-000000000004', 'DISPATCH_FROM'
);

INSERT INTO maintenance_log (
    maintenance_log_id, maintenance_activity_id, log_entry_type, message, logged_at, logged_by_user_id
) VALUES (
    '18000003-0001-4001-8001-000000000003',
    '16000004-0001-4001-8001-000000000004', 'DISPATCH',
    'Crew FBO-12 departed Urbandale depot with calibration kit CAL-ILS-02.',
    TIMESTAMP '2026-06-23 15:35:00', '20000002-0001-4001-8001-000000000002'
);

-- ---------------------------------------------------------------------------
-- Parts catalog expansion
-- ---------------------------------------------------------------------------

INSERT INTO equipment_part (
    equipment_part_id, part_number, name, description, equipment_type_code,
    unit_of_measure, stock_quantity, reorder_threshold, storage_facility_id
) VALUES (
    '1a000003-0001-4001-8001-000000000003',
    'ILS-LOC-ANT-420', 'ILS Localizer Antenna Array',
    'Thales ILS-420 localizer antenna assembly',
    'ILS', 'EA', 1, 1, '10000006-0001-4001-8001-000000000006'
);

INSERT INTO equipment_part (
    equipment_part_id, part_number, name, description, equipment_type_code,
    unit_of_measure, stock_quantity, reorder_threshold, storage_facility_id
) VALUES (
    '1a000004-0001-4001-8001-000000000004',
    'COM-VHF-TX-06', 'VHF Transmitter Module',
    'Park Air T6 VHF transmitter card',
    'COM_VHF', 'EA', 6, 2, '10000006-0001-4001-8001-000000000006'
);

INSERT INTO equipment_part_quote (
    equipment_part_quote_id, equipment_part_id, vendor_name,
    quoted_unit_cost, currency_code, lead_time_days, quote_status,
    quoted_at, valid_until
) VALUES (
    '1b000002-0001-4001-8001-000000000002',
    '1a000004-0001-4001-8001-000000000004',
    'Park Air Systems',
    12400.00, 'USD', 7, 'PENDING',
    TIMESTAMP '2026-06-22 09:00:00', TIMESTAMP '2026-09-22 09:00:00'
);

-- ---------------------------------------------------------------------------
-- Equipment alerts
-- ---------------------------------------------------------------------------

INSERT INTO equipment_alert (
    equipment_alert_id, equipment_id, alert_type, severity, title, message,
    raised_at, related_maintenance_activity_id
) VALUES (
    '1d000003-0001-4001-8001-000000000003',
    '1200000d-0001-4001-8001-00000000000d', 'DEGRADED', 'MEDIUM',
    'MKE ILS 01L Glide Slope Calibration Drift',
    'Flight check trend shows GS angle 0.02° above nominal. Cat I still within tolerance; calibration scheduled.',
    TIMESTAMP '2026-06-23 10:15:00',
    '16000004-0001-4001-8001-000000000004'
);

-- ---------------------------------------------------------------------------
-- Flight requests & operations — corridor expansion
-- ---------------------------------------------------------------------------

INSERT INTO flight_request (
    flight_request_id, request_number, origin_facility_id, destination_facility_id,
    requested_departure_at, requested_arrival_at, aircraft_id, passenger_count,
    request_status, requested_by_user_id, notes
) VALUES (
    '21000003-0001-4001-8001-000000000003',
    'FR-2026-0623-003',
    '10000009-0001-4001-8001-000000000009',
    '10000001-0001-4001-8001-000000000001',
    TIMESTAMP '2026-06-23 12:00:00', TIMESTAMP '2026-06-23 13:05:00',
    '15000006-0001-4001-8001-000000000006', 162,
    'APPROVED', '00000000-0000-0000-0000-000000000100',
    'SW2941 OMA→DSM — routine hop into affected airspace'
);

INSERT INTO flight_request (
    flight_request_id, request_number, origin_facility_id, destination_facility_id,
    requested_departure_at, requested_arrival_at, aircraft_id, passenger_count,
    request_status, requested_by_user_id, notes
) VALUES (
    '21000004-0001-4001-8001-000000000004',
    'FR-2026-0623-004',
    '1000000a-0001-4001-8001-00000000000a',
    '10000002-0001-4001-8001-000000000002',
    TIMESTAMP '2026-06-23 15:30:00', TIMESTAMP '2026-06-23 16:45:00',
    '15000008-0001-4001-8001-000000000008', 70,
    'SUBMITTED', '00000000-0000-0000-0000-000000000100',
    'UA512 CID→ORD evening regional'
);

INSERT INTO flight_request (
    flight_request_id, request_number, origin_facility_id, destination_facility_id,
    requested_departure_at, requested_arrival_at, aircraft_id, passenger_count,
    request_status, requested_by_user_id, notes
) VALUES (
    '21000005-0001-4001-8001-000000000005',
    'FR-2026-0623-005',
    '10000001-0001-4001-8001-000000000001',
    '10000001-0001-4001-8001-000000000001',
    TIMESTAMP '2026-06-23 14:30:00', TIMESTAMP '2026-06-23 15:00:00',
    '15000004-0001-4001-8001-000000000004', 2,
    'APPROVED', '20000001-0001-4001-8001-000000000001',
    'Local pattern work — Cedar Flight Academy (DSM traffic permitting)'
);

INSERT INTO flight_operation (
    flight_operation_id, flight_request_id, flight_number,
    origin_facility_id, destination_facility_id,
    departure_runway_id, arrival_runway_id,
    current_phase, operation_status,
    scheduled_departure_at, scheduled_arrival_at,
    actual_departure_at, aircraft_id, delay_minutes, metadata_json
) VALUES (
    '22000004-0001-4001-8001-000000000004',
    '21000003-0001-4001-8001-000000000003', 'SW2941',
    '10000009-0001-4001-8001-000000000009',
    '10000001-0001-4001-8001-000000000001',
    '11000006-0001-4001-8001-000000000006', '11000002-0001-4001-8001-000000000002',
    'ENROUTE', 'ACTIVE',
    TIMESTAMP '2026-06-23 12:00:00', TIMESTAMP '2026-06-23 13:05:00',
    TIMESTAMP '2026-06-23 12:08:00', '15000006-0001-4001-8001-000000000006', 0,
    q'[{"cruiseAltFt":34000,"route":"OMA DSM JVL"}]'
);

INSERT INTO flight_operation (
    flight_operation_id, flight_request_id, flight_number,
    origin_facility_id, destination_facility_id,
    departure_runway_id, current_phase, operation_status,
    scheduled_departure_at, scheduled_arrival_at, aircraft_id, delay_minutes, metadata_json
) VALUES (
    '22000005-0001-4001-8001-000000000005',
    NULL, 'DL447',
    '10000003-0001-4001-8001-000000000003',
    '10000002-0001-4001-8001-000000000002',
    '11000005-0001-4001-8001-000000000005', 'BOARDING', 'ACTIVE',
    TIMESTAMP '2026-06-23 15:00:00', TIMESTAMP '2026-06-23 16:20:00',
    '15000003-0001-4001-8001-000000000003', 0,
    q'[{"gate":"G12","boardingPct":72}]'
);

INSERT INTO flight_operation (
    flight_operation_id, flight_request_id, flight_number,
    origin_facility_id, destination_facility_id,
    departure_runway_id, current_phase, operation_status,
    scheduled_departure_at, scheduled_arrival_at, aircraft_id, metadata_json
) VALUES (
    '22000006-0001-4001-8001-000000000006',
    '21000004-0001-4001-8001-000000000004', 'UA512',
    '1000000a-0001-4001-8001-00000000000a',
    '10000002-0001-4001-8001-000000000002',
    '11000007-0001-4001-8001-000000000007', 'SCHEDULED', 'ACTIVE',
    TIMESTAMP '2026-06-23 15:30:00', TIMESTAMP '2026-06-23 16:45:00',
    '15000008-0001-4001-8001-000000000008',
    q'[{"gate":"B4","status":"AWAITING_CLEARANCE"}]'
);

INSERT INTO flight_operation (
    flight_operation_id, flight_request_id, flight_number,
    origin_facility_id, destination_facility_id,
    current_phase, operation_status,
    scheduled_departure_at, scheduled_arrival_at, aircraft_id, metadata_json
) VALUES (
    '22000007-0001-4001-8001-000000000007',
    NULL, 'FDX882',
    '1000000c-0001-4001-8001-00000000000c',
    '10000002-0001-4001-8001-000000000002',
    'ENROUTE', 'ACTIVE',
    TIMESTAMP '2026-06-23 11:30:00', TIMESTAMP '2026-06-23 12:15:00',
    '15000007-0001-4001-8001-000000000007',
    q'[{"cargoLbs":142000,"flightLevel":370}]'
);

INSERT INTO flight_operation (
    flight_operation_id, flight_request_id, flight_number,
    origin_facility_id, destination_facility_id,
    departure_runway_id, current_phase, operation_status,
    scheduled_departure_at, scheduled_arrival_at, aircraft_id, metadata_json
) VALUES (
    '22000008-0001-4001-8001-000000000008',
    '21000005-0001-4001-8001-000000000005', 'CFI101',
    '10000001-0001-4001-8001-000000000001',
    '10000001-0001-4001-8001-000000000001',
    '11000002-0001-4001-8001-000000000002', 'SCHEDULED', 'ACTIVE',
    TIMESTAMP '2026-06-23 14:30:00', TIMESTAMP '2026-06-23 15:00:00',
    '15000004-0001-4001-8001-000000000004',
    q'[{"flightType":"LOCAL_PATTERN","instructor":"CFI Martinez","student":"Private pilot checkout"}]'
);

-- Flight paths
INSERT INTO flight_path (flight_path_id, flight_operation_id, sequence_order, waypoint_name, latitude, longitude, altitude_ft, estimated_time_at)
VALUES ('23000008-0001-4001-8001-000000000008', '22000004-0001-4001-8001-000000000004', 1, 'OMA', 41.3032000, -95.8941000, 0, TIMESTAMP '2026-06-23 12:08:00');

INSERT INTO flight_path (flight_path_id, flight_operation_id, sequence_order, waypoint_name, latitude, longitude, altitude_ft, estimated_time_at)
VALUES ('23000009-0001-4001-8001-000000000009', '22000004-0001-4001-8001-000000000004', 2, 'JVL', 42.5000000, -89.0000000, 34000, TIMESTAMP '2026-06-23 12:35:00');

INSERT INTO flight_path (flight_path_id, flight_operation_id, sequence_order, waypoint_name, latitude, longitude, altitude_ft, estimated_time_at)
VALUES ('2300000a-0001-4001-8001-00000000000a', '22000004-0001-4001-8001-000000000004', 3, 'DSM', 41.5340000, -93.6631000, 0, TIMESTAMP '2026-06-23 13:05:00');

INSERT INTO flight_path (flight_path_id, flight_operation_id, sequence_order, waypoint_name, latitude, longitude, altitude_ft, estimated_time_at)
VALUES ('2300000b-0001-4001-8001-00000000000b', '22000007-0001-4001-8001-000000000007', 1, 'MKE', 42.9472000, -87.8966000, 0, TIMESTAMP '2026-06-23 11:35:00');

INSERT INTO flight_path (flight_path_id, flight_operation_id, sequence_order, waypoint_name, latitude, longitude, altitude_ft, estimated_time_at)
VALUES ('2300000c-0001-4001-8001-00000000000c', '22000007-0001-4001-8001-000000000007', 2, 'ORD', 41.9742000, -87.9073000, 0, TIMESTAMP '2026-06-23 12:15:00');

INSERT INTO flight_incident (
    flight_incident_id, flight_operation_id, incident_type_code, severity,
    title, description, occurred_at, related_facility_id
) VALUES (
    '25000002-0001-4001-8001-000000000002',
    '22000004-0001-4001-8001-000000000004', 'WEATHER_HOLD', 'LOW',
    'SW2941 Deviation — Convective Buildups West of DSM',
    'ZAU issued weather deviation 20 NM north of planned track to remain clear of building CU.',
    TIMESTAMP '2026-06-23 12:40:00',
    '10000001-0001-4001-8001-000000000001'
);

INSERT INTO flight_event (flight_event_id, flight_operation_id, event_type_code, occurred_at, sequence_number, payload_json)
VALUES ('26000006-0001-4001-8001-000000000006', '22000004-0001-4001-8001-000000000004', 'PHASE_CHANGED', TIMESTAMP '2026-06-23 12:08:00', 1, q'[{"from":"TAXI_OUT","to":"DEPARTED"}]');

INSERT INTO flight_event (flight_event_id, flight_operation_id, event_type_code, occurred_at, sequence_number, payload_json)
VALUES ('26000007-0001-4001-8001-000000000007', '22000004-0001-4001-8001-000000000004', 'WEATHER_IMPACT', TIMESTAMP '2026-06-23 12:40:00', 2, q'[{"action":"DEVIATION","direction":"NORTH","nm":20}]');

INSERT INTO flight_event (flight_event_id, flight_operation_id, event_type_code, occurred_at, sequence_number, payload_json)
VALUES ('26000008-0001-4001-8001-000000000008', '22000005-0001-4001-8001-000000000005', 'PHASE_CHANGED', TIMESTAMP '2026-06-23 14:45:00', 1, q'[{"from":"SCHEDULED","to":"BOARDING"}]');

INSERT INTO flight_event (flight_event_id, flight_operation_id, event_type_code, occurred_at, sequence_number, payload_json)
VALUES ('26000009-0001-4001-8001-000000000009', '22000007-0001-4001-8001-000000000007', 'PHASE_CHANGED', TIMESTAMP '2026-06-23 11:50:00', 1, q'[{"from":"DEPARTED","to":"ENROUTE"}]');

-- ---------------------------------------------------------------------------
-- Additional weather
-- ---------------------------------------------------------------------------

INSERT INTO weather_event (
    weather_event_id, weather_type_code, name, severity,
    started_at, ended_at, max_wind_kts, visibility_sm, ceiling_ft, precipitation_rate, metadata_json
) VALUES (
    '27000002-0001-4001-8001-000000000002',
    'FOG', 'MSP Morning Ground Fog', 'MEDIUM',
    TIMESTAMP '2026-06-23 10:00:00', TIMESTAMP '2026-06-23 14:30:00',
    8.0, 0.25, 200, 0.0,
    q'[{"ifr":"LIFR","burnOffExpected":"14:30Z"}]'
);

INSERT INTO weather_event (
    weather_event_id, weather_type_code, name, severity,
    started_at, ended_at, max_wind_kts, visibility_sm, metadata_json
) VALUES (
    '27000003-0001-4001-8001-000000000003',
    'WIND_SHEAR', 'ORD Low-Level Wind Shear Alert', 'HIGH',
    TIMESTAMP '2026-06-23 13:15:00', TIMESTAMP '2026-06-23 16:00:00',
    35.0, 6.0,
    q'[{"runwaysAffected":["10L","10C","28R"],"alertType":"LLWAS"}]'
);

INSERT INTO weather_event_path (
    weather_event_path_id, weather_event_id, sequence_order,
    latitude, longitude, radius_nm, effective_at, intensity_factor
) VALUES (
    '28000004-0001-4001-8001-000000000004', '27000002-0001-4001-8001-000000000002', 1,
    44.8848000, -93.2223000, 8.0, TIMESTAMP '2026-06-23 10:00:00', 1.0
);

INSERT INTO weather_event_path (
    weather_event_path_id, weather_event_id, sequence_order,
    latitude, longitude, radius_nm, effective_at, intensity_factor
) VALUES (
    '28000005-0001-4001-8001-000000000005', '27000003-0001-4001-8001-000000000003', 1,
    41.9742000, -87.9073000, 5.0, TIMESTAMP '2026-06-23 13:15:00', 1.0
);

INSERT INTO weather_event_alert (
    weather_event_alert_id, weather_event_id, facility_id, alert_level, message, issued_at, expires_at
) VALUES (
    '29000003-0001-4001-8001-000000000003',
    '27000002-0001-4001-8001-000000000002',
    '10000003-0001-4001-8001-000000000003', 'MEDIUM',
    'LIFR fog at MSP. RVR below Cat I mins on 12R. Expect ground delay program.',
    TIMESTAMP '2026-06-23 11:00:00', TIMESTAMP '2026-06-23 14:30:00'
);

INSERT INTO weather_event_alert (
    weather_event_alert_id, weather_event_id, facility_id, alert_level, message, issued_at
) VALUES (
    '29000004-0001-4001-8001-000000000004',
    '27000003-0001-4001-8001-000000000003',
    '10000002-0001-4001-8001-000000000002', 'HIGH',
    'LLWAS alert ORD: wind shear detected on final approach 10L. Use caution; alternate runways available.',
    TIMESTAMP '2026-06-23 13:20:00'
);

INSERT INTO weather_event_alert (
    weather_event_alert_id, weather_event_id, facility_id, flight_operation_id,
    alert_level, message, issued_at
) VALUES (
    '29000005-0001-4001-8001-000000000005',
    '27000003-0001-4001-8001-000000000003',
    NULL, '22000007-0001-4001-8001-000000000007',
    'MEDIUM',
    'FDX882: wind shear advisory on ORD arrival. Expect go-around or alternate spacing.',
    TIMESTAMP '2026-06-23 13:25:00'
);

-- ---------------------------------------------------------------------------
-- Geo lookups — remaining facilities + training context
-- ---------------------------------------------------------------------------

INSERT INTO simulation_geo_location_lookup (
    simulation_geo_location_id, render_context_id, facility_id,
    real_city, real_state_code, real_zip_code,
    virtual_latitude, virtual_longitude, virtual_elevation_ft, transform_json, notes
) VALUES (
    '2a000007-0001-4001-8001-000000000007',
    '00000000-0000-0000-0000-000000000010',
    '10000005-0001-4001-8001-000000000005',
    'Des Moines', 'IA', '50321',
    -0.0100000, -0.0100000, 0,
    q'[{"unityPosition":{"x":-1,"y":25,"z":-1},"scale":0.9,"mapLayer":"alpha-midwest","facilityType":"TRACON"}]',
    'DSM TRACON — co-located with airport in real world'
);

INSERT INTO simulation_geo_location_lookup (
    simulation_geo_location_id, render_context_id, facility_id,
    real_city, real_state_code, real_zip_code,
    virtual_latitude, virtual_longitude, virtual_elevation_ft, transform_json, notes
) VALUES (
    '2a000008-0001-4001-8001-000000000008',
    '00000000-0000-0000-0000-000000000010',
    '10000008-0001-4001-8001-000000000008',
    'Ames', 'IA', '50010',
    0.3500000, 0.4200000, 0,
    q'[{"unityPosition":{"x":42,"y":0,"z":35},"scale":1.0,"mapLayer":"alpha-midwest","facilityType":"NAVAID"}]',
    'Ames VORTAC — northeast of DSM hub'
);

INSERT INTO simulation_geo_location_lookup (
    simulation_geo_location_id, render_context_id, facility_id,
    real_city, real_state_code, real_zip_code,
    virtual_latitude, virtual_longitude, virtual_elevation_ft, transform_json, notes
) VALUES (
    '2a000009-0001-4001-8001-000000000009',
    '00000000-0000-0000-0000-000000000010',
    '10000009-0001-4001-8001-000000000009',
    'Omaha', 'NE', '68110',
    -1.2000000, -0.9500000, 0,
    q'[{"unityPosition":{"x":-95,"y":0,"z":-120},"scale":1.0,"mapLayer":"alpha-midwest"}]',
    'KOMA — west of DSM corridor'
);

INSERT INTO simulation_geo_location_lookup (
    simulation_geo_location_id, render_context_id, facility_id,
    real_city, real_state_code, real_zip_code,
    virtual_latitude, virtual_longitude, virtual_elevation_ft, transform_json, notes
) VALUES (
    '2a00000a-0001-4001-8001-00000000000a',
    '00000000-0000-0000-0000-000000000010',
    '1000000a-0001-4001-8001-00000000000a',
    'Cedar Rapids', 'IA', '52404',
    0.2200000, 0.1800000, 0,
    q'[{"unityPosition":{"x":18,"y":0,"z":22},"scale":1.0,"mapLayer":"alpha-midwest"}]',
    'KCID — diversion alternate for DSM'
);

INSERT INTO simulation_geo_location_lookup (
    simulation_geo_location_id, render_context_id, facility_id,
    real_city, real_state_code, real_zip_code,
    virtual_latitude, virtual_longitude, virtual_elevation_ft, transform_json, notes
) VALUES (
    '2a00000b-0001-4001-8001-00000000000b',
    '00000000-0000-0000-0000-000000000010',
    '1000000b-0001-4001-8001-00000000000b',
    'Moline', 'IL', '61265',
    0.1500000, 1.1000000, 0,
    q'[{"unityPosition":{"x":110,"y":0,"z":15},"scale":1.0,"mapLayer":"alpha-midwest"}]',
    'KMLI — Mississippi River crossing'
);

INSERT INTO simulation_geo_location_lookup (
    simulation_geo_location_id, render_context_id, facility_id,
    real_city, real_state_code, real_zip_code,
    virtual_latitude, virtual_longitude, virtual_elevation_ft, transform_json, notes
) VALUES (
    '2a00000c-0001-4001-8001-00000000000c',
    '00000000-0000-0000-0000-000000000010',
    '1000000c-0001-4001-8001-00000000000c',
    'Milwaukee', 'WI', '53207',
    1.5500000, 2.1000000, 0,
    q'[{"unityPosition":{"x":210,"y":0,"z":155},"scale":1.0,"mapLayer":"alpha-midwest"}]',
    'KMKE — Lake Michigan shore'
);

INSERT INTO simulation_geo_location_lookup (
    simulation_geo_location_id, render_context_id, facility_id,
    real_city, real_state_code, real_zip_code,
    virtual_latitude, virtual_longitude, virtual_elevation_ft, transform_json, notes
) VALUES (
    '2a00000d-0001-4001-8001-00000000000d',
    '00000000-0000-0000-0000-000000000010',
    '1000000d-0001-4001-8001-00000000000d',
    'Farmington', 'MN', '55024',
    3.2000000, -0.2000000, 0,
    q'[{"unityPosition":{"x":-20,"y":60,"z":320},"scale":0.7,"mapLayer":"alpha-midwest","facilityType":"ARTCC"}]',
    'Minneapolis Center'
);

-- Training context — scaled layout for classroom demos
INSERT INTO simulation_geo_location_lookup (
    simulation_geo_location_id, render_context_id, facility_id,
    real_city, real_state_code, real_zip_code,
    virtual_latitude, virtual_longitude, virtual_elevation_ft, transform_json, notes
) VALUES (
    '2a000100-0001-4001-8001-000000000100',
    '00000000-0000-0000-0000-000000000020',
    '10000001-0001-4001-8001-000000000001',
    'Des Moines', 'IA', '50321',
    0.0000000, 0.0000000, 0,
    q'[{"unityPosition":{"x":0,"y":0,"z":0},"scale":2.0,"mapLayer":"training-sandbox"}]',
    'Training sandbox — DSM at origin, 2x scale'
);

INSERT INTO simulation_geo_location_lookup (
    simulation_geo_location_id, render_context_id, facility_id,
    real_city, real_state_code, real_zip_code,
    virtual_latitude, virtual_longitude, virtual_elevation_ft, transform_json, notes
) VALUES (
    '2a000101-0001-4001-8001-000000000101',
    '00000000-0000-0000-0000-000000000020',
    '10000002-0001-4001-8001-000000000002',
    'Chicago', 'IL', '60666',
    0.0000000, 5.7000000, 0,
    q'[{"unityPosition":{"x":570,"y":0,"z":0},"scale":2.0,"mapLayer":"training-sandbox"}]',
    'Training sandbox — ORD on east axis'
);

-- ---------------------------------------------------------------------------
-- Second snapshot
-- ---------------------------------------------------------------------------

INSERT INTO simulation_snapshot (
    simulation_snapshot_id, snapshot_label, render_context_id,
    sim_time_utc, clock_mode_code, time_scale, run_status_code, step_sequence,
    state_json, created_by_user_id
) VALUES (
    '2b000002-0001-4001-8001-000000000002',
    'Corridor Expanded — Thunderstorm + Fog + Wind Shear',
    '00000000-0000-0000-0000-000000000010',
    TIMESTAMP '2026-06-23 14:00:00', 'REALTIME', 1, 'PAUSED', 0,
    q'[{"scenario":"upper-midwest-corridor-extended","facilities":13,"activeFlights":8,"weatherEvents":3,"maintenanceActivities":4,"notes":"101 extended seed applied"}]',
    '20000001-0001-4001-8001-000000000001'
);

COMMIT;
