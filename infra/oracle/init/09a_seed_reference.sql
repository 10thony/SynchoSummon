-- =============================================================================
-- Reference seed data (lookup tables only — no operational simulation data)
-- =============================================================================

ALTER SESSION SET CONTAINER = FREEPDB1;
ALTER SESSION SET CURRENT_SCHEMA = nas_sim;

-- Facility types
MERGE INTO facility_type_lkp t
USING (SELECT 'AIRPORT' AS facility_type_code FROM dual) s
ON (t.facility_type_code = s.facility_type_code)
WHEN NOT MATCHED THEN INSERT (facility_type_code, display_name, description) VALUES ('AIRPORT', 'Airport', 'Airfield with runways and terminal operations');
MERGE INTO facility_type_lkp t
USING (SELECT 'ARTCC' AS facility_type_code FROM dual) s
ON (t.facility_type_code = s.facility_type_code)
WHEN NOT MATCHED THEN INSERT (facility_type_code, display_name, description) VALUES ('ARTCC', 'Air Route Traffic Control Center', 'En-route ATC facility');
MERGE INTO facility_type_lkp t
USING (SELECT 'TRACON' AS facility_type_code FROM dual) s
ON (t.facility_type_code = s.facility_type_code)
WHEN NOT MATCHED THEN INSERT (facility_type_code, display_name, description) VALUES ('TRACON', 'Terminal Radar Approach Control', 'Terminal ATC facility');
MERGE INTO facility_type_lkp t
USING (SELECT 'MAINTENANCE_DEPOT' AS facility_type_code FROM dual) s
ON (t.facility_type_code = s.facility_type_code)
WHEN NOT MATCHED THEN INSERT (facility_type_code, display_name, description) VALUES ('MAINTENANCE_DEPOT', 'Maintenance Depot', 'Central maintenance and parts storage');
MERGE INTO facility_type_lkp t
USING (SELECT 'RADAR_SITE' AS facility_type_code FROM dual) s
ON (t.facility_type_code = s.facility_type_code)
WHEN NOT MATCHED THEN INSERT (facility_type_code, display_name, description) VALUES ('RADAR_SITE', 'Radar Site', 'Surveillance radar installation');
MERGE INTO facility_type_lkp t
USING (SELECT 'NAVAID_SITE' AS facility_type_code FROM dual) s
ON (t.facility_type_code = s.facility_type_code)
WHEN NOT MATCHED THEN INSERT (facility_type_code, display_name, description) VALUES ('NAVAID_SITE', 'NAVAID Site', 'Standalone navigation aid');

-- Operational statuses
MERGE INTO operational_status_lkp t
USING (SELECT 'OPERATIONAL' AS status_code, 'FACILITY' AS applies_to_entity FROM dual) s
ON (t.status_code = s.status_code AND t.applies_to_entity = s.applies_to_entity)
WHEN NOT MATCHED THEN INSERT (status_code, display_name, applies_to_entity, sort_order) VALUES ('OPERATIONAL', 'Operational', 'FACILITY', 1);
MERGE INTO operational_status_lkp t
USING (SELECT 'DEGRADED' AS status_code, 'FACILITY' AS applies_to_entity FROM dual) s
ON (t.status_code = s.status_code AND t.applies_to_entity = s.applies_to_entity)
WHEN NOT MATCHED THEN INSERT (status_code, display_name, applies_to_entity, sort_order) VALUES ('DEGRADED', 'Degraded', 'FACILITY', 2);
MERGE INTO operational_status_lkp t
USING (SELECT 'CLOSED' AS status_code, 'FACILITY' AS applies_to_entity FROM dual) s
ON (t.status_code = s.status_code AND t.applies_to_entity = s.applies_to_entity)
WHEN NOT MATCHED THEN INSERT (status_code, display_name, applies_to_entity, sort_order) VALUES ('CLOSED', 'Closed', 'FACILITY', 3);
MERGE INTO operational_status_lkp t
USING (SELECT 'OPEN' AS status_code, 'RUNWAY' AS applies_to_entity FROM dual) s
ON (t.status_code = s.status_code AND t.applies_to_entity = s.applies_to_entity)
WHEN NOT MATCHED THEN INSERT (status_code, display_name, applies_to_entity, sort_order) VALUES ('OPEN', 'Open', 'RUNWAY', 1);
MERGE INTO operational_status_lkp t
USING (SELECT 'CLOSED' AS status_code, 'RUNWAY' AS applies_to_entity FROM dual) s
ON (t.status_code = s.status_code AND t.applies_to_entity = s.applies_to_entity)
WHEN NOT MATCHED THEN INSERT (status_code, display_name, applies_to_entity, sort_order) VALUES ('CLOSED', 'Closed', 'RUNWAY', 2);
MERGE INTO operational_status_lkp t
USING (SELECT 'RESTRICTED' AS status_code, 'RUNWAY' AS applies_to_entity FROM dual) s
ON (t.status_code = s.status_code AND t.applies_to_entity = s.applies_to_entity)
WHEN NOT MATCHED THEN INSERT (status_code, display_name, applies_to_entity, sort_order) VALUES ('RESTRICTED', 'Restricted', 'RUNWAY', 3);
MERGE INTO operational_status_lkp t
USING (SELECT 'OPERATIONAL' AS status_code, 'EQUIPMENT' AS applies_to_entity FROM dual) s
ON (t.status_code = s.status_code AND t.applies_to_entity = s.applies_to_entity)
WHEN NOT MATCHED THEN INSERT (status_code, display_name, applies_to_entity, sort_order) VALUES ('OPERATIONAL', 'Operational', 'EQUIPMENT', 1);
MERGE INTO operational_status_lkp t
USING (SELECT 'DEGRADED' AS status_code, 'EQUIPMENT' AS applies_to_entity FROM dual) s
ON (t.status_code = s.status_code AND t.applies_to_entity = s.applies_to_entity)
WHEN NOT MATCHED THEN INSERT (status_code, display_name, applies_to_entity, sort_order) VALUES ('DEGRADED', 'Degraded', 'EQUIPMENT', 2);
MERGE INTO operational_status_lkp t
USING (SELECT 'FAILED' AS status_code, 'EQUIPMENT' AS applies_to_entity FROM dual) s
ON (t.status_code = s.status_code AND t.applies_to_entity = s.applies_to_entity)
WHEN NOT MATCHED THEN INSERT (status_code, display_name, applies_to_entity, sort_order) VALUES ('FAILED', 'Failed', 'EQUIPMENT', 3);
MERGE INTO operational_status_lkp t
USING (SELECT 'MAINTENANCE' AS status_code, 'EQUIPMENT' AS applies_to_entity FROM dual) s
ON (t.status_code = s.status_code AND t.applies_to_entity = s.applies_to_entity)
WHEN NOT MATCHED THEN INSERT (status_code, display_name, applies_to_entity, sort_order) VALUES ('MAINTENANCE', 'Under Maintenance', 'EQUIPMENT', 4);

-- Equipment types
MERGE INTO equipment_type_lkp t
USING (SELECT 'ILS' AS equipment_type_code FROM dual) s
ON (t.equipment_type_code = s.equipment_type_code)
WHEN NOT MATCHED THEN INSERT (equipment_type_code, display_name, category) VALUES ('ILS', 'Instrument Landing System', 'NAVAID');
MERGE INTO equipment_type_lkp t
USING (SELECT 'VOR' AS equipment_type_code FROM dual) s
ON (t.equipment_type_code = s.equipment_type_code)
WHEN NOT MATCHED THEN INSERT (equipment_type_code, display_name, category) VALUES ('VOR', 'VHF Omnidirectional Range', 'NAVAID');
MERGE INTO equipment_type_lkp t
USING (SELECT 'DME' AS equipment_type_code FROM dual) s
ON (t.equipment_type_code = s.equipment_type_code)
WHEN NOT MATCHED THEN INSERT (equipment_type_code, display_name, category) VALUES ('DME', 'Distance Measuring Equipment', 'NAVAID');
MERGE INTO equipment_type_lkp t
USING (SELECT 'RADAR_ASR' AS equipment_type_code FROM dual) s
ON (t.equipment_type_code = s.equipment_type_code)
WHEN NOT MATCHED THEN INSERT (equipment_type_code, display_name, category) VALUES ('RADAR_ASR', 'Airport Surveillance Radar', 'RADAR');
MERGE INTO equipment_type_lkp t
USING (SELECT 'RADAR_ARR' AS equipment_type_code FROM dual) s
ON (t.equipment_type_code = s.equipment_type_code)
WHEN NOT MATCHED THEN INSERT (equipment_type_code, display_name, category) VALUES ('RADAR_ARR', 'Air Route Surveillance Radar', 'RADAR');
MERGE INTO equipment_type_lkp t
USING (SELECT 'COM_VHF' AS equipment_type_code FROM dual) s
ON (t.equipment_type_code = s.equipment_type_code)
WHEN NOT MATCHED THEN INSERT (equipment_type_code, display_name, category) VALUES ('COM_VHF', 'VHF Communications', 'COMMS');
MERGE INTO equipment_type_lkp t
USING (SELECT 'COM_UHF' AS equipment_type_code FROM dual) s
ON (t.equipment_type_code = s.equipment_type_code)
WHEN NOT MATCHED THEN INSERT (equipment_type_code, display_name, category) VALUES ('COM_UHF', 'UHF Communications', 'COMMS');
MERGE INTO equipment_type_lkp t
USING (SELECT 'PAPI' AS equipment_type_code FROM dual) s
ON (t.equipment_type_code = s.equipment_type_code)
WHEN NOT MATCHED THEN INSERT (equipment_type_code, display_name, category) VALUES ('PAPI', 'Precision Approach Path Indicator', 'LIGHTING');
MERGE INTO equipment_type_lkp t
USING (SELECT 'RWY_LIGHTING' AS equipment_type_code FROM dual) s
ON (t.equipment_type_code = s.equipment_type_code)
WHEN NOT MATCHED THEN INSERT (equipment_type_code, display_name, category) VALUES ('RWY_LIGHTING', 'Runway Lighting System', 'LIGHTING');

