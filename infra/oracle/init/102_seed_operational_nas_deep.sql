-- =============================================================================
-- NAS Simulation — deep operational seed (102)
-- Extends 100 + 101 — maintenance trails, path approvals, incident history,
-- parts logistics, user scoping, and a third snapshot for replay demos.
-- =============================================================================

ALTER SESSION SET CONTAINER = FREEPDB1;
ALTER SESSION SET CURRENT_SCHEMA = nas_sim;

-- ---------------------------------------------------------------------------
-- Maintenance — progress logs and interim reports
-- ---------------------------------------------------------------------------

INSERT INTO maintenance_log (
    maintenance_log_id, maintenance_activity_id, log_entry_type, message, logged_at, logged_by_user_id
) VALUES (
    '18000004-0001-4001-8001-000000000004',
    '16000001-0001-4001-8001-000000000001', 'STATUS_CHANGE',
    'GS module ILS-GS-739 received at DSM; bench test passed. Crew commencing swap on glide slope cabinet.',
    TIMESTAMP '2026-06-23 14:45:00', '20000002-0001-4001-8001-000000000002'
);

INSERT INTO maintenance_log (
    maintenance_log_id, maintenance_activity_id, log_entry_type, message, logged_at, logged_by_user_id,
    metadata_json
) VALUES (
    '18000005-0001-4001-8001-000000000005',
    '16000001-0001-4001-8001-000000000001', 'PART_USED',
    'Installed replacement glide slope transmitter module ILS-GS-739 (SN GS-739-8842).',
    TIMESTAMP '2026-06-23 15:10:00', '20000002-0001-4001-8001-000000000002',
    q'[{"partNumber":"ILS-GS-739","serialNumber":"GS-739-8842"}]'
);

INSERT INTO maintenance_log (
    maintenance_log_id, maintenance_activity_id, log_entry_type, message, logged_at, logged_by_user_id
) VALUES (
    '18000006-0001-4001-8001-000000000006',
    '16000003-0001-4001-8001-000000000003', 'NOTE',
    'FAA flight check slot confirmed 25 Jun 08:00–12:00 local. NOTAM draft prepared for 24h ILS outage window if needed.',
    TIMESTAMP '2026-06-23 14:00:00', '20000002-0001-4001-8001-000000000002'
);

INSERT INTO maintenance_log (
    maintenance_log_id, maintenance_activity_id, log_entry_type, message, logged_at, logged_by_user_id
) VALUES (
    '18000007-0001-4001-8001-000000000007',
    '16000004-0001-4001-8001-000000000004', 'STATUS_CHANGE',
    'Calibration crew on site MKE RWY 01L. Localizer course width within 0.01° of nominal.',
    TIMESTAMP '2026-06-23 16:05:00', '20000002-0001-4001-8001-000000000002'
);

INSERT INTO facility_maintenance_activity (
    facility_maintenance_activity_id, facility_id, maintenance_activity_id, role_type
) VALUES (
    '17000005-0001-4001-8001-000000000005',
    '1000000a-0001-4001-8001-00000000000a',
    '16000003-0001-4001-8001-000000000003', 'SITE'
);

-- ---------------------------------------------------------------------------
-- Parts — calibration kit catalog, quote acceptance, depot order
-- ---------------------------------------------------------------------------

INSERT INTO equipment_part (
    equipment_part_id, part_number, name, description, equipment_type_code,
    unit_of_measure, stock_quantity, reorder_threshold, storage_facility_id
) VALUES (
    '1a000005-0001-4001-8001-000000000005',
    'CAL-ILS-02', 'ILS Calibration Kit — Field Portable',
    'Portable ILS glide slope / localizer alignment kit for Thales ILS-420',
    'ILS', 'KIT', 3, 1, '10000006-0001-4001-8001-000000000006'
);

UPDATE equipment_part_quote
SET quote_status = 'ACCEPTED'
WHERE equipment_part_quote_id = '1b000002-0001-4001-8001-000000000002';

