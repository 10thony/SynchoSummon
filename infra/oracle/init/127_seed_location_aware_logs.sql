-- =============================================================================
-- Location-aware operational logs
-- Backfills facility / equipment / runway / location_label on existing logs and
-- adds a multi-step trail demonstrating interconnected log behavior.
-- Schema is general; DSM ILS corridor IDs are the demo narrative only.
-- =============================================================================

ALTER SESSION SET CONTAINER = FREEPDB1;
ALTER SESSION SET CURRENT_SCHEMA = nas_sim;

-- Stable demo IDs from 100_seed_operational_nas
-- facility DSM:     10000001-0001-4001-8001-000000000001
-- facility depot:   10000006-0001-4001-8001-000000000006
-- runway 13/31:     11000001-0001-4001-8001-000000000001
-- equipment ILS-13: 12000001-0001-4001-8001-000000000001
-- maint activity:   16000001-0001-4001-8001-000000000001
-- user maint coord: 20000002-0001-4001-8001-000000000002

----------------------------------------------------------------------------
-- Backfill existing ILS RWY 13 maintenance logs with location context
----------------------------------------------------------------------------

UPDATE maintenance_log
SET facility_id    = '10000006-0001-4001-8001-000000000006',
    location_label = 'DEPOT_DISPATCH_DESK',
    metadata_json  = NVL(metadata_json, q'[{"phase":"dispatch","corridor":"DSM_ILS_13"}]')
WHERE maintenance_log_id = '18000001-0001-4001-8001-000000000001';

UPDATE maintenance_log
SET facility_id    = '10000001-0001-4001-8001-000000000001',
    equipment_id   = '12000001-0001-4001-8001-000000000001',
    runway_id      = '11000001-0001-4001-8001-000000000001',
    location_label = 'GS_CABINET',
    metadata_json  = NVL(metadata_json, q'[{"faultCode":"GS-TX-07","corridor":"DSM_ILS_13"}]')
WHERE maintenance_log_id = '18000002-0001-4001-8001-000000000002';

UPDATE maintenance_log
SET facility_id    = '10000001-0001-4001-8001-000000000001',
    equipment_id   = '12000001-0001-4001-8001-000000000001',
    runway_id      = '11000001-0001-4001-8001-000000000001',
    location_label = 'GS_CABINET',
    metadata_json  = NVL(metadata_json, q'[{"module":"ILS-GS-739","corridor":"DSM_ILS_13"}]')
WHERE maintenance_log_id = '18000004-0001-4001-8001-000000000004';

UPDATE maintenance_log
SET facility_id    = '10000001-0001-4001-8001-000000000001',
    equipment_id   = '12000001-0001-4001-8001-000000000001',
    runway_id      = '11000001-0001-4001-8001-000000000001',
    location_label = 'GS_CABINET',
    metadata_json  = NVL(
        metadata_json,
        q'[{"partNumber":"ILS-GS-739","serialNumber":"GS-739-8842","corridor":"DSM_ILS_13"}]'
    )
WHERE maintenance_log_id = '18000005-0001-4001-8001-000000000005';

----------------------------------------------------------------------------
-- Multi-step interconnected trail (idempotent MERGE)
----------------------------------------------------------------------------

-- DISPATCH from Urbandale depot
MERGE INTO maintenance_log t
USING (SELECT '18000010-0001-4001-8001-000000000010' AS maintenance_log_id FROM dual) s
ON (t.maintenance_log_id = s.maintenance_log_id)
WHEN NOT MATCHED THEN INSERT (
    maintenance_log_id, maintenance_activity_id, log_entry_type, message,
    logged_at, logged_by_user_id, facility_id, equipment_id, runway_id,
    location_label, metadata_json
) VALUES (
    '18000010-0001-4001-8001-000000000010',
    '16000001-0001-4001-8001-000000000001',
    'DISPATCH',
    'Depot crew rolled with GS replacement module; destination DSM RWY 13 glide slope cabinet.',
    TIMESTAMP '2026-06-23 12:20:00',
    '20000002-0001-4001-8001-000000000002',
    '10000006-0001-4001-8001-000000000006',
    '12000001-0001-4001-8001-000000000001',
    NULL,
    'DEPOT_BAY_3',
    q'[{"vehicle":"NAS-MW-TRK-04","etaMinutes":45,"corridor":"DSM_ILS_13"}]'
);

