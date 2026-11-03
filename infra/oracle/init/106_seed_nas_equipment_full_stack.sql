-- =============================================================================
-- NAS Simulation — full equipment stack (106)
-- Idempotent extension of 100–105: new equipment types, depot test assets,
-- corridor-wide radio/radar/surveillance/weather, dependencies, parts, and
-- day-1 alerts. Safe to re-run on existing databases.
-- =============================================================================

SET DEFINE OFF

ALTER SESSION SET CONTAINER = FREEPDB1;
ALTER SESSION SET CURRENT_SCHEMA = nas_sim;

-- ---------------------------------------------------------------------------
-- Equipment types (106 additions — idempotent)
-- ---------------------------------------------------------------------------

MERGE INTO equipment_type_lkp t
USING (SELECT 'LLWAS' AS equipment_type_code, 'Low Level Wind Shear Alert System' AS display_name, 'WEATHER' AS category FROM dual) s
ON (t.equipment_type_code = s.equipment_type_code)
WHEN NOT MATCHED THEN INSERT (equipment_type_code, display_name, category)
    VALUES (s.equipment_type_code, s.display_name, s.category);

MERGE INTO equipment_type_lkp t
USING (SELECT 'AWOS' AS equipment_type_code, 'Automated Weather Observing System' AS display_name, 'WEATHER' AS category FROM dual) s
ON (t.equipment_type_code = s.equipment_type_code)
WHEN NOT MATCHED THEN INSERT (equipment_type_code, display_name, category)
    VALUES (s.equipment_type_code, s.display_name, s.category);

MERGE INTO equipment_type_lkp t
USING (SELECT 'TACAN' AS equipment_type_code, 'TACAN Navigation Aid' AS display_name, 'NAVAID' AS category FROM dual) s
ON (t.equipment_type_code = s.equipment_type_code)
WHEN NOT MATCHED THEN INSERT (equipment_type_code, display_name, category)
    VALUES (s.equipment_type_code, s.display_name, s.category);

MERGE INTO equipment_type_lkp t
USING (SELECT 'NDB' AS equipment_type_code, 'Non-Directional Beacon' AS display_name, 'NAVAID' AS category FROM dual) s
ON (t.equipment_type_code = s.equipment_type_code)
WHEN NOT MATCHED THEN INSERT (equipment_type_code, display_name, category)
    VALUES (s.equipment_type_code, s.display_name, s.category);

MERGE INTO equipment_type_lkp t
USING (SELECT 'ADS_B' AS equipment_type_code, 'ADS-B Ground Station' AS display_name, 'SURVEILLANCE' AS category FROM dual) s
ON (t.equipment_type_code = s.equipment_type_code)
WHEN NOT MATCHED THEN INSERT (equipment_type_code, display_name, category)
    VALUES (s.equipment_type_code, s.display_name, s.category);

MERGE INTO equipment_type_lkp t
USING (SELECT 'MAINT_TEST' AS equipment_type_code, 'Maintenance Test Equipment' AS display_name, 'MAINTENANCE' AS category FROM dual) s
ON (t.equipment_type_code = s.equipment_type_code)
WHEN NOT MATCHED THEN INSERT (equipment_type_code, display_name, category)
    VALUES (s.equipment_type_code, s.display_name, s.category);

-- ---------------------------------------------------------------------------
-- Maintenance depot — test benches and calibration rigs
-- ---------------------------------------------------------------------------

INSERT INTO equipment (
    equipment_id, facility_id, equipment_type_code, identifier, name,
    operational_status, installed_at, serial_number, manufacturer, model, metadata_json
)
SELECT '1200000f-0001-4001-8001-00000000000f', '10000006-0001-4001-8001-000000000006', 'MAINT_TEST', 'BENCH-ILS-01',
    'ILS Glide Slope / Localizer Bench Test System', 'OPERATIONAL',
    TIMESTAMP '2022-04-01 00:00:00', 'BENCH-ILS-MW-01', 'Thales', 'ILS-Bench-420',
    q'[{"capability":["ILS-420","ILS-450"],"calibrationIntervalDays":90,"depotZone":"NAVAID Lab A"}]'
FROM dual WHERE NOT EXISTS (SELECT 1 FROM equipment WHERE equipment_id = '1200000f-0001-4001-8001-00000000000f');

INSERT INTO equipment (
    equipment_id, facility_id, equipment_type_code, identifier, name,
    operational_status, installed_at, serial_number, manufacturer, model, metadata_json
)
SELECT '12000010-0001-4001-8001-000000000010', '10000006-0001-4001-8001-000000000006', 'MAINT_TEST', 'BENCH-VOR-01',
    'VOR/DME Field Analyzer — Portable', 'OPERATIONAL',
    TIMESTAMP '2021-09-15 00:00:00', 'BENCH-VOR-MW-01', 'Aeroflex', 'IFR-4000S',
    q'[{"capability":["VOR","DME","TACAN"],"vehicleMount":true,"depotZone":"Mobile Bay 2"}]'
FROM dual WHERE NOT EXISTS (SELECT 1 FROM equipment WHERE equipment_id = '12000010-0001-4001-8001-000000000010');

INSERT INTO equipment (
    equipment_id, facility_id, equipment_type_code, identifier, name,
    operational_status, installed_at, serial_number, manufacturer, model, metadata_json
)
SELECT '12000011-0001-4001-8001-000000000011', '10000006-0001-4001-8001-000000000006', 'MAINT_TEST', 'BENCH-RADAR-01',
    'ASR/ARSR Radar Transmitter Test Set', 'OPERATIONAL',
    TIMESTAMP '2020-11-01 00:00:00', 'BENCH-RAD-MW-01', 'Raytheon', 'RTS-ASR9',
    q'[{"capability":["ASR-9","ASR-8","ARSR-4"],"magnetronTest":true,"depotZone":"Radar Lab"}]'
FROM dual WHERE NOT EXISTS (SELECT 1 FROM equipment WHERE equipment_id = '12000011-0001-4001-8001-000000000011');

INSERT INTO equipment (
    equipment_id, facility_id, equipment_type_code, identifier, name,
    operational_status, installed_at, serial_number, manufacturer, model, metadata_json
)
SELECT '12000012-0001-4001-8001-000000000012', '10000006-0001-4001-8001-000000000006', 'MAINT_TEST', 'BENCH-COM-01',
    'VHF/UHF Communications RF Analyzer', 'OPERATIONAL',
    TIMESTAMP '2023-02-10 00:00:00', 'BENCH-COM-MW-01', q'[Rohde & Schwarz]', 'FSV3000',
    q'[{"capability":["COM_VHF","COM_UHF"],"spectrumRangeMhz":[108,512],"depotZone":"Comms Lab"}]'
FROM dual WHERE NOT EXISTS (SELECT 1 FROM equipment WHERE equipment_id = '12000012-0001-4001-8001-000000000012');

INSERT INTO equipment (
    equipment_id, facility_id, equipment_type_code, identifier, name,
    operational_status, installed_at, serial_number, manufacturer, model, metadata_json
)
SELECT '12000013-0001-4001-8001-000000000013', '10000006-0001-4001-8001-000000000006', 'MAINT_TEST', 'BENCH-ADS-01',
    'ADS-B / Mode S Ground Station Validator', 'OPERATIONAL',
    TIMESTAMP '2024-06-01 00:00:00', 'BENCH-ADS-MW-01', 'ERA', 'SQUID-ADS',
    q'[{"capability":["ADS_B","1090ES"],"depotZone":"Surveillance Lab"}]'
FROM dual WHERE NOT EXISTS (SELECT 1 FROM equipment WHERE equipment_id = '12000013-0001-4001-8001-000000000013');

-- ---------------------------------------------------------------------------
-- KDSM — approach, ground, weather, surveillance
-- ---------------------------------------------------------------------------

INSERT INTO equipment (equipment_id, facility_id, equipment_type_code, identifier, name, operational_status, installed_at, serial_number, manufacturer, model, metadata_json)
SELECT '12000014-0001-4001-8001-000000000014', '10000001-0001-4001-8001-000000000001', 'COM_VHF', 'COM-DSM-APP',
    'Des Moines Approach (119.1 MHz)', 'OPERATIONAL', TIMESTAMP '2016-01-10 00:00:00', 'COM-DSM-02', 'Park Air', 'T6 VHF',
    q'[{"frequencyMhz":119.1,"sector":"DSM Approach","pairedBackup":"COM-DSM-UHF"}]'
