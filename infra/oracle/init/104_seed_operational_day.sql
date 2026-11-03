-- =============================================================================
-- NAS Simulation — full operational day (104)
-- Extends 100-103 with a 06:00-22:00 UTC timeline covering every workflow
-- state Unity needs: request approval/denial, inspections, maintenance
-- lifecycle, weather with/without path impact, and equipment outages.
-- =============================================================================

ALTER SESSION SET CONTAINER = FREEPDB1;
ALTER SESSION SET CURRENT_SCHEMA = nas_sim;

-- Operational day window (Unity clock sync anchor)
MERGE INTO global_configuration target
USING (
    SELECT 'simulation.operational_day_start_utc' AS config_key,
           '2026-06-23T06:00:00' AS config_value,
           'STRING' AS value_type,
           'Start of seeded operational day (UTC)' AS description
    FROM dual
) source ON (target.config_key = source.config_key)
WHEN MATCHED THEN UPDATE SET target.config_value = source.config_value
WHEN NOT MATCHED THEN INSERT (config_key, config_value, value_type, description)
    VALUES (source.config_key, source.config_value, source.value_type, source.description);

MERGE INTO global_configuration target
USING (
    SELECT 'simulation.operational_day_end_utc' AS config_key,
           '2026-06-23T22:00:00' AS config_value,
           'STRING' AS value_type,
           'End of seeded operational day (UTC)' AS description
    FROM dual
) source ON (target.config_key = source.config_key)
WHEN MATCHED THEN UPDATE SET target.config_value = source.config_value
WHEN NOT MATCHED THEN INSERT (config_key, config_value, value_type, description)
    VALUES (source.config_key, source.config_value, source.value_type, source.description);

MERGE INTO global_configuration target
USING (
    SELECT 'simulation.operational_day_label' AS config_key,
           'Upper Midwest Corridor — 23 Jun 2026' AS config_value,
           'STRING' AS value_type,
           'Display label for Unity scenario picker' AS description
    FROM dual
) source ON (target.config_key = source.config_key)
WHEN MATCHED THEN UPDATE SET target.config_value = source.config_value
WHEN NOT MATCHED THEN INSERT (config_key, config_value, value_type, description)
    VALUES (source.config_key, source.config_value, source.value_type, source.description);

-- ---------------------------------------------------------------------------
-- Morning maintenance — completed inspection + planned preventive work
-- ---------------------------------------------------------------------------

INSERT INTO maintenance_activity (
    maintenance_activity_id, equipment_id, originating_facility_id,
    activity_type_code, maintenance_status, priority, title, description,
    scheduled_start_at, scheduled_end_at, actual_start_at, actual_end_at,
    assigned_user_id, estimated_duration_hrs, created_by
) VALUES (
    '16000005-0001-4001-8001-000000000005',
    '12000002-0001-4001-8001-000000000002',
    '10000001-0001-4001-8001-000000000001',
    'PREVENTIVE', 'COMPLETED', 4,
    'DSM RWY 13 PAPI — Quarterly Lamp & Alignment Check',
    'Replaced two lamps on left PAPI unit. Alignment verified within 0.01 deg. Completed before ILS outage.',
    TIMESTAMP '2026-06-23 06:00:00', TIMESTAMP '2026-06-23 07:30:00',
    TIMESTAMP '2026-06-23 06:05:00', TIMESTAMP '2026-06-23 07:15:00',
    '20000002-0001-4001-8001-000000000002', 2,
    '20000002-0001-4001-8001-000000000002'
);

INSERT INTO maintenance_activity (
    maintenance_activity_id, equipment_id, originating_facility_id,
    activity_type_code, maintenance_status, priority, title, description,
    scheduled_start_at, scheduled_end_at, assigned_user_id, estimated_duration_hrs, created_by
) VALUES (
    '16000006-0001-4001-8001-000000000006',
    '12000008-0001-4001-8001-000000000008',
    '10000002-0001-4001-8001-000000000002',
    'INSPECTION', 'PLANNED', 3,
    'ORD ILS 10L — Six-Month Flight Inspection Window',
    'FAA flight check scheduled 24 Jun. Ground prep and monitor alignment today if time permits.',
    TIMESTAMP '2026-06-23 08:00:00', TIMESTAMP '2026-06-23 12:00:00',
    '20000002-0001-4001-8001-000000000002', 4,
    '20000001-0001-4001-8001-000000000001'
);