INSERT INTO equipment_part_order (
    equipment_part_order_id, equipment_part_id, equipment_part_quote_id,
    receiving_facility_id, maintenance_activity_id,
    quantity_ordered, unit_cost, order_status,
    ordered_at, expected_delivery_at, received_at, notes
) VALUES (
    '1c000002-0001-4001-8001-000000000002',
    '1a000005-0001-4001-8001-000000000005',
    NULL,
    '1000000c-0001-4001-8001-00000000000c',
    '16000004-0001-4001-8001-000000000004',
    1, 0.00, 'RECEIVED',
    TIMESTAMP '2026-06-23 15:00:00', TIMESTAMP '2026-06-23 15:30:00',
    TIMESTAMP '2026-06-23 15:28:00',
    'Depot stock issue — CAL-ILS-02 kit for MKE glide slope calibration'
);

INSERT INTO equipment_part_order (
    equipment_part_order_id, equipment_part_id, equipment_part_quote_id,
    receiving_facility_id, maintenance_activity_id,
    quantity_ordered, unit_cost, order_status,
    ordered_at, expected_delivery_at, notes
) VALUES (
    '1c000003-0001-4001-8001-000000000003',
    '1a000004-0001-4001-8001-000000000004',
    '1b000002-0001-4001-8001-000000000002',
    '10000005-0001-4001-8001-000000000005',
    NULL,
    2, 12400.00, 'ORDERED',
    TIMESTAMP '2026-06-23 13:00:00', TIMESTAMP '2026-06-24 09:00:00',
    'Spare VHF transmitter cards for DSM TRACON approach backup net'
);

-- ---------------------------------------------------------------------------
-- Equipment dependencies & alerts
-- ---------------------------------------------------------------------------

INSERT INTO equipment_dependency (
    equipment_dependency_id, parent_equipment_id, child_equipment_id, dependency_type
) VALUES (
    '14000004-0001-4001-8001-000000000004',
    '12000006-0001-4001-8001-000000000006',
    '1200000e-0001-4001-8001-00000000000e',
    'BACKUP_FOR'
);

INSERT INTO equipment_dependency (
    equipment_dependency_id, parent_equipment_id, child_equipment_id, dependency_type
) VALUES (
    '14000005-0001-4001-8001-000000000005',
    '1200000b-0001-4001-8001-00000000000b',
    '12000001-0001-4001-8001-000000000001',
    'ALTERNATE_FOR'
);

INSERT INTO equipment_alert (
    equipment_alert_id, equipment_id, alert_type, severity, title, message,
    raised_at, acknowledged_at, acknowledged_by_user_id
) VALUES (
    '1d000004-0001-4001-8001-000000000004',
    '1200000e-0001-4001-8001-00000000000e', 'INFO', 'LOW',
    'DSM Approach UHF Backup Net — Standby Active',
    'Primary VHF approach frequency experiencing intermittent interference. UHF backup net activated per SOP.',
    TIMESTAMP '2026-06-23 13:55:00',
    TIMESTAMP '2026-06-23 14:02:00',
    '20000001-0001-4001-8001-000000000001'
);

-- ---------------------------------------------------------------------------
-- User permissions — facility-scoped grants (DSM maint scope is in 100)
-- ---------------------------------------------------------------------------

INSERT INTO user_permissions (
    user_permission_id, user_id, role_id, permission_code, facility_scope_id, granted_by_user_id
) VALUES (
    '30000011-0001-4001-8001-000000000011',
    '20000002-0001-4001-8001-000000000002',
    '00000000-0000-0000-0000-000000000003',
    'maintenance.manage',
    '1000000a-0001-4001-8001-00000000000a',
    '20000001-0001-4001-8001-000000000001'
);

INSERT INTO user_permissions (
    user_permission_id, user_id, role_id, permission_code, facility_scope_id, granted_by_user_id
) VALUES (
    '30000012-0001-4001-8001-000000000012',
    '20000003-0001-4001-8001-000000000003',
    '00000000-0000-0000-0000-000000000004',
    'flight.view',
    NULL,
    '20000001-0001-4001-8001-000000000001'
);

-- ---------------------------------------------------------------------------
-- Flight path requests — ATC reroutes and alternates
-- ---------------------------------------------------------------------------