FROM dual WHERE NOT EXISTS (SELECT 1 FROM equipment WHERE equipment_id = '12000014-0001-4001-8001-000000000014');

INSERT INTO equipment (equipment_id, facility_id, equipment_type_code, identifier, name, operational_status, installed_at, serial_number, manufacturer, model, metadata_json)
SELECT '12000015-0001-4001-8001-000000000015', '10000001-0001-4001-8001-000000000001', 'COM_VHF', 'COM-DSM-GND',
    'Des Moines Ground Control (121.7 MHz)', 'OPERATIONAL', TIMESTAMP '2016-01-10 00:00:00', 'COM-DSM-03', 'Park Air', 'T6 VHF',
    q'[{"frequencyMhz":121.7,"role":"ground"}]'
FROM dual WHERE NOT EXISTS (SELECT 1 FROM equipment WHERE equipment_id = '12000015-0001-4001-8001-000000000015');

INSERT INTO equipment (equipment_id, facility_id, equipment_type_code, identifier, name, operational_status, installed_at, serial_number, manufacturer, model, metadata_json)
SELECT '12000016-0001-4001-8001-000000000016', '10000001-0001-4001-8001-000000000001', 'AWOS', 'AWOS-DSM',
    'Des Moines AWOS-3PT', 'OPERATIONAL', TIMESTAMP '2019-05-01 00:00:00', 'AWOS-DSM-01', 'Vaisala', 'AWOS-3PT',
    q'[{"frequencyMhz":118.525,"autoMetar":true}]'
FROM dual WHERE NOT EXISTS (SELECT 1 FROM equipment WHERE equipment_id = '12000016-0001-4001-8001-000000000016');

INSERT INTO equipment (equipment_id, facility_id, equipment_type_code, identifier, name, operational_status, installed_at, serial_number, manufacturer, model, metadata_json)
SELECT '12000017-0001-4001-8001-000000000017', '10000001-0001-4001-8001-000000000001', 'LLWAS', 'LLWAS-DSM',
    'Des Moines LLWAS — Runway 13/31', 'OPERATIONAL', TIMESTAMP '2014-08-01 00:00:00', 'LLWAS-DSM-01', 'Mesotech', 'LLWAS-III',
    q'[{"runways":["13","31"],"sensorCount":6}]'
FROM dual WHERE NOT EXISTS (SELECT 1 FROM equipment WHERE equipment_id = '12000017-0001-4001-8001-000000000017');

INSERT INTO equipment (equipment_id, facility_id, equipment_type_code, identifier, name, operational_status, installed_at, serial_number, manufacturer, model, metadata_json)
SELECT '12000018-0001-4001-8001-000000000018', '10000001-0001-4001-8001-000000000001', 'ADS_B', 'ADS-B-DSM',
    'Des Moines ADS-B Ground Station', 'OPERATIONAL', TIMESTAMP '2020-03-01 00:00:00', 'ADS-DSM-01', 'ERA', 'Squid-1090',
    q'[{"siteType":"ASR-9 colocated","coverageNm":80}]'
FROM dual WHERE NOT EXISTS (SELECT 1 FROM equipment WHERE equipment_id = '12000018-0001-4001-8001-000000000018');

-- DSM TRACON — primary approach VHF (UHF backup already seeded as 1200000e)
INSERT INTO equipment (equipment_id, facility_id, equipment_type_code, identifier, name, operational_status, installed_at, serial_number, manufacturer, model, metadata_json)
SELECT '12000019-0001-4001-8001-000000000019', '10000005-0001-4001-8001-000000000005', 'COM_VHF', 'COM-DSM-TRACON',
    'DSM TRACON Approach Control (124.0 MHz)', 'OPERATIONAL', TIMESTAMP '2018-03-01 00:00:00', 'COM-TRACON-01', 'Park Air', 'T6 VHF',
    q'[{"frequencyMhz":124.0,"feedsFrom":"ASR9-DSM","backupNet":"COM-DSM-UHF"}]'
FROM dual WHERE NOT EXISTS (SELECT 1 FROM equipment WHERE equipment_id = '12000019-0001-4001-8001-000000000019');

-- ---------------------------------------------------------------------------
-- KORD — full ATC stack (wind-shear LLWAS ties to 101 weather scenario)
-- ---------------------------------------------------------------------------

INSERT INTO equipment (equipment_id, facility_id, equipment_type_code, identifier, name, operational_status, installed_at, serial_number, manufacturer, model, metadata_json)
SELECT '1200001a-0001-4001-8001-00000000001a', '10000002-0001-4001-8001-000000000002', 'COM_VHF', 'COM-ORD-TWR',
    'O''Hare Tower (120.75 MHz)', 'OPERATIONAL', TIMESTAMP '2015-01-01 00:00:00', 'COM-ORD-01', 'Park Air', 'T6 VHF',
    q'[{"frequencyMhz":120.75,"sector":"ORD Tower"}]'
FROM dual WHERE NOT EXISTS (SELECT 1 FROM equipment WHERE equipment_id = '1200001a-0001-4001-8001-00000000001a');

INSERT INTO equipment (equipment_id, facility_id, equipment_type_code, identifier, name, operational_status, installed_at, serial_number, manufacturer, model, metadata_json)
SELECT '1200001b-0001-4001-8001-00000000001b', '10000002-0001-4001-8001-000000000002', 'COM_VHF', 'COM-ORD-APP',
    'Chicago Approach (127.9 MHz)', 'OPERATIONAL', TIMESTAMP '2015-01-01 00:00:00', 'COM-ORD-02', 'Park Air', 'T6 VHF',
    q'[{"frequencyMhz":127.9,"sector":"ORD Approach"}]'
FROM dual WHERE NOT EXISTS (SELECT 1 FROM equipment WHERE equipment_id = '1200001b-0001-4001-8001-00000000001b');

INSERT INTO equipment (equipment_id, facility_id, equipment_type_code, identifier, name, operational_status, installed_at, serial_number, manufacturer, model, metadata_json)
SELECT '1200001c-0001-4001-8001-00000000001c', '10000002-0001-4001-8001-000000000002', 'COM_VHF', 'COM-ORD-GND',
    'O''Hare Ground (121.9 MHz)', 'OPERATIONAL', TIMESTAMP '2015-01-01 00:00:00', 'COM-ORD-03', 'Park Air', 'T6 VHF',
    q'[{"frequencyMhz":121.9,"role":"ground"}]'
FROM dual WHERE NOT EXISTS (SELECT 1 FROM equipment WHERE equipment_id = '1200001c-0001-4001-8001-00000000001c');

INSERT INTO equipment (equipment_id, facility_id, equipment_type_code, identifier, name, operational_status, installed_at, serial_number, manufacturer, model, metadata_json)
SELECT '1200001d-0001-4001-8001-00000000001d', '10000002-0001-4001-8001-000000000002', 'COM_UHF', 'COM-ORD-UHF',
    'Chicago Approach UHF Backup (257.8 MHz)', 'OPERATIONAL', TIMESTAMP '2016-06-01 00:00:00', 'COM-ORD-UHF', 'Park Air', 'T6 UHF',
    q'[{"frequencyMhz":257.8,"backupFor":"COM-ORD-APP"}]'
FROM dual WHERE NOT EXISTS (SELECT 1 FROM equipment WHERE equipment_id = '1200001d-0001-4001-8001-00000000001d');

INSERT INTO equipment (equipment_id, facility_id, equipment_type_code, identifier, name, operational_status, installed_at, serial_number, manufacturer, model, metadata_json)
SELECT '1200001e-0001-4001-8001-00000000001e', '10000002-0001-4001-8001-000000000002', 'RADAR_ASR', 'ASR9-ORD',
    'O''Hare ASR-9 Approach Radar', 'OPERATIONAL', TIMESTAMP '2012-04-01 00:00:00', 'ASR-ORD-01', 'Raytheon', 'ASR-9',
    q'[{"coverageNm":60,"feedsTracon":"ORD TRACON"}]'
FROM dual WHERE NOT EXISTS (SELECT 1 FROM equipment WHERE equipment_id = '1200001e-0001-4001-8001-00000000001e');