INSERT INTO maintenance_activity (
    maintenance_activity_id, equipment_id, originating_facility_id,
    activity_type_code, maintenance_status, priority, title, description,
    scheduled_start_at, scheduled_end_at, assigned_user_id, estimated_duration_hrs, created_by
) VALUES (
    '16000007-0001-4001-8001-000000000007',
    '1200000c-0001-4001-8001-00000000000c',
    '10000009-0001-4001-8001-000000000009',
    'INSPECTION', 'SCHEDULED', 3,
    'KOMA ASR-8 — Annual Surveillance Radar Inspection',
    'Magnetron output and rotation rate check. No impact to arrivals expected.',
    TIMESTAMP '2026-06-23 16:00:00', TIMESTAMP '2026-06-23 20:00:00',
    '20000002-0001-4001-8001-000000000002', 6,
    '20000002-0001-4001-8001-000000000002'
);

INSERT INTO maintenance_activity (
    maintenance_activity_id, equipment_id, originating_facility_id,
    activity_type_code, maintenance_status, priority, title, description,
    scheduled_start_at, assigned_user_id, estimated_duration_hrs, created_by
) VALUES (
    '16000008-0001-4001-8001-000000000008',
    '12000009-0001-4001-8001-000000000009',
    '10000004-0001-4001-8001-000000000004',
    'PREVENTIVE', 'PLANNED', 4,
    'ZAU Sector 42 VHF — Firmware Update Window',
    'Coordinate with Chicago Center for 15-min comms switch to backup during firmware push.',
    TIMESTAMP '2026-06-23 21:00:00',
    '20000002-0001-4001-8001-000000000002', 1,
    '20000001-0001-4001-8001-000000000001'
);

INSERT INTO maintenance_log (
    maintenance_log_id, maintenance_activity_id, log_entry_type, message, logged_at, logged_by_user_id
) VALUES (
    '18000008-0001-4001-8001-000000000008',
    '16000005-0001-4001-8001-000000000005', 'STATUS_CHANGE',
    'PAPI inspection completed. All units within tolerance.',
    TIMESTAMP '2026-06-23 07:15:00', '20000002-0001-4001-8001-000000000002'
);

INSERT INTO maintenance_report (
    maintenance_report_id, maintenance_activity_id, findings, actions_taken,
    parts_consumed_json, equipment_restored, completed_at, completed_by_user_id
) VALUES (
    '19000003-0001-4001-8001-000000000003',
    '16000005-0001-4001-8001-000000000005',
    'Left PAPI unit lamps at 78% nominal intensity. Alignment 2.98 deg (nominal 3.0).',
    'Replaced 2 lamps. Re-aligned left unit. Verified from runway roll.',
    q'[{"partNumber":"PAPI-LAMP-HI","quantity":2}]',
    'Y',
    TIMESTAMP '2026-06-23 07:15:00',
    '20000002-0001-4001-8001-000000000002'
);

-- ---------------------------------------------------------------------------
-- Flight requests — full approval lifecycle
-- ---------------------------------------------------------------------------

INSERT INTO flight_request (
    flight_request_id, request_number, origin_facility_id, destination_facility_id,
    requested_departure_at, requested_arrival_at, aircraft_id, passenger_count,
    request_status, requested_by_user_id, notes, metadata_json
) VALUES (
    '21000006-0001-4001-8001-000000000006',
    'FR-2026-0623-006',
    '10000003-0001-4001-8001-000000000003',
    '10000002-0001-4001-8001-000000000002',
    TIMESTAMP '2026-06-23 08:30:00', TIMESTAMP '2026-06-23 09:45:00',
    '15000002-0001-4001-8001-000000000002', 142,
    'SUBMITTED', '00000000-0000-0000-0000-000000000100',
    'AA892 MSP-ORD morning bank — awaiting slot confirmation',
    q'[{"priority":"NORMAL","slotRequest":"08:30Z","submittedAt":"2026-06-23T06:15:00Z"}]'
);

INSERT INTO flight_request (
    flight_request_id, request_number, origin_facility_id, destination_facility_id,
    requested_departure_at, requested_arrival_at, aircraft_id, passenger_count,
    request_status, requested_by_user_id, notes, metadata_json
) VALUES (
    '21000007-0001-4001-8001-000000000007',
    'FR-2026-0623-007',
    '10000009-0001-4001-8001-000000000009',
    '10000002-0001-4001-8001-000000000002',
    TIMESTAMP '2026-06-23 09:15:00', TIMESTAMP '2026-06-23 10:20:00',
    '15000006-0001-4001-8001-000000000006', 165,
    'SUBMITTED', '00000000-0000-0000-0000-000000000100',
    'WN4102 OMA-ORD — pending dispatcher review',
    q'[{"priority":"NORMAL","submittedAt":"2026-06-23T06:45:00Z"}]'
);

