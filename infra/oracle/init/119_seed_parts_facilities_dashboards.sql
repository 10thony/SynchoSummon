-- =============================================================================
-- Integrate parts logistics into Equipment & Facilities dashboards.
-- Fixes panel ID collisions from 118 vs 10_seed (Weather panels own p1000041–44).
-- Removes standalone PARTS drawing if it was applied by an earlier revision.
-- =============================================================================

ALTER SESSION SET CONTAINER = FREEPDB1;
ALTER SESSION SET CURRENT_SCHEMA = nas_sim;
SET DEFINE OFF;

-- Roll back standalone PARTS drawing (not used — parts live under EQUIPMENT)
DELETE FROM dashboard_key_mapping WHERE dashboard_id = 'd1000012-0001-4001-8001-000000000012';
DELETE FROM dashboard_panel WHERE dashboard_id = 'd1000012-0001-4001-8001-000000000012';
DELETE FROM dashboard_definition WHERE dashboard_id = 'd1000012-0001-4001-8001-000000000012';

-- ---- Equipment & Parts: Parts first in sheet index (SH-11 in master index) ----
MERGE INTO dashboard_panel t
USING (SELECT 'p1000011-0001-4001-8001-000000000011' AS panel_id,
              'd1000002-0001-4001-8001-000000000002' AS dashboard_id,
              'Equipment' AS title, 'equipment' AS entity_slug,
              0 AS grid_row, 1 AS grid_column, 10 AS sort_order FROM dual) s
ON (t.panel_id = s.panel_id)
WHEN MATCHED THEN UPDATE SET
    t.grid_row = s.grid_row, t.grid_column = s.grid_column, t.sort_order = s.sort_order;

MERGE INTO dashboard_panel t
USING (SELECT 'p1000012-0001-4001-8001-000000000012' AS panel_id,
              'd1000002-0001-4001-8001-000000000002' AS dashboard_id,
              'Parts' AS title, 'equipment-part' AS entity_slug,
              0 AS grid_row, 0 AS grid_column, 5 AS sort_order FROM dual) s
ON (t.panel_id = s.panel_id)
WHEN MATCHED THEN UPDATE SET
    t.grid_row = s.grid_row, t.grid_column = s.grid_column, t.sort_order = s.sort_order
WHEN NOT MATCHED THEN INSERT (panel_id, dashboard_id, title, entity_slug, grid_row, grid_column, sort_order)
    VALUES (s.panel_id, s.dashboard_id, s.title, s.entity_slug, s.grid_row, s.grid_column, s.sort_order);

MERGE INTO dashboard_panel t
USING (SELECT 'p1000013-0001-4001-8001-000000000013' AS panel_id,
              'd1000002-0001-4001-8001-000000000002' AS dashboard_id,
              'Part Orders' AS title, 'equipment-part-order' AS entity_slug,
              1 AS grid_row, 0 AS grid_column, 25 AS sort_order FROM dual) s
ON (t.panel_id = s.panel_id)
WHEN MATCHED THEN UPDATE SET
    t.grid_row = s.grid_row, t.grid_column = s.grid_column, t.sort_order = s.sort_order;

MERGE INTO dashboard_panel t
USING (SELECT 'p1000014-0001-4001-8001-000000000014' AS panel_id,
              'd1000002-0001-4001-8001-000000000002' AS dashboard_id,
              'Part Quotes' AS title, 'equipment-part-quote' AS entity_slug,
              1 AS grid_row, 1 AS grid_column, 26 AS sort_order FROM dual) s
ON (t.panel_id = s.panel_id)
WHEN MATCHED THEN UPDATE SET
    t.grid_row = s.grid_row, t.grid_column = s.grid_column, t.sort_order = s.sort_order;

MERGE INTO dashboard_panel t
USING (SELECT 'p1000103-0001-4001-8001-000000000103' AS panel_id,
              'd1000002-0001-4001-8001-000000000002' AS dashboard_id,
              'Part Shipments' AS title, 'equipment-part-shipment' AS entity_slug,
              1 AS grid_row, 2 AS grid_column, 27 AS sort_order FROM dual) s