INSERT INTO equipment (equipment_id, facility_id, equipment_type_code, identifier, name, operational_status, installed_at, serial_number, manufacturer, model, metadata_json)
SELECT '1200001f-0001-4001-8001-00000000001f', '10000002-0001-4001-8001-000000000002', 'LLWAS', 'LLWAS-ORD',
    'O''Hare LLWAS — Runways 10L/10C/28R', 'OPERATIONAL', TIMESTAMP '2010-02-01 00:00:00', 'LLWAS-ORD-01', 'Mesotech', 'LLWAS-III',
    q'[{"runways":["10L","10C","28R"],"windShearAlertActive":true,"scenarioNote":"FDX882 go-around trigger"}]'
FROM dual WHERE NOT EXISTS (SELECT 1 FROM equipment WHERE equipment_id = '1200001f-0001-4001-8001-00000000001f');

INSERT INTO equipment (equipment_id, facility_id, equipment_type_code, identifier, name, operational_status, installed_at, serial_number, manufacturer, model, metadata_json)
SELECT '12000020-0001-4001-8001-000000000020', '10000002-0001-4001-8001-000000000002', 'PAPI', 'PAPI-10L-ORD',
    'PAPI — Runway 10L', 'OPERATIONAL', TIMESTAMP '2013-06-01 00:00:00', 'PAPI-ORD-10L', 'Honeywell', 'PAPI-4',
    q'[{"runway":"10L","slopeAngle":3.0}]'
FROM dual WHERE NOT EXISTS (SELECT 1 FROM equipment WHERE equipment_id = '12000020-0001-4001-8001-000000000020');

INSERT INTO equipment (equipment_id, facility_id, equipment_type_code, identifier, name, operational_status, installed_at, serial_number, manufacturer, model, metadata_json)
SELECT '12000021-0001-4001-8001-000000000021', '10000002-0001-4001-8001-000000000002', 'RWY_LIGHTING', 'RWY-LGT-10L-ORD',
    'Runway 10L High-Intensity Lighting', 'OPERATIONAL', TIMESTAMP '2013-06-01 00:00:00', 'RALS-ORD-10L', 'Honeywell', 'ALS-F-2',
    q'[{"runway":"10L","intensitySteps":5}]'
FROM dual WHERE NOT EXISTS (SELECT 1 FROM equipment WHERE equipment_id = '12000021-0001-4001-8001-000000000021');

INSERT INTO equipment (equipment_id, facility_id, equipment_type_code, identifier, name, operational_status, installed_at, serial_number, manufacturer, model, metadata_json)
SELECT '12000022-0001-4001-8001-000000000022', '10000002-0001-4001-8001-000000000002', 'AWOS', 'AWOS-ORD',
    'O''Hare AWOS-3PT', 'OPERATIONAL', TIMESTAMP '2018-01-01 00:00:00', 'AWOS-ORD-01', 'Vaisala', 'AWOS-3PT',
    q'[{"frequencyMhz":135.425}]'
FROM dual WHERE NOT EXISTS (SELECT 1 FROM equipment WHERE equipment_id = '12000022-0001-4001-8001-000000000022');

INSERT INTO equipment (equipment_id, facility_id, equipment_type_code, identifier, name, operational_status, installed_at, serial_number, manufacturer, model, metadata_json)
SELECT '12000023-0001-4001-8001-000000000023', '10000002-0001-4001-8001-000000000002', 'ADS_B', 'ADS-B-ORD',
    'O''Hare ADS-B Ground Station', 'OPERATIONAL', TIMESTAMP '2021-01-01 00:00:00', 'ADS-ORD-01', 'ERA', 'Squid-1090',
    q'[{"coverageNm":120,"siteType":"airport"}]'
FROM dual WHERE NOT EXISTS (SELECT 1 FROM equipment WHERE equipment_id = '12000023-0001-4001-8001-000000000023');

-- ---------------------------------------------------------------------------
-- KMSP — hub equipment (fog scenario)
-- ---------------------------------------------------------------------------

INSERT INTO equipment (equipment_id, facility_id, equipment_type_code, identifier, name, operational_status, installed_at, serial_number, manufacturer, model, metadata_json)
SELECT '12000024-0001-4001-8001-000000000024', '10000003-0001-4001-8001-000000000003', 'ILS', 'ILS-12R-MSP',
    'ILS Category III — Runway 12R', 'OPERATIONAL', TIMESTAMP '2016-08-01 00:00:00', 'ILS-MSP-12R', 'Thales', 'ILS-450',
    q'[{"runway":"12R","cat":"III","fogOps":true}]'
FROM dual WHERE NOT EXISTS (SELECT 1 FROM equipment WHERE equipment_id = '12000024-0001-4001-8001-000000000024');

INSERT INTO equipment (equipment_id, facility_id, equipment_type_code, identifier, name, operational_status, installed_at, serial_number, manufacturer, model, metadata_json)
SELECT '12000025-0001-4001-8001-000000000025', '10000003-0001-4001-8001-000000000003', 'COM_VHF', 'COM-MSP-TWR',
    'MSP Tower (118.7 MHz)', 'OPERATIONAL', TIMESTAMP '2014-01-01 00:00:00', 'COM-MSP-01', 'Park Air', 'T6 VHF',
    q'[{"frequencyMhz":118.7}]'
FROM dual WHERE NOT EXISTS (SELECT 1 FROM equipment WHERE equipment_id = '12000025-0001-4001-8001-000000000025');

INSERT INTO equipment (equipment_id, facility_id, equipment_type_code, identifier, name, operational_status, installed_at, serial_number, manufacturer, model, metadata_json)
SELECT '12000026-0001-4001-8001-000000000026', '10000003-0001-4001-8001-000000000003', 'COM_VHF', 'COM-MSP-APP',
    'Minneapolis Approach (124.7 MHz)', 'OPERATIONAL', TIMESTAMP '2014-01-01 00:00:00', 'COM-MSP-02', 'Park Air', 'T6 VHF',
    q'[{"frequencyMhz":124.7}]'
FROM dual WHERE NOT EXISTS (SELECT 1 FROM equipment WHERE equipment_id = '12000026-0001-4001-8001-000000000026');

INSERT INTO equipment (equipment_id, facility_id, equipment_type_code, identifier, name, operational_status, installed_at, serial_number, manufacturer, model, metadata_json)
SELECT '12000027-0001-4001-8001-000000000027', '10000003-0001-4001-8001-000000000003', 'RADAR_ASR', 'ASR9-MSP',
    'MSP ASR-9 Approach Radar', 'OPERATIONAL', TIMESTAMP '2011-09-01 00:00:00', 'ASR-MSP-01', 'Raytheon', 'ASR-9',
    q'[{"coverageNm":55}]'
FROM dual WHERE NOT EXISTS (SELECT 1 FROM equipment WHERE equipment_id = '12000027-0001-4001-8001-000000000027');

INSERT INTO equipment (equipment_id, facility_id, equipment_type_code, identifier, name, operational_status, installed_at, serial_number, manufacturer, model, metadata_json)
SELECT '12000028-0001-4001-8001-000000000028', '10000003-0001-4001-8001-000000000003', 'PAPI', 'PAPI-12R-MSP',
    'PAPI — Runway 12R', 'OPERATIONAL', TIMESTAMP '2015-03-01 00:00:00', 'PAPI-MSP-12R', 'Honeywell', 'PAPI-4',
    q'[{"runway":"12R"}]'
FROM dual WHERE NOT EXISTS (SELECT 1 FROM equipment WHERE equipment_id = '12000028-0001-4001-8001-000000000028');

INSERT INTO equipment (equipment_id, facility_id, equipment_type_code, identifier, name, operational_status, installed_at, serial_number, manufacturer, model, metadata_json)
SELECT '12000029-0001-4001-8001-000000000029', '10000003-0001-4001-8001-000000000003', 'AWOS', 'AWOS-MSP',
    'MSP AWOS-3PT', 'OPERATIONAL', TIMESTAMP '2017-04-01 00:00:00', 'AWOS-MSP-01', 'Vaisala', 'AWOS-3PT',
    q'[{"frequencyMhz":124.325,"fogSensor":true}]'
FROM dual WHERE NOT EXISTS (SELECT 1 FROM equipment WHERE equipment_id = '12000029-0001-4001-8001-000000000029');

INSERT INTO equipment (equipment_id, facility_id, equipment_type_code, identifier, name, operational_status, installed_at, serial_number, manufacturer, model, metadata_json)
SELECT '1200002a-0001-4001-8001-00000000002a', '10000003-0001-4001-8001-000000000003', 'ADS_B', 'ADS-B-MSP',
    'MSP ADS-B Ground Station', 'OPERATIONAL', TIMESTAMP '2020-08-01 00:00:00', 'ADS-MSP-01', 'ERA', 'Squid-1090',
    q'[{"coverageNm":90}]'