UPDATE flight_path_request
SET request_status = 'APPROVED',
    reviewed_by_user_id = '20000001-0001-4001-8001-000000000001',
    resolved_at = TIMESTAMP '2026-06-23 14:10:00',
    resolution_notes = 'Approved RNAV RWY 05 approach. ILS 13 remains unavailable.'
WHERE flight_path_request_id = '24000001-0001-4001-8001-000000000001';

INSERT INTO flight_path_request (
    flight_path_request_id, flight_operation_id, request_reason, request_status,
    requested_path_json, requested_by_user_id, reviewed_by_user_id,
    requested_at, resolved_at, resolution_notes
) VALUES (
    '24000002-0001-4001-8001-000000000002',
    '22000002-0001-4001-8001-000000000002',
    'Request diversion to KCID — DSM ILS outage + convective weather on final',
    'APPROVED',
    q'[{"alternate":"KCID","waypoints":[{"name":"DSM-HOLD","lat":41.65,"lon":-93.90,"altFt":5000},{"name":"CID","lat":41.89,"lon":-91.71,"altFt":0}]}]',
    '00000000-0000-0000-0000-000000000100',
    '20000001-0001-4001-8001-000000000001',
    TIMESTAMP '2026-06-23 14:05:00',
    TIMESTAMP '2026-06-23 14:12:00',
    'Diversion approved to Cedar Rapids. Fuel sufficient. Ground handlers notified.'
);

INSERT INTO flight_path_request (
    flight_path_request_id, flight_operation_id, request_reason, request_status,
    requested_path_json, requested_by_user_id, requested_at
) VALUES (
    '24000003-0001-4001-8001-000000000003',
    '22000007-0001-4001-8001-000000000007',
    'Request hold at OSH due to ORD wind shear — cargo time-critical',
    'PENDING',
    q'[{"holdFix":"OSH","holdMinutes":20,"reason":"LLWAS_ORD"}]',
    '00000000-0000-0000-0000-000000000100',
    TIMESTAMP '2026-06-23 13:30:00'
);

INSERT INTO flight_path_request (
    flight_path_request_id, flight_operation_id, request_reason, request_status,
    requested_path_json, requested_by_user_id, reviewed_by_user_id,
    requested_at, resolved_at, resolution_notes
) VALUES (
    '24000004-0001-4001-8001-000000000004',
    '22000001-0001-4001-8001-000000000001',
    'Request departure clearance RWY 31 — RWY 13 ILS unavailable, winds favor 31',
    'APPROVED',
    q'[{"departureRunway":"31","sid":"DSM7","notes":"RNAV departure only"}]',
    '20000001-0001-4001-8001-000000000001',
    '20000001-0001-4001-8001-000000000001',
    TIMESTAMP '2026-06-23 14:20:00',
    TIMESTAMP '2026-06-23 14:25:00',
    'Cleared RNAV departure RWY 31. Expect 15-min EDCT due to ZAU weather reroutes.'
);

-- ---------------------------------------------------------------------------
-- Flight paths — completed history and planned legs
-- ---------------------------------------------------------------------------

INSERT INTO flight_path (flight_path_id, flight_operation_id, sequence_order, waypoint_name, latitude, longitude, altitude_ft, estimated_time_at)
VALUES ('2300000d-0001-4001-8001-00000000000d', '22000003-0001-4001-8001-000000000003', 1, 'ORD', 41.9742000, -87.9073000, 0, TIMESTAMP '2026-06-23 10:05:00');

INSERT INTO flight_path (flight_path_id, flight_operation_id, sequence_order, waypoint_name, latitude, longitude, altitude_ft, estimated_time_at)
VALUES ('2300000e-0001-4001-8001-00000000000e', '22000003-0001-4001-8001-000000000003', 2, 'MSN', 43.1400000, -89.3400000, 32000, TIMESTAMP '2026-06-23 10:45:00');

INSERT INTO flight_path (flight_path_id, flight_operation_id, sequence_order, waypoint_name, latitude, longitude, altitude_ft, estimated_time_at)
VALUES ('2300000f-0001-4001-8001-00000000000f', '22000003-0001-4001-8001-000000000003', 3, 'MSP', 44.8848000, -93.2223000, 0, TIMESTAMP '2026-06-23 11:40:00');