-- ARRIVAL on site / runway section
MERGE INTO maintenance_log t
USING (SELECT '18000011-0001-4001-8001-000000000011' AS maintenance_log_id FROM dual) s
ON (t.maintenance_log_id = s.maintenance_log_id)
WHEN NOT MATCHED THEN INSERT (
    maintenance_log_id, maintenance_activity_id, log_entry_type, message,
    logged_at, logged_by_user_id, facility_id, equipment_id, runway_id,
    location_label, metadata_json
) VALUES (
    '18000011-0001-4001-8001-000000000011',
    '16000001-0001-4001-8001-000000000001',
    'ARRIVAL',
    'Crew on station at DSM RWY 13 approach end; access granted to GS shelter.',
    TIMESTAMP '2026-06-23 13:05:00',
    '20000002-0001-4001-8001-000000000002',
    '10000001-0001-4001-8001-000000000001',
    '12000001-0001-4001-8001-000000000001',
    '11000001-0001-4001-8001-000000000001',
    'GS_SHELTER',
    q'[{"accessBadge":"DSM-OPS-19","corridor":"DSM_ILS_13"}]'
);

-- INSPECTION at localizer antenna (same runway, different section)
MERGE INTO maintenance_log t
USING (SELECT '18000012-0001-4001-8001-000000000012' AS maintenance_log_id FROM dual) s
ON (t.maintenance_log_id = s.maintenance_log_id)
WHEN NOT MATCHED THEN INSERT (
    maintenance_log_id, maintenance_activity_id, log_entry_type, message,
    logged_at, logged_by_user_id, facility_id, equipment_id, runway_id,
    location_label, metadata_json
) VALUES (
    '18000012-0001-4001-8001-000000000012',
    '16000001-0001-4001-8001-000000000001',
    'INSPECTION',
    'Localizer course width checked while GS swap staged; LOC remains nominal.',
    TIMESTAMP '2026-06-23 13:20:00',
    '20000002-0001-4001-8001-000000000002',
    '10000001-0001-4001-8001-000000000001',
    '12000001-0001-4001-8001-000000000001',
    '11000001-0001-4001-8001-000000000001',
    'LOC_ANTENNA',
    q'[{"courseWidthDeg":0.0,"corridor":"DSM_ILS_13"}]'
);

-- HANDOFF site → TRACON coordination note (facility only)
MERGE INTO maintenance_log t
USING (SELECT '18000013-0001-4001-8001-000000000013' AS maintenance_log_id FROM dual) s
ON (t.maintenance_log_id = s.maintenance_log_id)
WHEN NOT MATCHED THEN INSERT (
    maintenance_log_id, maintenance_activity_id, log_entry_type, message,
    logged_at, logged_by_user_id, facility_id, equipment_id, runway_id,
    location_label, metadata_json
) VALUES (
    '18000013-0001-4001-8001-000000000013',
    '16000001-0001-4001-8001-000000000001',
    'HANDOFF',
    'Ops handoff: DSM TRACON advised Cat I RWY 13 remains suspended pending post-install flight check.',
    TIMESTAMP '2026-06-23 15:25:00',
    '20000002-0001-4001-8001-000000000002',
    '10000001-0001-4001-8001-000000000001',
    '12000001-0001-4001-8001-000000000001',
    '11000001-0001-4001-8001-000000000001',
    'ATCT_COORD',
    q'[{"notified":"DSM_TRACON","corridor":"DSM_ILS_13"}]'
);

-- STATUS_CHANGE restoring equipment after install
MERGE INTO maintenance_log t
USING (SELECT '18000014-0001-4001-8001-000000000014' AS maintenance_log_id FROM dual) s
ON (t.maintenance_log_id = s.maintenance_log_id)
WHEN NOT MATCHED THEN INSERT (
    maintenance_log_id, maintenance_activity_id, log_entry_type, message,
    logged_at, logged_by_user_id, facility_id, equipment_id, runway_id,
    location_label, metadata_json
) VALUES (
    '18000014-0001-4001-8001-000000000014',
    '16000001-0001-4001-8001-000000000001',
    'STATUS_CHANGE',
    'Post-install BIT green on GS transmitter; equipment status FAILED → MAINTENANCE pending flight check.',
    TIMESTAMP '2026-06-23 15:40:00',
    '20000002-0001-4001-8001-000000000002',
    '10000001-0001-4001-8001-000000000001',
    '12000001-0001-4001-8001-000000000001',
    '11000001-0001-4001-8001-000000000001',
    'GS_CABINET',
    q'[{"fromStatus":"FAILED","toStatus":"MAINTENANCE","corridor":"DSM_ILS_13"}]'
);

