-- =============================================================================
-- NAS Simulation — data enrichment (103)
-- Fills metadata_json, inspection schedules, flight request metadata, and
-- other optional columns left null by 100-102. Safe to re-run (UPDATE only).
-- =============================================================================

ALTER SESSION SET CONTAINER = FREEPDB1;
ALTER SESSION SET CURRENT_SCHEMA = nas_sim;

-- ---------------------------------------------------------------------------
-- Runways — operational metadata for all corridor runways
-- ---------------------------------------------------------------------------

UPDATE runway SET metadata_json = q'[{"ils":"Cat I RWY 13","restriction":"ILS GS offline","notam":"6/234","papi":true}]'
WHERE runway_id = '11000001-0001-4001-8001-000000000001';

UPDATE runway SET metadata_json = q'[{"ils":"None","preferredWhen":"ILS outage","crosswindLimitKts":15}]'
WHERE runway_id = '11000002-0001-4001-8001-000000000002';

UPDATE runway SET metadata_json = q'[{"ils":"Cat III 10L","llwas":true,"primaryArrival":true}]'
WHERE runway_id = '11000003-0001-4001-8001-000000000003';

UPDATE runway SET metadata_json = q'[{"ils":"Cat I 09R","departureRatePerHr":42}]'
WHERE runway_id = '11000004-0001-4001-8001-000000000004';

UPDATE runway SET metadata_json = q'[{"ils":"Cat III 12R","fogOps":true,"rvrMeters":400}]'
WHERE runway_id = '11000005-0001-4001-8001-000000000005';

UPDATE runway SET metadata_json = q'[{"ils":"Cat I 14/32","lengthFt":9502,"surface":"CONCRETE"}]'
WHERE runway_id = '11000006-0001-4001-8001-000000000006';

UPDATE runway SET metadata_json = q'[{"ils":"Cat I 13","diversionAlternateFor":"KDSM"}]'
WHERE runway_id = '11000007-0001-4001-8001-000000000007';

UPDATE runway SET metadata_json = q'[{"ils":"None","gaFriendly":true}]'
WHERE runway_id = '11000008-0001-4001-8001-000000000008';

UPDATE runway SET metadata_json = q'[{"ils":"Cat I 01L","calibrationDue":"2026-06-23","glideSlopeDriftDeg":0.02}]'
WHERE runway_id = '11000009-0001-4001-8001-000000000009';

-- ---------------------------------------------------------------------------
-- Equipment — metadata_json + inspection fields where missing
-- ---------------------------------------------------------------------------

UPDATE equipment SET
    metadata_json = q'[{"runway":"13/31","frequencyMhz":110.3,"failureCode":"GS-TX-07","notamIssued":true,"cat":"I"}]',
    last_inspection_at = TIMESTAMP '2026-05-15 08:00:00',
    next_inspection_due_at = TIMESTAMP '2026-11-15 08:00:00',
    mean_time_between_failure_hrs = 8760,
    mean_time_to_repair_hrs = 8
WHERE equipment_id = '12000001-0001-4001-8001-000000000001';

UPDATE equipment SET
    metadata_json = q'[{"runway":"13/31","side":"left","slopeAngle":3.0}]',
    last_inspection_at = TIMESTAMP '2026-04-01 10:00:00',
    next_inspection_due_at = TIMESTAMP '2026-10-01 10:00:00',
    mean_time_between_failure_hrs = 17520,
    mean_time_to_repair_hrs = 2
WHERE equipment_id = '12000002-0001-4001-8001-000000000002';

UPDATE equipment SET
    metadata_json = q'[{"runway":"13/31","system":"ALS-F-2","intensitySteps":5}]',
    last_inspection_at = TIMESTAMP '2026-03-20 14:00:00',
    next_inspection_due_at = TIMESTAMP '2026-09-20 14:00:00',
    mean_time_between_failure_hrs = 8760,
    mean_time_to_repair_hrs = 4
WHERE equipment_id = '12000003-0001-4001-8001-000000000003';

