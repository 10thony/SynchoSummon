-- =============================================================================
-- Part warehouse scenario: NAS-PARTS-DSM, manufacturers, cargo aircraft,
-- inventory, shipments, and facility logistics activities.
-- =============================================================================

ALTER SESSION SET CONTAINER = FREEPDB1;
ALTER SESSION SET CURRENT_SCHEMA = nas_sim;
SET DEFINE OFF;

-- Cargo aircraft types (idempotent if 99_seed_reference already applied)
MERGE INTO aircraft_type_lkp t
USING (SELECT 'C208F' AS aircraft_type_code, 'Cessna 208 Caravan Freighter' AS display_name,
              'C208' AS icao_designator, 'LIGHT' AS wake_category, 175 AS typical_cruise_kts, 0 AS max_seating FROM dual) s
ON (t.aircraft_type_code = s.aircraft_type_code)
WHEN NOT MATCHED THEN INSERT (aircraft_type_code, display_name, icao_designator, wake_category, typical_cruise_kts, max_seating)
    VALUES (s.aircraft_type_code, s.display_name, s.icao_designator, s.wake_category, s.typical_cruise_kts, s.max_seating);

MERGE INTO aircraft_type_lkp t
USING (SELECT 'B763F' AS aircraft_type_code, 'Boeing 767-300F' AS display_name,
              'B763' AS icao_designator, 'HEAVY' AS wake_category, 460 AS typical_cruise_kts, 0 AS max_seating FROM dual) s
ON (t.aircraft_type_code = s.aircraft_type_code)
WHEN NOT MATCHED THEN INSERT (aircraft_type_code, display_name, icao_designator, wake_category, typical_cruise_kts, max_seating)
    VALUES (s.aircraft_type_code, s.display_name, s.icao_designator, s.wake_category, s.typical_cruise_kts, s.max_seating);

-- ---------------------------------------------------------------------------
-- Warehouse staff users
-- ---------------------------------------------------------------------------

MERGE INTO users t
USING (SELECT '20000007-0001-4001-8001-000000000007' AS user_id, 'warehouse.manager.dsm' AS username,
              'DSM Parts Warehouse Manager' AS display_name, 'warehouse.manager.dsm@nas-sim.local' AS email FROM dual) s
ON (t.user_id = s.user_id)
WHEN NOT MATCHED THEN INSERT (user_id, username, display_name, email, is_active, auth_source, entra_tenant_id, entra_object_id, entra_upn, entra_display_name)
    VALUES (s.user_id, s.username, s.display_name, s.email, 'Y', 'LOCAL_DEV',
            '11111111-1111-1111-1111-111111111111', '77777777-7777-7777-7777-777777777777',
            s.email, s.display_name);

MERGE INTO users t
USING (SELECT '20000008-0001-4001-8001-000000000008' AS user_id, 'logistics.coord.dsm' AS username,
              'DSM Logistics Coordinator' AS display_name, 'logistics.coord.dsm@nas-sim.local' AS email FROM dual) s
ON (t.user_id = s.user_id)
WHEN NOT MATCHED THEN INSERT (user_id, username, display_name, email, is_active, auth_source, entra_tenant_id, entra_object_id, entra_upn, entra_display_name)
    VALUES (s.user_id, s.username, s.display_name, s.email, 'Y', 'LOCAL_DEV',
            '11111111-1111-1111-1111-111111111111', '88888888-8888-8888-8888-888888888888',
            s.email, s.display_name);

MERGE INTO users t
USING (SELECT '20000009-0001-4001-8001-000000000009' AS user_id, 'parts.clerk.dsm' AS username,
              'DSM Parts Clerk' AS display_name, 'parts.clerk.dsm@nas-sim.local' AS email FROM dual) s
ON (t.user_id = s.user_id)
WHEN NOT MATCHED THEN INSERT (user_id, username, display_name, email, is_active, auth_source, entra_tenant_id, entra_object_id, entra_upn, entra_display_name)
    VALUES (s.user_id, s.username, s.display_name, s.email, 'Y', 'LOCAL_DEV',
            '11111111-1111-1111-1111-111111111111', '99999999-9999-9999-9999-999999999999',
            s.email, s.display_name);

-- ---------------------------------------------------------------------------
-- Part manufacturers (off-NAS OEM registry)
-- ---------------------------------------------------------------------------

MERGE INTO part_manufacturer_lkp t
USING (SELECT 'm1000001-0001-4001-8001-000000000001' AS manufacturer_id, 'THALES' AS manufacturer_code,
              'Thales Avionics OEM' AS display_name, 'parts@thalesavionics.example' AS contact_email,
              q'[{"line1":"2101 E El Segundo Blvd","city":"El Segundo","state":"CA","zip":"90245"}]' AS address_json FROM dual) s
