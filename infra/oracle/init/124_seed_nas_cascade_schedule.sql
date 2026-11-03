-- NAS cascade demo schedule: inject/activate ops via WORKFLOW + ENTITY_UPSERT.
-- Times are relative to seeded operational day (~2026-06-28); adjust if clock drifts.

ALTER SESSION SET CONTAINER = FREEPDB1;
ALTER SESSION SET CURRENT_SCHEMA = nas_sim;

MERGE INTO simulation_schedule t
USING (SELECT 'NAS_CASCADE' AS schedule_code FROM dual) s
ON (t.schedule_code = s.schedule_code)
WHEN NOT MATCHED THEN INSERT (
    schedule_id, schedule_code, title, description, is_active
) VALUES (
    'd2000001-0001-4001-8001-0000000000ca',
    'NAS_CASCADE',
    'NAS Cascade Demo',
    'Flight / parts / maintenance inject events for cascade spine demos',
    'Y'
);

-- Phase 1: Activate a known flight into ENROUTE (movement sim then owns progress_pct).
INSERT INTO simulation_schedule_event (
    schedule_event_id, schedule_id, occurred_at_sim_utc, action_code, entity_slug, summary, payload_json, sort_order
)
SELECT
    'd2000002-0001-4001-8001-0000000000e1',
    schedule_id,
    TIMESTAMP '2026-06-28 06:10:00',
    'WORKFLOW',
    'flight-operation',
    'Activate DL1920 enroute for cascade demo',
    '{"workflow":"ACTIVATE_FLIGHT_ENROUTE","flightOperationId":"22000002-0001-4001-8001-000000000002"}',
    10
FROM simulation_schedule WHERE schedule_code = 'NAS_CASCADE'
AND NOT EXISTS (
    SELECT 1 FROM simulation_schedule_event WHERE schedule_event_id = 'd2000002-0001-4001-8001-0000000000e1'
);

-- Phase 2: Put NAS-TRK-07 in transit on the carrier flight (air-coupled progress).
INSERT INTO simulation_schedule_event (
    schedule_event_id, schedule_id, occurred_at_sim_utc, action_code, entity_slug, summary, payload_json, sort_order
)
SELECT
    'd2000002-0001-4001-8001-0000000000e3',
    schedule_id,
    TIMESTAMP '2026-06-28 06:12:00',
    'ENTITY_UPSERT',
    'equipment-part-shipment',
    'Cascade: NAS-TRK-07 IN_TRANSIT on DL1920',
    '{"equipmentPartShipmentId":"1e000001-0001-4001-8001-000000000001","shipmentStatus":"IN_TRANSIT","carrierModeCode":"AIR","carrierFlightOperationId":"22000002-0001-4001-8001-000000000002","progressPct":15}',
    15
FROM simulation_schedule WHERE schedule_code = 'NAS_CASCADE'
AND NOT EXISTS (
    SELECT 1 FROM simulation_schedule_event WHERE schedule_event_id = 'd2000002-0001-4001-8001-0000000000e3'
);

-- Phase 3: note — HIGH/CRITICAL alerts spawn PLANNED maintenance via MaintenanceSimulationService.
INSERT INTO simulation_schedule_event (
    schedule_event_id, schedule_id, occurred_at_sim_utc, action_code, entity_slug, summary, payload_json, sort_order
)
SELECT
    'd2000002-0001-4001-8001-0000000000e2',
    schedule_id,
    TIMESTAMP '2026-06-28 06:20:00',
    'TIMELINE_NOTE',
    'maintenance-activity',
    'Cascade note: open HIGH/CRITICAL alerts spawn PLANNED maintenance via sim tick',
    '{}',
    20
FROM simulation_schedule WHERE schedule_code = 'NAS_CASCADE'
AND NOT EXISTS (
    SELECT 1 FROM simulation_schedule_event WHERE schedule_event_id = 'd2000002-0001-4001-8001-0000000000e2'
);

COMMIT;