-- Maintenance
MERGE INTO maintenance_activity_type_lkp t
USING (SELECT 'INSPECTION' AS activity_type_code FROM dual) s
ON (t.activity_type_code = s.activity_type_code)
WHEN NOT MATCHED THEN INSERT (activity_type_code, display_name) VALUES ('INSPECTION', 'Routine Inspection');
MERGE INTO maintenance_activity_type_lkp t
USING (SELECT 'CORRECTIVE' AS activity_type_code FROM dual) s
ON (t.activity_type_code = s.activity_type_code)
WHEN NOT MATCHED THEN INSERT (activity_type_code, display_name) VALUES ('CORRECTIVE', 'Corrective Maintenance');
MERGE INTO maintenance_activity_type_lkp t
USING (SELECT 'PREVENTIVE' AS activity_type_code FROM dual) s
ON (t.activity_type_code = s.activity_type_code)
WHEN NOT MATCHED THEN INSERT (activity_type_code, display_name) VALUES ('PREVENTIVE', 'Preventive Maintenance');
MERGE INTO maintenance_activity_type_lkp t
USING (SELECT 'EMERGENCY' AS activity_type_code FROM dual) s
ON (t.activity_type_code = s.activity_type_code)
WHEN NOT MATCHED THEN INSERT (activity_type_code, display_name) VALUES ('EMERGENCY', 'Emergency Repair');
MERGE INTO maintenance_activity_type_lkp t
USING (SELECT 'CALIBRATION' AS activity_type_code FROM dual) s
ON (t.activity_type_code = s.activity_type_code)
WHEN NOT MATCHED THEN INSERT (activity_type_code, display_name) VALUES ('CALIBRATION', 'Calibration');

MERGE INTO maintenance_status_lkp t
USING (SELECT 'PLANNED' AS status_code FROM dual) s
ON (t.status_code = s.status_code)
WHEN NOT MATCHED THEN INSERT (status_code, display_name, is_terminal) VALUES ('PLANNED', 'Planned', 'N');
MERGE INTO maintenance_status_lkp t
USING (SELECT 'SCHEDULED' AS status_code FROM dual) s
ON (t.status_code = s.status_code)
WHEN NOT MATCHED THEN INSERT (status_code, display_name, is_terminal) VALUES ('SCHEDULED', 'Scheduled', 'N');
MERGE INTO maintenance_status_lkp t
USING (SELECT 'DISPATCHED' AS status_code FROM dual) s
ON (t.status_code = s.status_code)
WHEN NOT MATCHED THEN INSERT (status_code, display_name, is_terminal) VALUES ('DISPATCHED', 'Crew Dispatched', 'N');
MERGE INTO maintenance_status_lkp t
USING (SELECT 'IN_PROGRESS' AS status_code FROM dual) s
ON (t.status_code = s.status_code)
WHEN NOT MATCHED THEN INSERT (status_code, display_name, is_terminal) VALUES ('IN_PROGRESS', 'In Progress', 'N');
MERGE INTO maintenance_status_lkp t
USING (SELECT 'COMPLETED' AS status_code FROM dual) s
ON (t.status_code = s.status_code)
WHEN NOT MATCHED THEN INSERT (status_code, display_name, is_terminal) VALUES ('COMPLETED', 'Completed', 'Y');
MERGE INTO maintenance_status_lkp t
USING (SELECT 'CANCELLED' AS status_code FROM dual) s
ON (t.status_code = s.status_code)
WHEN NOT MATCHED THEN INSERT (status_code, display_name, is_terminal) VALUES ('CANCELLED', 'Cancelled', 'Y');

-- Flight phases
MERGE INTO flight_phase_lkp t
USING (SELECT 'SCHEDULED' AS phase_code FROM dual) s
ON (t.phase_code = s.phase_code)
WHEN NOT MATCHED THEN INSERT (phase_code, display_name, sort_order) VALUES ('SCHEDULED', 'Scheduled', 1);
MERGE INTO flight_phase_lkp t
USING (SELECT 'GROUND_OPS' AS phase_code FROM dual) s
ON (t.phase_code = s.phase_code)
WHEN NOT MATCHED THEN INSERT (phase_code, display_name, sort_order) VALUES ('GROUND_OPS', 'Ground Operations', 2);
MERGE INTO flight_phase_lkp t
USING (SELECT 'BOARDING' AS phase_code FROM dual) s
ON (t.phase_code = s.phase_code)
WHEN NOT MATCHED THEN INSERT (phase_code, display_name, sort_order) VALUES ('BOARDING', 'Boarding', 3);
MERGE INTO flight_phase_lkp t
USING (SELECT 'TAXI_OUT' AS phase_code FROM dual) s
ON (t.phase_code = s.phase_code)
WHEN NOT MATCHED THEN INSERT (phase_code, display_name, sort_order) VALUES ('TAXI_OUT', 'Taxi Out', 4);
MERGE INTO flight_phase_lkp t
USING (SELECT 'DEPARTED' AS phase_code FROM dual) s
ON (t.phase_code = s.phase_code)
WHEN NOT MATCHED THEN INSERT (phase_code, display_name, sort_order) VALUES ('DEPARTED', 'Departed', 5);
MERGE INTO flight_phase_lkp t
USING (SELECT 'ENROUTE' AS phase_code FROM dual) s
ON (t.phase_code = s.phase_code)
WHEN NOT MATCHED THEN INSERT (phase_code, display_name, sort_order) VALUES ('ENROUTE', 'En Route', 6);
MERGE INTO flight_phase_lkp t
USING (SELECT 'APPROACH' AS phase_code FROM dual) s
ON (t.phase_code = s.phase_code)
WHEN NOT MATCHED THEN INSERT (phase_code, display_name, sort_order) VALUES ('APPROACH', 'Approach', 7);
MERGE INTO flight_phase_lkp t
USING (SELECT 'LANDED' AS phase_code FROM dual) s
ON (t.phase_code = s.phase_code)
WHEN NOT MATCHED THEN INSERT (phase_code, display_name, sort_order) VALUES ('LANDED', 'Landed', 8);
MERGE INTO flight_phase_lkp t
USING (SELECT 'TAXI_IN' AS phase_code FROM dual) s
ON (t.phase_code = s.phase_code)
WHEN NOT MATCHED THEN INSERT (phase_code, display_name, sort_order) VALUES ('TAXI_IN', 'Taxi In', 9);
MERGE INTO flight_phase_lkp t
USING (SELECT 'COMPLETE' AS phase_code FROM dual) s
ON (t.phase_code = s.phase_code)
WHEN NOT MATCHED THEN INSERT (phase_code, display_name, sort_order) VALUES ('COMPLETE', 'Complete', 10);
MERGE INTO flight_phase_lkp t
USING (SELECT 'DELAYED' AS phase_code FROM dual) s
ON (t.phase_code = s.phase_code)
WHEN NOT MATCHED THEN INSERT (phase_code, display_name, sort_order) VALUES ('DELAYED', 'Delayed', 11);
MERGE INTO flight_phase_lkp t
USING (SELECT 'CANCELLED' AS phase_code FROM dual) s
ON (t.phase_code = s.phase_code)
WHEN NOT MATCHED THEN INSERT (phase_code, display_name, sort_order) VALUES ('CANCELLED', 'Cancelled', 12);
MERGE INTO flight_phase_lkp t
USING (SELECT 'DIVERTED' AS phase_code FROM dual) s
ON (t.phase_code = s.phase_code)
WHEN NOT MATCHED THEN INSERT (phase_code, display_name, sort_order) VALUES ('DIVERTED', 'Diverted', 13);