----------------------------------------------------------------------------
-- Ground ops logs (MSP gate turn) — same location shape
----------------------------------------------------------------------------

MERGE INTO ground_operation_log t
USING (SELECT '34000001-0001-4001-8001-000000000001' AS ground_operation_log_id FROM dual) s
ON (t.ground_operation_log_id = s.ground_operation_log_id)
WHEN NOT MATCHED THEN INSERT (
    ground_operation_log_id, ground_operation_activity_id, log_entry_type, message,
    logged_at, logged_by_user_id, facility_id, equipment_id, runway_id,
    location_label, metadata_json
) VALUES (
    '34000001-0001-4001-8001-000000000001',
    '33000001-0001-4001-8001-000000000001',
    'PROGRESS',
    'Boarding 72% complete at Gate G12; jetbridge connected.',
    TIMESTAMP '2026-06-23 14:20:00',
    '00000000-0000-0000-0000-000000000100',
    '10000003-0001-4001-8001-000000000003',
    NULL,
    NULL,
    'GATE_G12',
    q'[{"passengersBoarded":136,"jetbridge":"JB-G12"}]'
);

MERGE INTO ground_operation_log t
USING (SELECT '34000002-0001-4001-8001-000000000002' AS ground_operation_log_id FROM dual) s
ON (t.ground_operation_log_id = s.ground_operation_log_id)
WHEN NOT MATCHED THEN INSERT (
    ground_operation_log_id, ground_operation_activity_id, log_entry_type, message,
    logged_at, logged_by_user_id, facility_id, equipment_id, runway_id,
    location_label, metadata_json
) VALUES (
    '34000002-0001-4001-8001-000000000002',
    '33000001-0001-4001-8001-000000000002',
    'PROGRESS',
    'Fueling truck FT-MSP-07 connected on ramp stand; 4200/5000 gal loaded.',
    TIMESTAMP '2026-06-23 14:05:00',
    '00000000-0000-0000-0000-000000000100',
    '10000003-0001-4001-8001-000000000003',
    NULL,
    NULL,
    'RAMP_STAND_G12',
    q'[{"fuelTruckId":"FT-MSP-07","gallonsLoaded":4200}]'
);

----------------------------------------------------------------------------
-- Logistics logs (part put-away) — facility + bin section
----------------------------------------------------------------------------

MERGE INTO facility_logistics_log t
USING (SELECT '1f100001-0001-4001-8001-000000000001' AS facility_logistics_log_id FROM dual) s
ON (t.facility_logistics_log_id = s.facility_logistics_log_id)
WHEN NOT MATCHED THEN INSERT (
    facility_logistics_log_id, facility_logistics_activity_id, log_entry_type, message,
    logged_at, logged_by_user_id, facility_id, equipment_id, runway_id,
    location_label, metadata_json
) VALUES (
    '1f100001-0001-4001-8001-000000000001',
    '1f000001-0001-4001-8001-000000000001',
    'ARRIVAL',
    'Inbound GS module pallet received at Urbandale depot receiving dock.',
    TIMESTAMP '2026-06-23 11:55:00',
    '20000002-0001-4001-8001-000000000002',
    '10000006-0001-4001-8001-000000000006',
    NULL,
    NULL,
    'RECV_DOCK_1',
    q'[{"shipmentRef":"NAS-MW-GS-739","corridor":"DSM_ILS_13"}]'
);

MERGE INTO facility_logistics_log t
USING (SELECT '1f100002-0001-4001-8001-000000000002' AS facility_logistics_log_id FROM dual) s
ON (t.facility_logistics_log_id = s.facility_logistics_log_id)
WHEN NOT MATCHED THEN INSERT (
    facility_logistics_log_id, facility_logistics_activity_id, log_entry_type, message,
    logged_at, logged_by_user_id, facility_id, equipment_id, runway_id,
    location_label, metadata_json
) VALUES (
    '1f100002-0001-4001-8001-000000000002',
    '1f000002-0001-4001-8001-000000000002',
    'PART_USED',
    'Module staged to BIN_A3 for DSM ILS crew pickup.',
    TIMESTAMP '2026-06-23 12:10:00',
    '20000002-0001-4001-8001-000000000002',
    '10000006-0001-4001-8001-000000000006',
    '12000001-0001-4001-8001-000000000001',
    NULL,
    'BIN_A3',
    q'[{"bin":"A3","partNumber":"ILS-GS-739","corridor":"DSM_ILS_13"}]'
);

COMMIT;
