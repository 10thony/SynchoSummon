-- =============================================================================
-- Ground operations seed — DL447 turn activities and UA512 scheduled ground prep
-- =============================================================================

ALTER SESSION SET CONTAINER = FREEPDB1;
ALTER SESSION SET CURRENT_SCHEMA = nas_sim;

-- Migrate DL447 from legacy BOARDING phase to GROUND_OPS umbrella
UPDATE flight_operation
SET current_phase = 'GROUND_OPS',
    metadata_json = q'[{"gate":"G12","fogClearanceExpected":"14:30Z","deicing":false,"cargoFlight":false}]',
    updated_at = SYSTIMESTAMP
WHERE flight_operation_id = '22000005-0001-4001-8001-000000000005'
  AND current_phase = 'BOARDING';

-- DL447 — parallel ground activities in progress (MSP turn, sim time ~14:45)
INSERT INTO ground_operation_activity (
    ground_operation_activity_id, flight_operation_id, aircraft_id, facility_id,
    activity_type_code, activity_status, title, description,
    progress_pct, scheduled_start_at, scheduled_end_at, actual_start_at,
    estimated_duration_min, priority, metadata_json
) VALUES (
    '33000001-0001-4001-8001-000000000001',
    '22000005-0001-4001-8001-000000000005',
    '15000003-0001-4001-8001-000000000003',
    '10000003-0001-4001-8001-000000000003',
    'PASSENGER_BOARDING', 'IN_PROGRESS', 'DL447 Passenger Boarding',
    'Boarding passengers at Gate G12',
    72, TIMESTAMP '2026-06-23 14:00:00', TIMESTAMP '2026-06-23 14:45:00',
    TIMESTAMP '2026-06-23 14:00:00', 45, 2,
    q'[{"gate":"G12","passengersBoarded":136,"passengersExpected":189}]'
);

INSERT INTO ground_operation_activity (
    ground_operation_activity_id, flight_operation_id, aircraft_id, facility_id,
    activity_type_code, activity_status, title, description,
    progress_pct, scheduled_start_at, scheduled_end_at, actual_start_at,
    estimated_duration_min, priority, metadata_json
) VALUES (
    '33000001-0001-4001-8001-000000000002',
    '22000005-0001-4001-8001-000000000005',
    '15000003-0001-4001-8001-000000000003',
    '10000003-0001-4001-8001-000000000003',
    'AIRCRAFT_FUELING', 'IN_PROGRESS', 'DL447 Aircraft Fueling',
    'Fueling B738 on ramp',
    85, TIMESTAMP '2026-06-23 13:50:00', TIMESTAMP '2026-06-23 14:15:00',
    TIMESTAMP '2026-06-23 13:50:00', 25, 2,
    q'[{"fuelTruckId":"FT-MSP-07","gallonsLoaded":4200,"gallonsRequired":5000}]'
);

INSERT INTO ground_operation_activity (
    ground_operation_activity_id, flight_operation_id, aircraft_id, facility_id,
    activity_type_code, activity_status, title, description,
    progress_pct, scheduled_start_at, scheduled_end_at, actual_start_at,
    estimated_duration_min, priority, metadata_json
) VALUES (
    '33000001-0001-4001-8001-000000000003',
    '22000005-0001-4001-8001-000000000005',
    '15000003-0001-4001-8001-000000000003',
    '10000003-0001-4001-8001-000000000003',
    'CREW_LOADING', 'COMPLETED', 'DL447 Crew Loading',
    'Flight deck and cabin crew on board',
    100, TIMESTAMP '2026-06-23 13:45:00', TIMESTAMP '2026-06-23 14:00:00',
    TIMESTAMP '2026-06-23 13:45:00', 15, 3,
    q'[{"crewCount":6}]'
);

-- UA512 — scheduled departure, ground ops not yet started (will auto-spawn on tick)
INSERT INTO ground_operation_activity (
    ground_operation_activity_id, flight_operation_id, aircraft_id, facility_id,
    activity_type_code, activity_status, title, description,
    progress_pct, scheduled_start_at, scheduled_end_at,
    estimated_duration_min, priority, metadata_json
) VALUES (
    '33000002-0001-4001-8001-000000000001',
    '22000006-0001-4001-8001-000000000006',
    '15000008-0001-4001-8001-000000000008',
    '1000000a-0001-4001-8001-00000000000a',
    'PASSENGER_BOARDING', 'PLANNED', 'UA512 Passenger Boarding',
    'Scheduled boarding at Gate G8',
    0, TIMESTAMP '2026-06-23 16:00:00', TIMESTAMP '2026-06-23 16:45:00',
    45, 2,
    q'[{"gate":"G8","passengersExpected":165}]'
);

INSERT INTO ground_operation_activity (
    ground_operation_activity_id, flight_operation_id, aircraft_id, facility_id,
    activity_type_code, activity_status, title, description,
    progress_pct, scheduled_start_at, scheduled_end_at,
    estimated_duration_min, priority, metadata_json
) VALUES (
    '33000002-0001-4001-8001-000000000002',
    '22000006-0001-4001-8001-000000000006',
    '15000008-0001-4001-8001-000000000008',
    '1000000a-0001-4001-8001-00000000000a',
    'AIRCRAFT_FUELING', 'PLANNED', 'UA512 Aircraft Fueling',
    'Scheduled fueling',
    0, TIMESTAMP '2026-06-23 15:50:00', TIMESTAMP '2026-06-23 16:15:00',
    25, 2, NULL
);

INSERT INTO ground_operation_activity (
    ground_operation_activity_id, flight_operation_id, aircraft_id, facility_id,
    activity_type_code, activity_status, title, description,
    progress_pct, scheduled_start_at, scheduled_end_at,
    estimated_duration_min, priority, metadata_json
) VALUES (
    '33000002-0001-4001-8001-000000000003',
    '22000006-0001-4001-8001-000000000006',
    '15000008-0001-4001-8001-000000000008',
    '1000000a-0001-4001-8001-00000000000a',
    'CREW_LOADING', 'PLANNED', 'UA512 Crew Loading',
    'Scheduled crew boarding',
    0, TIMESTAMP '2026-06-23 15:45:00', TIMESTAMP '2026-06-23 16:00:00',
    15, 3, NULL
);

-- FDX882 cargo flight — includes CARGO_LOADING as required activity
UPDATE flight_operation
SET metadata_json = q'[{"gate":"C4","cargoFlight":true,"freightPallets":12}]',
    updated_at = SYSTIMESTAMP
WHERE flight_number = 'FDX882';

COMMIT;