UPDATE equipment SET
    metadata_json = q'[{"frequencyMhz":121.9,"sector":"DSM Tower","backupNet":"COM-DSM-UHF"}]',
    last_inspection_at = TIMESTAMP '2026-02-10 09:00:00',
    next_inspection_due_at = TIMESTAMP '2026-08-10 09:00:00',
    mean_time_between_failure_hrs = 4380,
    mean_time_to_repair_hrs = 1
WHERE equipment_id = '12000004-0001-4001-8001-000000000004';

UPDATE equipment SET
    metadata_json = q'[{"coverageNm":60,"feeds":"DSM-TRACON","rotationRpm":12}]',
    last_inspection_at = TIMESTAMP '2026-06-20 10:00:00',
    next_inspection_due_at = TIMESTAMP '2026-12-20 10:00:00',
    mean_time_between_failure_hrs = 4380,
    mean_time_to_repair_hrs = 6
WHERE equipment_id = '12000005-0001-4001-8001-000000000005';

UPDATE equipment SET
    metadata_json = q'[{"ident":"DSM","frequencyMhz":113.2,"serviceVolume":"High"}]',
    last_inspection_at = TIMESTAMP '2026-01-15 08:00:00',
    next_inspection_due_at = TIMESTAMP '2026-07-15 08:00:00',
    mean_time_between_failure_hrs = 8760,
    mean_time_to_repair_hrs = 12
WHERE equipment_id = '12000006-0001-4001-8001-000000000006';

UPDATE equipment SET
    metadata_json = q'[{"ident":"DSM","channel":62,"pairedWith":"VOR-DSM"}]',
    last_inspection_at = TIMESTAMP '2026-01-15 08:00:00',
    next_inspection_due_at = TIMESTAMP '2026-07-15 08:00:00',
    mean_time_between_failure_hrs = 8760,
    mean_time_to_repair_hrs = 8
WHERE equipment_id = '12000007-0001-4001-8001-000000000007';

UPDATE equipment SET
    metadata_json = q'[{"runway":"10L/28R","cat":"III","autolandCapable":true}]',
    last_inspection_at = TIMESTAMP '2026-05-01 06:00:00',
    next_inspection_due_at = TIMESTAMP '2026-11-01 06:00:00',
    mean_time_between_failure_hrs = 8760,
    mean_time_to_repair_hrs = 10
WHERE equipment_id = '12000008-0001-4001-8001-000000000008';

UPDATE equipment SET
    metadata_json = q'[{"sector":"42","frequencyMhz":127.85,"artcc":"ZAU"}]',
    last_inspection_at = TIMESTAMP '2026-04-15 12:00:00',
    next_inspection_due_at = TIMESTAMP '2026-10-15 12:00:00',
    mean_time_between_failure_hrs = 4380,
    mean_time_to_repair_hrs = 2
WHERE equipment_id = '12000009-0001-4001-8001-000000000009';

UPDATE equipment SET
    metadata_json = q'[{"radarType":"ASR-9","standbyChannel":"degraded","feedsTracon":"DSM"}]',
    last_inspection_at = TIMESTAMP '2026-06-20 10:00:00',
    next_inspection_due_at = TIMESTAMP '2026-12-20 10:00:00',
    mean_time_between_failure_hrs = 4380,
    mean_time_to_repair_hrs = 6
WHERE equipment_id = '1200000a-0001-4001-8001-00000000000a';

UPDATE equipment SET
    metadata_json = q'[{"runway":"13","cat":"I","flightCheckDue":"2026-06-25"}]',
    last_inspection_at = TIMESTAMP '2026-05-01 08:00:00',
    next_inspection_due_at = TIMESTAMP '2026-11-01 08:00:00',
    mean_time_between_failure_hrs = 8760,
    mean_time_to_repair_hrs = 8
WHERE equipment_id = '1200000b-0001-4001-8001-00000000000b';