-- Flight event types (simulation event stream)
MERGE INTO flight_event_type_lkp t
USING (SELECT 'FLIGHT_SCHEDULED' AS event_type_code FROM dual) s
ON (t.event_type_code = s.event_type_code)
WHEN NOT MATCHED THEN INSERT (event_type_code, display_name, category) VALUES ('FLIGHT_SCHEDULED', 'Flight Scheduled', 'OPERATIONAL');
MERGE INTO flight_event_type_lkp t
USING (SELECT 'PHASE_CHANGED' AS event_type_code FROM dual) s
ON (t.event_type_code = s.event_type_code)
WHEN NOT MATCHED THEN INSERT (event_type_code, display_name, category) VALUES ('PHASE_CHANGED', 'Phase Changed', 'OPERATIONAL');
MERGE INTO flight_event_type_lkp t
USING (SELECT 'DELAYED' AS event_type_code FROM dual) s
ON (t.event_type_code = s.event_type_code)
WHEN NOT MATCHED THEN INSERT (event_type_code, display_name, category) VALUES ('DELAYED', 'Flight Delayed', 'DELAY');
MERGE INTO flight_event_type_lkp t
USING (SELECT 'CANCELLED' AS event_type_code FROM dual) s
ON (t.event_type_code = s.event_type_code)
WHEN NOT MATCHED THEN INSERT (event_type_code, display_name, category) VALUES ('CANCELLED', 'Flight Cancelled', 'DELAY');
MERGE INTO flight_event_type_lkp t
USING (SELECT 'DIVERTED' AS event_type_code FROM dual) s
ON (t.event_type_code = s.event_type_code)
WHEN NOT MATCHED THEN INSERT (event_type_code, display_name, category) VALUES ('DIVERTED', 'Flight Diverted', 'DIVERSION');
MERGE INTO flight_event_type_lkp t
USING (SELECT 'RUNWAY_ASSIGNED' AS event_type_code FROM dual) s
ON (t.event_type_code = s.event_type_code)
WHEN NOT MATCHED THEN INSERT (event_type_code, display_name, category) VALUES ('RUNWAY_ASSIGNED', 'Runway Assigned', 'ATC');
MERGE INTO flight_event_type_lkp t
USING (SELECT 'PATH_UPDATED' AS event_type_code FROM dual) s
ON (t.event_type_code = s.event_type_code)
WHEN NOT MATCHED THEN INSERT (event_type_code, display_name, category) VALUES ('PATH_UPDATED', 'Flight Path Updated', 'ATC');
MERGE INTO flight_event_type_lkp t
USING (SELECT 'WEATHER_IMPACT' AS event_type_code FROM dual) s
ON (t.event_type_code = s.event_type_code)
WHEN NOT MATCHED THEN INSERT (event_type_code, display_name, category) VALUES ('WEATHER_IMPACT', 'Weather Impact', 'WEATHER');
MERGE INTO flight_event_type_lkp t
USING (SELECT 'EQUIPMENT_IMPACT' AS event_type_code FROM dual) s
ON (t.event_type_code = s.event_type_code)
WHEN NOT MATCHED THEN INSERT (event_type_code, display_name, category) VALUES ('EQUIPMENT_IMPACT', 'Equipment Impact', 'EQUIPMENT');
MERGE INTO flight_event_type_lkp t
USING (SELECT 'GROUND_OPS_STARTED' AS event_type_code FROM dual) s
ON (t.event_type_code = s.event_type_code)
WHEN NOT MATCHED THEN INSERT (event_type_code, display_name, category) VALUES ('GROUND_OPS_STARTED', 'Ground Operations Started', 'GROUND_OPS');
MERGE INTO flight_event_type_lkp t
USING (SELECT 'GROUND_OP_STARTED' AS event_type_code FROM dual) s
ON (t.event_type_code = s.event_type_code)
WHEN NOT MATCHED THEN INSERT (event_type_code, display_name, category) VALUES ('GROUND_OP_STARTED', 'Ground Activity Started', 'GROUND_OPS');
MERGE INTO flight_event_type_lkp t
USING (SELECT 'GROUND_OP_PROGRESS' AS event_type_code FROM dual) s
ON (t.event_type_code = s.event_type_code)
WHEN NOT MATCHED THEN INSERT (event_type_code, display_name, category) VALUES ('GROUND_OP_PROGRESS', 'Ground Activity Progress', 'GROUND_OPS');
MERGE INTO flight_event_type_lkp t
USING (SELECT 'GROUND_OP_COMPLETED' AS event_type_code FROM dual) s
ON (t.event_type_code = s.event_type_code)
WHEN NOT MATCHED THEN INSERT (event_type_code, display_name, category) VALUES ('GROUND_OP_COMPLETED', 'Ground Activity Completed', 'GROUND_OPS');
MERGE INTO flight_event_type_lkp t
USING (SELECT 'GROUND_OPS_ALL_COMPLETE' AS event_type_code FROM dual) s
ON (t.event_type_code = s.event_type_code)
WHEN NOT MATCHED THEN INSERT (event_type_code, display_name, category) VALUES ('GROUND_OPS_ALL_COMPLETE', 'All Ground Ops Complete', 'GROUND_OPS');
MERGE INTO flight_event_type_lkp t
USING (SELECT 'INCIDENT_OCCURRED' AS event_type_code FROM dual) s
ON (t.event_type_code = s.event_type_code)
WHEN NOT MATCHED THEN INSERT (event_type_code, display_name, category) VALUES ('INCIDENT_OCCURRED', 'Incident Occurred', 'INCIDENT');

-- Incident types (behavior_json drives simulation response per incident)
MERGE INTO incident_type_lkp t
USING (SELECT 'GO_AROUND' AS incident_type_code FROM dual) s
ON (t.incident_type_code = s.incident_type_code)
WHEN NOT MATCHED THEN INSERT (incident_type_code, display_name, default_severity, behavior_json) VALUES ('GO_AROUND', 'Go Around', 'LOW', q'[{"affectsActivityTypes":["PASSENGER_BOARDING"],"action":"PAUSE","delayMinutes":0}]');
MERGE INTO incident_type_lkp t
USING (SELECT 'DIVERSION' AS incident_type_code FROM dual) s
ON (t.incident_type_code = s.incident_type_code)
WHEN NOT MATCHED THEN INSERT (incident_type_code, display_name, default_severity, behavior_json) VALUES ('DIVERSION', 'Diversion', 'MEDIUM', q'[{"affectsActivityTypes":[],"action":"CANCEL_FLIGHT","delayMinutes":0}]');
MERGE INTO incident_type_lkp t
USING (SELECT 'EQUIPMENT_FAILURE' AS incident_type_code FROM dual) s
ON (t.incident_type_code = s.incident_type_code)
WHEN NOT MATCHED THEN INSERT (incident_type_code, display_name, default_severity, behavior_json) VALUES ('EQUIPMENT_FAILURE', 'Equipment Failure Impact', 'HIGH', q'[{"affectsActivityTypes":["AIRCRAFT_FUELING","CARGO_LOADING"],"action":"PAUSE","delayMinutes":30}]');
MERGE INTO incident_type_lkp t
USING (SELECT 'WEATHER_HOLD' AS incident_type_code FROM dual) s
ON (t.incident_type_code = s.incident_type_code)
WHEN NOT MATCHED THEN INSERT (incident_type_code, display_name, default_severity, behavior_json) VALUES ('WEATHER_HOLD', 'Weather Hold', 'MEDIUM', q'[{"affectsActivityTypes":[],"action":"PAUSE","delayMinutes":45}]');
MERGE INTO incident_type_lkp t
USING (SELECT 'RUNWAY_INCURSION' AS incident_type_code FROM dual) s
ON (t.incident_type_code = s.incident_type_code)
WHEN NOT MATCHED THEN INSERT (incident_type_code, display_name, default_severity, behavior_json) VALUES ('RUNWAY_INCURSION', 'Runway Incursion', 'CRITICAL', q'[{"affectsActivityTypes":[],"action":"PAUSE","delayMinutes":60}]');
MERGE INTO incident_type_lkp t
USING (SELECT 'PASSENGER_REMOVAL' AS incident_type_code FROM dual) s
ON (t.incident_type_code = s.incident_type_code)
WHEN NOT MATCHED THEN INSERT (incident_type_code, display_name, default_severity, behavior_json) VALUES ('PASSENGER_REMOVAL', 'Passenger Removal', 'MEDIUM', q'[{"affectsActivityTypes":["PASSENGER_BOARDING"],"action":"RESET","delayMinutes":20,"progressResetTo":0}]');
MERGE INTO incident_type_lkp t
USING (SELECT 'PASSENGER_DISRUPTION' AS incident_type_code FROM dual) s
ON (t.incident_type_code = s.incident_type_code)
WHEN NOT MATCHED THEN INSERT (incident_type_code, display_name, default_severity, behavior_json) VALUES ('PASSENGER_DISRUPTION', 'Passenger Disruption', 'LOW', q'[{"affectsActivityTypes":["PASSENGER_BOARDING"],"action":"PAUSE","delayMinutes":10}]');
MERGE INTO incident_type_lkp t
USING (SELECT 'SECURITY_INCIDENT' AS incident_type_code FROM dual) s
ON (t.incident_type_code = s.incident_type_code)
WHEN NOT MATCHED THEN INSERT (incident_type_code, display_name, default_severity, behavior_json) VALUES ('SECURITY_INCIDENT', 'Security Incident', 'HIGH', q'[{"affectsActivityTypes":["PASSENGER_BOARDING","CREW_LOADING"],"action":"PAUSE","delayMinutes":30}]');
MERGE INTO incident_type_lkp t
USING (SELECT 'FUELING_DELAY' AS incident_type_code FROM dual) s
ON (t.incident_type_code = s.incident_type_code)
WHEN NOT MATCHED THEN INSERT (incident_type_code, display_name, default_severity, behavior_json) VALUES ('FUELING_DELAY', 'Fueling Delay', 'LOW', q'[{"affectsActivityTypes":["AIRCRAFT_FUELING"],"action":"PAUSE","delayMinutes":15}]');