ON (t.panel_id = s.panel_id)
WHEN MATCHED THEN UPDATE SET
    t.dashboard_id = s.dashboard_id, t.title = s.title, t.entity_slug = s.entity_slug,
    t.grid_row = s.grid_row, t.grid_column = s.grid_column, t.sort_order = s.sort_order
WHEN NOT MATCHED THEN INSERT (panel_id, dashboard_id, title, entity_slug, grid_row, grid_column, sort_order)
    VALUES (s.panel_id, s.dashboard_id, s.title, s.entity_slug, s.grid_row, s.grid_column, s.sort_order);

MERGE INTO dashboard_panel t
USING (SELECT 'p1000045-0001-4001-8001-000000000045' AS panel_id,
              'd1000002-0001-4001-8001-000000000002' AS dashboard_id,
              'Warehouse Activities' AS title, 'facility-logistics-activity' AS entity_slug,
              2 AS grid_row, 0 AS grid_column, 28 AS sort_order FROM dual) s
ON (t.panel_id = s.panel_id)
WHEN MATCHED THEN UPDATE SET
    t.dashboard_id = s.dashboard_id, t.title = s.title, t.entity_slug = s.entity_slug,
    t.grid_row = s.grid_row, t.grid_column = s.grid_column, t.sort_order = s.sort_order
WHEN NOT MATCHED THEN INSERT (panel_id, dashboard_id, title, entity_slug, grid_row, grid_column, sort_order)
    VALUES (s.panel_id, s.dashboard_id, s.title, s.entity_slug, s.grid_row, s.grid_column, s.sort_order);

-- Push non-parts equipment sheets below the logistics group
MERGE INTO dashboard_panel t
USING (SELECT 'p1000015-0001-4001-8001-000000000015' AS panel_id,
              3 AS grid_row, 0 AS grid_column, 50 AS sort_order FROM dual) s
ON (t.panel_id = s.panel_id)
WHEN MATCHED THEN UPDATE SET t.grid_row = s.grid_row, t.grid_column = s.grid_column, t.sort_order = s.sort_order;

MERGE INTO dashboard_panel t
USING (SELECT 'p1000016-0001-4001-8001-000000000016' AS panel_id,
              3 AS grid_row, 1 AS grid_column, 51 AS sort_order FROM dual) s
ON (t.panel_id = s.panel_id)
WHEN MATCHED THEN UPDATE SET t.grid_row = s.grid_row, t.grid_column = s.grid_column, t.sort_order = s.sort_order;

MERGE INTO dashboard_panel t
USING (SELECT 'p1000017-0001-4001-8001-000000000017' AS panel_id,
              3 AS grid_row, 2 AS grid_column, 52 AS sort_order FROM dual) s
ON (t.panel_id = s.panel_id)
WHEN MATCHED THEN UPDATE SET t.grid_row = s.grid_row, t.grid_column = s.grid_column, t.sort_order = s.sort_order;

MERGE INTO dashboard_panel t
USING (SELECT 'p1000018-0001-4001-8001-000000000018' AS panel_id,
              4 AS grid_row, 0 AS grid_column, 53 AS sort_order FROM dual) s
ON (t.panel_id = s.panel_id)
WHEN MATCHED THEN UPDATE SET t.grid_row = s.grid_row, t.grid_column = s.grid_column, t.sort_order = s.sort_order;

MERGE INTO dashboard_panel t
USING (SELECT 'p1000019-0001-4001-8001-000000000019' AS panel_id,
              4 AS grid_row, 1 AS grid_column, 54 AS sort_order FROM dual) s
ON (t.panel_id = s.panel_id)
WHEN MATCHED THEN UPDATE SET t.grid_row = s.grid_row, t.grid_column = s.grid_column, t.sort_order = s.sort_order;