UPDATE equipment SET
    metadata_json = q'[{"radarType":"ASR-8","coverageNm":40}]',
    last_inspection_at = TIMESTAMP '2026-03-10 09:00:00',
    next_inspection_due_at = TIMESTAMP '2026-09-10 09:00:00',
    mean_time_between_failure_hrs = 4380,
    mean_time_to_repair_hrs = 5
WHERE equipment_id = '1200000c-0001-4001-8001-00000000000c';

UPDATE equipment SET
    metadata_json = q'[{"runway":"01L","glideSlopeNominalDeg":3.0,"driftDeg":0.02}]',
    last_inspection_at = TIMESTAMP '2026-06-23 10:15:00',
    next_inspection_due_at = TIMESTAMP '2026-12-23 10:15:00',
    mean_time_between_failure_hrs = 8760,
    mean_time_to_repair_hrs = 4
WHERE equipment_id = '1200000d-0001-4001-8001-00000000000d';

UPDATE equipment SET
    metadata_json = q'[{"frequencyMhz":118.25,"role":"approach backup","pairedPrimary":"COM-DSM-TWR"}]',
    last_inspection_at = TIMESTAMP '2026-02-01 11:00:00',
    next_inspection_due_at = TIMESTAMP '2026-08-01 11:00:00',
    mean_time_between_failure_hrs = 4380,
    mean_time_to_repair_hrs = 1
WHERE equipment_id = '1200000e-0001-4001-8001-00000000000e';

-- ---------------------------------------------------------------------------
-- Aircraft — expanded fleet metadata
-- ---------------------------------------------------------------------------

UPDATE aircraft SET metadata_json = q'[{"operator":"United Airlines","fleetId":"UA-738-041","livery":"United Globe","yearBuilt":2018,"hoursSinceCheck":4200}]'
WHERE aircraft_id = '15000001-0001-4001-8001-000000000001';

UPDATE aircraft SET metadata_json = q'[{"operator":"American Airlines","fleetId":"AA-A321-112","yearBuilt":2019,"hoursSinceCheck":3100}]'
WHERE aircraft_id = '15000002-0001-4001-8001-000000000002';

UPDATE aircraft SET metadata_json = q'[{"operator":"Delta Air Lines","fleetId":"DL-A320-088","yearBuilt":2017,"hoursSinceCheck":5800}]'
WHERE aircraft_id = '15000003-0001-4001-8001-000000000003';

UPDATE aircraft SET metadata_json = q'[{"operator":"Cedar Flight Academy","flightType":"GA","instructorOnBoard":true,"fuelGal":42}]'
WHERE aircraft_id = '15000004-0001-4001-8001-000000000004';

UPDATE aircraft SET metadata_json = q'[{"operator":"United Airlines","fleetId":"UA-77W-003","cargoCapable":false,"yearBuilt":2016}]'
WHERE aircraft_id = '15000005-0001-4001-8001-000000000005';

UPDATE aircraft SET metadata_json = q'[{"operator":"Southwest Airlines","fleetId":"SW-738-294","winglets":true,"yearBuilt":2020}]'
WHERE aircraft_id = '15000006-0001-4001-8001-000000000006';

UPDATE aircraft SET metadata_json = q'[{"operator":"FedEx Express","fleetId":"FDX-77W-925","cargoOnly":true,"mainDeckPositions":27}]'
WHERE aircraft_id = '15000007-0001-4001-8001-000000000007';

UPDATE aircraft SET metadata_json = q'[{"operator":"United Express","regional":true,"carrier":"SkyWest","seatsFirst":12,"seatsEconomy":64}]'
WHERE aircraft_id = '15000008-0001-4001-8001-000000000008';

-- ---------------------------------------------------------------------------
-- Flight requests — metadata_json
-- ---------------------------------------------------------------------------

UPDATE flight_request SET metadata_json = q'[{"priority":"HIGH","paxConnections":42,"bagCount":187,"cateringComplete":true,"deicingRequired":false}]'
WHERE flight_request_id = '21000001-0001-4001-8001-000000000001';