ON (t.manufacturer_id = s.manufacturer_id)
WHEN NOT MATCHED THEN INSERT (manufacturer_id, manufacturer_code, display_name, contact_email, address_json)
    VALUES (s.manufacturer_id, s.manufacturer_code, s.display_name, s.contact_email, s.address_json);

MERGE INTO part_manufacturer_lkp t
USING (SELECT 'm1000002-0001-4001-8001-000000000002' AS manufacturer_id, 'RAYTHEON' AS manufacturer_code,
              'Raytheon Technologies' AS display_name, 'radar.parts@rtx.example' AS contact_email,
              q'[{"line1":"870 Winter St","city":"Waltham","state":"MA","zip":"02451"}]' AS address_json FROM dual) s
ON (t.manufacturer_id = s.manufacturer_id)
WHEN NOT MATCHED THEN INSERT (manufacturer_id, manufacturer_code, display_name, contact_email, address_json)
    VALUES (s.manufacturer_id, s.manufacturer_code, s.display_name, s.contact_email, s.address_json);

MERGE INTO part_manufacturer_lkp t
USING (SELECT 'm1000003-0001-4001-8001-000000000003' AS manufacturer_id, 'HONEYWELL' AS manufacturer_code,
              'Honeywell Aerospace' AS display_name, 'supply@honeywell-aero.example' AS contact_email,
              q'[{"line1":"1944 E Sky Harbor Cir S","city":"Phoenix","state":"AZ","zip":"85034"}]' AS address_json FROM dual) s
ON (t.manufacturer_id = s.manufacturer_id)
WHEN NOT MATCHED THEN INSERT (manufacturer_id, manufacturer_code, display_name, contact_email, address_json)
    VALUES (s.manufacturer_id, s.manufacturer_code, s.display_name, s.contact_email, s.address_json);

-- ---------------------------------------------------------------------------
-- Part warehouse facility
-- ---------------------------------------------------------------------------

MERGE INTO facility t
USING (SELECT '10000019-0001-4001-8001-000000000019' AS facility_id, 'NAS-PARTS-DSM' AS facility_code,
              'NAS Midwest Parts Distribution Center' AS name, 'PART_WAREHOUSE' AS facility_type_code,
              NULL AS parent_facility_id,
              '4200 NW 128th St' AS address_line1, 'Urbandale' AS city, 'IA' AS state_code, '50323' AS zip_code,
              41.6150000 AS latitude, -93.7550000 AS longitude, 940 AS elevation_ft,
              'America/Chicago' AS timezone_name, 'OPERATIONAL' AS operational_status,
              q'[{"warehouseCode":"NAS-PW-DSM","hubFor":["KDSM","DSM-ASR","KCID"]}]' AS metadata_json FROM dual) s
ON (t.facility_id = s.facility_id)
WHEN NOT MATCHED THEN INSERT (
    facility_id, facility_code, name, facility_type_code, parent_facility_id,
    address_line1, city, state_code, zip_code, latitude, longitude, elevation_ft,
    timezone_name, operational_status, metadata_json, created_by, updated_by)
VALUES (s.facility_id, s.facility_code, s.name, s.facility_type_code, s.parent_facility_id,
        s.address_line1, s.city, s.state_code, s.zip_code, s.latitude, s.longitude, s.elevation_ft,
        s.timezone_name, s.operational_status, s.metadata_json,
        '20000001-0001-4001-8001-000000000001', '20000001-0001-4001-8001-000000000001');

MERGE INTO simulation_geo_location_lookup t
USING (SELECT '2a000019-0001-4001-8001-000000000019' AS simulation_geo_location_id,
              '00000000-0000-0000-0000-000000000010' AS render_context_id,
              '10000019-0001-4001-8001-000000000019' AS facility_id,
              'Urbandale' AS real_city, 'IA' AS real_state_code, '50323' AS real_zip_code,
              -0.2000000 AS virtual_latitude, -0.2000000 AS virtual_longitude, 0 AS virtual_elevation_ft,
              q'[{"unityPosition":{"x":-200,"y":0,"z":-20},"scale":1.0,"rotationYDegrees":0,"mapLayer":"alpha-midwest"}]' AS transform_json,
              'Regional parts warehouse — west of depot on grid row -1 col -2' AS notes FROM dual) s
ON (t.simulation_geo_location_id = s.simulation_geo_location_id)
WHEN NOT MATCHED THEN INSERT (
    simulation_geo_location_id, render_context_id, facility_id,
    real_city, real_state_code, real_zip_code,
    virtual_latitude, virtual_longitude, virtual_elevation_ft, transform_json, notes)
