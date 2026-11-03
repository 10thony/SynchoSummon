-- =============================================================================
-- Facilities dashboard — staffing, asset profiles, equipment requirements panels
-- =============================================================================

ALTER SESSION SET CONTAINER = FREEPDB1;
ALTER SESSION SET CURRENT_SCHEMA = nas_sim;
SET DEFINE OFF;

MERGE INTO dashboard_panel t
USING (SELECT 'p1000038-0001-4001-8001-000000000038' AS panel_id,
              'd1000004-0001-4001-8001-000000000004' AS dashboard_id,
              'Facility Staff' AS title, 'facility-staff-assignment' AS entity_slug,
              2 AS grid_row, 2 AS grid_column, 38 AS sort_order FROM dual) s
ON (t.panel_id = s.panel_id)
WHEN NOT MATCHED THEN INSERT (panel_id, dashboard_id, title, entity_slug, grid_row, grid_column, sort_order)
    VALUES (s.panel_id, s.dashboard_id, s.title, s.entity_slug, s.grid_row, s.grid_column, s.sort_order);

MERGE INTO dashboard_panel t
USING (SELECT 'p1000039-0001-4001-8001-000000000039' AS panel_id,
              'd1000004-0001-4001-8001-000000000004' AS dashboard_id,
              'Personnel Roles' AS title, 'facility-personnel-role-lkp' AS entity_slug,
              3 AS grid_row, 0 AS grid_column, 39 AS sort_order FROM dual) s
ON (t.panel_id = s.panel_id)
WHEN NOT MATCHED THEN INSERT (panel_id, dashboard_id, title, entity_slug, grid_row, grid_column, sort_order)
    VALUES (s.panel_id, s.dashboard_id, s.title, s.entity_slug, s.grid_row, s.grid_column, s.sort_order);

MERGE INTO dashboard_panel t
USING (SELECT 'p100003a-0001-4001-8001-00000000003a' AS panel_id,
              'd1000004-0001-4001-8001-000000000004' AS dashboard_id,
              'Type Asset Profiles' AS title, 'facility-type-asset-profile' AS entity_slug,
              3 AS grid_row, 1 AS grid_column, 40 AS sort_order FROM dual) s
ON (t.panel_id = s.panel_id)
WHEN NOT MATCHED THEN INSERT (panel_id, dashboard_id, title, entity_slug, grid_row, grid_column, sort_order)
    VALUES (s.panel_id, s.dashboard_id, s.title, s.entity_slug, s.grid_row, s.grid_column, s.sort_order);

MERGE INTO dashboard_panel t
USING (SELECT 'p100003b-0001-4001-8001-00000000003b' AS panel_id,
              'd1000004-0001-4001-8001-000000000004' AS dashboard_id,
              'Equipment Requirements' AS title, 'facility-type-equipment-requirement' AS entity_slug,
              3 AS grid_row, 2 AS grid_column, 41 AS sort_order FROM dual) s
ON (t.panel_id = s.panel_id)
WHEN NOT MATCHED THEN INSERT (panel_id, dashboard_id, title, entity_slug, grid_row, grid_column, sort_order)
    VALUES (s.panel_id, s.dashboard_id, s.title, s.entity_slug, s.grid_row, s.grid_column, s.sort_order);