INSERT INTO flight_request (
    flight_request_id, request_number, origin_facility_id, destination_facility_id,
    requested_departure_at, requested_arrival_at, aircraft_id, passenger_count,
    request_status, requested_by_user_id, notes, metadata_json
) VALUES (
    '21000008-0001-4001-8001-000000000008',
    'FR-2026-0623-008',
    '10000001-0001-4001-8001-000000000001',
    '10000003-0001-4001-8001-000000000003',
    TIMESTAMP '2026-06-23 07:30:00', TIMESTAMP '2026-06-23 08:35:00',
    '15000003-0001-4001-8001-000000000003', 68,
    'APPROVED', '20000001-0001-4001-8001-000000000001',
    'DL1055 DSM-MSP morning commuter — approved 06:50Z',
    q'[{"priority":"NORMAL","approvedAt":"2026-06-23T06:50:00Z","approvedBy":"nas.admin"}]'
);

INSERT INTO flight_request (
    flight_request_id, request_number, origin_facility_id, destination_facility_id,
    requested_departure_at, requested_arrival_at, aircraft_id, passenger_count,
    request_status, requested_by_user_id, notes, metadata_json
) VALUES (
    '21000009-0001-4001-8001-000000000009',
    'FR-2026-0623-009',
    '10000002-0001-4001-8001-000000000002',
    '10000001-0001-4001-8001-000000000001',
    TIMESTAMP '2026-06-23 10:00:00', TIMESTAMP '2026-06-23 11:05:00',
    '15000001-0001-4001-8001-000000000001', 155,
    'REJECTED', '20000001-0001-4001-8001-000000000001',
    'UA991 ORD-DSM denied — DSM ILS outage, no Cat I arrival until further notice',
    q'[{"priority":"HIGH","rejectedAt":"2026-06-23T07:10:00Z","rejectedBy":"nas.admin","reason":"NAVAID_OUTAGE"}]'
);

INSERT INTO flight_request (
    flight_request_id, request_number, origin_facility_id, destination_facility_id,
    requested_departure_at, requested_arrival_at, aircraft_id, passenger_count,
    request_status, requested_by_user_id, notes, metadata_json
) VALUES (
    '2100000a-0001-4001-8001-00000000000a',
    'FR-2026-0623-010',
    '1000000c-0001-4001-8001-00000000000c',
    '10000002-0001-4001-8001-000000000002',
    TIMESTAMP '2026-06-23 18:00:00', TIMESTAMP '2026-06-23 21:30:00',
    '15000006-0001-4001-8001-000000000006', 178,
    'CANCELLED', '00000000-0000-0000-0000-000000000100',
    'NK882 MKE-ORD cancelled — crew duty time exceeded after ORD wind shear delays',
    q'[{"cancelledAt":"2026-06-23T16:30:00Z","reason":"CREW_TIMEOUT"}]'
);

INSERT INTO flight_request (
    flight_request_id, request_number, origin_facility_id, destination_facility_id,
    requested_departure_at, requested_arrival_at, aircraft_id, passenger_count,
    request_status, requested_by_user_id, notes, metadata_json
) VALUES (
    '2100000b-0001-4001-8001-00000000000b',
    'FR-2026-0623-011',
    '1000000c-0001-4001-8001-00000000000c',
    '10000002-0001-4001-8001-000000000002',
    TIMESTAMP '2026-06-23 20:30:00', TIMESTAMP '2026-06-23 21:15:00',
    '15000007-0001-4001-8001-000000000007', 0,
    'APPROVED', '20000001-0001-4001-8001-000000000001',
    'FX991 MKE-ORD evening cargo positioning',
    q'[{"priority":"NORMAL","cargoLbs":98000,"approvedAt":"2026-06-23T14:00:00Z"}]'
);

-- ---------------------------------------------------------------------------
-- Flight operations — morning through evening schedule
-- ---------------------------------------------------------------------------