FROM dual WHERE NOT EXISTS (SELECT 1 FROM equipment WHERE equipment_id = '1200002a-0001-4001-8001-00000000002a');

-- ---------------------------------------------------------------------------
-- KOMA, KCID, KMLI, KMKE — corridor airports
-- ---------------------------------------------------------------------------

INSERT INTO equipment (equipment_id, facility_id, equipment_type_code, identifier, name, operational_status, installed_at, serial_number, manufacturer, model, metadata_json)
SELECT '1200002b-0001-4001-8001-00000000002b', '10000009-0001-4001-8001-000000000009', 'COM_VHF', 'COM-OMA-TWR',
    'Eppley Tower (121.0 MHz)', 'OPERATIONAL', TIMESTAMP '2013-01-01 00:00:00', 'COM-OMA-01', 'Park Air', 'T6 VHF',
    q'[{"frequencyMhz":121.0}]'
FROM dual WHERE NOT EXISTS (SELECT 1 FROM equipment WHERE equipment_id = '1200002b-0001-4001-8001-00000000002b');

INSERT INTO equipment (equipment_id, facility_id, equipment_type_code, identifier, name, operational_status, installed_at, serial_number, manufacturer, model, metadata_json)
SELECT '1200002c-0001-4001-8001-00000000002c', '10000009-0001-4001-8001-000000000009', 'COM_VHF', 'COM-OMA-APP',
    'Omaha Approach (120.15 MHz)', 'OPERATIONAL', TIMESTAMP '2013-01-01 00:00:00', 'COM-OMA-02', 'Park Air', 'T6 VHF',
    q'[{"frequencyMhz":120.15}]'
FROM dual WHERE NOT EXISTS (SELECT 1 FROM equipment WHERE equipment_id = '1200002c-0001-4001-8001-00000000002c');

INSERT INTO equipment (equipment_id, facility_id, equipment_type_code, identifier, name, operational_status, installed_at, serial_number, manufacturer, model, metadata_json)
SELECT '1200002d-0001-4001-8001-00000000002d', '10000009-0001-4001-8001-000000000009', 'ILS', 'ILS-14R-OMA',
    'ILS Category I — Runway 14R', 'OPERATIONAL', TIMESTAMP '2018-02-01 00:00:00', 'ILS-OMA-14R', 'Thales', 'ILS-420',
    q'[{"runway":"14R","cat":"I"}]'
FROM dual WHERE NOT EXISTS (SELECT 1 FROM equipment WHERE equipment_id = '1200002d-0001-4001-8001-00000000002d');

INSERT INTO equipment (equipment_id, facility_id, equipment_type_code, identifier, name, operational_status, installed_at, serial_number, manufacturer, model, metadata_json)
SELECT '1200002e-0001-4001-8001-00000000002e', '10000009-0001-4001-8001-000000000009', 'AWOS', 'AWOS-OMA',
    'Eppley AWOS-3', 'OPERATIONAL', TIMESTAMP '2016-07-01 00:00:00', 'AWOS-OMA-01', 'Vaisala', 'AWOS-3',
    q'[{"frequencyMhz":118.0}]'
FROM dual WHERE NOT EXISTS (SELECT 1 FROM equipment WHERE equipment_id = '1200002e-0001-4001-8001-00000000002e');

INSERT INTO equipment (equipment_id, facility_id, equipment_type_code, identifier, name, operational_status, installed_at, serial_number, manufacturer, model, metadata_json)
SELECT '1200002f-0001-4001-8001-00000000002f', '10000009-0001-4001-8001-000000000009', 'ADS_B', 'ADS-B-OMA',
    'Eppley ADS-B Ground Station', 'OPERATIONAL', TIMESTAMP '2021-03-01 00:00:00', 'ADS-OMA-01', 'ERA', 'Squid-1090',
    q'[{"coverageNm":70}]'
FROM dual WHERE NOT EXISTS (SELECT 1 FROM equipment WHERE equipment_id = '1200002f-0001-4001-8001-00000000002f');

INSERT INTO equipment (equipment_id, facility_id, equipment_type_code, identifier, name, operational_status, installed_at, serial_number, manufacturer, model, metadata_json)
SELECT '12000030-0001-4001-8001-000000000030', '1000000a-0001-4001-8001-00000000000a', 'COM_VHF', 'COM-CID-TWR',
    'Cedar Rapids Tower (120.7 MHz)', 'OPERATIONAL', TIMESTAMP '2015-05-01 00:00:00', 'COM-CID-01', 'Park Air', 'T6 VHF',
    q'[{"frequencyMhz":120.7}]'
FROM dual WHERE NOT EXISTS (SELECT 1 FROM equipment WHERE equipment_id = '12000030-0001-4001-8001-000000000030');

INSERT INTO equipment (equipment_id, facility_id, equipment_type_code, identifier, name, operational_status, installed_at, serial_number, manufacturer, model, metadata_json)
SELECT '12000031-0001-4001-8001-000000000031', '1000000a-0001-4001-8001-00000000000a', 'COM_VHF', 'COM-CID-APP',
    'Cedar Rapids Approach (119.75 MHz)', 'OPERATIONAL', TIMESTAMP '2015-05-01 00:00:00', 'COM-CID-02', 'Park Air', 'T6 VHF',
    q'[{"frequencyMhz":119.75}]'
FROM dual WHERE NOT EXISTS (SELECT 1 FROM equipment WHERE equipment_id = '12000031-0001-4001-8001-000000000031');

INSERT INTO equipment (equipment_id, facility_id, equipment_type_code, identifier, name, operational_status, installed_at, serial_number, manufacturer, model, metadata_json)
SELECT '12000032-0001-4001-8001-000000000032', '1000000a-0001-4001-8001-00000000000a', 'PAPI', 'PAPI-13-CID',
    'PAPI — Runway 13 Cedar Rapids', 'OPERATIONAL', TIMESTAMP '2019-01-15 00:00:00', 'PAPI-CID-13', 'Honeywell', 'PAPI-4',
    q'[{"runway":"13"}]'
FROM dual WHERE NOT EXISTS (SELECT 1 FROM equipment WHERE equipment_id = '12000032-0001-4001-8001-000000000032');

INSERT INTO equipment (equipment_id, facility_id, equipment_type_code, identifier, name, operational_status, installed_at, serial_number, manufacturer, model, metadata_json)
SELECT '12000033-0001-4001-8001-000000000033', '1000000a-0001-4001-8001-00000000000a', 'AWOS', 'AWOS-CID',
    'Cedar Rapids AWOS-3', 'OPERATIONAL', TIMESTAMP '2017-01-01 00:00:00', 'AWOS-CID-01', 'Vaisala', 'AWOS-3',
    q'[{"frequencyMhz":118.875}]'
FROM dual WHERE NOT EXISTS (SELECT 1 FROM equipment WHERE equipment_id = '12000033-0001-4001-8001-000000000033');

INSERT INTO equipment (equipment_id, facility_id, equipment_type_code, identifier, name, operational_status, installed_at, serial_number, manufacturer, model, metadata_json)
SELECT '12000034-0001-4001-8001-000000000034', '1000000a-0001-4001-8001-00000000000a', 'ADS_B', 'ADS-B-CID',
    'Cedar Rapids ADS-B Ground Station', 'OPERATIONAL', TIMESTAMP '2022-01-01 00:00:00', 'ADS-CID-01', 'ERA', 'Squid-1090',
    q'[{"coverageNm":60}]'
FROM dual WHERE NOT EXISTS (SELECT 1 FROM equipment WHERE equipment_id = '12000034-0001-4001-8001-000000000034');

INSERT INTO equipment (equipment_id, facility_id, equipment_type_code, identifier, name, operational_status, installed_at, serial_number, manufacturer, model, metadata_json)
SELECT '12000035-0001-4001-8001-000000000035', '1000000b-0001-4001-8001-00000000000b', 'ILS', 'ILS-09-MLI',
    'ILS Category I — Runway 09', 'OPERATIONAL', TIMESTAMP '2020-06-01 00:00:00', 'ILS-MLI-09', 'Thales', 'ILS-420',
    q'[{"runway":"09","cat":"I"}]'