VALUES (s.simulation_geo_location_id, s.render_context_id, s.facility_id,
        s.real_city, s.real_state_code, s.real_zip_code,
        s.virtual_latitude, s.virtual_longitude, s.virtual_elevation_ft, s.transform_json, s.notes);

-- Warehouse staffing
MERGE INTO facility_staff_assignment t
USING (SELECT '33000019-0001-4001-8001-000000000019' AS assignment_id,
              '10000019-0001-4001-8001-000000000019' AS facility_id,
              '20000007-0001-4001-8001-000000000007' AS user_id,
              'WAREHOUSE_MANAGER' AS role_code, 'Y' AS is_lead FROM dual) s
ON (t.assignment_id = s.assignment_id)
WHEN NOT MATCHED THEN INSERT (assignment_id, facility_id, user_id, role_code, is_lead)
    VALUES (s.assignment_id, s.facility_id, s.user_id, s.role_code, s.is_lead);

MERGE INTO facility_staff_assignment t
USING (SELECT '3300001a-0001-4001-8001-00000000001a' AS assignment_id,
              '10000019-0001-4001-8001-000000000019' AS facility_id,
              '20000008-0001-4001-8001-000000000008' AS user_id,
              'LOGISTICS_COORDINATOR' AS role_code, 'N' AS is_lead FROM dual) s
ON (t.assignment_id = s.assignment_id)
WHEN NOT MATCHED THEN INSERT (assignment_id, facility_id, user_id, role_code, is_lead)
    VALUES (s.assignment_id, s.facility_id, s.user_id, s.role_code, s.is_lead);

MERGE INTO facility_staff_assignment t
USING (SELECT '3300001b-0001-4001-8001-00000000001b' AS assignment_id,
              '10000019-0001-4001-8001-000000000019' AS facility_id,
              '20000009-0001-4001-8001-000000000009' AS user_id,
              'PARTS_CLERK' AS role_code, 'N' AS is_lead FROM dual) s
ON (t.assignment_id = s.assignment_id)
WHEN NOT MATCHED THEN INSERT (assignment_id, facility_id, user_id, role_code, is_lead)
    VALUES (s.assignment_id, s.facility_id, s.user_id, s.role_code, s.is_lead);

MERGE INTO facility_staff_assignment t
USING (SELECT '3300001c-0001-4001-8001-00000000001c' AS assignment_id,
              '10000019-0001-4001-8001-000000000019' AS facility_id,
              '20000002-0001-4001-8001-000000000002' AS user_id,
              'PARTS_CLERK' AS role_code, 'N' AS is_lead FROM dual) s
ON (t.assignment_id = s.assignment_id)
WHEN NOT MATCHED THEN INSERT (assignment_id, facility_id, user_id, role_code, is_lead)
    VALUES (s.assignment_id, s.facility_id, s.user_id, s.role_code, s.is_lead);

-- ---------------------------------------------------------------------------
-- Cargo aircraft homed at warehouse
-- ---------------------------------------------------------------------------

MERGE INTO aircraft t
USING (SELECT '15000009-0001-4001-8001-000000000009' AS aircraft_id, 'NAS-208F' AS tail_number,
              'C208F' AS aircraft_type_code, '10000019-0001-4001-8001-000000000019' AS home_facility_id,
              'AVAILABLE' AS operational_status, 0 AS seating_capacity, 8750 AS max_takeoff_weight_lbs,
              q'[{"operator":"NAS Parts Air","role":"regional_parts_hop","cargoFlight":true}]' AS metadata_json FROM dual) s
ON (t.aircraft_id = s.aircraft_id)
WHEN NOT MATCHED THEN INSERT (aircraft_id, tail_number, aircraft_type_code, home_facility_id, operational_status, seating_capacity, max_takeoff_weight_lbs, metadata_json)
    VALUES (s.aircraft_id, s.tail_number, s.aircraft_type_code, s.home_facility_id, s.operational_status, s.seating_capacity, s.max_takeoff_weight_lbs, s.metadata_json);

MERGE INTO aircraft t
USING (SELECT '1500000a-0001-4001-8001-00000000000a' AS aircraft_id, 'NAS-763F' AS tail_number,
              'B763F' AS aircraft_type_code, '10000019-0001-4001-8001-000000000019' AS home_facility_id,
              'AVAILABLE' AS operational_status, 0 AS seating_capacity, 412000 AS max_takeoff_weight_lbs,
              q'[{"operator":"NAS Parts Air","role":"corridor_freighter","cargoFlight":true}]' AS metadata_json FROM dual) s