MERGE INTO dashboard_panel t
USING (SELECT 'p1000020-0001-4001-8001-000000000020' AS panel_id,
              4 AS grid_row, 2 AS grid_column, 55 AS sort_order FROM dual) s
ON (t.panel_id = s.panel_id)
WHEN MATCHED THEN UPDATE SET t.grid_row = s.grid_row, t.grid_column = s.grid_column, t.sort_order = s.sort_order;

-- ---- Manufacturers dashboard: panels 118 failed to insert (ID collision) ----
MERGE INTO dashboard_panel t
USING (SELECT 'p1000100-0001-4001-8001-000000000100' AS panel_id,
              'd1000011-0001-4001-8001-000000000011' AS dashboard_id,
              'Part Quotes' AS title, 'equipment-part-quote' AS entity_slug,
              0 AS grid_row, 1 AS grid_column, 20 AS sort_order FROM dual) s
ON (t.panel_id = s.panel_id)
WHEN NOT MATCHED THEN INSERT (panel_id, dashboard_id, title, entity_slug, grid_row, grid_column, sort_order)
    VALUES (s.panel_id, s.dashboard_id, s.title, s.entity_slug, s.grid_row, s.grid_column, s.sort_order);

MERGE INTO dashboard_panel t
USING (SELECT 'p1000101-0001-4001-8001-000000000101' AS panel_id,
              'd1000011-0001-4001-8001-000000000011' AS dashboard_id,
              'Part Orders' AS title, 'equipment-part-order' AS entity_slug,
              1 AS grid_row, 0 AS grid_column, 30 AS sort_order FROM dual) s
ON (t.panel_id = s.panel_id)
WHEN NOT MATCHED THEN INSERT (panel_id, dashboard_id, title, entity_slug, grid_row, grid_column, sort_order)
    VALUES (s.panel_id, s.dashboard_id, s.title, s.entity_slug, s.grid_row, s.grid_column, s.sort_order);

MERGE INTO dashboard_panel t
USING (SELECT 'p1000102-0001-4001-8001-000000000102' AS panel_id,
              'd1000011-0001-4001-8001-000000000011' AS dashboard_id,
              'Catalog Parts' AS title, 'equipment-part' AS entity_slug,
              1 AS grid_row, 1 AS grid_column, 40 AS sort_order FROM dual) s
ON (t.panel_id = s.panel_id)
WHEN NOT MATCHED THEN INSERT (panel_id, dashboard_id, title, entity_slug, grid_row, grid_column, sort_order)
    VALUES (s.panel_id, s.dashboard_id, s.title, s.entity_slug, s.grid_row, s.grid_column, s.sort_order);

MERGE INTO dashboard_key_mapping t
USING (SELECT 'w1000011-0001-4001-8001-000000000011' AS key_mapping_id,
              'd1000011-0001-4001-8001-000000000011' AS dashboard_id,
              'Shift+V' AS key_chord,
              'WEB' AS platform_code FROM dual) s
ON (t.key_mapping_id = s.key_mapping_id)
WHEN NOT MATCHED THEN INSERT (key_mapping_id, dashboard_id, key_chord, platform_code)
    VALUES (s.key_mapping_id, s.dashboard_id, s.key_chord, s.platform_code);

-- ---- Facilities & Airports: logistics sheets after core facility data ----
MERGE INTO dashboard_panel t
USING (SELECT 'p1000114-0001-4001-8001-000000000114' AS panel_id,
              'd1000004-0001-4001-8001-000000000004' AS dashboard_id,
              'Part Warehouses' AS title, 'facility' AS entity_slug,
              2 AS grid_row, 0 AS grid_column, 35 AS sort_order,
              '{"facilityTypeCode":"PART_WAREHOUSE"}' AS filter_json FROM dual) s
ON (t.panel_id = s.panel_id)
WHEN MATCHED THEN UPDATE SET
    t.grid_row = s.grid_row, t.grid_column = s.grid_column, t.sort_order = s.sort_order,
    t.filter_json = s.filter_json