-- Ground operation activity types
MERGE INTO ground_operation_activity_type_lkp t
USING (SELECT 'PASSENGER_BOARDING' AS activity_type_code FROM dual) s
ON (t.activity_type_code = s.activity_type_code)
WHEN NOT MATCHED THEN INSERT (activity_type_code, display_name, default_duration_min, required_for_departure, sort_order, description) VALUES ('PASSENGER_BOARDING', 'Passenger Boarding', 45, 'Y', 1, 'Passenger boarding at gate');
MERGE INTO ground_operation_activity_type_lkp t
USING (SELECT 'AIRCRAFT_FUELING' AS activity_type_code FROM dual) s
ON (t.activity_type_code = s.activity_type_code)
WHEN NOT MATCHED THEN INSERT (activity_type_code, display_name, default_duration_min, required_for_departure, sort_order, description) VALUES ('AIRCRAFT_FUELING', 'Aircraft Fueling', 25, 'Y', 2, 'Refueling aircraft on ramp');
MERGE INTO ground_operation_activity_type_lkp t
USING (SELECT 'CARGO_LOADING' AS activity_type_code FROM dual) s
ON (t.activity_type_code = s.activity_type_code)
WHEN NOT MATCHED THEN INSERT (activity_type_code, display_name, default_duration_min, required_for_departure, sort_order, description) VALUES ('CARGO_LOADING', 'Cargo Loading', 30, 'N', 3, 'Baggage and freight loading (required for cargo flights via metadata)');
MERGE INTO ground_operation_activity_type_lkp t
USING (SELECT 'CREW_LOADING' AS activity_type_code FROM dual) s
ON (t.activity_type_code = s.activity_type_code)
WHEN NOT MATCHED THEN INSERT (activity_type_code, display_name, default_duration_min, required_for_departure, sort_order, description) VALUES ('CREW_LOADING', 'Crew Loading', 15, 'Y', 4, 'Flight and cabin crew boarding');

-- Ground operation statuses
MERGE INTO ground_operation_status_lkp t
USING (SELECT 'PLANNED' AS status_code FROM dual) s
ON (t.status_code = s.status_code)
WHEN NOT MATCHED THEN INSERT (status_code, display_name, is_terminal) VALUES ('PLANNED', 'Planned', 'N');
MERGE INTO ground_operation_status_lkp t
USING (SELECT 'IN_PROGRESS' AS status_code FROM dual) s
ON (t.status_code = s.status_code)
WHEN NOT MATCHED THEN INSERT (status_code, display_name, is_terminal) VALUES ('IN_PROGRESS', 'In Progress', 'N');
MERGE INTO ground_operation_status_lkp t
USING (SELECT 'PAUSED' AS status_code FROM dual) s
ON (t.status_code = s.status_code)
WHEN NOT MATCHED THEN INSERT (status_code, display_name, is_terminal) VALUES ('PAUSED', 'Paused', 'N');
MERGE INTO ground_operation_status_lkp t
USING (SELECT 'BLOCKED' AS status_code FROM dual) s
ON (t.status_code = s.status_code)
WHEN NOT MATCHED THEN INSERT (status_code, display_name, is_terminal) VALUES ('BLOCKED', 'Blocked', 'N');
MERGE INTO ground_operation_status_lkp t
USING (SELECT 'COMPLETED' AS status_code FROM dual) s
ON (t.status_code = s.status_code)
WHEN NOT MATCHED THEN INSERT (status_code, display_name, is_terminal) VALUES ('COMPLETED', 'Completed', 'Y');
MERGE INTO ground_operation_status_lkp t
USING (SELECT 'CANCELLED' AS status_code FROM dual) s
ON (t.status_code = s.status_code)
WHEN NOT MATCHED THEN INSERT (status_code, display_name, is_terminal) VALUES ('CANCELLED', 'Cancelled', 'Y');

-- Weather types
MERGE INTO weather_event_type_lkp t
USING (SELECT 'THUNDERSTORM' AS weather_type_code FROM dual) s
ON (t.weather_type_code = s.weather_type_code)
WHEN NOT MATCHED THEN INSERT (weather_type_code, display_name) VALUES ('THUNDERSTORM', 'Thunderstorm');
MERGE INTO weather_event_type_lkp t
USING (SELECT 'FOG' AS weather_type_code FROM dual) s
ON (t.weather_type_code = s.weather_type_code)
WHEN NOT MATCHED THEN INSERT (weather_type_code, display_name) VALUES ('FOG', 'Fog / Low Visibility');
MERGE INTO weather_event_type_lkp t
USING (SELECT 'SNOW' AS weather_type_code FROM dual) s
ON (t.weather_type_code = s.weather_type_code)
WHEN NOT MATCHED THEN INSERT (weather_type_code, display_name) VALUES ('SNOW', 'Snow / Ice');
MERGE INTO weather_event_type_lkp t
USING (SELECT 'WIND_SHEAR' AS weather_type_code FROM dual) s
ON (t.weather_type_code = s.weather_type_code)
WHEN NOT MATCHED THEN INSERT (weather_type_code, display_name) VALUES ('WIND_SHEAR', 'Wind Shear');
MERGE INTO weather_event_type_lkp t
USING (SELECT 'TROPICAL' AS weather_type_code FROM dual) s
ON (t.weather_type_code = s.weather_type_code)
WHEN NOT MATCHED THEN INSERT (weather_type_code, display_name) VALUES ('TROPICAL', 'Tropical System');

-- Alert severity
MERGE INTO alert_severity_lkp t
USING (SELECT 'LOW' AS severity_code FROM dual) s
ON (t.severity_code = s.severity_code)
WHEN NOT MATCHED THEN INSERT (severity_code, display_name, sort_order) VALUES ('LOW', 'Low', 1);
MERGE INTO alert_severity_lkp t
USING (SELECT 'MEDIUM' AS severity_code FROM dual) s
ON (t.severity_code = s.severity_code)
WHEN NOT MATCHED THEN INSERT (severity_code, display_name, sort_order) VALUES ('MEDIUM', 'Medium', 2);
MERGE INTO alert_severity_lkp t
USING (SELECT 'HIGH' AS severity_code FROM dual) s
ON (t.severity_code = s.severity_code)
WHEN NOT MATCHED THEN INSERT (severity_code, display_name, sort_order) VALUES ('HIGH', 'High', 3);
MERGE INTO alert_severity_lkp t
USING (SELECT 'CRITICAL' AS severity_code FROM dual) s
ON (t.severity_code = s.severity_code)
WHEN NOT MATCHED THEN INSERT (severity_code, display_name, sort_order) VALUES ('CRITICAL', 'Critical', 4);