ON (t.aircraft_id = s.aircraft_id)
WHEN NOT MATCHED THEN INSERT (aircraft_id, tail_number, aircraft_type_code, home_facility_id, operational_status, seating_capacity, max_takeoff_weight_lbs, metadata_json)
    VALUES (s.aircraft_id, s.tail_number, s.aircraft_type_code, s.home_facility_id, s.operational_status, s.seating_capacity, s.max_takeoff_weight_lbs, s.metadata_json);

-- ---------------------------------------------------------------------------
-- Parts catalog expansion + warehouse stock
-- ---------------------------------------------------------------------------

UPDATE equipment_part SET storage_facility_id = '10000019-0001-4001-8001-000000000019', stock_quantity = 8, updated_at = SYSTIMESTAMP
WHERE equipment_part_id = '1a000001-0001-4001-8001-000000000001';

UPDATE equipment_part SET storage_facility_id = '10000019-0001-4001-8001-000000000019', stock_quantity = 6, updated_at = SYSTIMESTAMP
WHERE equipment_part_id = '1a000002-0001-4001-8001-000000000002';

MERGE INTO equipment_part t
USING (SELECT '1a000003-0001-4001-8001-000000000003' AS equipment_part_id, 'VOR-ANT-450' AS part_number,
              'VOR Antenna Assembly 450 MHz' AS name, 'Replacement VOR antenna for Thales VOR-420' AS description,
              'VOR' AS equipment_type_code, 'EA' AS unit_of_measure, 3 AS stock_quantity, 1 AS reorder_threshold,
              '10000019-0001-4001-8001-000000000019' AS storage_facility_id FROM dual) s
ON (t.equipment_part_id = s.equipment_part_id)
WHEN NOT MATCHED THEN INSERT (equipment_part_id, part_number, name, description, equipment_type_code, unit_of_measure, stock_quantity, reorder_threshold, storage_facility_id)
    VALUES (s.equipment_part_id, s.part_number, s.name, s.description, s.equipment_type_code, s.unit_of_measure, s.stock_quantity, s.reorder_threshold, s.storage_facility_id);

MERGE INTO equipment_part t
USING (SELECT '1a000004-0001-4001-8001-000000000004' AS equipment_part_id, 'COM-VHF-8800' AS part_number,
              'VHF Transceiver Module 8800 Series' AS name, 'Hot-swappable VHF comm module for RCO sites' AS description,
              'COM_VHF' AS equipment_type_code, 'EA' AS unit_of_measure, 5 AS stock_quantity, 2 AS reorder_threshold,
              '10000019-0001-4001-8001-000000000019' AS storage_facility_id FROM dual) s
ON (t.equipment_part_id = s.equipment_part_id)
WHEN NOT MATCHED THEN INSERT (equipment_part_id, part_number, name, description, equipment_type_code, unit_of_measure, stock_quantity, reorder_threshold, storage_facility_id)
    VALUES (s.equipment_part_id, s.part_number, s.name, s.description, s.equipment_type_code, s.unit_of_measure, s.stock_quantity, s.reorder_threshold, s.storage_facility_id);

MERGE INTO equipment_part t
USING (SELECT '1a000005-0001-4001-8001-000000000005' AS equipment_part_id, 'PAPI-LAMP-LED' AS part_number,
              'PAPI LED Lamp Assembly' AS name, 'Precision approach path indicator lamp module' AS description,
              'PAPI' AS equipment_type_code, 'EA' AS unit_of_measure, 12 AS stock_quantity, 4 AS reorder_threshold,
              '10000019-0001-4001-8001-000000000019' AS storage_facility_id FROM dual) s
ON (t.equipment_part_id = s.equipment_part_id)
WHEN NOT MATCHED THEN INSERT (equipment_part_id, part_number, name, description, equipment_type_code, unit_of_measure, stock_quantity, reorder_threshold, storage_facility_id)
    VALUES (s.equipment_part_id, s.part_number, s.name, s.description, s.equipment_type_code, s.unit_of_measure, s.stock_quantity, s.reorder_threshold, s.storage_facility_id);

-- Depot keeps one low-stock spare
MERGE INTO equipment_part t
USING (SELECT '1a000006-0001-4001-8001-000000000006' AS equipment_part_id, 'RAD-MAG-ASR9-SP' AS part_number,
              'ASR-9 Magnetron Spare (Depot Hold)' AS name, 'Depot-held emergency magnetron for field swap' AS description,
              'RADAR_ASR' AS equipment_type_code, 'EA' AS unit_of_measure, 1 AS stock_quantity, 1 AS reorder_threshold,
              '10000006-0001-4001-8001-000000000006' AS storage_facility_id FROM dual) s