UPDATE flight_request SET metadata_json = q'[{"priority":"NORMAL","codeshare":"SKW","slotRequested":"16:00Z"}]'
WHERE flight_request_id = '21000002-0001-4001-8001-000000000002';

UPDATE flight_request SET metadata_json = q'[{"priority":"NORMAL","cargoLbs":0,"crewReportTime":"11:45Z"}]'
WHERE flight_request_id = '21000003-0001-4001-8001-000000000003';

UPDATE flight_request SET metadata_json = q'[{"priority":"NORMAL","fogDelayRisk":"MEDIUM","alternate":"KORD"}]'
WHERE flight_request_id = '21000004-0001-4001-8001-000000000004';

UPDATE flight_request SET metadata_json = q'[{"priority":"LOW","flightType":"LOCAL_PATTERN","touchAndGosPlanned":6,"studentPilot":true}]'
WHERE flight_request_id = '21000005-0001-4001-8001-000000000005';

-- ---------------------------------------------------------------------------
-- Flight operations — metadata for rows missing it
-- ---------------------------------------------------------------------------

UPDATE flight_operation SET metadata_json = q'[{"onTimePerformance":"98%","blockTimeMin":95,"fuelPlannedLbs":12400,"crew":"2/4"}]'
WHERE flight_operation_id = '22000003-0001-4001-8001-000000000003';

UPDATE flight_operation SET metadata_json = q'[{"cruiseAltFt":34000,"route":"OMA DSM JVL","eteMin":57,"fuelOnBoardLbs":18200}]'
WHERE flight_operation_id = '22000004-0001-4001-8001-000000000004' AND metadata_json IS NULL;

UPDATE flight_operation SET metadata_json = q'[{"gate":"G12","boardingPct":72,"fogClearanceExpected":"14:30Z","deicing":false}]'
WHERE flight_operation_id = '22000005-0001-4001-8001-000000000005';

UPDATE flight_operation SET metadata_json = q'[{"gate":"B4","status":"AWAITING_CLEARANCE","atcFlowProgram":false}]'
WHERE flight_operation_id = '22000006-0001-4001-8001-000000000006';

UPDATE flight_operation SET metadata_json = q'[{"cargoLbs":142000,"flightLevel":370,"goAroundCount":1,"holdFix":"OSH"}]'
WHERE flight_operation_id = '22000007-0001-4001-8001-000000000007';

UPDATE flight_operation SET metadata_json = q'[{"flightType":"LOCAL_PATTERN","instructor":"CFI Martinez","student":"Private pilot checkout","patternAltFt":2500}]'
WHERE flight_operation_id = '22000008-0001-4001-8001-000000000008';

-- ---------------------------------------------------------------------------
-- Equipment parts — descriptions and metadata
-- ---------------------------------------------------------------------------

UPDATE equipment_part SET
    description = 'Replacement glide slope transmitter module for Thales ILS-420. FAA PMA approved. Shelf life 10 years.',
    metadata_json = q'[{"hazmat":false,"weightLbs":48,"leadTimeDays":14,"criticality":"AOG"}]'
WHERE equipment_part_id = '1a000001-0001-4001-8001-000000000001';

UPDATE equipment_part SET
    description = 'Surveillance radar magnetron for Raytheon ASR-9 primary/standby channels.',
    metadata_json = q'[{"hazmat":false,"weightLbs":22,"criticality":"HIGH"}]'
WHERE equipment_part_id = '1a000002-0001-4001-8001-000000000002';

UPDATE equipment_part SET
    description = 'Thales ILS-420 localizer antenna array assembly. Requires crane for installation.',
    metadata_json = q'[{"hazmat":false,"weightLbs":890,"installHours":16}]'
WHERE equipment_part_id = '1a000003-0001-4001-8001-000000000003';

UPDATE equipment_part SET
    description = 'Park Air T6 VHF transmitter card. Compatible with DSM tower and approach nets.',
    metadata_json = q'[{"hazmat":false,"weightLbs":3.2,"stockLocations":["NAS-DEPOT-IA"]}]'