FROM dual WHERE NOT EXISTS (SELECT 1 FROM equipment WHERE equipment_id = '12000035-0001-4001-8001-000000000035');

INSERT INTO equipment (equipment_id, facility_id, equipment_type_code, identifier, name, operational_status, installed_at, serial_number, manufacturer, model, metadata_json)
SELECT '12000036-0001-4001-8001-000000000036', '1000000b-0001-4001-8001-00000000000b', 'COM_VHF', 'COM-MLI-TWR',
    'Quad City Tower (121.1 MHz)', 'OPERATIONAL', TIMESTAMP '2014-03-01 00:00:00', 'COM-MLI-01', 'Park Air', 'T6 VHF',
    q'[{"frequencyMhz":121.1}]'
FROM dual WHERE NOT EXISTS (SELECT 1 FROM equipment WHERE equipment_id = '12000036-0001-4001-8001-000000000036');

INSERT INTO equipment (equipment_id, facility_id, equipment_type_code, identifier, name, operational_status, installed_at, serial_number, manufacturer, model, metadata_json)
SELECT '12000037-0001-4001-8001-000000000037', '1000000b-0001-4001-8001-00000000000b', 'NDB', 'NDB-MLI',
    'Quad City NDB (MLI)', 'OPERATIONAL', TIMESTAMP '2008-01-01 00:00:00', 'NDB-MLI-01', 'Selex', 'NDB-200',
    q'[{"frequencyKhz":353,"ident":"MLI"}]'
FROM dual WHERE NOT EXISTS (SELECT 1 FROM equipment WHERE equipment_id = '12000037-0001-4001-8001-000000000037');

INSERT INTO equipment (equipment_id, facility_id, equipment_type_code, identifier, name, operational_status, installed_at, serial_number, manufacturer, model, metadata_json)
SELECT '12000038-0001-4001-8001-000000000038', '1000000b-0001-4001-8001-00000000000b', 'AWOS', 'AWOS-MLI',
    'Quad City AWOS-3', 'OPERATIONAL', TIMESTAMP '2016-09-01 00:00:00', 'AWOS-MLI-01', 'Vaisala', 'AWOS-3',
    q'[{"frequencyMhz":118.35}]'
FROM dual WHERE NOT EXISTS (SELECT 1 FROM equipment WHERE equipment_id = '12000038-0001-4001-8001-000000000038');

INSERT INTO equipment (equipment_id, facility_id, equipment_type_code, identifier, name, operational_status, installed_at, serial_number, manufacturer, model, metadata_json)
SELECT '12000039-0001-4001-8001-000000000039', '1000000c-0001-4001-8001-00000000000c', 'COM_VHF', 'COM-MKE-TWR',
    'Milwaukee Tower (119.3 MHz)', 'OPERATIONAL', TIMESTAMP '2013-08-01 00:00:00', 'COM-MKE-01', 'Park Air', 'T6 VHF',
    q'[{"frequencyMhz":119.3}]'
FROM dual WHERE NOT EXISTS (SELECT 1 FROM equipment WHERE equipment_id = '12000039-0001-4001-8001-000000000039');

INSERT INTO equipment (equipment_id, facility_id, equipment_type_code, identifier, name, operational_status, installed_at, serial_number, manufacturer, model, metadata_json)
SELECT '1200003a-0001-4001-8001-00000000003a', '1000000c-0001-4001-8001-00000000000c', 'COM_VHF', 'COM-MKE-APP',
    'Milwaukee Approach (120.55 MHz)', 'OPERATIONAL', TIMESTAMP '2013-08-01 00:00:00', 'COM-MKE-02', 'Park Air', 'T6 VHF',
    q'[{"frequencyMhz":120.55}]'
FROM dual WHERE NOT EXISTS (SELECT 1 FROM equipment WHERE equipment_id = '1200003a-0001-4001-8001-00000000003a');

INSERT INTO equipment (equipment_id, facility_id, equipment_type_code, identifier, name, operational_status, installed_at, serial_number, manufacturer, model, metadata_json)
SELECT '1200003b-0001-4001-8001-00000000003b', '1000000c-0001-4001-8001-00000000000c', 'RADAR_ASR', 'ASR8-MKE',
    'Milwaukee ASR-8 Approach Radar', 'OPERATIONAL', TIMESTAMP '2010-05-01 00:00:00', 'ASR-MKE-01', 'Raytheon', 'ASR-8',
    q'[{"coverageNm":45}]'
FROM dual WHERE NOT EXISTS (SELECT 1 FROM equipment WHERE equipment_id = '1200003b-0001-4001-8001-00000000003b');

INSERT INTO equipment (equipment_id, facility_id, equipment_type_code, identifier, name, operational_status, installed_at, serial_number, manufacturer, model, metadata_json)
SELECT '1200003c-0001-4001-8001-00000000003c', '1000000c-0001-4001-8001-00000000000c', 'PAPI', 'PAPI-01L-MKE',
    'PAPI — Runway 01L Milwaukee', 'DEGRADED', TIMESTAMP '2016-09-01 00:00:00', 'PAPI-MKE-01L', 'Honeywell', 'PAPI-4',
    q'[{"runway":"01L","lampIntensityPct":82}]'
FROM dual WHERE NOT EXISTS (SELECT 1 FROM equipment WHERE equipment_id = '1200003c-0001-4001-8001-00000000003c');

INSERT INTO equipment (equipment_id, facility_id, equipment_type_code, identifier, name, operational_status, installed_at, serial_number, manufacturer, model, metadata_json)
SELECT '1200003d-0001-4001-8001-00000000003d', '1000000c-0001-4001-8001-00000000000c', 'AWOS', 'AWOS-MKE',
    'Milwaukee AWOS-3PT', 'OPERATIONAL', TIMESTAMP '2018-11-01 00:00:00', 'AWOS-MKE-01', 'Vaisala', 'AWOS-3PT',
    q'[{"frequencyMhz":118.55}]'
FROM dual WHERE NOT EXISTS (SELECT 1 FROM equipment WHERE equipment_id = '1200003d-0001-4001-8001-00000000003d');

INSERT INTO equipment (equipment_id, facility_id, equipment_type_code, identifier, name, operational_status, installed_at, serial_number, manufacturer, model, metadata_json)
SELECT '1200003e-0001-4001-8001-00000000003e', '1000000c-0001-4001-8001-00000000000c', 'ADS_B', 'ADS-B-MKE',
    'Milwaukee ADS-B Ground Station', 'DEGRADED', TIMESTAMP '2021-06-01 00:00:00', 'ADS-MKE-01', 'ERA', 'Squid-1090',
    q'[{"coverageNm":65,"degradedReason":"antenna feed loss 2.1 dB"}]'
FROM dual WHERE NOT EXISTS (SELECT 1 FROM equipment WHERE equipment_id = '1200003e-0001-4001-8001-00000000003e');

-- ---------------------------------------------------------------------------
-- ARTCC — en-route radar and sector comms (ZAU, ZMP)
-- ---------------------------------------------------------------------------

INSERT INTO equipment (equipment_id, facility_id, equipment_type_code, identifier, name, operational_status, installed_at, serial_number, manufacturer, model, metadata_json)
SELECT '1200003f-0001-4001-8001-00000000003f', '10000004-0001-4001-8001-000000000004', 'RADAR_ARR', 'ARSR-ZAU-1',
    'Chicago Center ARSR-4 — Site 1', 'OPERATIONAL', TIMESTAMP '2009-06-01 00:00:00', 'ARSR-ZAU-01', 'Raytheon', 'ARSR-4',
    q'[{"coverageNm":200,"feedsArtcc":"ZAU","siteId":"CIG-1"}]'
FROM dual WHERE NOT EXISTS (SELECT 1 FROM equipment WHERE equipment_id = '1200003f-0001-4001-8001-00000000003f');

INSERT INTO equipment (equipment_id, facility_id, equipment_type_code, identifier, name, operational_status, installed_at, serial_number, manufacturer, model, metadata_json)
SELECT '12000040-0001-4001-8001-000000000040', '10000004-0001-4001-8001-000000000004', 'RADAR_ARR', 'ARSR-ZAU-2',
    'Chicago Center ARSR-4 — Site 2 (Backup)', 'OPERATIONAL', TIMESTAMP '2009-06-01 00:00:00', 'ARSR-ZAU-02', 'Raytheon', 'ARSR-4',
    q'[{"coverageNm":200,"role":"hot standby"}]'