ON (t.equipment_part_id = s.equipment_part_id)
WHEN NOT MATCHED THEN INSERT (equipment_part_id, part_number, name, description, equipment_type_code, unit_of_measure, stock_quantity, reorder_threshold, storage_facility_id)
    VALUES (s.equipment_part_id, s.part_number, s.name, s.description, s.equipment_type_code, s.unit_of_measure, s.stock_quantity, s.reorder_threshold, s.storage_facility_id);

-- Link existing quote to manufacturer
UPDATE equipment_part_quote SET manufacturer_id = 'm1000001-0001-4001-8001-000000000001'
WHERE equipment_part_quote_id = '1b000001-0001-4001-8001-000000000001';

MERGE INTO equipment_part_quote t
USING (SELECT '1b000002-0001-4001-8001-000000000002' AS equipment_part_quote_id,
              '1a000003-0001-4001-8001-000000000003' AS equipment_part_id,
              'Thales Avionics OEM' AS vendor_name, 'm1000001-0001-4001-8001-000000000001' AS manufacturer_id,
              12400.00 AS quoted_unit_cost, 'USD' AS currency_code, 10 AS lead_time_days, 'ACCEPTED' AS quote_status,
              TIMESTAMP '2026-05-01 09:00:00' AS quoted_at, TIMESTAMP '2026-11-01 09:00:00' AS valid_until FROM dual) s
ON (t.equipment_part_quote_id = s.equipment_part_quote_id)
WHEN NOT MATCHED THEN INSERT (equipment_part_quote_id, equipment_part_id, vendor_name, manufacturer_id, quoted_unit_cost, currency_code, lead_time_days, quote_status, quoted_at, valid_until)
    VALUES (s.equipment_part_quote_id, s.equipment_part_id, s.vendor_name, s.manufacturer_id, s.quoted_unit_cost, s.currency_code, s.lead_time_days, s.quote_status, s.quoted_at, s.valid_until);

-- ---------------------------------------------------------------------------
-- Part orders
-- ---------------------------------------------------------------------------

MERGE INTO equipment_part_order t
USING (SELECT '1c000002-0001-4001-8001-000000000002' AS equipment_part_order_id,
              '1a000003-0001-4001-8001-000000000003' AS equipment_part_id,
              '1b000002-0001-4001-8001-000000000002' AS equipment_part_quote_id,
              '10000019-0001-4001-8001-000000000019' AS receiving_facility_id,
              'm1000001-0001-4001-8001-000000000001' AS origin_manufacturer_id,
              2 AS quantity_ordered, 12400.00 AS unit_cost, 'ORDERED' AS order_status,
              TIMESTAMP '2026-06-22 08:00:00' AS ordered_at, TIMESTAMP '2026-06-23 16:00:00' AS expected_delivery_at,
              'Inbound OEM restock — VOR antenna assemblies' AS notes FROM dual) s
ON (t.equipment_part_order_id = s.equipment_part_order_id)
WHEN NOT MATCHED THEN INSERT (equipment_part_order_id, equipment_part_id, equipment_part_quote_id, receiving_facility_id, origin_manufacturer_id, quantity_ordered, unit_cost, order_status, ordered_at, expected_delivery_at, notes)
    VALUES (s.equipment_part_order_id, s.equipment_part_id, s.equipment_part_quote_id, s.receiving_facility_id, s.origin_manufacturer_id, s.quantity_ordered, s.unit_cost, s.order_status, s.ordered_at, s.expected_delivery_at, s.notes);

MERGE INTO equipment_part_order t
USING (SELECT '1c000003-0001-4001-8001-000000000003' AS equipment_part_order_id,
              '1a000001-0001-4001-8001-000000000001' AS equipment_part_id,
              '1b000001-0001-4001-8001-000000000001' AS equipment_part_quote_id,
              '10000001-0001-4001-8001-000000000001' AS receiving_facility_id,
              NULL AS origin_manufacturer_id,
              1 AS quantity_ordered, 42850.00 AS unit_cost, 'SHIPPED' AS order_status,
              TIMESTAMP '2026-06-23 13:00:00' AS ordered_at, TIMESTAMP '2026-06-23 15:00:00' AS expected_delivery_at,
              'Warehouse dispatch — ILS GS module to KDSM for RWY 13 outage' AS notes FROM dual) s