INSERT INTO flight_path (flight_path_id, flight_operation_id, sequence_order, waypoint_name, latitude, longitude, altitude_ft, estimated_time_at)
VALUES ('23000010-0001-4001-8001-000000000010', '22000005-0001-4001-8001-000000000005', 1, 'MSP', 44.8848000, -93.2223000, 0, TIMESTAMP '2026-06-23 15:00:00');

INSERT INTO flight_path (flight_path_id, flight_operation_id, sequence_order, waypoint_name, latitude, longitude, altitude_ft, estimated_time_at)
VALUES ('23000011-0001-4001-8001-000000000011', '22000005-0001-4001-8001-000000000005', 2, 'ORD', 41.9742000, -87.9073000, 0, TIMESTAMP '2026-06-23 16:20:00');

INSERT INTO flight_path (flight_path_id, flight_operation_id, sequence_order, waypoint_name, latitude, longitude, altitude_ft, estimated_time_at)
VALUES ('23000012-0001-4001-8001-000000000012', '22000006-0001-4001-8001-000000000006', 1, 'CID', 41.8867000, -91.7108000, 0, TIMESTAMP '2026-06-23 15:30:00');

INSERT INTO flight_path (flight_path_id, flight_operation_id, sequence_order, waypoint_name, latitude, longitude, altitude_ft, estimated_time_at)
VALUES ('23000013-0001-4001-8001-000000000013', '22000006-0001-4001-8001-000000000006', 2, 'IOW', 41.5330000, -91.7250000, 24000, TIMESTAMP '2026-06-23 15:55:00');

INSERT INTO flight_path (flight_path_id, flight_operation_id, sequence_order, waypoint_name, latitude, longitude, altitude_ft, estimated_time_at)
VALUES ('23000014-0001-4001-8001-000000000014', '22000006-0001-4001-8001-000000000006', 3, 'ORD', 41.9742000, -87.9073000, 0, TIMESTAMP '2026-06-23 16:45:00');

INSERT INTO flight_path (flight_path_id, flight_operation_id, sequence_order, waypoint_name, latitude, longitude, altitude_ft, estimated_time_at, is_active)
VALUES ('23000015-0001-4001-8001-000000000015', '22000008-0001-4001-8001-000000000008', 1, 'DSM-PAT-1', 41.5600000, -93.6800000, 2500, TIMESTAMP '2026-06-23 14:35:00', 'Y');

INSERT INTO flight_path (flight_path_id, flight_operation_id, sequence_order, waypoint_name, latitude, longitude, altitude_ft, estimated_time_at, is_active)
VALUES ('23000016-0001-4001-8001-000000000016', '22000008-0001-4001-8001-000000000008', 2, 'DSM-PAT-2', 41.5100000, -93.6500000, 2500, TIMESTAMP '2026-06-23 14:42:00', 'Y');

INSERT INTO flight_path (flight_path_id, flight_operation_id, sequence_order, waypoint_name, latitude, longitude, altitude_ft, estimated_time_at, is_active)
VALUES ('23000017-0001-4001-8001-000000000017', '22000002-0001-4001-8001-000000000002', 4, 'CID-RWY13', 41.8867000, -91.7108000, 0, TIMESTAMP '2026-06-23 14:35:00', 'Y');

-- ---------------------------------------------------------------------------
-- Flight incidents
-- ---------------------------------------------------------------------------

INSERT INTO flight_incident (
    flight_incident_id, flight_operation_id, incident_type_code, severity,
    title, description, occurred_at, related_equipment_id, related_facility_id
) VALUES (
    '25000003-0001-4001-8001-000000000003',
    '22000001-0001-4001-8001-000000000001', 'EQUIPMENT_FAILURE', 'HIGH',
    'UA2847 Ground Delay — DSM ILS RWY 13 Outage',
    'Cat I ILS unavailable. Flight held at gate pending RNAV departure clearance on RWY 31.',
    TIMESTAMP '2026-06-23 11:45:00',
    '12000001-0001-4001-8001-000000000001',
    '10000001-0001-4001-8001-000000000001'
);