INSERT INTO flight_operation (
    flight_operation_id, flight_request_id, flight_number,
    origin_facility_id, destination_facility_id,
    departure_runway_id, arrival_runway_id,
    current_phase, operation_status,
    scheduled_departure_at, scheduled_arrival_at,
    actual_departure_at, actual_arrival_at,
    aircraft_id, delay_minutes, metadata_json
) VALUES (
    '22000009-0001-4001-8001-000000000009',
    '21000008-0001-4001-8001-000000000008', 'DL1055',
    '10000001-0001-4001-8001-000000000001',
    '10000003-0001-4001-8001-000000000003',
    '11000002-0001-4001-8001-000000000002', '11000005-0001-4001-8001-000000000005',
    'COMPLETE', 'COMPLETED',
    TIMESTAMP '2026-06-23 07:30:00', TIMESTAMP '2026-06-23 08:35:00',
    TIMESTAMP '2026-06-23 07:32:00', TIMESTAMP '2026-06-23 08:38:00',
    '15000003-0001-4001-8001-000000000003', 2,
    q'[{"onTime":true,"departedRunway":"05/23","morningCommuter":true}]'
);

INSERT INTO flight_operation (
    flight_operation_id, flight_request_id, flight_number,
    origin_facility_id, destination_facility_id,
    departure_runway_id, arrival_runway_id,
    current_phase, operation_status,
    scheduled_departure_at, scheduled_arrival_at, aircraft_id, metadata_json
) VALUES (
    '2200000a-0001-4001-8001-00000000000a',
    '21000006-0001-4001-8001-000000000006', 'AA892',
    '10000003-0001-4001-8001-000000000003',
    '10000002-0001-4001-8001-000000000002',
    '11000005-0001-4001-8001-000000000005', '11000003-0001-4001-8001-000000000003',
    'SCHEDULED', 'ACTIVE',
    TIMESTAMP '2026-06-23 08:30:00', TIMESTAMP '2026-06-23 09:45:00',
    '15000002-0001-4001-8001-000000000002',
    q'[{"gate":"G18","awaitingRequestApproval":true}]'
);

INSERT INTO flight_operation (
    flight_operation_id, flight_request_id, flight_number,
    origin_facility_id, destination_facility_id,
    current_phase, operation_status,
    scheduled_departure_at, scheduled_arrival_at,
    actual_departure_at, aircraft_id, metadata_json
) VALUES (
    '2200000b-0001-4001-8001-00000000000b',
    NULL, 'NK554',
    '10000001-0001-4001-8001-000000000001',
    '10000002-0001-4001-8001-000000000002',
    'ENROUTE', 'ACTIVE',
    TIMESTAMP '2026-06-23 11:00:00', TIMESTAMP '2026-06-23 12:10:00',
    TIMESTAMP '2026-06-23 11:05:00', '15000006-0001-4001-8001-000000000006',
    q'[{"weatherImpact":false,"route":"north of convective line","cruiseAltFt":36000,"note":"Clear of Iowa cells"}]'
);

INSERT INTO flight_operation (
    flight_operation_id, flight_request_id, flight_number,
    origin_facility_id, destination_facility_id,
    departure_runway_id, arrival_runway_id,
    current_phase, operation_status,
    scheduled_departure_at, scheduled_arrival_at,
    actual_departure_at, actual_arrival_at,
    aircraft_id, delay_minutes, metadata_json
) VALUES (
    '2200000c-0001-4001-8001-00000000000c',
    NULL, 'AA100',
    '10000002-0001-4001-8001-000000000002',
    '1000000a-0001-4001-8001-00000000000a',
    '11000004-0001-4001-8001-000000000004', '11000007-0001-4001-8001-000000000007',
    'COMPLETE', 'COMPLETED',
    TIMESTAMP '2026-06-23 06:00:00', TIMESTAMP '2026-06-23 07:00:00',
    TIMESTAMP '2026-06-23 06:02:00', TIMESTAMP '2026-06-23 06:55:00',
    '15000002-0001-4001-8001-000000000002', 0,
    q'[{"earlyArrival":true,"diversionAlternate":false,"firstFlightOfDay":true}]'
);

INSERT INTO flight_operation (
    flight_operation_id, flight_request_id, flight_number,
    origin_facility_id, destination_facility_id,
    departure_runway_id, current_phase, operation_status,
    scheduled_departure_at, scheduled_arrival_at, aircraft_id, metadata_json
) VALUES (
    '2200000d-0001-4001-8001-00000000000d',
    '2100000b-0001-4001-8001-00000000000b', 'FX991',
    '1000000c-0001-4001-8001-00000000000c',
    '10000002-0001-4001-8001-000000000002',
    '11000009-0001-4001-8001-000000000009', 'SCHEDULED', 'ACTIVE',
    TIMESTAMP '2026-06-23 20:30:00', TIMESTAMP '2026-06-23 21:15:00',
    '15000007-0001-4001-8001-000000000007',
    q'[{"cargoLbs":98000,"flightLevel":350,"eveningPositioning":true}]'
);