ON (t.equipment_part_order_id = s.equipment_part_order_id)
WHEN NOT MATCHED THEN INSERT (equipment_part_order_id, equipment_part_id, equipment_part_quote_id, receiving_facility_id, origin_manufacturer_id, quantity_ordered, unit_cost, order_status, ordered_at, expected_delivery_at, notes)
    VALUES (s.equipment_part_order_id, s.equipment_part_id, s.equipment_part_quote_id, s.receiving_facility_id, s.origin_manufacturer_id, s.quantity_ordered, s.unit_cost, s.order_status, s.ordered_at, s.expected_delivery_at, s.notes);

-- ---------------------------------------------------------------------------
-- Parts cargo flight (warehouse -> KORD corridor positioning)
-- ---------------------------------------------------------------------------

MERGE INTO flight_operation t
USING (SELECT '22000020-0001-4001-8001-000000000020' AS flight_operation_id,
              NULL AS flight_request_id, 'NAS763' AS flight_number,
              '10000019-0001-4001-8001-000000000019' AS origin_facility_id,
              '10000002-0001-4001-8001-000000000002' AS destination_facility_id,
              NULL AS departure_runway_id, NULL AS arrival_runway_id,
              'SCHEDULED' AS current_phase, 'ACTIVE' AS operation_status,
              TIMESTAMP '2026-06-23 18:00:00' AS scheduled_departure_at,
              TIMESTAMP '2026-06-23 19:30:00' AS scheduled_arrival_at,
              '1500000a-0001-4001-8001-00000000000a' AS aircraft_id,
              q'[{"cargoFlight":true,"partsShipment":true,"freightPallets":6}]' AS metadata_json FROM dual) s
ON (t.flight_operation_id = s.flight_operation_id)
WHEN NOT MATCHED THEN INSERT (flight_operation_id, flight_request_id, flight_number, origin_facility_id, destination_facility_id, departure_runway_id, arrival_runway_id, current_phase, operation_status, scheduled_departure_at, scheduled_arrival_at, aircraft_id, metadata_json)
    VALUES (s.flight_operation_id, s.flight_request_id, s.flight_number, s.origin_facility_id, s.destination_facility_id, s.departure_runway_id, s.arrival_runway_id, s.current_phase, s.operation_status, s.scheduled_departure_at, s.scheduled_arrival_at, s.aircraft_id, s.metadata_json);

-- ---------------------------------------------------------------------------
-- Shipments (mixed modes)
-- ---------------------------------------------------------------------------

MERGE INTO equipment_part_shipment t
USING (SELECT '1e000001-0001-4001-8001-000000000001' AS equipment_part_shipment_id,
              '1c000002-0001-4001-8001-000000000002' AS equipment_part_order_id,
              '1a000003-0001-4001-8001-000000000003' AS equipment_part_id,
              NULL AS origin_facility_id, 'm1000001-0001-4001-8001-000000000001' AS origin_manufacturer_id,
              '10000019-0001-4001-8001-000000000019' AS destination_facility_id,
              'GROUND' AS carrier_mode_code, NULL AS carrier_flight_operation_id,
              2 AS quantity, 'IN_TRANSIT' AS shipment_status,
              TIMESTAMP '2026-06-23 10:00:00' AS scheduled_depart_at, TIMESTAMP '2026-06-23 16:00:00' AS scheduled_arrival_at,
              TIMESTAMP '2026-06-23 10:15:00' AS actual_depart_at, NULL AS actual_arrival_at,
              'NAS-TRK-07' AS tracking_number,
              q'[{"truckId":"NAS-TRK-07","driver":"Field Logistics"}]' AS metadata_json FROM dual) s
ON (t.equipment_part_shipment_id = s.equipment_part_shipment_id)
WHEN NOT MATCHED THEN INSERT (equipment_part_shipment_id, equipment_part_order_id, equipment_part_id, origin_facility_id, origin_manufacturer_id, destination_facility_id, carrier_mode_code, carrier_flight_operation_id, quantity, shipment_status, scheduled_depart_at, scheduled_arrival_at, actual_depart_at, actual_arrival_at, tracking_number, metadata_json)
    VALUES (s.equipment_part_shipment_id, s.equipment_part_order_id, s.equipment_part_id, s.origin_facility_id, s.origin_manufacturer_id, s.destination_facility_id, s.carrier_mode_code, s.carrier_flight_operation_id, s.quantity, s.shipment_status, s.scheduled_depart_at, s.scheduled_arrival_at, s.actual_depart_at, s.actual_arrival_at, s.tracking_number, s.metadata_json);