INSERT INTO flight_incident (
    flight_incident_id, flight_operation_id, incident_type_code, severity,
    title, description, occurred_at, related_facility_id, metadata_json
) VALUES (
    '25000004-0001-4001-8001-000000000004',
    '22000002-0001-4001-8001-000000000002', 'DIVERSION', 'MEDIUM',
    'DL1920 Diversion to Cedar Rapids',
    'Unable ILS 13 approach due to navaid outage and convective weather on final. Diverted to KCID.',
    TIMESTAMP '2026-06-23 14:15:00',
    '1000000a-0001-4001-8001-00000000000a',
    q'[{"originalDestination":"KDSM","fuelRemainingLbs":8200}]'
);

INSERT INTO flight_incident (
    flight_incident_id, flight_operation_id, incident_type_code, severity,
    title, description, occurred_at, related_facility_id
) VALUES (
    '25000005-0001-4001-8001-000000000005',
    '22000007-0001-4001-8001-000000000007', 'GO_AROUND', 'MEDIUM',
    'FDX882 Go-Around — ORD Wind Shear',
    'Wind shear alert on final 10L. Crew executed missed approach; holding at OSH pending vectors.',
    TIMESTAMP '2026-06-23 12:18:00',
    '10000002-0001-4001-8001-000000000002'
);

INSERT INTO flight_incident (
    flight_incident_id, flight_operation_id, incident_type_code, severity,
    title, description, occurred_at, related_facility_id
) VALUES (
    '25000006-0001-4001-8001-000000000006',
    '22000008-0001-4001-8001-000000000008', 'WEATHER_HOLD', 'LOW',
    'CFI101 Pattern Suspended — DSM Convective Activity',
    'Local pattern work suspended 30 min due to thunderstorm 15 NM west. Resumption expected 15:00Z.',
    TIMESTAMP '2026-06-23 14:10:00',
    '10000001-0001-4001-8001-000000000001'
);

-- ---------------------------------------------------------------------------
-- Flight events — extended event stream for replay / SignalR demos
-- ---------------------------------------------------------------------------

INSERT INTO flight_event (flight_event_id, flight_operation_id, event_type_code, occurred_at, sequence_number, payload_json, correlation_id)
VALUES ('2600000a-0001-4001-8001-00000000000a', '22000003-0001-4001-8001-000000000003', 'PHASE_CHANGED', TIMESTAMP '2026-06-23 10:05:00', 1, q'[{"from":"SCHEDULED","to":"DEPARTED"}]', 'corr-aa451-001');

INSERT INTO flight_event (flight_event_id, flight_operation_id, event_type_code, occurred_at, sequence_number, payload_json, correlation_id)
VALUES ('2600000b-0001-4001-8001-00000000000b', '22000003-0001-4001-8001-000000000003', 'PHASE_CHANGED', TIMESTAMP '2026-06-23 11:40:00', 2, q'[{"from":"ENROUTE","to":"COMPLETE"}]', 'corr-aa451-001');

INSERT INTO flight_event (flight_event_id, flight_operation_id, event_type_code, occurred_at, sequence_number, payload_json, correlation_id)
VALUES ('2600000c-0001-4001-8001-00000000000c', '22000001-0001-4001-8001-000000000001', 'RUNWAY_ASSIGNED', TIMESTAMP '2026-06-23 14:25:00', 4, q'[{"runway":"31","type":"RNAV_DEPARTURE"}]', 'corr-ua2847-001');

INSERT INTO flight_event (flight_event_id, flight_operation_id, event_type_code, occurred_at, sequence_number, payload_json, correlation_id)
VALUES ('2600000d-0001-4001-8001-00000000000d', '22000002-0001-4001-8001-000000000002', 'DIVERTED', TIMESTAMP '2026-06-23 14:15:00', 3, q'[{"from":"KDSM","to":"KCID","reason":"ILS_WEATHER"}]', 'corr-dl1920-001');