-- Flight paths — NK554 clear of weather (north route)
INSERT INTO flight_path (flight_path_id, flight_operation_id, sequence_order, waypoint_name, latitude, longitude, altitude_ft, estimated_time_at)
VALUES ('23000018-0001-4001-8001-000000000018', '2200000b-0001-4001-8001-00000000000b', 1, 'DSM', 41.5340000, -93.6631000, 0, TIMESTAMP '2026-06-23 11:05:00');

INSERT INTO flight_path (flight_path_id, flight_operation_id, sequence_order, waypoint_name, latitude, longitude, altitude_ft, estimated_time_at)
VALUES ('23000019-0001-4001-8001-000000000019', '2200000b-0001-4001-8001-00000000000b', 2, 'MCW', 43.1000000, -93.3300000, 34000, TIMESTAMP '2026-06-23 11:25:00');

INSERT INTO flight_path (flight_path_id, flight_operation_id, sequence_order, waypoint_name, latitude, longitude, altitude_ft, estimated_time_at)
VALUES ('2300001a-0001-4001-8001-00000000001a', '2200000b-0001-4001-8001-00000000000b', 3, 'ORD', 41.9742000, -87.9073000, 0, TIMESTAMP '2026-06-23 12:10:00');

-- DL1055 morning path
INSERT INTO flight_path (flight_path_id, flight_operation_id, sequence_order, waypoint_name, latitude, longitude, altitude_ft, estimated_time_at)
VALUES ('2300001b-0001-4001-8001-00000000001b', '22000009-0001-4001-8001-000000000009', 1, 'DSM', 41.5340000, -93.6631000, 0, TIMESTAMP '2026-06-23 07:32:00');

INSERT INTO flight_path (flight_path_id, flight_operation_id, sequence_order, waypoint_name, latitude, longitude, altitude_ft, estimated_time_at)
VALUES ('2300001c-0001-4001-8001-00000000001c', '22000009-0001-4001-8001-000000000009', 2, 'MSP', 44.8848000, -93.2223000, 0, TIMESTAMP '2026-06-23 08:38:00');

-- Flight events — morning through afternoon
INSERT INTO flight_event (flight_event_id, flight_operation_id, event_type_code, occurred_at, sequence_number, payload_json)
VALUES ('26000012-0001-4001-8001-000000000012', '22000009-0001-4001-8001-000000000009', 'PHASE_CHANGED', TIMESTAMP '2026-06-23 07:32:00', 1, q'[{"from":"SCHEDULED","to":"DEPARTED"}]');

INSERT INTO flight_event (flight_event_id, flight_operation_id, event_type_code, occurred_at, sequence_number, payload_json)
VALUES ('26000013-0001-4001-8001-000000000013', '22000009-0001-4001-8001-000000000009', 'PHASE_CHANGED', TIMESTAMP '2026-06-23 08:38:00', 2, q'[{"from":"ENROUTE","to":"COMPLETE"}]');

INSERT INTO flight_event (flight_event_id, flight_operation_id, event_type_code, occurred_at, sequence_number, payload_json)
VALUES ('26000014-0001-4001-8001-000000000014', '2200000b-0001-4001-8001-00000000000b', 'PHASE_CHANGED', TIMESTAMP '2026-06-23 11:05:00', 1, q'[{"from":"DEPARTED","to":"ENROUTE"}]');

INSERT INTO flight_event (flight_event_id, flight_operation_id, event_type_code, occurred_at, sequence_number, payload_json)
VALUES ('26000015-0001-4001-8001-000000000015', '2200000b-0001-4001-8001-00000000000b', 'PATH_UPDATED', TIMESTAMP '2026-06-23 11:00:00', 2, q'[{"reason":"WEATHER_AVOIDANCE","action":"NORTH_ROUTE","weatherImpact":false}]');

INSERT INTO flight_event (flight_event_id, flight_operation_id, event_type_code, occurred_at, sequence_number, payload_json)
VALUES ('26000016-0001-4001-8001-000000000016', '2200000c-0001-4001-8001-00000000000c', 'PHASE_CHANGED', TIMESTAMP '2026-06-23 06:55:00', 1, q'[{"from":"ENROUTE","to":"COMPLETE"}]');

