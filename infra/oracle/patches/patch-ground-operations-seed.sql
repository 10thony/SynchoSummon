-- Seed ground operations lookup data and reference updates (run after patch-ground-operations.sql)

ALTER SESSION SET CONTAINER = FREEPDB1;
ALTER SESSION SET CURRENT_SCHEMA = nas_sim;

INSERT INTO flight_phase_lkp (phase_code, display_name, sort_order)
SELECT 'GROUND_OPS', 'Ground Operations', 2 FROM dual
WHERE NOT EXISTS (SELECT 1 FROM flight_phase_lkp WHERE phase_code = 'GROUND_OPS');

UPDATE flight_phase_lkp SET sort_order = 3 WHERE phase_code = 'BOARDING' AND sort_order = 2;
UPDATE flight_phase_lkp SET sort_order = 4 WHERE phase_code = 'TAXI_OUT' AND sort_order = 3;
UPDATE flight_phase_lkp SET sort_order = 5 WHERE phase_code = 'DEPARTED' AND sort_order = 4;
UPDATE flight_phase_lkp SET sort_order = 6 WHERE phase_code = 'ENROUTE' AND sort_order = 5;
UPDATE flight_phase_lkp SET sort_order = 7 WHERE phase_code = 'APPROACH' AND sort_order = 6;
UPDATE flight_phase_lkp SET sort_order = 8 WHERE phase_code = 'LANDED' AND sort_order = 7;
UPDATE flight_phase_lkp SET sort_order = 9 WHERE phase_code = 'TAXI_IN' AND sort_order = 8;
UPDATE flight_phase_lkp SET sort_order = 10 WHERE phase_code = 'COMPLETE' AND sort_order = 9;
UPDATE flight_phase_lkp SET sort_order = 11 WHERE phase_code = 'DELAYED' AND sort_order = 10;
UPDATE flight_phase_lkp SET sort_order = 12 WHERE phase_code = 'CANCELLED' AND sort_order = 11;
UPDATE flight_phase_lkp SET sort_order = 13 WHERE phase_code = 'DIVERTED' AND sort_order = 12;

MERGE INTO flight_event_type_lkp t USING (SELECT 'GROUND_OPS_STARTED' c, 'Ground Operations Started' d, 'GROUND_OPS' cat FROM dual) s
ON (t.event_type_code = s.c) WHEN NOT MATCHED THEN INSERT (event_type_code, display_name, category) VALUES (s.c, s.d, s.cat);
MERGE INTO flight_event_type_lkp t USING (SELECT 'GROUND_OP_STARTED' c, 'Ground Activity Started' d, 'GROUND_OPS' cat FROM dual) s
ON (t.event_type_code = s.c) WHEN NOT MATCHED THEN INSERT (event_type_code, display_name, category) VALUES (s.c, s.d, s.cat);
MERGE INTO flight_event_type_lkp t USING (SELECT 'GROUND_OP_PROGRESS' c, 'Ground Activity Progress' d, 'GROUND_OPS' cat FROM dual) s
ON (t.event_type_code = s.c) WHEN NOT MATCHED THEN INSERT (event_type_code, display_name, category) VALUES (s.c, s.d, s.cat);
MERGE INTO flight_event_type_lkp t USING (SELECT 'GROUND_OP_COMPLETED' c, 'Ground Activity Completed' d, 'GROUND_OPS' cat FROM dual) s
ON (t.event_type_code = s.c) WHEN NOT MATCHED THEN INSERT (event_type_code, display_name, category) VALUES (s.c, s.d, s.cat);
MERGE INTO flight_event_type_lkp t USING (SELECT 'GROUND_OPS_ALL_COMPLETE' c, 'All Ground Ops Complete' d, 'GROUND_OPS' cat FROM dual) s
ON (t.event_type_code = s.c) WHEN NOT MATCHED THEN INSERT (event_type_code, display_name, category) VALUES (s.c, s.d, s.cat);
MERGE INTO flight_event_type_lkp t USING (SELECT 'INCIDENT_OCCURRED' c, 'Incident Occurred' d, 'INCIDENT' cat FROM dual) s
ON (t.event_type_code = s.c) WHEN NOT MATCHED THEN INSERT (event_type_code, display_name, category) VALUES (s.c, s.d, s.cat);