FROM dual WHERE NOT EXISTS (SELECT 1 FROM equipment WHERE equipment_id = '12000040-0001-4001-8001-000000000040');

INSERT INTO equipment (equipment_id, facility_id, equipment_type_code, identifier, name, operational_status, installed_at, serial_number, manufacturer, model, metadata_json)
SELECT '12000041-0001-4001-8001-000000000041', '10000004-0001-4001-8001-000000000004', 'COM_VHF', 'COM-ZAU-2',
    'Chicago Center VHF Sector 15', 'OPERATIONAL', TIMESTAMP '2018-08-01 00:00:00', 'COM-ZAU-15', 'Park Air', 'T6 VHF',
    q'[{"sector":"15","frequencyMhz":125.85,"artcc":"ZAU"}]'
FROM dual WHERE NOT EXISTS (SELECT 1 FROM equipment WHERE equipment_id = '12000041-0001-4001-8001-000000000041');

INSERT INTO equipment (equipment_id, facility_id, equipment_type_code, identifier, name, operational_status, installed_at, serial_number, manufacturer, model, metadata_json)
SELECT '12000042-0001-4001-8001-000000000042', '10000004-0001-4001-8001-000000000004', 'COM_VHF', 'COM-ZAU-3',
    'Chicago Center VHF Sector 52', 'OPERATIONAL', TIMESTAMP '2018-08-01 00:00:00', 'COM-ZAU-52', 'Park Air', 'T6 VHF',
    q'[{"sector":"52","frequencyMhz":132.45,"artcc":"ZAU"}]'
FROM dual WHERE NOT EXISTS (SELECT 1 FROM equipment WHERE equipment_id = '12000042-0001-4001-8001-000000000042');

INSERT INTO equipment (equipment_id, facility_id, equipment_type_code, identifier, name, operational_status, installed_at, serial_number, manufacturer, model, metadata_json)
SELECT '12000043-0001-4001-8001-000000000043', '10000004-0001-4001-8001-000000000004', 'COM_UHF', 'COM-ZAU-UHF',
    'Chicago Center UHF Sector Backup Net', 'OPERATIONAL', TIMESTAMP '2019-01-01 00:00:00', 'COM-ZAU-UHF', 'Park Air', 'T6 UHF',
    q'[{"frequencyMhz":257.4,"backupFor":["COM-ZAU-1","COM-ZAU-2"]}]'
FROM dual WHERE NOT EXISTS (SELECT 1 FROM equipment WHERE equipment_id = '12000043-0001-4001-8001-000000000043');

INSERT INTO equipment (equipment_id, facility_id, equipment_type_code, identifier, name, operational_status, installed_at, serial_number, manufacturer, model, metadata_json)
SELECT '12000044-0001-4001-8001-000000000044', '1000000d-0001-4001-8001-00000000000d', 'RADAR_ARR', 'ARSR-ZMP-1',
    'Minneapolis Center ARSR-4', 'OPERATIONAL', TIMESTAMP '2010-03-01 00:00:00', 'ARSR-ZMP-01', 'Raytheon', 'ARSR-4',
    q'[{"coverageNm":220,"feedsArtcc":"ZMP"}]'
FROM dual WHERE NOT EXISTS (SELECT 1 FROM equipment WHERE equipment_id = '12000044-0001-4001-8001-000000000044');

INSERT INTO equipment (equipment_id, facility_id, equipment_type_code, identifier, name, operational_status, installed_at, serial_number, manufacturer, model, metadata_json)
SELECT '12000045-0001-4001-8001-000000000045', '1000000d-0001-4001-8001-00000000000d', 'COM_VHF', 'COM-ZMP-1',
    'Minneapolis Center VHF Sector 28', 'OPERATIONAL', TIMESTAMP '2017-05-01 00:00:00', 'COM-ZMP-28', 'Park Air', 'T6 VHF',
    q'[{"sector":"28","frequencyMhz":128.6,"artcc":"ZMP"}]'
FROM dual WHERE NOT EXISTS (SELECT 1 FROM equipment WHERE equipment_id = '12000045-0001-4001-8001-000000000045');

INSERT INTO equipment (equipment_id, facility_id, equipment_type_code, identifier, name, operational_status, installed_at, serial_number, manufacturer, model, metadata_json)
SELECT '12000046-0001-4001-8001-000000000046', '1000000d-0001-4001-8001-00000000000d', 'COM_VHF', 'COM-ZMP-2',
    'Minneapolis Center VHF Sector 31', 'OPERATIONAL', TIMESTAMP '2017-05-01 00:00:00', 'COM-ZMP-31', 'Park Air', 'T6 VHF',
    q'[{"sector":"31","frequencyMhz":135.175,"artcc":"ZMP"}]'
FROM dual WHERE NOT EXISTS (SELECT 1 FROM equipment WHERE equipment_id = '12000046-0001-4001-8001-000000000046');

-- KAMW VORTAC — TACAN component
INSERT INTO equipment (equipment_id, facility_id, equipment_type_code, identifier, name, operational_status, installed_at, serial_number, manufacturer, model, metadata_json)
SELECT '12000047-0001-4001-8001-000000000047', '10000008-0001-4001-8001-000000000008', 'TACAN', 'TACAN-DSM',
    'Des Moines VORTAC TACAN (DSM)', 'OPERATIONAL', TIMESTAMP '2010-11-01 00:00:00', 'TACAN-DSM-01', 'Selex', 'TACAN-1150',
    q'[{"ident":"DSM","channel":79,"pairedVor":"VOR-DSM"}]'
FROM dual WHERE NOT EXISTS (SELECT 1 FROM equipment WHERE equipment_id = '12000047-0001-4001-8001-000000000047');

-- ---------------------------------------------------------------------------
-- Runway ↔ equipment links (new rows only)
-- ---------------------------------------------------------------------------

INSERT INTO runway_equipment (runway_equipment_id, runway_id, equipment_id, relationship_type, is_required)
SELECT '13000006-0001-4001-8001-000000000006', '11000003-0001-4001-8001-000000000003', '12000020-0001-4001-8001-000000000020', 'SUPPORTS', 'N'
FROM dual WHERE NOT EXISTS (SELECT 1 FROM runway_equipment WHERE runway_equipment_id = '13000006-0001-4001-8001-000000000006');

INSERT INTO runway_equipment (runway_equipment_id, runway_id, equipment_id, relationship_type, is_required)
SELECT '13000007-0001-4001-8001-000000000007', '11000003-0001-4001-8001-000000000003', '12000021-0001-4001-8001-000000000021', 'SUPPORTS', 'Y'
FROM dual WHERE NOT EXISTS (SELECT 1 FROM runway_equipment WHERE runway_equipment_id = '13000007-0001-4001-8001-000000000007');

INSERT INTO runway_equipment (runway_equipment_id, runway_id, equipment_id, relationship_type, is_required)
SELECT '13000008-0001-4001-8001-000000000008', '11000005-0001-4001-8001-000000000005', '12000024-0001-4001-8001-000000000024', 'SUPPORTS', 'Y'
FROM dual WHERE NOT EXISTS (SELECT 1 FROM runway_equipment WHERE runway_equipment_id = '13000008-0001-4001-8001-000000000008');

INSERT INTO runway_equipment (runway_equipment_id, runway_id, equipment_id, relationship_type, is_required)
SELECT '13000009-0001-4001-8001-000000000009', '11000005-0001-4001-8001-000000000005', '12000028-0001-4001-8001-000000000028', 'SUPPORTS', 'N'
FROM dual WHERE NOT EXISTS (SELECT 1 FROM runway_equipment WHERE runway_equipment_id = '13000009-0001-4001-8001-000000000009');

INSERT INTO runway_equipment (runway_equipment_id, runway_id, equipment_id, relationship_type, is_required)
SELECT '1300000a-0001-4001-8001-00000000000a', '11000006-0001-4001-8001-000000000006', '1200002d-0001-4001-8001-00000000002d', 'SUPPORTS', 'Y'
FROM dual WHERE NOT EXISTS (SELECT 1 FROM runway_equipment WHERE runway_equipment_id = '1300000a-0001-4001-8001-00000000000a');

INSERT INTO runway_equipment (runway_equipment_id, runway_id, equipment_id, relationship_type, is_required)
SELECT '1300000b-0001-4001-8001-00000000000b', '11000007-0001-4001-8001-000000000007', '12000032-0001-4001-8001-000000000032', 'SUPPORTS', 'N'
FROM dual WHERE NOT EXISTS (SELECT 1 FROM runway_equipment WHERE runway_equipment_id = '1300000b-0001-4001-8001-00000000000b');