-- Order / quote status
MERGE INTO order_status_lkp t
USING (SELECT 'DRAFT' AS status_code FROM dual) s
ON (t.status_code = s.status_code)
WHEN NOT MATCHED THEN INSERT (status_code, display_name) VALUES ('DRAFT', 'Draft');
MERGE INTO order_status_lkp t
USING (SELECT 'SUBMITTED' AS status_code FROM dual) s
ON (t.status_code = s.status_code)
WHEN NOT MATCHED THEN INSERT (status_code, display_name) VALUES ('SUBMITTED', 'Submitted');
MERGE INTO order_status_lkp t
USING (SELECT 'APPROVED' AS status_code FROM dual) s
ON (t.status_code = s.status_code)
WHEN NOT MATCHED THEN INSERT (status_code, display_name) VALUES ('APPROVED', 'Approved');
MERGE INTO order_status_lkp t
USING (SELECT 'ORDERED' AS status_code FROM dual) s
ON (t.status_code = s.status_code)
WHEN NOT MATCHED THEN INSERT (status_code, display_name) VALUES ('ORDERED', 'Ordered');
MERGE INTO order_status_lkp t
USING (SELECT 'SHIPPED' AS status_code FROM dual) s
ON (t.status_code = s.status_code)
WHEN NOT MATCHED THEN INSERT (status_code, display_name) VALUES ('SHIPPED', 'Shipped');
MERGE INTO order_status_lkp t
USING (SELECT 'RECEIVED' AS status_code FROM dual) s
ON (t.status_code = s.status_code)
WHEN NOT MATCHED THEN INSERT (status_code, display_name) VALUES ('RECEIVED', 'Received');
MERGE INTO order_status_lkp t
USING (SELECT 'CANCELLED' AS status_code FROM dual) s
ON (t.status_code = s.status_code)
WHEN NOT MATCHED THEN INSERT (status_code, display_name) VALUES ('CANCELLED', 'Cancelled');

MERGE INTO quote_status_lkp t
USING (SELECT 'PENDING' AS status_code FROM dual) s
ON (t.status_code = s.status_code)
WHEN NOT MATCHED THEN INSERT (status_code, display_name) VALUES ('PENDING', 'Pending');
MERGE INTO quote_status_lkp t
USING (SELECT 'ACCEPTED' AS status_code FROM dual) s
ON (t.status_code = s.status_code)
WHEN NOT MATCHED THEN INSERT (status_code, display_name) VALUES ('ACCEPTED', 'Accepted');
MERGE INTO quote_status_lkp t
USING (SELECT 'REJECTED' AS status_code FROM dual) s
ON (t.status_code = s.status_code)
WHEN NOT MATCHED THEN INSERT (status_code, display_name) VALUES ('REJECTED', 'Rejected');
MERGE INTO quote_status_lkp t
USING (SELECT 'EXPIRED' AS status_code FROM dual) s
ON (t.status_code = s.status_code)
WHEN NOT MATCHED THEN INSERT (status_code, display_name) VALUES ('EXPIRED', 'Expired');