MERGE INTO ground_operation_activity_type_lkp t USING (SELECT 'PASSENGER_BOARDING' c FROM dual) s ON (t.activity_type_code = s.c)
WHEN NOT MATCHED THEN INSERT (activity_type_code, display_name, default_duration_min, required_for_departure, sort_order, description)
VALUES ('PASSENGER_BOARDING', 'Passenger Boarding', 45, 'Y', 1, 'Passenger boarding at gate');
MERGE INTO ground_operation_activity_type_lkp t USING (SELECT 'AIRCRAFT_FUELING' c FROM dual) s ON (t.activity_type_code = s.c)
WHEN NOT MATCHED THEN INSERT (activity_type_code, display_name, default_duration_min, required_for_departure, sort_order, description)
VALUES ('AIRCRAFT_FUELING', 'Aircraft Fueling', 25, 'Y', 2, 'Refueling aircraft on ramp');
MERGE INTO ground_operation_activity_type_lkp t USING (SELECT 'CARGO_LOADING' c FROM dual) s ON (t.activity_type_code = s.c)
WHEN NOT MATCHED THEN INSERT (activity_type_code, display_name, default_duration_min, required_for_departure, sort_order, description)
VALUES ('CARGO_LOADING', 'Cargo Loading', 30, 'N', 3, 'Baggage and freight loading');
MERGE INTO ground_operation_activity_type_lkp t USING (SELECT 'CREW_LOADING' c FROM dual) s ON (t.activity_type_code = s.c)
WHEN NOT MATCHED THEN INSERT (activity_type_code, display_name, default_duration_min, required_for_departure, sort_order, description)
VALUES ('CREW_LOADING', 'Crew Loading', 15, 'Y', 4, 'Flight and cabin crew boarding');

MERGE INTO ground_operation_status_lkp t USING (SELECT 'PLANNED' c FROM dual) s ON (t.status_code = s.c) WHEN NOT MATCHED THEN INSERT VALUES ('PLANNED', 'Planned', 'N');
MERGE INTO ground_operation_status_lkp t USING (SELECT 'IN_PROGRESS' c FROM dual) s ON (t.status_code = s.c) WHEN NOT MATCHED THEN INSERT VALUES ('IN_PROGRESS', 'In Progress', 'N');
MERGE INTO ground_operation_status_lkp t USING (SELECT 'PAUSED' c FROM dual) s ON (t.status_code = s.c) WHEN NOT MATCHED THEN INSERT VALUES ('PAUSED', 'Paused', 'N');
MERGE INTO ground_operation_status_lkp t USING (SELECT 'BLOCKED' c FROM dual) s ON (t.status_code = s.c) WHEN NOT MATCHED THEN INSERT VALUES ('BLOCKED', 'Blocked', 'N');
MERGE INTO ground_operation_status_lkp t USING (SELECT 'COMPLETED' c FROM dual) s ON (t.status_code = s.c) WHEN NOT MATCHED THEN INSERT VALUES ('COMPLETED', 'Completed', 'Y');
MERGE INTO ground_operation_status_lkp t USING (SELECT 'CANCELLED' c FROM dual) s ON (t.status_code = s.c) WHEN NOT MATCHED THEN INSERT VALUES ('CANCELLED', 'Cancelled', 'Y');

MERGE INTO global_configuration t USING (SELECT 'simulation.ground_ops.incident_probability_per_tick' k FROM dual) s ON (t.config_key = s.k)
WHEN NOT MATCHED THEN INSERT (config_key, config_value, value_type, description) VALUES ('simulation.ground_ops.incident_probability_per_tick', '0.0001', 'NUMBER', 'Probability of random passenger incident per tick during boarding');
MERGE INTO global_configuration t USING (SELECT 'simulation.ground_ops.lead_time_minutes' k FROM dual) s ON (t.config_key = s.k)
WHEN NOT MATCHED THEN INSERT (config_key, config_value, value_type, description) VALUES ('simulation.ground_ops.lead_time_minutes', '90', 'NUMBER', 'Minutes before scheduled departure to auto-enter GROUND_OPS');
MERGE INTO global_configuration t USING (SELECT 'simulation.ground_ops.progress_broadcast_threshold_pct' k FROM dual) s ON (t.config_key = s.k)
WHEN NOT MATCHED THEN INSERT (config_key, config_value, value_type, description) VALUES ('simulation.ground_ops.progress_broadcast_threshold_pct', '10', 'NUMBER', 'Min progress change before broadcast');

COMMIT;