MERGE INTO equipment_part_shipment t
USING (SELECT '1e000002-0001-4001-8001-000000000002' AS equipment_part_shipment_id,
              '1c000003-0001-4001-8001-000000000003' AS equipment_part_order_id,
              '1a000001-0001-4001-8001-000000000001' AS equipment_part_id,
              '10000019-0001-4001-8001-000000000019' AS origin_facility_id, NULL AS origin_manufacturer_id,
              '10000001-0001-4001-8001-000000000001' AS destination_facility_id,
              'AIR' AS carrier_mode_code, NULL AS carrier_flight_operation_id,
              1 AS quantity, 'PLANNED' AS shipment_status,
              TIMESTAMP '2026-06-23 14:30:00' AS scheduled_depart_at, TIMESTAMP '2026-06-23 15:00:00' AS scheduled_arrival_at,
              NULL AS actual_depart_at, NULL AS actual_arrival_at,
              'NAS-AIR-208F-01' AS tracking_number,
              q'[{"aircraftTail":"NAS-208F","priority":"EMERGENCY"}]' AS metadata_json FROM dual) s
ON (t.equipment_part_shipment_id = s.equipment_part_shipment_id)
WHEN NOT MATCHED THEN INSERT (equipment_part_shipment_id, equipment_part_order_id, equipment_part_id, origin_facility_id, origin_manufacturer_id, destination_facility_id, carrier_mode_code, carrier_flight_operation_id, quantity, shipment_status, scheduled_depart_at, scheduled_arrival_at, actual_depart_at, actual_arrival_at, tracking_number, metadata_json)
    VALUES (s.equipment_part_shipment_id, s.equipment_part_order_id, s.equipment_part_id, s.origin_facility_id, s.origin_manufacturer_id, s.destination_facility_id, s.carrier_mode_code, s.carrier_flight_operation_id, s.quantity, s.shipment_status, s.scheduled_depart_at, s.scheduled_arrival_at, s.actual_depart_at, s.actual_arrival_at, s.tracking_number, s.metadata_json);

MERGE INTO equipment_part_shipment t
USING (SELECT '1e000003-0001-4001-8001-000000000003' AS equipment_part_shipment_id,
              NULL AS equipment_part_order_id,
              '1a000002-0001-4001-8001-000000000002' AS equipment_part_id,
              '10000019-0001-4001-8001-000000000019' AS origin_facility_id, NULL AS origin_manufacturer_id,
              '10000002-0001-4001-8001-000000000002' AS destination_facility_id,
              'AIR' AS carrier_mode_code, '22000020-0001-4001-8001-000000000020' AS carrier_flight_operation_id,
              1 AS quantity, 'PLANNED' AS shipment_status,
              TIMESTAMP '2026-06-23 18:00:00' AS scheduled_depart_at, TIMESTAMP '2026-06-23 19:30:00' AS scheduled_arrival_at,
              NULL AS actual_depart_at, NULL AS actual_arrival_at,
              'NAS-AIR-763F-01' AS tracking_number,
              q'[{"aircraftTail":"NAS-763F","corridorPositioning":true}]' AS metadata_json FROM dual) s
ON (t.equipment_part_shipment_id = s.equipment_part_shipment_id)
WHEN NOT MATCHED THEN INSERT (equipment_part_shipment_id, equipment_part_order_id, equipment_part_id, origin_facility_id, origin_manufacturer_id, destination_facility_id, carrier_mode_code, carrier_flight_operation_id, quantity, shipment_status, scheduled_depart_at, scheduled_arrival_at, actual_depart_at, actual_arrival_at, tracking_number, metadata_json)
    VALUES (s.equipment_part_shipment_id, s.equipment_part_order_id, s.equipment_part_id, s.origin_facility_id, s.origin_manufacturer_id, s.destination_facility_id, s.carrier_mode_code, s.carrier_flight_operation_id, s.quantity, s.shipment_status, s.scheduled_depart_at, s.scheduled_arrival_at, s.actual_depart_at, s.actual_arrival_at, s.tracking_number, s.metadata_json);

MERGE INTO equipment_part_shipment t
USING (SELECT '1e000004-0001-4001-8001-000000000004' AS equipment_part_shipment_id,
              NULL AS equipment_part_order_id,
              '1a000002-0001-4001-8001-000000000002' AS equipment_part_id,
              '10000019-0001-4001-8001-000000000019' AS origin_facility_id, NULL AS origin_manufacturer_id,
              '10000007-0001-4001-8001-000000000007' AS destination_facility_id,
              'GROUND' AS carrier_mode_code, NULL AS carrier_flight_operation_id,
              1 AS quantity, 'DELIVERED' AS shipment_status,
              TIMESTAMP '2026-06-22 14:00:00' AS scheduled_depart_at, TIMESTAMP '2026-06-22 15:30:00' AS scheduled_arrival_at,
              TIMESTAMP '2026-06-22 14:10:00' AS actual_depart_at, TIMESTAMP '2026-06-22 15:20:00' AS actual_arrival_at,
              'NAS-TRK-03' AS tracking_number,
              q'[{"truckId":"NAS-TRK-03","maintenanceDispatch":true}]' AS metadata_json FROM dual) s
