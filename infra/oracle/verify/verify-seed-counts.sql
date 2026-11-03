-- =============================================================================
-- Seed verification: band counts + minimum thresholds + orphan FK checks
-- Run: .\scripts\verify.ps1
-- =============================================================================

ALTER SESSION SET CONTAINER = FREEPDB1;
ALTER SESSION SET CURRENT_SCHEMA = nas_sim;

SET PAGESIZE 200
SET LINESIZE 200

PROMPT === Entity row counts ===
SELECT 'facility' AS entity, COUNT(*) AS row_count FROM facility
UNION ALL SELECT 'runway', COUNT(*) FROM runway
UNION ALL SELECT 'runway_equipment', COUNT(*) FROM runway_equipment
UNION ALL SELECT 'equipment', COUNT(*) FROM equipment
UNION ALL SELECT 'equipment_dependency', COUNT(*) FROM equipment_dependency
UNION ALL SELECT 'aircraft', COUNT(*) FROM aircraft
UNION ALL SELECT 'maintenance_activity', COUNT(*) FROM maintenance_activity
UNION ALL SELECT 'maintenance_log', COUNT(*) FROM maintenance_log
UNION ALL SELECT 'facility_maintenance_activity', COUNT(*) FROM facility_maintenance_activity
UNION ALL SELECT 'flight_operation', COUNT(*) FROM flight_operation
UNION ALL SELECT 'flight_request', COUNT(*) FROM flight_request
UNION ALL SELECT 'flight_event', COUNT(*) FROM flight_event
UNION ALL SELECT 'flight_path', COUNT(*) FROM flight_path
UNION ALL SELECT 'flight_path_request', COUNT(*) FROM flight_path_request
UNION ALL SELECT 'flight_incident', COUNT(*) FROM flight_incident
UNION ALL SELECT 'weather_event', COUNT(*) FROM weather_event
UNION ALL SELECT 'weather_event_alert', COUNT(*) FROM weather_event_alert
UNION ALL SELECT 'weather_event_path', COUNT(*) FROM weather_event_path
UNION ALL SELECT 'equipment_alert', COUNT(*) FROM equipment_alert
UNION ALL SELECT 'equipment_part', COUNT(*) FROM equipment_part
UNION ALL SELECT 'equipment_part_order', COUNT(*) FROM equipment_part_order
UNION ALL SELECT 'equipment_part_shipment', COUNT(*) FROM equipment_part_shipment
UNION ALL SELECT 'part_manufacturer_lkp', COUNT(*) FROM part_manufacturer_lkp
UNION ALL SELECT 'facility_logistics_activity', COUNT(*) FROM facility_logistics_activity
UNION ALL SELECT 'facility_logistics_log', COUNT(*) FROM facility_logistics_log
UNION ALL SELECT 'ground_operation_log', COUNT(*) FROM ground_operation_log
UNION ALL SELECT 'log_entry_type_lkp', COUNT(*) FROM log_entry_type_lkp
UNION ALL SELECT 'simulation_geo_location_lookup', COUNT(*) FROM simulation_geo_location_lookup
UNION ALL SELECT 'simulation_snapshot', COUNT(*) FROM simulation_snapshot
UNION ALL SELECT 'user_permissions', COUNT(*) FROM user_permissions
UNION ALL SELECT 'users', COUNT(*) FROM users
UNION ALL SELECT 'scenario_clock', COUNT(*) FROM scenario_clock
UNION ALL SELECT 'eval_benchmark', COUNT(*) FROM eval_benchmark
UNION ALL SELECT 'eval_task', COUNT(*) FROM eval_task
UNION ALL SELECT 'notam', COUNT(*) FROM notam
ORDER BY 1;

PROMPT === Band minimums (FAIL rows should be empty) ===
WITH counts AS (
    SELECT
        (SELECT COUNT(*) FROM facility) AS facility_cnt,
        (SELECT COUNT(*) FROM flight_operation) AS flight_cnt,
        (SELECT COUNT(*) FROM equipment) AS equipment_cnt,
        (SELECT COUNT(*) FROM users) AS users_cnt,
        (SELECT COUNT(*) FROM facility_type_lkp) AS facility_type_cnt,
        (SELECT COUNT(*) FROM scenario_clock) AS clock_cnt,
        (SELECT COUNT(*) FROM eval_task) AS eval_task_cnt,
        (SELECT COUNT(*) FROM log_entry_type_lkp) AS log_type_cnt,
        (SELECT COUNT(*) FROM maintenance_log WHERE facility_id IS NOT NULL) AS maint_log_located_cnt,
        (SELECT COUNT(*) FROM ground_operation_log WHERE facility_id IS NOT NULL) AS ground_log_located_cnt,
        (SELECT COUNT(*) FROM facility_logistics_log WHERE facility_id IS NOT NULL) AS logistics_log_located_cnt
    FROM dual
)
SELECT check_name, expected_min, actual_count,
       CASE WHEN actual_count >= expected_min THEN 'PASS' ELSE 'FAIL' END AS status
