-- =============================================================================
-- Clear mutable operational / overlay data before corridor seeds (100–126).
-- Leaves lookups, auth, dashboards, eval catalog, and scenario_clock intact.
-- Safe on first boot (tables empty) and required for idempotent re-seed.
-- =============================================================================

ALTER SESSION SET CONTAINER = FREEPDB1;
ALTER SESSION SET CURRENT_SCHEMA = nas_sim;

-- Eval runtime (keep catalog in eval_benchmark / eval_task / eval_model_profile)
DELETE FROM eval_action_trace;
DELETE FROM eval_artifact;
DELETE FROM eval_audit_event;
DELETE FROM eval_task_run;
DELETE FROM eval_run;

-- Perf samples (schema only on fresh boot)
DELETE FROM perf_test_metric;
DELETE FROM perf_test_run;

-- Flight / weather / ground event streams
DELETE FROM flight_event;
DELETE FROM flight_incident;
DELETE FROM flight_path;
DELETE FROM flight_path_request;
DELETE FROM weather_event_alert;
DELETE FROM weather_event_path;
DELETE FROM weather_event;
DELETE FROM ground_operation_log;
DELETE FROM ground_operation_activity;
DELETE FROM equipment_alert;
DELETE FROM notam;

-- Parts / logistics
DELETE FROM facility_logistics_log;
DELETE FROM facility_logistics_activity;
DELETE FROM equipment_part_shipment;
DELETE FROM equipment_part_order;
DELETE FROM equipment_part_quote;
DELETE FROM equipment_part;

-- Maintenance
DELETE FROM maintenance_log;
DELETE FROM maintenance_report;
DELETE FROM facility_maintenance_activity;
DELETE FROM maintenance_activity;

-- Ops core
DELETE FROM flight_operation;
DELETE FROM flight_request;
DELETE FROM runway_equipment;
DELETE FROM equipment_dependency;
DELETE FROM equipment;
DELETE FROM aircraft;

-- Facility graph (staff / geo first)
DELETE FROM facility_staff_assignment;
DELETE FROM simulation_geo_location_lookup;
DELETE FROM simulation_snapshot;
DELETE FROM simulation_schedule_event;
DELETE FROM simulation_schedule_run;
DELETE FROM simulation_schedule;
UPDATE user_permissions SET facility_scope_id = NULL WHERE facility_scope_id IS NOT NULL;
UPDATE runway SET occupied_by_flight_operation_id = NULL;
DELETE FROM runway;
DELETE FROM facility;

COMMIT;