WHERE equipment_part_id = '1a000004-0001-4001-8001-000000000004';

UPDATE equipment_part SET
    description = 'Portable ILS glide slope / localizer alignment kit. Includes test antennas and spectrum analyzer interface.',
    metadata_json = q'[{"hazmat":false,"weightLbs":85,"calibrationIntervalDays":180}]'
WHERE equipment_part_id = '1a000005-0001-4001-8001-000000000005';

-- ---------------------------------------------------------------------------
-- Maintenance activities — richer descriptions
-- ---------------------------------------------------------------------------

UPDATE maintenance_activity SET
    description = 'Emergency repair: ILS RWY 13 glide slope transmitter failed at 11:42Z. GS module ILS-GS-739 shipped from Urbandale depot. Estimated return to service 16:00Z pending flight check.',
    estimated_duration_hrs = 6
WHERE maintenance_activity_id = '16000001-0001-4001-8001-000000000001';

UPDATE maintenance_activity SET
    description = 'Quarterly ASR-9 inspection identified standby magnetron 12% below nominal output. Magnetron replaced; failover test passed. Primary channel within tolerance.',
    estimated_duration_hrs = 8
WHERE maintenance_activity_id = '16000002-0001-4001-8001-000000000002';

-- ---------------------------------------------------------------------------
-- Maintenance report for CID inspection prep (101 activity without report)
-- ---------------------------------------------------------------------------

INSERT INTO maintenance_report (
    maintenance_report_id, maintenance_activity_id, findings, actions_taken,
    parts_consumed_json, equipment_restored, completed_at, completed_by_user_id
)
SELECT
    '19000002-0001-4001-8001-000000000002',
    '16000003-0001-4001-8001-000000000003',
    'Pre-inspection walkdown complete. Localizer course width 700 ft (nominal). Glide path angle 2.99 deg.',
    'Adjusted monitor thresholds. Coordinated FAA flight check slot 25 Jun 08:00L.',
    q'[]',
    'N',
    TIMESTAMP '2026-06-23 14:30:00',
    '20000002-0001-4001-8001-000000000002'
FROM dual
WHERE NOT EXISTS (
    SELECT 1 FROM maintenance_report WHERE maintenance_activity_id = '16000003-0001-4001-8001-000000000003'
);

-- ---------------------------------------------------------------------------
-- Users — last login timestamps
-- ---------------------------------------------------------------------------

UPDATE users SET last_login_at = TIMESTAMP '2026-06-23 14:00:00'
WHERE user_id = '00000000-0000-0000-0000-000000000100';

UPDATE users SET last_login_at = TIMESTAMP '2026-06-23 13:55:00'
WHERE user_id = '20000001-0001-4001-8001-000000000001';

UPDATE users SET last_login_at = TIMESTAMP '2026-06-23 15:10:00'
WHERE user_id = '20000002-0001-4001-8001-000000000002';

UPDATE users SET last_login_at = TIMESTAMP '2026-06-23 12:00:00'
WHERE user_id = '20000003-0001-4001-8001-000000000003';

-- ---------------------------------------------------------------------------
-- Weather events — expanded metadata
-- ---------------------------------------------------------------------------

UPDATE weather_event SET metadata_json = q'[{"movement":"ESE","speedKts":25,"topsFl":420,"hailRisk":"MOD","tornadoRisk":"LOW"}]'
WHERE weather_event_id = '27000001-0001-4001-8001-000000000001';

UPDATE weather_event SET metadata_json = q'[{"ifr":"LIFR","burnOffExpected":"14:30Z","visibilityTrend":"IMPROVING"}]'
WHERE weather_event_id = '27000002-0001-4001-8001-000000000002';

UPDATE weather_event SET metadata_json = q'[{"runwaysAffected":["10L","10C","28R"],"alertType":"LLWAS","windShearKts":35}]'
WHERE weather_event_id = '27000003-0001-4001-8001-000000000003';

COMMIT;