INSERT INTO flight_event (flight_event_id, flight_operation_id, event_type_code, occurred_at, sequence_number, payload_json, correlation_id)
VALUES ('2600000e-0001-4001-8001-00000000000e', '22000002-0001-4001-8001-000000000002', 'PATH_UPDATED', TIMESTAMP '2026-06-23 14:12:00', 4, q'[{"pathRequestId":"24000002-0001-4001-8001-000000000002"}]', 'corr-dl1920-001');

INSERT INTO flight_event (flight_event_id, flight_operation_id, event_type_code, occurred_at, sequence_number, payload_json)
VALUES ('2600000f-0001-4001-8001-00000000000f', '22000007-0001-4001-8001-000000000007', 'WEATHER_IMPACT', TIMESTAMP '2026-06-23 12:18:00', 2, q'[{"action":"GO_AROUND","runway":"10L"}]');

INSERT INTO flight_event (flight_event_id, flight_operation_id, event_type_code, occurred_at, sequence_number, payload_json)
VALUES ('26000010-0001-4001-8001-000000000010', '22000004-0001-4001-8001-000000000004', 'PHASE_CHANGED', TIMESTAMP '2026-06-23 13:02:00', 3, q'[{"from":"ENROUTE","to":"ARRIVED"}]');

INSERT INTO flight_event (flight_event_id, flight_operation_id, event_type_code, occurred_at, sequence_number, payload_json)
VALUES ('26000011-0001-4001-8001-000000000011', '22000008-0001-4001-8001-000000000008', 'WEATHER_IMPACT', TIMESTAMP '2026-06-23 14:10:00', 1, q'[{"action":"PATTERN_SUSPENDED","minutes":30}]');

-- ---------------------------------------------------------------------------
-- Weather — thunderstorm cell movement (extends event from 100)
-- ---------------------------------------------------------------------------

INSERT INTO weather_event_path (
    weather_event_path_id, weather_event_id, sequence_order,
    latitude, longitude, radius_nm, effective_at, intensity_factor
) VALUES (
    '28000006-0001-4001-8001-000000000006', '27000001-0001-4001-8001-000000000001', 4,
    41.7200000, -94.0500000, 22.0, TIMESTAMP '2026-06-23 14:30:00', 0.85
);

INSERT INTO weather_event_path (
    weather_event_path_id, weather_event_id, sequence_order,
    latitude, longitude, radius_nm, effective_at, intensity_factor
) VALUES (
    '28000007-0001-4001-8001-000000000007', '27000001-0001-4001-8001-000000000001', 5,
    41.7800000, -93.8200000, 18.0, TIMESTAMP '2026-06-23 15:00:00', 0.6
);

INSERT INTO weather_event_alert (
    weather_event_alert_id, weather_event_id, facility_id, alert_level, message, issued_at, expires_at
) VALUES (
    '29000006-0001-4001-8001-000000000006',
    '27000001-0001-4001-8001-000000000001',
    '10000009-0001-4001-8001-000000000009', 'MEDIUM',
    'Convective line approaching KOMA from west. Expect ground stops for eastbound departures after 15:30Z.',
    TIMESTAMP '2026-06-23 14:45:00', TIMESTAMP '2026-06-23 16:00:00'
);

-- ---------------------------------------------------------------------------
-- Third snapshot — full corridor stress test
-- ---------------------------------------------------------------------------

INSERT INTO simulation_snapshot (
    simulation_snapshot_id, snapshot_label, render_context_id,
    sim_time_utc, clock_mode_code, time_scale, run_status_code, step_sequence,
    state_json, created_by_user_id
) VALUES (
    '2b000003-0001-4001-8001-000000000003',
    'Corridor Deep — Diversion + Repair In Progress',
    '00000000-0000-0000-0000-000000000010',
    TIMESTAMP '2026-06-23 15:00:00', 'REALTIME', 1, 'PAUSED', 0,
    q'[{"scenario":"upper-midwest-corridor-deep","facilities":13,"activeFlights":8,"weatherEvents":3,"maintenanceActivities":4,"flightIncidents":6,"pathRequests":4,"notes":"102 deep seed — DL1920 diverted CID, ILS repair underway"}]',
    '20000001-0001-4001-8001-000000000001'
);

COMMIT;