INSERT INTO runway_equipment (runway_equipment_id, runway_id, equipment_id, relationship_type, is_required)
SELECT '1300000c-0001-4001-8001-00000000000c', '11000008-0001-4001-8001-000000000008', '12000035-0001-4001-8001-000000000035', 'SUPPORTS', 'Y'
FROM dual WHERE NOT EXISTS (SELECT 1 FROM runway_equipment WHERE runway_equipment_id = '1300000c-0001-4001-8001-00000000000c');

INSERT INTO runway_equipment (runway_equipment_id, runway_id, equipment_id, relationship_type, is_required)
SELECT '1300000d-0001-4001-8001-00000000000d', '11000009-0001-4001-8001-000000000009', '1200003c-0001-4001-8001-00000000003c', 'SUPPORTS', 'N'
FROM dual WHERE NOT EXISTS (SELECT 1 FROM runway_equipment WHERE runway_equipment_id = '1300000d-0001-4001-8001-00000000000d');

INSERT INTO runway_equipment (runway_equipment_id, runway_id, equipment_id, relationship_type, is_required)
SELECT '1300000e-0001-4001-8001-00000000000e', '11000001-0001-4001-8001-000000000001', '12000017-0001-4001-8001-000000000017', 'MONITORS', 'Y'
FROM dual WHERE NOT EXISTS (SELECT 1 FROM runway_equipment WHERE runway_equipment_id = '1300000e-0001-4001-8001-00000000000e');

INSERT INTO runway_equipment (runway_equipment_id, runway_id, equipment_id, relationship_type, is_required)
SELECT '1300000f-0001-4001-8001-00000000000f', '11000003-0001-4001-8001-000000000003', '1200001f-0001-4001-8001-00000000001f', 'MONITORS', 'Y'
FROM dual WHERE NOT EXISTS (SELECT 1 FROM runway_equipment WHERE runway_equipment_id = '1300000f-0001-4001-8001-00000000000f');

-- ---------------------------------------------------------------------------
-- Equipment dependency graph — radar feeds, comms backup, navaid pairing
-- ---------------------------------------------------------------------------

INSERT INTO equipment_dependency (equipment_dependency_id, parent_equipment_id, child_equipment_id, dependency_type)
SELECT '14000006-0001-4001-8001-000000000006', '12000005-0001-4001-8001-000000000005', '12000019-0001-4001-8001-000000000019', 'FEEDS'
FROM dual WHERE NOT EXISTS (SELECT 1 FROM equipment_dependency WHERE equipment_dependency_id = '14000006-0001-4001-8001-000000000006');

INSERT INTO equipment_dependency (equipment_dependency_id, parent_equipment_id, child_equipment_id, dependency_type)
SELECT '14000007-0001-4001-8001-000000000007', '1200000e-0001-4001-8001-00000000000e', '12000014-0001-4001-8001-000000000014', 'BACKUP_FOR'
FROM dual WHERE NOT EXISTS (SELECT 1 FROM equipment_dependency WHERE equipment_dependency_id = '14000007-0001-4001-8001-000000000007');

INSERT INTO equipment_dependency (equipment_dependency_id, parent_equipment_id, child_equipment_id, dependency_type)
SELECT '14000008-0001-4001-8001-000000000008', '1200001d-0001-4001-8001-00000000001d', '1200001b-0001-4001-8001-00000000001b', 'BACKUP_FOR'
FROM dual WHERE NOT EXISTS (SELECT 1 FROM equipment_dependency WHERE equipment_dependency_id = '14000008-0001-4001-8001-000000000008');

INSERT INTO equipment_dependency (equipment_dependency_id, parent_equipment_id, child_equipment_id, dependency_type)
SELECT '14000009-0001-4001-8001-000000000009', '1200001e-0001-4001-8001-00000000001e', '1200001b-0001-4001-8001-00000000001b', 'FEEDS'
FROM dual WHERE NOT EXISTS (SELECT 1 FROM equipment_dependency WHERE equipment_dependency_id = '14000009-0001-4001-8001-000000000009');

INSERT INTO equipment_dependency (equipment_dependency_id, parent_equipment_id, child_equipment_id, dependency_type)
SELECT '1400000a-0001-4001-8001-00000000000a', '1200003f-0001-4001-8001-00000000003f', '12000040-0001-4001-8001-000000000040', 'BACKUP_FOR'
FROM dual WHERE NOT EXISTS (SELECT 1 FROM equipment_dependency WHERE equipment_dependency_id = '1400000a-0001-4001-8001-00000000000a');

INSERT INTO equipment_dependency (equipment_dependency_id, parent_equipment_id, child_equipment_id, dependency_type)
SELECT '1400000b-0001-4001-8001-00000000000b', '12000043-0001-4001-8001-000000000043', '12000009-0001-4001-8001-000000000009', 'BACKUP_FOR'
FROM dual WHERE NOT EXISTS (SELECT 1 FROM equipment_dependency WHERE equipment_dependency_id = '1400000b-0001-4001-8001-00000000000b');

INSERT INTO equipment_dependency (equipment_dependency_id, parent_equipment_id, child_equipment_id, dependency_type)
SELECT '1400000c-0001-4001-8001-00000000000c', '12000006-0001-4001-8001-000000000006', '12000047-0001-4001-8001-000000000047', 'REQUIRES'
FROM dual WHERE NOT EXISTS (SELECT 1 FROM equipment_dependency WHERE equipment_dependency_id = '1400000c-0001-4001-8001-00000000000c');

INSERT INTO equipment_dependency (equipment_dependency_id, parent_equipment_id, child_equipment_id, dependency_type)
SELECT '1400000d-0001-4001-8001-00000000000d', '1200000c-0001-4001-8001-00000000000c', '1200002c-0001-4001-8001-00000000002c', 'FEEDS'
FROM dual WHERE NOT EXISTS (SELECT 1 FROM equipment_dependency WHERE equipment_dependency_id = '1400000d-0001-4001-8001-00000000000d');

INSERT INTO equipment_dependency (equipment_dependency_id, parent_equipment_id, child_equipment_id, dependency_type)
SELECT '1400000e-0001-4001-8001-00000000000e', '12000027-0001-4001-8001-000000000027', '12000026-0001-4001-8001-000000000026', 'FEEDS'
FROM dual WHERE NOT EXISTS (SELECT 1 FROM equipment_dependency WHERE equipment_dependency_id = '1400000e-0001-4001-8001-00000000000e');

INSERT INTO equipment_dependency (equipment_dependency_id, parent_equipment_id, child_equipment_id, dependency_type)
SELECT '1400000f-0001-4001-8001-00000000000f', '1200001f-0001-4001-8001-00000000001f', '12000008-0001-4001-8001-000000000008', 'MONITORS'
FROM dual WHERE NOT EXISTS (SELECT 1 FROM equipment_dependency WHERE equipment_dependency_id = '1400000f-0001-4001-8001-00000000000f');

-- ---------------------------------------------------------------------------
-- Depot parts catalog expansion
-- ---------------------------------------------------------------------------

INSERT INTO equipment_part (
    equipment_part_id, part_number, name, description, equipment_type_code,
    unit_of_measure, stock_quantity, reorder_threshold, storage_facility_id, metadata_json
)
SELECT '1a000006-0001-4001-8001-000000000006', 'LLWAS-SENS-03', 'LLWAS III Sensor Pod Assembly',
    'Replacement anemometer and shear sensor pod for Mesotech LLWAS-III',
    'LLWAS', 'EA', 6, 2, '10000006-0001-4001-8001-000000000006',
    q'[{"hazmat":false,"weightLbs":18,"criticality":"HIGH"}]'
FROM dual WHERE NOT EXISTS (SELECT 1 FROM equipment_part WHERE equipment_part_id = '1a000006-0001-4001-8001-000000000006');

INSERT INTO equipment_part (
    equipment_part_id, part_number, name, description, equipment_type_code,
    unit_of_measure, stock_quantity, reorder_threshold, storage_facility_id, metadata_json
)
SELECT '1a000007-0001-4001-8001-000000000007', 'ADS-B-TX-1090', 'ADS-B 1090ES Transceiver Module',
    'ERA Squid-1090 ground station transceiver card',
    'ADS_B', 'EA', 3, 1, '10000006-0001-4001-8001-000000000006',
    q'[{"hazmat":false,"weightLbs":4.5,"leadTimeDays":21}]'