-- ---------------------------------------------------------------------------
-- Weather — isolated event with NO corridor impact
-- ---------------------------------------------------------------------------

INSERT INTO weather_event (
    weather_event_id, weather_type_code, name, severity,
    started_at, ended_at, max_wind_kts, visibility_sm, ceiling_ft, precipitation_rate, metadata_json
) VALUES (
    '27000004-0001-4001-8001-000000000004',
    'SNOW', 'Northern Minnesota Lake Effect Flurries', 'LOW',
    TIMESTAMP '2026-06-23 09:00:00', TIMESTAMP '2026-06-23 15:00:00',
    12.0, 3.0, 2500, 0.1,
    q'[{"corridorImpact":false,"region":"northern MN","note":"No active flight path intersections","affectsFacilities":["ZMP"]}]'
);

INSERT INTO weather_event_path (
    weather_event_path_id, weather_event_id, sequence_order,
    latitude, longitude, radius_nm, effective_at, intensity_factor
) VALUES (
    '28000008-0001-4001-8001-000000000008', '27000004-0001-4001-8001-000000000004', 1,
    47.5000000, -94.2000000, 40.0, TIMESTAMP '2026-06-23 09:00:00', 0.4
);

-- No weather_event_alert rows for WX-04 — intentionally zero impact on corridor flights

-- ---------------------------------------------------------------------------
-- Equipment outage — KOMA comm degraded (facility operational, no flight cancel)
-- ---------------------------------------------------------------------------

INSERT INTO equipment_alert (
    equipment_alert_id, equipment_id, alert_type, severity, title, message,
    raised_at, acknowledged_at, acknowledged_by_user_id
) VALUES (
    '1d000005-0001-4001-8001-000000000005',
    '1200000c-0001-4001-8001-00000000000c', 'DEGRADED', 'MEDIUM',
    'KOMA ASR-8 — Intermittent Rotation Rate Fluctuation',
    'Radar rotation varying 11.8-12.2 RPM. Surveillance coverage maintained. Inspection scheduled 16:00Z.',
    TIMESTAMP '2026-06-23 12:30:00',
    TIMESTAMP '2026-06-23 12:45:00',
    '20000001-0001-4001-8001-000000000001'
);

-- Facility stays OPERATIONAL — no UPDATE needed; outage is equipment-level only

-- ---------------------------------------------------------------------------
-- Path request — denied (weather not a factor; runway capacity)
-- ---------------------------------------------------------------------------

INSERT INTO flight_path_request (
    flight_path_request_id, flight_operation_id, request_reason, request_status,
    requested_path_json, requested_by_user_id, reviewed_by_user_id,
    requested_at, resolved_at, resolution_notes
) VALUES (
    '24000005-0001-4001-8001-000000000005',
    '2200000b-0001-4001-8001-00000000000b',
    'Request direct DSM-ORD due to fuel optimization',
    'DENIED',
    q'[{"waypoints":[{"name":"DSM","lat":41.53,"lon":-93.66},{"name":"ORD","lat":41.97,"lon":-87.91}]}]',
    '00000000-0000-0000-0000-000000000100',
    '20000001-0001-4001-8001-000000000001',
    TIMESTAMP '2026-06-23 11:15:00',
    TIMESTAMP '2026-06-23 11:18:00',
    'Denied — remain on northern weather deviation route per ZAU.'
);

-- ---------------------------------------------------------------------------
-- Operational day snapshot
-- ---------------------------------------------------------------------------

INSERT INTO simulation_snapshot (
    simulation_snapshot_id, snapshot_label, render_context_id,
    sim_time_utc, clock_mode_code, time_scale, run_status_code, step_sequence,
    state_json, created_by_user_id
) VALUES (
    '2b000004-0001-4001-8001-000000000004',
    'Operational Day — 06:00 UTC Start',
    '00000000-0000-0000-0000-000000000010',
    TIMESTAMP '2026-06-23 06:00:00', 'REALTIME', 1, 'PAUSED', 0,
    q'[{"scenario":"operational-day-full","windowUtc":["06:00","22:00"],"flightRequests":11,"flightOperations":13,"maintenanceActivities":8,"weatherEvents":4,"pathImpactEvents":3,"noImpactWeather":1}]',
    '20000001-0001-4001-8001-000000000001'
);

COMMIT;