-- US states (50 states + DC)
MERGE INTO us_state_lkp t
USING (SELECT 'AL' AS state_code FROM dual) s
ON (t.state_code = s.state_code)
WHEN NOT MATCHED THEN INSERT (state_code, state_name) VALUES ('AL', 'Alabama');
MERGE INTO us_state_lkp t
USING (SELECT 'AK' AS state_code FROM dual) s
ON (t.state_code = s.state_code)
WHEN NOT MATCHED THEN INSERT (state_code, state_name) VALUES ('AK', 'Alaska');
MERGE INTO us_state_lkp t
USING (SELECT 'AZ' AS state_code FROM dual) s
ON (t.state_code = s.state_code)
WHEN NOT MATCHED THEN INSERT (state_code, state_name) VALUES ('AZ', 'Arizona');
MERGE INTO us_state_lkp t
USING (SELECT 'AR' AS state_code FROM dual) s
ON (t.state_code = s.state_code)
WHEN NOT MATCHED THEN INSERT (state_code, state_name) VALUES ('AR', 'Arkansas');
MERGE INTO us_state_lkp t
USING (SELECT 'CA' AS state_code FROM dual) s
ON (t.state_code = s.state_code)
WHEN NOT MATCHED THEN INSERT (state_code, state_name) VALUES ('CA', 'California');
MERGE INTO us_state_lkp t
USING (SELECT 'CO' AS state_code FROM dual) s
ON (t.state_code = s.state_code)
WHEN NOT MATCHED THEN INSERT (state_code, state_name) VALUES ('CO', 'Colorado');
MERGE INTO us_state_lkp t
USING (SELECT 'CT' AS state_code FROM dual) s
ON (t.state_code = s.state_code)
WHEN NOT MATCHED THEN INSERT (state_code, state_name) VALUES ('CT', 'Connecticut');
MERGE INTO us_state_lkp t
USING (SELECT 'DE' AS state_code FROM dual) s
ON (t.state_code = s.state_code)
WHEN NOT MATCHED THEN INSERT (state_code, state_name) VALUES ('DE', 'Delaware');
MERGE INTO us_state_lkp t
USING (SELECT 'DC' AS state_code FROM dual) s
ON (t.state_code = s.state_code)
WHEN NOT MATCHED THEN INSERT (state_code, state_name) VALUES ('DC', 'District of Columbia');
MERGE INTO us_state_lkp t
USING (SELECT 'FL' AS state_code FROM dual) s
ON (t.state_code = s.state_code)
WHEN NOT MATCHED THEN INSERT (state_code, state_name) VALUES ('FL', 'Florida');
MERGE INTO us_state_lkp t
USING (SELECT 'GA' AS state_code FROM dual) s
ON (t.state_code = s.state_code)
WHEN NOT MATCHED THEN INSERT (state_code, state_name) VALUES ('GA', 'Georgia');
MERGE INTO us_state_lkp t
USING (SELECT 'HI' AS state_code FROM dual) s
ON (t.state_code = s.state_code)
WHEN NOT MATCHED THEN INSERT (state_code, state_name) VALUES ('HI', 'Hawaii');
MERGE INTO us_state_lkp t
USING (SELECT 'ID' AS state_code FROM dual) s
ON (t.state_code = s.state_code)
WHEN NOT MATCHED THEN INSERT (state_code, state_name) VALUES ('ID', 'Idaho');
MERGE INTO us_state_lkp t
USING (SELECT 'IL' AS state_code FROM dual) s
ON (t.state_code = s.state_code)
WHEN NOT MATCHED THEN INSERT (state_code, state_name) VALUES ('IL', 'Illinois');
MERGE INTO us_state_lkp t
USING (SELECT 'IN' AS state_code FROM dual) s
ON (t.state_code = s.state_code)
WHEN NOT MATCHED THEN INSERT (state_code, state_name) VALUES ('IN', 'Indiana');
MERGE INTO us_state_lkp t
USING (SELECT 'IA' AS state_code FROM dual) s
ON (t.state_code = s.state_code)
WHEN NOT MATCHED THEN INSERT (state_code, state_name) VALUES ('IA', 'Iowa');
MERGE INTO us_state_lkp t
USING (SELECT 'KS' AS state_code FROM dual) s
ON (t.state_code = s.state_code)
WHEN NOT MATCHED THEN INSERT (state_code, state_name) VALUES ('KS', 'Kansas');
MERGE INTO us_state_lkp t
USING (SELECT 'KY' AS state_code FROM dual) s
ON (t.state_code = s.state_code)
WHEN NOT MATCHED THEN INSERT (state_code, state_name) VALUES ('KY', 'Kentucky');
MERGE INTO us_state_lkp t
USING (SELECT 'LA' AS state_code FROM dual) s
ON (t.state_code = s.state_code)
WHEN NOT MATCHED THEN INSERT (state_code, state_name) VALUES ('LA', 'Louisiana');
MERGE INTO us_state_lkp t
USING (SELECT 'ME' AS state_code FROM dual) s
ON (t.state_code = s.state_code)
WHEN NOT MATCHED THEN INSERT (state_code, state_name) VALUES ('ME', 'Maine');
MERGE INTO us_state_lkp t
USING (SELECT 'MD' AS state_code FROM dual) s
ON (t.state_code = s.state_code)
WHEN NOT MATCHED THEN INSERT (state_code, state_name) VALUES ('MD', 'Maryland');
MERGE INTO us_state_lkp t
USING (SELECT 'MA' AS state_code FROM dual) s
ON (t.state_code = s.state_code)
WHEN NOT MATCHED THEN INSERT (state_code, state_name) VALUES ('MA', 'Massachusetts');
MERGE INTO us_state_lkp t
USING (SELECT 'MI' AS state_code FROM dual) s
ON (t.state_code = s.state_code)
WHEN NOT MATCHED THEN INSERT (state_code, state_name) VALUES ('MI', 'Michigan');
MERGE INTO us_state_lkp t
USING (SELECT 'MN' AS state_code FROM dual) s
ON (t.state_code = s.state_code)
WHEN NOT MATCHED THEN INSERT (state_code, state_name) VALUES ('MN', 'Minnesota');
MERGE INTO us_state_lkp t
USING (SELECT 'MS' AS state_code FROM dual) s
ON (t.state_code = s.state_code)
WHEN NOT MATCHED THEN INSERT (state_code, state_name) VALUES ('MS', 'Mississippi');
MERGE INTO us_state_lkp t
USING (SELECT 'MO' AS state_code FROM dual) s
ON (t.state_code = s.state_code)
WHEN NOT MATCHED THEN INSERT (state_code, state_name) VALUES ('MO', 'Missouri');
MERGE INTO us_state_lkp t
USING (SELECT 'MT' AS state_code FROM dual) s
ON (t.state_code = s.state_code)
WHEN NOT MATCHED THEN INSERT (state_code, state_name) VALUES ('MT', 'Montana');
MERGE INTO us_state_lkp t
USING (SELECT 'NE' AS state_code FROM dual) s
ON (t.state_code = s.state_code)
WHEN NOT MATCHED THEN INSERT (state_code, state_name) VALUES ('NE', 'Nebraska');
MERGE INTO us_state_lkp t
USING (SELECT 'NV' AS state_code FROM dual) s
ON (t.state_code = s.state_code)
WHEN NOT MATCHED THEN INSERT (state_code, state_name) VALUES ('NV', 'Nevada');
MERGE INTO us_state_lkp t
USING (SELECT 'NH' AS state_code FROM dual) s
ON (t.state_code = s.state_code)
WHEN NOT MATCHED THEN INSERT (state_code, state_name) VALUES ('NH', 'New Hampshire');
MERGE INTO us_state_lkp t
USING (SELECT 'NJ' AS state_code FROM dual) s
ON (t.state_code = s.state_code)
WHEN NOT MATCHED THEN INSERT (state_code, state_name) VALUES ('NJ', 'New Jersey');
MERGE INTO us_state_lkp t
USING (SELECT 'NM' AS state_code FROM dual) s
ON (t.state_code = s.state_code)
WHEN NOT MATCHED THEN INSERT (state_code, state_name) VALUES ('NM', 'New Mexico');
MERGE INTO us_state_lkp t
USING (SELECT 'NY' AS state_code FROM dual) s
ON (t.state_code = s.state_code)
WHEN NOT MATCHED THEN INSERT (state_code, state_name) VALUES ('NY', 'New York');
MERGE INTO us_state_lkp t
USING (SELECT 'NC' AS state_code FROM dual) s
ON (t.state_code = s.state_code)
WHEN NOT MATCHED THEN INSERT (state_code, state_name) VALUES ('NC', 'North Carolina');
MERGE INTO us_state_lkp t
USING (SELECT 'ND' AS state_code FROM dual) s
ON (t.state_code = s.state_code)
WHEN NOT MATCHED THEN INSERT (state_code, state_name) VALUES ('ND', 'North Dakota');
MERGE INTO us_state_lkp t
USING (SELECT 'OH' AS state_code FROM dual) s
ON (t.state_code = s.state_code)
WHEN NOT MATCHED THEN INSERT (state_code, state_name) VALUES ('OH', 'Ohio');
MERGE INTO us_state_lkp t
USING (SELECT 'OK' AS state_code FROM dual) s
ON (t.state_code = s.state_code)
WHEN NOT MATCHED THEN INSERT (state_code, state_name) VALUES ('OK', 'Oklahoma');
MERGE INTO us_state_lkp t
USING (SELECT 'OR' AS state_code FROM dual) s
ON (t.state_code = s.state_code)
WHEN NOT MATCHED THEN INSERT (state_code, state_name) VALUES ('OR', 'Oregon');
MERGE INTO us_state_lkp t
USING (SELECT 'PA' AS state_code FROM dual) s
ON (t.state_code = s.state_code)
WHEN NOT MATCHED THEN INSERT (state_code, state_name) VALUES ('PA', 'Pennsylvania');
MERGE INTO us_state_lkp t
USING (SELECT 'RI' AS state_code FROM dual) s
ON (t.state_code = s.state_code)
WHEN NOT MATCHED THEN INSERT (state_code, state_name) VALUES ('RI', 'Rhode Island');
MERGE INTO us_state_lkp t
USING (SELECT 'SC' AS state_code FROM dual) s
ON (t.state_code = s.state_code)
WHEN NOT MATCHED THEN INSERT (state_code, state_name) VALUES ('SC', 'South Carolina');
MERGE INTO us_state_lkp t
USING (SELECT 'SD' AS state_code FROM dual) s
ON (t.state_code = s.state_code)
WHEN NOT MATCHED THEN INSERT (state_code, state_name) VALUES ('SD', 'South Dakota');
MERGE INTO us_state_lkp t
USING (SELECT 'TN' AS state_code FROM dual) s
ON (t.state_code = s.state_code)
WHEN NOT MATCHED THEN INSERT (state_code, state_name) VALUES ('TN', 'Tennessee');
MERGE INTO us_state_lkp t
USING (SELECT 'TX' AS state_code FROM dual) s
ON (t.state_code = s.state_code)
WHEN NOT MATCHED THEN INSERT (state_code, state_name) VALUES ('TX', 'Texas');
MERGE INTO us_state_lkp t
USING (SELECT 'UT' AS state_code FROM dual) s
ON (t.state_code = s.state_code)
WHEN NOT MATCHED THEN INSERT (state_code, state_name) VALUES ('UT', 'Utah');
MERGE INTO us_state_lkp t
USING (SELECT 'VT' AS state_code FROM dual) s
ON (t.state_code = s.state_code)
WHEN NOT MATCHED THEN INSERT (state_code, state_name) VALUES ('VT', 'Vermont');
MERGE INTO us_state_lkp t
USING (SELECT 'VA' AS state_code FROM dual) s
ON (t.state_code = s.state_code)
WHEN NOT MATCHED THEN INSERT (state_code, state_name) VALUES ('VA', 'Virginia');
MERGE INTO us_state_lkp t
USING (SELECT 'WA' AS state_code FROM dual) s
ON (t.state_code = s.state_code)
WHEN NOT MATCHED THEN INSERT (state_code, state_name) VALUES ('WA', 'Washington');
MERGE INTO us_state_lkp t
USING (SELECT 'WV' AS state_code FROM dual) s
ON (t.state_code = s.state_code)
WHEN NOT MATCHED THEN INSERT (state_code, state_name) VALUES ('WV', 'West Virginia');
MERGE INTO us_state_lkp t
USING (SELECT 'WI' AS state_code FROM dual) s
ON (t.state_code = s.state_code)
WHEN NOT MATCHED THEN INSERT (state_code, state_name) VALUES ('WI', 'Wisconsin');
MERGE INTO us_state_lkp t
USING (SELECT 'WY' AS state_code FROM dual) s
ON (t.state_code = s.state_code)
WHEN NOT MATCHED THEN INSERT (state_code, state_name) VALUES ('WY', 'Wyoming');

-- Aircraft types
MERGE INTO aircraft_type_lkp t
USING (SELECT 'B738' AS aircraft_type_code FROM dual) s
ON (t.aircraft_type_code = s.aircraft_type_code)
WHEN NOT MATCHED THEN INSERT (aircraft_type_code, display_name, icao_designator, wake_category, typical_cruise_kts, max_seating) VALUES ('B738', 'Boeing 737-800', 'B738', 'MEDIUM', 440, 189);
MERGE INTO aircraft_type_lkp t
USING (SELECT 'A320' AS aircraft_type_code FROM dual) s
ON (t.aircraft_type_code = s.aircraft_type_code)
WHEN NOT MATCHED THEN INSERT (aircraft_type_code, display_name, icao_designator, wake_category, typical_cruise_kts, max_seating) VALUES ('A320', 'Airbus A320', 'A320', 'MEDIUM', 447, 180);
MERGE INTO aircraft_type_lkp t
USING (SELECT 'E175' AS aircraft_type_code FROM dual) s
ON (t.aircraft_type_code = s.aircraft_type_code)
WHEN NOT MATCHED THEN INSERT (aircraft_type_code, display_name, icao_designator, wake_category, typical_cruise_kts, max_seating) VALUES ('E175', 'Embraer E175', 'E175', 'MEDIUM', 430, 76);
MERGE INTO aircraft_type_lkp t
USING (SELECT 'C172' AS aircraft_type_code FROM dual) s
ON (t.aircraft_type_code = s.aircraft_type_code)
WHEN NOT MATCHED THEN INSERT (aircraft_type_code, display_name, icao_designator, wake_category, typical_cruise_kts, max_seating) VALUES ('C172', 'Cessna 172', 'C172', 'LIGHT', 122, 4);
MERGE INTO aircraft_type_lkp t
USING (SELECT 'B77W' AS aircraft_type_code FROM dual) s
ON (t.aircraft_type_code = s.aircraft_type_code)
WHEN NOT MATCHED THEN INSERT (aircraft_type_code, display_name, icao_designator, wake_category, typical_cruise_kts, max_seating) VALUES ('B77W', 'Boeing 777-300ER', 'B77W', 'HEAVY', 490, 396);
MERGE INTO aircraft_type_lkp t
USING (SELECT 'C208F' AS aircraft_type_code FROM dual) s
ON (t.aircraft_type_code = s.aircraft_type_code)
WHEN NOT MATCHED THEN INSERT (aircraft_type_code, display_name, icao_designator, wake_category, typical_cruise_kts, max_seating) VALUES ('C208F', 'Cessna 208 Caravan Freighter', 'C208', 'LIGHT', 175, 0);
MERGE INTO aircraft_type_lkp t
USING (SELECT 'B763F' AS aircraft_type_code FROM dual) s
ON (t.aircraft_type_code = s.aircraft_type_code)
WHEN NOT MATCHED THEN INSERT (aircraft_type_code, display_name, icao_designator, wake_category, typical_cruise_kts, max_seating) VALUES ('B763F', 'Boeing 767-300F', 'B763', 'HEAVY', 460, 0);