FROM dual WHERE NOT EXISTS (SELECT 1 FROM equipment_part WHERE equipment_part_id = '1a000007-0001-4001-8001-000000000007');

INSERT INTO equipment_part (
    equipment_part_id, part_number, name, description, equipment_type_code,
    unit_of_measure, stock_quantity, reorder_threshold, storage_facility_id, metadata_json
)
SELECT '1a000008-0001-4001-8001-000000000008', 'AWOS-CEIL-01', 'AWOS Ceilometer Assembly',
    'Vaisala AWOS-3PT ceilometer sensor head',
    'AWOS', 'EA', 2, 1, '10000006-0001-4001-8001-000000000006',
    q'[{"hazmat":false,"weightLbs":32}]'
FROM dual WHERE NOT EXISTS (SELECT 1 FROM equipment_part WHERE equipment_part_id = '1a000008-0001-4001-8001-000000000008');

INSERT INTO equipment_part (
    equipment_part_id, part_number, name, description, equipment_type_code,
    unit_of_measure, stock_quantity, reorder_threshold, storage_facility_id, metadata_json
)
SELECT '1a000009-0001-4001-8001-000000000009', 'NDB-CPLR-200', 'NDB Antenna Coupler Unit',
    'Selex NDB-200 antenna coupling network',
    'NDB', 'EA', 2, 1, '10000006-0001-4001-8001-000000000006',
    q'[{"hazmat":false,"weightLbs":12}]'
FROM dual WHERE NOT EXISTS (SELECT 1 FROM equipment_part WHERE equipment_part_id = '1a000009-0001-4001-8001-000000000009');

INSERT INTO equipment_part (
    equipment_part_id, part_number, name, description, equipment_type_code,
    unit_of_measure, stock_quantity, reorder_threshold, storage_facility_id, metadata_json
)
SELECT '1a00000a-0001-4001-8001-00000000000a', 'TACAN-TX-1150', 'TACAN Transponder Module',
    'Selex TACAN-1150 airborne/ground transponder module',
    'TACAN', 'EA', 1, 1, '10000006-0001-4001-8001-000000000006',
    q'[{"hazmat":false,"weightLbs":28,"criticality":"MEDIUM"}]'
FROM dual WHERE NOT EXISTS (SELECT 1 FROM equipment_part WHERE equipment_part_id = '1a00000a-0001-4001-8001-00000000000a');

INSERT INTO equipment_part (
    equipment_part_id, part_number, name, description, equipment_type_code,
    unit_of_measure, stock_quantity, reorder_threshold, storage_facility_id, metadata_json
)
SELECT '1a00000b-0001-4001-8001-00000000000b', 'ARR-DP-ARSR4', 'ARSR-4 Digital Processor Card',
    'Raytheon ARSR-4 primary digital signal processor',
    'RADAR_ARR', 'EA', 2, 1, '10000006-0001-4001-8001-000000000006',
    q'[{"hazmat":false,"weightLbs":8,"criticality":"HIGH"}]'
FROM dual WHERE NOT EXISTS (SELECT 1 FROM equipment_part WHERE equipment_part_id = '1a00000b-0001-4001-8001-00000000000b');

-- ---------------------------------------------------------------------------
-- Depot calibration maintenance (day-1 morning window)
-- ---------------------------------------------------------------------------

INSERT INTO maintenance_activity (
    maintenance_activity_id, equipment_id, originating_facility_id,
    activity_type_code, maintenance_status, priority, title, description,
    scheduled_start_at, scheduled_end_at, actual_start_at, actual_end_at,
    assigned_user_id, estimated_duration_hrs, created_by
)
SELECT
    '16000009-0001-4001-8001-000000000009',
    '1200000f-0001-4001-8001-00000000000f',
    '10000006-0001-4001-8001-000000000006',
    'CALIBRATION', 'COMPLETED', 4,
    'Depot ILS Bench — Quarterly Calibration',
    'Verified ILS bench alignment references against FAA master standard. All channels within 0.005 deg.',
    TIMESTAMP '2026-06-23 05:30:00', TIMESTAMP '2026-06-23 06:30:00',
    TIMESTAMP '2026-06-23 05:35:00', TIMESTAMP '2026-06-23 06:20:00',
    '20000002-0001-4001-8001-000000000002', 1,
    '20000002-0001-4001-8001-000000000002'
FROM dual WHERE NOT EXISTS (SELECT 1 FROM maintenance_activity WHERE maintenance_activity_id = '16000009-0001-4001-8001-000000000009');

INSERT INTO facility_maintenance_activity (
    facility_maintenance_activity_id, facility_id, maintenance_activity_id, role_type
)
SELECT '17000006-0001-4001-8001-000000000006', '10000006-0001-4001-8001-000000000006',
    '16000009-0001-4001-8001-000000000009', 'SITE'
FROM dual WHERE NOT EXISTS (SELECT 1 FROM facility_maintenance_activity WHERE facility_maintenance_activity_id = '17000006-0001-4001-8001-000000000006');

-- ---------------------------------------------------------------------------
-- Day-1 equipment alerts (ties to 101/102/104 scenarios)
-- ---------------------------------------------------------------------------

INSERT INTO equipment_alert (
    equipment_alert_id, equipment_id, alert_type, severity, title, message,
    raised_at, acknowledged_at, acknowledged_by_user_id
)
SELECT '1d000006-0001-4001-8001-000000000006', '1200001f-0001-4001-8001-00000000001f', 'WIND_SHEAR', 'HIGH',
    'ORD LLWAS — Wind Shear Alert Runway 10L',
    'LLWAS detected 35 kt shear on final 10L. ATC issuing missed approach advisories. FDX882 go-around at 12:18Z.',
    TIMESTAMP '2026-06-23 12:15:00',
    TIMESTAMP '2026-06-23 12:16:00',
    '20000001-0001-4001-8001-000000000001'
FROM dual WHERE NOT EXISTS (SELECT 1 FROM equipment_alert WHERE equipment_alert_id = '1d000006-0001-4001-8001-000000000006');

INSERT INTO equipment_alert (
    equipment_alert_id, equipment_id, alert_type, severity, title, message,
    raised_at, acknowledged_at, acknowledged_by_user_id
)
SELECT '1d000007-0001-4001-8001-000000000007', '1200003e-0001-4001-8001-00000000003e', 'DEGRADED', 'LOW',
    'MKE ADS-B — Antenna Feed Loss Elevated',
    'Ground station reporting 2.1 dB feed loss. Surveillance coverage reduced at low altitude. Inspection scheduled.',
    TIMESTAMP '2026-06-23 09:00:00',
    TIMESTAMP '2026-06-23 09:15:00',
    '20000002-0001-4001-8001-000000000002'
FROM dual WHERE NOT EXISTS (SELECT 1 FROM equipment_alert WHERE equipment_alert_id = '1d000007-0001-4001-8001-000000000007');

INSERT INTO equipment_alert (
    equipment_alert_id, equipment_id, alert_type, severity, title, message,
    raised_at, resolved_at, resolved_by_user_id
)
SELECT '1d000008-0001-4001-8001-000000000008', '12000043-0001-4001-8001-000000000043', 'INFO', 'LOW',
    'ZAU UHF Backup Net — Standby Verified',
    'Monthly UHF backup net test completed. All sector handoffs nominal.',
    TIMESTAMP '2026-06-23 06:00:00',
    TIMESTAMP '2026-06-23 06:12:00',
    '20000002-0001-4001-8001-000000000002'
FROM dual WHERE NOT EXISTS (SELECT 1 FROM equipment_alert WHERE equipment_alert_id = '1d000008-0001-4001-8001-000000000008');

-- ---------------------------------------------------------------------------
-- Global config — equipment stack version marker
-- ---------------------------------------------------------------------------

MERGE INTO global_configuration target
USING (
    SELECT 'simulation.equipment_stack_version' AS config_key,
           '106-full-stack' AS config_value,
           'STRING' AS value_type,
           'Seeded NAS equipment stack revision (106)' AS description
    FROM dual
) source ON (target.config_key = source.config_key)
WHEN MATCHED THEN UPDATE SET target.config_value = source.config_value
WHEN NOT MATCHED THEN INSERT (config_key, config_value, value_type, description)
    VALUES (source.config_key, source.config_value, source.value_type, source.description);

COMMIT;