FROM counts
CROSS JOIN (
    SELECT 'facility' AS check_name, 5 AS expected_min, facility_cnt AS actual_count FROM counts
    UNION ALL SELECT 'flight_operation', 3, flight_cnt FROM counts
    UNION ALL SELECT 'equipment', 10, equipment_cnt FROM counts
    UNION ALL SELECT 'users', 1, users_cnt FROM counts
    UNION ALL SELECT 'facility_type_lkp', 5, facility_type_cnt FROM counts
    UNION ALL SELECT 'scenario_clock', 1, clock_cnt FROM counts
    UNION ALL SELECT 'eval_task', 3, eval_task_cnt FROM counts
    UNION ALL SELECT 'log_entry_type_lkp', 8, log_type_cnt FROM counts
    UNION ALL SELECT 'maintenance_log.facility_id populated', 5, maint_log_located_cnt FROM counts
    UNION ALL SELECT 'ground_operation_log.facility_id populated', 2, ground_log_located_cnt FROM counts
    UNION ALL SELECT 'facility_logistics_log.facility_id populated', 2, logistics_log_located_cnt FROM counts
);

PROMPT === Orphan FK checks (should return 0 orphan counts) ===
SELECT 'equipment.facility_id' AS orphan_check, COUNT(*) AS orphans
FROM equipment e
WHERE NOT EXISTS (SELECT 1 FROM facility f WHERE f.facility_id = e.facility_id)
UNION ALL
SELECT 'runway.facility_id', COUNT(*)
FROM runway r
WHERE NOT EXISTS (SELECT 1 FROM facility f WHERE f.facility_id = r.facility_id)
UNION ALL
SELECT 'flight_operation.origin_facility_id', COUNT(*)
FROM flight_operation fo
WHERE NOT EXISTS (SELECT 1 FROM facility f WHERE f.facility_id = fo.origin_facility_id)
UNION ALL
SELECT 'flight_operation.aircraft_id', COUNT(*)
FROM flight_operation fo
WHERE NOT EXISTS (SELECT 1 FROM aircraft a WHERE a.aircraft_id = fo.aircraft_id)
UNION ALL
SELECT 'flight_event.flight_operation_id', COUNT(*)
FROM flight_event fe
WHERE NOT EXISTS (SELECT 1 FROM flight_operation fo WHERE fo.flight_operation_id = fe.flight_operation_id)
UNION ALL
SELECT 'maintenance_activity.equipment_id', COUNT(*)
FROM maintenance_activity m
WHERE NOT EXISTS (SELECT 1 FROM equipment e WHERE e.equipment_id = m.equipment_id)
UNION ALL
SELECT 'facility_staff_assignment.user_id', COUNT(*)
FROM facility_staff_assignment s
WHERE NOT EXISTS (SELECT 1 FROM users u WHERE u.user_id = s.user_id)
UNION ALL
SELECT 'maintenance_log.facility_id', COUNT(*)
FROM maintenance_log ml
WHERE ml.facility_id IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM facility f WHERE f.facility_id = ml.facility_id)
UNION ALL
SELECT 'maintenance_log.equipment_id', COUNT(*)
FROM maintenance_log ml
WHERE ml.equipment_id IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM equipment e WHERE e.equipment_id = ml.equipment_id)
UNION ALL
SELECT 'maintenance_log.runway_id', COUNT(*)
FROM maintenance_log ml
WHERE ml.runway_id IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM runway r WHERE r.runway_id = ml.runway_id)
UNION ALL
SELECT 'maintenance_log.log_entry_type', COUNT(*)
FROM maintenance_log ml
WHERE NOT EXISTS (SELECT 1 FROM log_entry_type_lkp l WHERE l.log_entry_type_code = ml.log_entry_type)
UNION ALL
SELECT 'ground_operation_log.facility_id', COUNT(*)
FROM ground_operation_log gl
WHERE gl.facility_id IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM facility f WHERE f.facility_id = gl.facility_id)
UNION ALL
SELECT 'facility_logistics_log.facility_id', COUNT(*)
FROM facility_logistics_log ll
WHERE ll.facility_id IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM facility f WHERE f.facility_id = ll.facility_id);

PROMPT === Location-aware log sample (ILS corridor) ===
SELECT log_entry_type, location_label, facility_id, equipment_id, runway_id, logged_at
FROM maintenance_log
WHERE maintenance_activity_id = '16000001-0001-4001-8001-000000000001'
ORDER BY logged_at;

PROMPT === Scenario clock ===
SELECT clock_id, scenario_day, anchor_ts, description FROM scenario_clock;

EXIT;