MERGE INTO operational_status_lkp t
USING (SELECT 'AVAILABLE' AS status_code, 'AIRCRAFT' AS applies_to_entity FROM dual) s
ON (t.status_code = s.status_code AND t.applies_to_entity = s.applies_to_entity)
WHEN NOT MATCHED THEN INSERT (status_code, display_name, applies_to_entity, sort_order) VALUES ('AVAILABLE', 'Available', 'AIRCRAFT', 1);
MERGE INTO operational_status_lkp t
USING (SELECT 'IN_FLIGHT' AS status_code, 'AIRCRAFT' AS applies_to_entity FROM dual) s
ON (t.status_code = s.status_code AND t.applies_to_entity = s.applies_to_entity)
WHEN NOT MATCHED THEN INSERT (status_code, display_name, applies_to_entity, sort_order) VALUES ('IN_FLIGHT', 'In Flight', 'AIRCRAFT', 2);
MERGE INTO operational_status_lkp t
USING (SELECT 'MAINTENANCE' AS status_code, 'AIRCRAFT' AS applies_to_entity FROM dual) s
ON (t.status_code = s.status_code AND t.applies_to_entity = s.applies_to_entity)
WHEN NOT MATCHED THEN INSERT (status_code, display_name, applies_to_entity, sort_order) VALUES ('MAINTENANCE', 'Under Maintenance', 'AIRCRAFT', 3);
MERGE INTO operational_status_lkp t
USING (SELECT 'OUT_OF_SERVICE' AS status_code, 'AIRCRAFT' AS applies_to_entity FROM dual) s
ON (t.status_code = s.status_code AND t.applies_to_entity = s.applies_to_entity)
WHEN NOT MATCHED THEN INSERT (status_code, display_name, applies_to_entity, sort_order) VALUES ('OUT_OF_SERVICE', 'Out of Service', 'AIRCRAFT', 4);

-- Simulation clock
MERGE INTO simulation_clock_mode_lkp t
USING (SELECT 'REALTIME' AS clock_mode_code FROM dual) s
ON (t.clock_mode_code = s.clock_mode_code)
WHEN NOT MATCHED THEN INSERT (clock_mode_code, display_name, description) VALUES ('REALTIME', 'Real Time', 'One sim second equals one wall-clock second');
MERGE INTO simulation_clock_mode_lkp t
USING (SELECT 'ACCELERATED' AS clock_mode_code FROM dual) s
ON (t.clock_mode_code = s.clock_mode_code)
WHEN NOT MATCHED THEN INSERT (clock_mode_code, display_name, description) VALUES ('ACCELERATED', 'Accelerated', 'Sim time advances faster than wall clock per time_scale');

MERGE INTO simulation_run_status_lkp t
USING (SELECT 'RUNNING' AS run_status_code FROM dual) s
ON (t.run_status_code = s.run_status_code)
WHEN NOT MATCHED THEN INSERT (run_status_code, display_name, allows_tick) VALUES ('RUNNING', 'Running', 'Y');
MERGE INTO simulation_run_status_lkp t
USING (SELECT 'PAUSED' AS run_status_code FROM dual) s
ON (t.run_status_code = s.run_status_code)
WHEN NOT MATCHED THEN INSERT (run_status_code, display_name, allows_tick) VALUES ('PAUSED', 'Paused', 'N');
MERGE INTO simulation_run_status_lkp t
USING (SELECT 'STEPPING' AS run_status_code FROM dual) s
ON (t.run_status_code = s.run_status_code)
WHEN NOT MATCHED THEN INSERT (run_status_code, display_name, allows_tick) VALUES ('STEPPING', 'Stepping', 'N');

-- Default roles
MERGE INTO user_role_lookup t
USING (SELECT '00000000-0000-0000-0000-000000000001' AS role_id FROM dual) s
ON (t.role_id = s.role_id)
WHEN NOT MATCHED THEN INSERT (role_id, role_code, role_name, description, is_system_role) VALUES ('00000000-0000-0000-0000-000000000001', 'ADMIN', 'Administrator', 'Full system access', 'Y');
MERGE INTO user_role_lookup t
USING (SELECT '00000000-0000-0000-0000-000000000002' AS role_id FROM dual) s
ON (t.role_id = s.role_id)
WHEN NOT MATCHED THEN INSERT (role_id, role_code, role_name, description, is_system_role) VALUES ('00000000-0000-0000-0000-000000000002', 'OPERATOR', 'Simulation Operator', 'Run scenarios and view state', 'Y');
MERGE INTO user_role_lookup t
USING (SELECT '00000000-0000-0000-0000-000000000003' AS role_id FROM dual) s
ON (t.role_id = s.role_id)
WHEN NOT MATCHED THEN INSERT (role_id, role_code, role_name, description, is_system_role) VALUES ('00000000-0000-0000-0000-000000000003', 'MAINTENANCE', 'Maintenance Coordinator', 'Manage maintenance activities', 'Y');
MERGE INTO user_role_lookup t
USING (SELECT '00000000-0000-0000-0000-000000000004' AS role_id FROM dual) s
ON (t.role_id = s.role_id)
WHEN NOT MATCHED THEN INSERT (role_id, role_code, role_name, description, is_system_role) VALUES ('00000000-0000-0000-0000-000000000004', 'OBSERVER', 'Observer', 'Read-only access', 'Y');

-- Default simulation configuration
MERGE INTO global_configuration t
USING (SELECT 'simulation.tick_interval_ms' AS config_key FROM dual) s
ON (t.config_key = s.config_key)
WHEN NOT MATCHED THEN INSERT (config_key, config_value, value_type, description) VALUES ('simulation.tick_interval_ms', '1000', 'NUMBER', 'Simulation clock tick interval in milliseconds');
MERGE INTO global_configuration t
USING (SELECT 'simulation.clock_mode' AS config_key FROM dual) s
ON (t.config_key = s.config_key)
WHEN NOT MATCHED THEN INSERT (config_key, config_value, value_type, description) VALUES ('simulation.clock_mode', 'REALTIME', 'STRING', 'Default clock mode: REALTIME or ACCELERATED (overrides simulation_run_state on cold start)');
MERGE INTO global_configuration t
USING (SELECT 'simulation.time_scale' AS config_key FROM dual) s
ON (t.config_key = s.config_key)
WHEN NOT MATCHED THEN INSERT (config_key, config_value, value_type, description) VALUES ('simulation.time_scale', '1', 'NUMBER', 'Wall-clock to sim-time multiplier when ACCELERATED');
MERGE INTO global_configuration t
USING (SELECT 'simulation.auto_generate_alerts' AS config_key FROM dual) s
ON (t.config_key = s.config_key)
WHEN NOT MATCHED THEN INSERT (config_key, config_value, value_type, description) VALUES ('simulation.auto_generate_alerts', 'true', 'BOOL', 'Whether equipment failures auto-raise alerts');
MERGE INTO global_configuration t
USING (SELECT 'simulation.ground_ops.incident_probability_per_tick' AS config_key FROM dual) s
ON (t.config_key = s.config_key)
WHEN NOT MATCHED THEN INSERT (config_key, config_value, value_type, description) VALUES ('simulation.ground_ops.incident_probability_per_tick', '0.0001', 'NUMBER', 'Probability of random passenger incident per tick during boarding (0-1)');
MERGE INTO global_configuration t
USING (SELECT 'simulation.ground_ops.lead_time_minutes' AS config_key FROM dual) s
ON (t.config_key = s.config_key)
WHEN NOT MATCHED THEN INSERT (config_key, config_value, value_type, description) VALUES ('simulation.ground_ops.lead_time_minutes', '90', 'NUMBER', 'Minutes before scheduled departure to auto-enter GROUND_OPS phase');
MERGE INTO global_configuration t
USING (SELECT 'simulation.ground_ops.progress_broadcast_threshold_pct' AS config_key FROM dual) s
ON (t.config_key = s.config_key)
WHEN NOT MATCHED THEN INSERT (config_key, config_value, value_type, description) VALUES ('simulation.ground_ops.progress_broadcast_threshold_pct', '10', 'NUMBER', 'Minimum progress change (%) before broadcasting GROUND_OP_PROGRESS event');
MERGE INTO global_configuration t
USING (SELECT 'auth.entra.tenant_id' AS config_key FROM dual) s
ON (t.config_key = s.config_key)
WHEN NOT MATCHED THEN INSERT (config_key, config_value, value_type, description) VALUES ('auth.entra.tenant_id', '00000000-0000-0000-0000-000000000000', 'STRING', 'Microsoft Entra tenant ID (replace per environment)');
MERGE INTO global_configuration t
USING (SELECT 'auth.entra.client_id' AS config_key FROM dual) s
ON (t.config_key = s.config_key)
WHEN NOT MATCHED THEN INSERT (config_key, config_value, value_type, description) VALUES ('auth.entra.client_id', '00000000-0000-0000-0000-000000000000', 'STRING', 'App registration client ID (replace per environment)');
MERGE INTO global_configuration t
USING (SELECT 'auth.entra.instance' AS config_key FROM dual) s
ON (t.config_key = s.config_key)
WHEN NOT MATCHED THEN INSERT (config_key, config_value, value_type, description) VALUES ('auth.entra.instance', 'https://login.microsoftonline.com/', 'STRING', 'Entra authority base URL');