WHEN NOT MATCHED THEN INSERT (panel_id, dashboard_id, title, entity_slug, grid_row, grid_column, sort_order, filter_json)
    VALUES (s.panel_id, s.dashboard_id, s.title, s.entity_slug, s.grid_row, s.grid_column, s.sort_order, s.filter_json);

MERGE INTO dashboard_panel t
USING (SELECT 'p1000115-0001-4001-8001-000000000115' AS panel_id,
              'd1000004-0001-4001-8001-000000000004' AS dashboard_id,
              'Logistics Activities' AS title, 'facility-logistics-activity' AS entity_slug,
              2 AS grid_row, 1 AS grid_column, 36 AS sort_order FROM dual) s
ON (t.panel_id = s.panel_id)
WHEN MATCHED THEN UPDATE SET
    t.grid_row = s.grid_row, t.grid_column = s.grid_column, t.sort_order = s.sort_order
WHEN NOT MATCHED THEN INSERT (panel_id, dashboard_id, title, entity_slug, grid_row, grid_column, sort_order)
    VALUES (s.panel_id, s.dashboard_id, s.title, s.entity_slug, s.grid_row, s.grid_column, s.sort_order);

-- Reposition core facility lookup sheets to make room for logistics group at row 2
MERGE INTO dashboard_panel t
USING (SELECT 'p1000036-0001-4001-8001-000000000036' AS panel_id,
              3 AS grid_row, 0 AS grid_column, 60 AS sort_order FROM dual) s
ON (t.panel_id = s.panel_id)
WHEN MATCHED THEN UPDATE SET t.grid_row = s.grid_row, t.grid_column = s.grid_column, t.sort_order = s.sort_order;

MERGE INTO dashboard_panel t
USING (SELECT 'p1000037-0001-4001-8001-000000000037' AS panel_id,
              3 AS grid_row, 1 AS grid_column, 61 AS sort_order FROM dual) s
ON (t.panel_id = s.panel_id)
WHEN MATCHED THEN UPDATE SET t.grid_row = s.grid_row, t.grid_column = s.grid_column, t.sort_order = s.sort_order;

MERGE INTO dashboard_panel t
USING (SELECT 'p1000038-0001-4001-8001-000000000038' AS panel_id,
              3 AS grid_row, 2 AS grid_column, 62 AS sort_order FROM dual) s
ON (t.panel_id = s.panel_id)
WHEN MATCHED THEN UPDATE SET t.grid_row = s.grid_row, t.grid_column = s.grid_column, t.sort_order = s.sort_order;

MERGE INTO dashboard_panel t
USING (SELECT 'p1000039-0001-4001-8001-000000000039' AS panel_id,
              4 AS grid_row, 0 AS grid_column, 63 AS sort_order FROM dual) s
ON (t.panel_id = s.panel_id)
WHEN MATCHED THEN UPDATE SET t.grid_row = s.grid_row, t.grid_column = s.grid_column, t.sort_order = s.sort_order;

MERGE INTO dashboard_panel t
USING (SELECT 'p100003a-0001-4001-8001-00000000003a' AS panel_id,
              4 AS grid_row, 1 AS grid_column, 64 AS sort_order FROM dual) s
ON (t.panel_id = s.panel_id)
WHEN MATCHED THEN UPDATE SET t.grid_row = s.grid_row, t.grid_column = s.grid_column, t.sort_order = s.sort_order;

MERGE INTO dashboard_panel t
USING (SELECT 'p100003b-0001-4001-8001-00000000003b' AS panel_id,
              4 AS grid_row, 2 AS grid_column, 65 AS sort_order FROM dual) s
ON (t.panel_id = s.panel_id)
WHEN MATCHED THEN UPDATE SET t.grid_row = s.grid_row, t.grid_column = s.grid_column, t.sort_order = s.sort_order;

COMMIT;