ON (t.equipment_part_shipment_id = s.equipment_part_shipment_id)
WHEN NOT MATCHED THEN INSERT (equipment_part_shipment_id, equipment_part_order_id, equipment_part_id, origin_facility_id, origin_manufacturer_id, destination_facility_id, carrier_mode_code, carrier_flight_operation_id, quantity, shipment_status, scheduled_depart_at, scheduled_arrival_at, actual_depart_at, actual_arrival_at, tracking_number, metadata_json)
    VALUES (s.equipment_part_shipment_id, s.equipment_part_order_id, s.equipment_part_id, s.origin_facility_id, s.origin_manufacturer_id, s.destination_facility_id, s.carrier_mode_code, s.carrier_flight_operation_id, s.quantity, s.shipment_status, s.scheduled_depart_at, s.scheduled_arrival_at, s.actual_depart_at, s.actual_arrival_at, s.tracking_number, s.metadata_json);

-- ---------------------------------------------------------------------------
-- Facility logistics activities at warehouse
-- ---------------------------------------------------------------------------

MERGE INTO facility_logistics_activity t
USING (SELECT '1f000001-0001-4001-8001-000000000001' AS facility_logistics_activity_id,
              '10000019-0001-4001-8001-000000000019' AS facility_id,
              '1e000001-0001-4001-8001-000000000001' AS equipment_part_shipment_id,
              'PART_RECEIVING' AS activity_type_code, 'IN_PROGRESS' AS activity_status,
              'Receive inbound OEM truck NAS-TRK-07' AS title,
              'Unload and inspect VOR antenna assemblies from Thales inbound truck' AS description,
              45 AS progress_pct, TIMESTAMP '2026-06-23 15:30:00' AS scheduled_start_at,
              TIMESTAMP '2026-06-23 16:10:00' AS scheduled_end_at,
              TIMESTAMP '2026-06-23 15:35:00' AS actual_start_at, NULL AS actual_end_at,
              20 AS estimated_duration_min FROM dual) s
ON (t.facility_logistics_activity_id = s.facility_logistics_activity_id)
WHEN NOT MATCHED THEN INSERT (facility_logistics_activity_id, facility_id, equipment_part_shipment_id, activity_type_code, activity_status, title, description, progress_pct, scheduled_start_at, scheduled_end_at, actual_start_at, actual_end_at, estimated_duration_min)
    VALUES (s.facility_logistics_activity_id, s.facility_id, s.equipment_part_shipment_id, s.activity_type_code, s.activity_status, s.title, s.description, s.progress_pct, s.scheduled_start_at, s.scheduled_end_at, s.actual_start_at, s.actual_end_at, s.estimated_duration_min);

MERGE INTO facility_logistics_activity t
USING (SELECT '1f000002-0001-4001-8001-000000000002' AS facility_logistics_activity_id,
              '10000019-0001-4001-8001-000000000019' AS facility_id,
              '1e000002-0001-4001-8001-000000000002' AS equipment_part_shipment_id,
              'PART_STAGING' AS activity_type_code, 'PLANNED' AS activity_status,
              'Stage ILS GS module for air dispatch to KDSM' AS title,
              'Pick and pack emergency ILS glide slope module for NAS-208F hop' AS description,
              0 AS progress_pct, TIMESTAMP '2026-06-23 14:00:00' AS scheduled_start_at,
              TIMESTAMP '2026-06-23 14:15:00' AS scheduled_end_at,
              NULL AS actual_start_at, NULL AS actual_end_at,
              15 AS estimated_duration_min FROM dual) s
ON (t.facility_logistics_activity_id = s.facility_logistics_activity_id)
WHEN NOT MATCHED THEN INSERT (facility_logistics_activity_id, facility_id, equipment_part_shipment_id, activity_type_code, activity_status, title, description, progress_pct, scheduled_start_at, scheduled_end_at, actual_start_at, actual_end_at, estimated_duration_min)
    VALUES (s.facility_logistics_activity_id, s.facility_id, s.equipment_part_shipment_id, s.activity_type_code, s.activity_status, s.title, s.description, s.progress_pct, s.scheduled_start_at, s.scheduled_end_at, s.actual_start_at, s.actual_end_at, s.estimated_duration_min);

COMMIT;