-- Default render context and simulation run state (singleton)
MERGE INTO simulation_render_context t
USING (SELECT '00000000-0000-0000-0000-000000000010' AS render_context_id FROM dual) s
ON (t.render_context_id = s.render_context_id)
WHEN NOT MATCHED THEN INSERT (render_context_id, context_code, name, description, is_active) VALUES ('00000000-0000-0000-0000-000000000010', 'DEFAULT', 'Default Render Context', 'Baseline virtual environment for development', 'Y');

MERGE INTO simulation_run_state t
USING (SELECT 'CURRENT' AS run_state_id FROM dual) s
ON (t.run_state_id = s.run_state_id)
WHEN NOT MATCHED THEN INSERT (
    run_state_id, clock_mode_code, time_scale, run_status_code,
    current_sim_time_utc, step_sequence, active_render_context_id
) VALUES (
    'CURRENT', 'REALTIME', 1, 'PAUSED',
    SYSTIMESTAMP, 0, '00000000-0000-0000-0000-000000000010'
);

-- Local development / test operator (LOCAL_DEV auth via symmetric JWT in NasSim.Api)
MERGE INTO users t
USING (SELECT '00000000-0000-0000-0000-000000000100' AS user_id FROM dual) s
ON (t.user_id = s.user_id)
WHEN NOT MATCHED THEN INSERT (
    user_id, username, display_name, email, is_active, auth_source,
    entra_tenant_id, entra_object_id, entra_upn, entra_display_name
) VALUES (
    '00000000-0000-0000-0000-000000000100',
    'dev.operator',
    'Dev Operator',
    'dev.operator@nas-sim.local',
    'Y',
    'LOCAL_DEV',
    '11111111-1111-1111-1111-111111111111',
    '22222222-2222-2222-2222-222222222222',
    'dev.operator@nas-sim.local',
    'Dev Operator'
);

MERGE INTO entra_group_role_mapping t
USING (SELECT '00000000-0000-0000-0000-000000000200' AS entra_group_role_mapping_id FROM dual) s
ON (t.entra_group_role_mapping_id = s.entra_group_role_mapping_id)
WHEN NOT MATCHED THEN INSERT (
    entra_group_role_mapping_id, entra_tenant_id, entra_group_object_id, role_id, is_active
) VALUES (
    '00000000-0000-0000-0000-000000000200',
    '11111111-1111-1111-1111-111111111111',
    '33333333-3333-3333-3333-333333333333',
    '00000000-0000-0000-0000-000000000002',
    'Y'
);


-- Operational log entry types (shared across maintenance / ground-ops / logistics)
MERGE INTO log_entry_type_lkp t
USING (SELECT 'NOTE' AS log_entry_type_code FROM dual) s
ON (t.log_entry_type_code = s.log_entry_type_code)
WHEN NOT MATCHED THEN INSERT (log_entry_type_code, display_name, applies_to_domain, description)
VALUES ('NOTE', 'Note', 'ALL', 'Free-form operational note');
MERGE INTO log_entry_type_lkp t
USING (SELECT 'STATUS_CHANGE' AS log_entry_type_code FROM dual) s
ON (t.log_entry_type_code = s.log_entry_type_code)
WHEN NOT MATCHED THEN INSERT (log_entry_type_code, display_name, applies_to_domain, description)
VALUES ('STATUS_CHANGE', 'Status Change', 'ALL', 'Activity or asset status transition');
MERGE INTO log_entry_type_lkp t
USING (SELECT 'PART_USED' AS log_entry_type_code FROM dual) s
ON (t.log_entry_type_code = s.log_entry_type_code)
WHEN NOT MATCHED THEN INSERT (log_entry_type_code, display_name, applies_to_domain, description)
VALUES ('PART_USED', 'Part Used', 'MAINTENANCE,LOGISTICS', 'Part consumed or installed against an asset');
MERGE INTO log_entry_type_lkp t
USING (SELECT 'DISPATCH' AS log_entry_type_code FROM dual) s
ON (t.log_entry_type_code = s.log_entry_type_code)
WHEN NOT MATCHED THEN INSERT (log_entry_type_code, display_name, applies_to_domain, description)
VALUES ('DISPATCH', 'Dispatch', 'MAINTENANCE,LOGISTICS', 'Crew or shipment dispatched from a facility');
MERGE INTO log_entry_type_lkp t
USING (SELECT 'ARRIVAL' AS log_entry_type_code FROM dual) s
ON (t.log_entry_type_code = s.log_entry_type_code)
WHEN NOT MATCHED THEN INSERT (log_entry_type_code, display_name, applies_to_domain, description)
VALUES ('ARRIVAL', 'Arrival', 'ALL', 'Crew, part, or asset arrived at a location');
MERGE INTO log_entry_type_lkp t
USING (SELECT 'DEPARTURE' AS log_entry_type_code FROM dual) s
ON (t.log_entry_type_code = s.log_entry_type_code)
WHEN NOT MATCHED THEN INSERT (log_entry_type_code, display_name, applies_to_domain, description)
VALUES ('DEPARTURE', 'Departure', 'ALL', 'Crew, part, or asset departed a location');
MERGE INTO log_entry_type_lkp t
USING (SELECT 'PROGRESS' AS log_entry_type_code FROM dual) s
ON (t.log_entry_type_code = s.log_entry_type_code)
WHEN NOT MATCHED THEN INSERT (log_entry_type_code, display_name, applies_to_domain, description)
VALUES ('PROGRESS', 'Progress', 'ALL', 'Incremental progress update');
MERGE INTO log_entry_type_lkp t
USING (SELECT 'INSPECTION' AS log_entry_type_code FROM dual) s
ON (t.log_entry_type_code = s.log_entry_type_code)
WHEN NOT MATCHED THEN INSERT (log_entry_type_code, display_name, applies_to_domain, description)
VALUES ('INSPECTION', 'Inspection', 'MAINTENANCE', 'Inspection finding or checklist step');
MERGE INTO log_entry_type_lkp t
USING (SELECT 'HANDOFF' AS log_entry_type_code FROM dual) s
ON (t.log_entry_type_code = s.log_entry_type_code)
WHEN NOT MATCHED THEN INSERT (log_entry_type_code, display_name, applies_to_domain, description)
VALUES ('HANDOFF', 'Handoff', 'ALL', 'Responsibility handoff between facilities or crews');

-- Scenario day anchor (Upper Midwest corridor narrative). Change here, then re-seed.
MERGE INTO scenario_clock t
USING (SELECT 'DEFAULT' AS clock_id FROM dual) s
ON (t.clock_id = s.clock_id)
WHEN MATCHED THEN UPDATE SET
    scenario_day = DATE '2026-06-23',
    anchor_ts = TIMESTAMP '2026-06-23 12:00:00 +00:00',
    description = 'DSM ILS failure corridor scenario day (UTC)',
    updated_at = SYSTIMESTAMP
WHEN NOT MATCHED THEN INSERT (clock_id, scenario_day, anchor_ts, description)
VALUES (
    'DEFAULT',
    DATE '2026-06-23',
    TIMESTAMP '2026-06-23 12:00:00 +00:00',
    'DSM ILS failure corridor scenario day (UTC)');
COMMIT;
