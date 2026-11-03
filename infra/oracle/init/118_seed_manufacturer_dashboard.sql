-- =============================================================================
-- Manufacturers dashboard + logistics panels on Equipment dashboard
-- =============================================================================

ALTER SESSION SET CONTAINER = FREEPDB1;
ALTER SESSION SET CURRENT_SCHEMA = nas_sim;
SET DEFINE OFF;

MERGE INTO dashboard_definition t
USING (SELECT 'd1000011-0001-4001-8001-000000000011' AS dashboard_id,
              'MANUFACTURERS' AS dashboard_code,
              'Parts Manufacturers & Supply' AS title,
              'OEM registry, quotes, orders, and parts catalog (off-NAS)' AS description,
              25 AS sort_order FROM dual) s
ON (t.dashboard_id = s.dashboard_id)
WHEN NOT MATCHED THEN INSERT (dashboard_id, dashboard_code, title, description, sort_order)
    VALUES (s.dashboard_id, s.dashboard_code, s.title, s.description, s.sort_order);

MERGE INTO dashboard_key_mapping t
USING (SELECT 'k1000011-0001-4001-8001-000000000011' AS key_mapping_id,
              'd1000011-0001-4001-8001-000000000011' AS dashboard_id,
              'Shift+V' AS key_chord FROM dual) s
ON (t.key_mapping_id = s.key_mapping_id)
WHEN NOT MATCHED THEN INSERT (key_mapping_id, dashboard_id, key_chord)
    VALUES (s.key_mapping_id, s.dashboard_id, s.key_chord);

MERGE INTO dashboard_panel t
USING (SELECT 'p1000040-0001-4001-8001-000000000040' AS panel_id,
              'd1000011-0001-4001-8001-000000000011' AS dashboard_id,
              'Manufacturers' AS title, 'part-manufacturer-lkp' AS entity_slug,
              0 AS grid_row, 0 AS grid_column, 10 AS sort_order FROM dual) s
ON (t.panel_id = s.panel_id)
WHEN NOT MATCHED THEN INSERT (panel_id, dashboard_id, title, entity_slug, grid_row, grid_column, sort_order)
    VALUES (s.panel_id, s.dashboard_id, s.title, s.entity_slug, s.grid_row, s.grid_column, s.sort_order);

-- Panel IDs p1000041–p1000044 are reserved by Weather panels in 10_seed_dashboards.sql.
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

-- Equipment dashboard logistics panels
MERGE INTO dashboard_panel t
USING (SELECT 'p1000103-0001-4001-8001-000000000103' AS panel_id,
              'd1000002-0001-4001-8001-000000000002' AS dashboard_id,
              'Part Shipments' AS title, 'equipment-part-shipment' AS entity_slug,
              2 AS grid_row, 0 AS grid_column, 85 AS sort_order FROM dual) s
ON (t.panel_id = s.panel_id)
WHEN NOT MATCHED THEN INSERT (panel_id, dashboard_id, title, entity_slug, grid_row, grid_column, sort_order)
    VALUES (s.panel_id, s.dashboard_id, s.title, s.entity_slug, s.grid_row, s.grid_column, s.sort_order);

MERGE INTO dashboard_panel t
USING (SELECT 'p1000045-0001-4001-8001-000000000045' AS panel_id,
              'd1000002-0001-4001-8001-000000000002' AS dashboard_id,
              'Warehouse Activities' AS title, 'facility-logistics-activity' AS entity_slug,
              2 AS grid_row, 1 AS grid_column, 86 AS sort_order FROM dual) s
ON (t.panel_id = s.panel_id)
WHEN NOT MATCHED THEN INSERT (panel_id, dashboard_id, title, entity_slug, grid_row, grid_column, sort_order)
    VALUES (s.panel_id, s.dashboard_id, s.title, s.entity_slug, s.grid_row, s.grid_column, s.sort_order);
