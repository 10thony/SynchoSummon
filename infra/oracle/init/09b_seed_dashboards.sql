-- =============================================================================
-- Seed operator dashboards, keyboard mappings, and a sample simulation schedule
-- =============================================================================

ALTER SESSION SET CONTAINER = FREEPDB1;
ALTER SESSION SET CURRENT_SCHEMA = nas_sim;
SET DEFINE OFF;

-- Dashboard definitions
INSERT INTO dashboard_definition (dashboard_id, dashboard_code, title, description, sort_order) VALUES
('d1000001-0001-4001-8001-000000000001', 'ATC', 'ATC & Flights', 'Flight operations, paths, requests, events, and incidents', 10);
INSERT INTO dashboard_definition (dashboard_id, dashboard_code, title, description, sort_order) VALUES
('d1000002-0001-4001-8001-000000000002', 'EQUIPMENT', 'Equipment & Parts', 'NAS equipment, parts, orders, quotes, and alerts', 20);
INSERT INTO dashboard_definition (dashboard_id, dashboard_code, title, description, sort_order) VALUES
('d1000003-0001-4001-8001-000000000003', 'MAINTENANCE', 'Maintenance', 'Maintenance activities, logs, and facility work', 30);
INSERT INTO dashboard_definition (dashboard_id, dashboard_code, title, description, sort_order) VALUES
('d1000004-0001-4001-8001-000000000004', 'FACILITIES', 'Facilities & Airports', 'Facilities, runways, NOTAMs, and geo lookups', 40);
INSERT INTO dashboard_definition (dashboard_id, dashboard_code, title, description, sort_order) VALUES
('d1000005-0001-4001-8001-000000000005', 'WEATHER', 'Weather', 'Weather events, paths, and alerts', 50);
INSERT INTO dashboard_definition (dashboard_id, dashboard_code, title, description, sort_order) VALUES
('d1000006-0001-4001-8001-000000000006', 'SIMULATION', 'Simulation Control', 'Run state, snapshots, render context, and configuration', 60);
INSERT INTO dashboard_definition (dashboard_id, dashboard_code, title, description, sort_order) VALUES
('d1000007-0001-4001-8001-000000000007', 'USERS', 'Users & Permissions', 'Operator accounts, roles, and permissions', 70);
INSERT INTO dashboard_definition (dashboard_id, dashboard_code, title, description, sort_order) VALUES
('d1000008-0001-4001-8001-000000000008', 'GROUND_OPS', 'Ground Operations', 'Turnaround activities and ground ops logs', 80);
INSERT INTO dashboard_definition (dashboard_id, dashboard_code, title, description, sort_order) VALUES
('d1000009-0001-4001-8001-000000000009', 'LOOKUPS', 'Reference Lookups', 'Order, quote, and status lookup tables', 90);
INSERT INTO dashboard_definition (dashboard_id, dashboard_code, title, description, sort_order) VALUES
('d1000010-0001-4001-8001-000000000010', 'SCHEDULES', 'Simulation Schedules', 'Scripted timeline events for the simulation', 100);

-- Keyboard mappings (Unity operator console)
INSERT INTO dashboard_key_mapping (key_mapping_id, dashboard_id, key_chord) VALUES
('k1000001-0001-4001-8001-000000000001', 'd1000001-0001-4001-8001-000000000001', 'Shift+A');
INSERT INTO dashboard_key_mapping (key_mapping_id, dashboard_id, key_chord) VALUES
('k1000002-0001-4001-8001-000000000002', 'd1000002-0001-4001-8001-000000000002', 'Shift+P');
INSERT INTO dashboard_key_mapping (key_mapping_id, dashboard_id, key_chord) VALUES
('k1000003-0001-4001-8001-000000000003', 'd1000003-0001-4001-8001-000000000003', 'Shift+M');
INSERT INTO dashboard_key_mapping (key_mapping_id, dashboard_id, key_chord) VALUES
('k1000004-0001-4001-8001-000000000004', 'd1000004-0001-4001-8001-000000000004', 'Shift+F');
INSERT INTO dashboard_key_mapping (key_mapping_id, dashboard_id, key_chord) VALUES
('k1000005-0001-4001-8001-000000000005', 'd1000005-0001-4001-8001-000000000005', 'Shift+W');
INSERT INTO dashboard_key_mapping (key_mapping_id, dashboard_id, key_chord) VALUES
('k1000006-0001-4001-8001-000000000006', 'd1000006-0001-4001-8001-000000000006', 'Shift+S');
INSERT INTO dashboard_key_mapping (key_mapping_id, dashboard_id, key_chord) VALUES
('k1000007-0001-4001-8001-000000000007', 'd1000007-0001-4001-8001-000000000007', 'Shift+U');
INSERT INTO dashboard_key_mapping (key_mapping_id, dashboard_id, key_chord) VALUES
('k1000008-0001-4001-8001-000000000008', 'd1000008-0001-4001-8001-000000000008', 'Shift+G');
INSERT INTO dashboard_key_mapping (key_mapping_id, dashboard_id, key_chord) VALUES
('k1000009-0001-4001-8001-000000000009', 'd1000009-0001-4001-8001-000000000009', 'Shift+L');
INSERT INTO dashboard_key_mapping (key_mapping_id, dashboard_id, key_chord) VALUES
('k1000010-0001-4001-8001-000000000010', 'd1000010-0001-4001-8001-000000000010', 'Shift+T');

-- ATC panels
INSERT INTO dashboard_panel (panel_id, dashboard_id, title, entity_slug, grid_row, grid_column, grid_row_span, grid_column_span, sort_order) VALUES
('p1000001-0001-4001-8001-000000000001', 'd1000001-0001-4001-8001-000000000001', 'Flight Operations', 'flight-operation', 0, 0, 1, 2, 10);
INSERT INTO dashboard_panel (panel_id, dashboard_id, title, entity_slug, grid_row, grid_column, sort_order) VALUES
('p1000002-0001-4001-8001-000000000002', 'd1000001-0001-4001-8001-000000000001', 'Flight Paths', 'flight-path', 0, 2, 20);
INSERT INTO dashboard_panel (panel_id, dashboard_id, title, entity_slug, grid_row, grid_column, sort_order) VALUES
('p1000003-0001-4001-8001-000000000003', 'd1000001-0001-4001-8001-000000000001', 'Path Requests', 'flight-path-request', 1, 0, 30);
INSERT INTO dashboard_panel (panel_id, dashboard_id, title, entity_slug, grid_row, grid_column, sort_order) VALUES
('p1000004-0001-4001-8001-000000000004', 'd1000001-0001-4001-8001-000000000001', 'Flight Requests', 'flight-request', 1, 1, 40);
INSERT INTO dashboard_panel (panel_id, dashboard_id, title, entity_slug, grid_row, grid_column, sort_order) VALUES
('p1000005-0001-4001-8001-000000000005', 'd1000001-0001-4001-8001-000000000001', 'Flight Events', 'flight-event', 1, 2, 50);
INSERT INTO dashboard_panel (panel_id, dashboard_id, title, entity_slug, grid_row, grid_column, sort_order) VALUES
('p1000006-0001-4001-8001-000000000006', 'd1000001-0001-4001-8001-000000000001', 'Flight Incidents', 'flight-incident', 2, 0, 60);
INSERT INTO dashboard_panel (panel_id, dashboard_id, title, entity_slug, grid_row, grid_column, sort_order) VALUES
('p1000007-0001-4001-8001-000000000007', 'd1000001-0001-4001-8001-000000000001', 'Aircraft', 'aircraft', 2, 1, 70);
INSERT INTO dashboard_panel (panel_id, dashboard_id, title, entity_slug, grid_row, grid_column, sort_order) VALUES
('p1000008-0001-4001-8001-000000000008', 'd1000001-0001-4001-8001-000000000001', 'Flight Phases', 'flight-phase-lkp', 2, 2, 80);
INSERT INTO dashboard_panel (panel_id, dashboard_id, title, entity_slug, grid_row, grid_column, sort_order) VALUES
('p1000009-0001-4001-8001-000000000009', 'd1000001-0001-4001-8001-000000000001', 'Event Types', 'flight-event-type-lkp', 3, 0, 90);
INSERT INTO dashboard_panel (panel_id, dashboard_id, title, entity_slug, grid_row, grid_column, sort_order) VALUES
('p1000010-0001-4001-8001-000000000010', 'd1000001-0001-4001-8001-000000000001', 'Incident Types', 'incident-type-lkp', 3, 1, 100);

-- Equipment panels
INSERT INTO dashboard_panel (panel_id, dashboard_id, title, entity_slug, grid_row, grid_column, grid_row_span, grid_column_span, sort_order) VALUES
('p1000011-0001-4001-8001-000000000011', 'd1000002-0001-4001-8001-000000000002', 'Equipment', 'equipment', 0, 0, 1, 2, 10);
INSERT INTO dashboard_panel (panel_id, dashboard_id, title, entity_slug, grid_row, grid_column, sort_order) VALUES
('p1000012-0001-4001-8001-000000000012', 'd1000002-0001-4001-8001-000000000002', 'Parts', 'equipment-part', 0, 2, 20);
INSERT INTO dashboard_panel (panel_id, dashboard_id, title, entity_slug, grid_row, grid_column, sort_order) VALUES
('p1000013-0001-4001-8001-000000000013', 'd1000002-0001-4001-8001-000000000002', 'Part Orders', 'equipment-part-order', 1, 0, 30);
INSERT INTO dashboard_panel (panel_id, dashboard_id, title, entity_slug, grid_row, grid_column, sort_order) VALUES
('p1000014-0001-4001-8001-000000000014', 'd1000002-0001-4001-8001-000000000002', 'Part Quotes', 'equipment-part-quote', 1, 1, 40);
INSERT INTO dashboard_panel (panel_id, dashboard_id, title, entity_slug, grid_row, grid_column, sort_order) VALUES
('p1000015-0001-4001-8001-000000000015', 'd1000002-0001-4001-8001-000000000002', 'Dependencies', 'equipment-dependency', 1, 2, 50);
INSERT INTO dashboard_panel (panel_id, dashboard_id, title, entity_slug, grid_row, grid_column, sort_order) VALUES
('p1000016-0001-4001-8001-000000000016', 'd1000002-0001-4001-8001-000000000002', 'Alerts', 'equipment-alert', 2, 0, 60);
INSERT INTO dashboard_panel (panel_id, dashboard_id, title, entity_slug, grid_row, grid_column, sort_order) VALUES
('p1000017-0001-4001-8001-000000000017', 'd1000002-0001-4001-8001-000000000002', 'Equipment Types', 'equipment-type-lkp', 2, 1, 70);
INSERT INTO dashboard_panel (panel_id, dashboard_id, title, entity_slug, grid_row, grid_column, sort_order) VALUES
('p1000018-0001-4001-8001-000000000018', 'd1000002-0001-4001-8001-000000000002', 'Runway Equipment', 'runway-equipment', 2, 2, 80);
INSERT INTO dashboard_panel (panel_id, dashboard_id, title, entity_slug, grid_row, grid_column, sort_order) VALUES
('p1000019-0001-4001-8001-000000000019', 'd1000002-0001-4001-8001-000000000002', 'Aircraft Types', 'aircraft-type-lkp', 3, 0, 90);
INSERT INTO dashboard_panel (panel_id, dashboard_id, title, entity_slug, grid_row, grid_column, sort_order) VALUES
('p1000020-0001-4001-8001-000000000020', 'd1000002-0001-4001-8001-000000000002', 'Alert Severity', 'alert-severity-lkp', 3, 1, 100);

-- Maintenance panels
INSERT INTO dashboard_panel (panel_id, dashboard_id, title, entity_slug, grid_row, grid_column, grid_row_span, grid_column_span, sort_order) VALUES
('p1000021-0001-4001-8001-000000000021', 'd1000003-0001-4001-8001-000000000003', 'Activities', 'maintenance-activity', 0, 0, 1, 2, 10);
INSERT INTO dashboard_panel (panel_id, dashboard_id, title, entity_slug, grid_row, grid_column, sort_order) VALUES
('p1000022-0001-4001-8001-000000000022', 'd1000003-0001-4001-8001-000000000003', 'Logs', 'maintenance-log', 0, 2, 20);
INSERT INTO dashboard_panel (panel_id, dashboard_id, title, entity_slug, grid_row, grid_column, sort_order) VALUES
('p1000023-0001-4001-8001-000000000023', 'd1000003-0001-4001-8001-000000000003', 'Reports', 'maintenance-report', 1, 0, 30);
INSERT INTO dashboard_panel (panel_id, dashboard_id, title, entity_slug, grid_row, grid_column, sort_order) VALUES
('p1000024-0001-4001-8001-000000000024', 'd1000003-0001-4001-8001-000000000003', 'Facility Maintenance', 'facility-maintenance-activity', 1, 1, 40);
INSERT INTO dashboard_panel (panel_id, dashboard_id, title, entity_slug, grid_row, grid_column, sort_order) VALUES
('p1000025-0001-4001-8001-000000000025', 'd1000003-0001-4001-8001-000000000003', 'Activity Types', 'maintenance-activity-type-lkp', 1, 2, 50);
INSERT INTO dashboard_panel (panel_id, dashboard_id, title, entity_slug, grid_row, grid_column, sort_order) VALUES
('p1000026-0001-4001-8001-000000000026', 'd1000003-0001-4001-8001-000000000003', 'Status Codes', 'maintenance-status-lkp', 2, 0, 60);

-- Facilities panels
INSERT INTO dashboard_panel (panel_id, dashboard_id, title, entity_slug, grid_row, grid_column, grid_row_span, grid_column_span, sort_order) VALUES
('p1000031-0001-4001-8001-000000000031', 'd1000004-0001-4001-8001-000000000004', 'Facilities', 'facility', 0, 0, 1, 2, 10);
INSERT INTO dashboard_panel (panel_id, dashboard_id, title, entity_slug, grid_row, grid_column, sort_order) VALUES
('p1000032-0001-4001-8001-000000000032', 'd1000004-0001-4001-8001-000000000004', 'Runways', 'runway', 0, 2, 20);
INSERT INTO dashboard_panel (panel_id, dashboard_id, title, entity_slug, grid_row, grid_column, sort_order) VALUES
('p1000033-0001-4001-8001-000000000033', 'd1000004-0001-4001-8001-000000000004', 'NOTAMs', 'notam', 1, 0, 30);
INSERT INTO dashboard_panel (panel_id, dashboard_id, title, entity_slug, grid_row, grid_column, sort_order) VALUES
('p1000034-0001-4001-8001-000000000034', 'd1000004-0001-4001-8001-000000000004', 'Geo Lookups', 'simulation-geo-location-lookup', 1, 1, 40);
INSERT INTO dashboard_panel (panel_id, dashboard_id, title, entity_slug, grid_row, grid_column, sort_order) VALUES
('p1000035-0001-4001-8001-000000000035', 'd1000004-0001-4001-8001-000000000004', 'Facility Types', 'facility-type-lkp', 1, 2, 50);
INSERT INTO dashboard_panel (panel_id, dashboard_id, title, entity_slug, grid_row, grid_column, sort_order) VALUES
('p1000036-0001-4001-8001-000000000036', 'd1000004-0001-4001-8001-000000000004', 'Operational Status', 'operational-status-lkp', 2, 0, 60);
INSERT INTO dashboard_panel (panel_id, dashboard_id, title, entity_slug, grid_row, grid_column, sort_order) VALUES
('p1000037-0001-4001-8001-000000000037', 'd1000004-0001-4001-8001-000000000004', 'US States', 'us-state-lkp', 2, 1, 70);

-- Weather panels
INSERT INTO dashboard_panel (panel_id, dashboard_id, title, entity_slug, grid_row, grid_column, sort_order) VALUES
('p1000041-0001-4001-8001-000000000041', 'd1000005-0001-4001-8001-000000000005', 'Weather Events', 'weather-event', 0, 0, 10);
INSERT INTO dashboard_panel (panel_id, dashboard_id, title, entity_slug, grid_row, grid_column, sort_order) VALUES
('p1000042-0001-4001-8001-000000000042', 'd1000005-0001-4001-8001-000000000005', 'Event Paths', 'weather-event-path', 0, 1, 20);
INSERT INTO dashboard_panel (panel_id, dashboard_id, title, entity_slug, grid_row, grid_column, sort_order) VALUES
('p1000043-0001-4001-8001-000000000043', 'd1000005-0001-4001-8001-000000000005', 'Weather Alerts', 'weather-event-alert', 0, 2, 30);
INSERT INTO dashboard_panel (panel_id, dashboard_id, title, entity_slug, grid_row, grid_column, sort_order) VALUES
('p1000044-0001-4001-8001-000000000044', 'd1000005-0001-4001-8001-000000000005', 'Event Types', 'weather-event-type-lkp', 1, 0, 40);

-- Simulation panels
INSERT INTO dashboard_panel (panel_id, dashboard_id, title, entity_slug, grid_row, grid_column, sort_order) VALUES
('p1000051-0001-4001-8001-000000000051', 'd1000006-0001-4001-8001-000000000006', 'Run State', 'simulation-run-state', 0, 0, 10);
INSERT INTO dashboard_panel (panel_id, dashboard_id, title, entity_slug, grid_row, grid_column, sort_order) VALUES
('p1000052-0001-4001-8001-000000000052', 'd1000006-0001-4001-8001-000000000006', 'Render Context', 'simulation-render-context', 0, 1, 20);
INSERT INTO dashboard_panel (panel_id, dashboard_id, title, entity_slug, grid_row, grid_column, sort_order) VALUES
('p1000053-0001-4001-8001-000000000053', 'd1000006-0001-4001-8001-000000000006', 'Snapshots', 'simulation-snapshot', 0, 2, 30);
INSERT INTO dashboard_panel (panel_id, dashboard_id, title, entity_slug, grid_row, grid_column, sort_order) VALUES
('p1000054-0001-4001-8001-000000000054', 'd1000006-0001-4001-8001-000000000006', 'Global Config', 'global-configuration', 1, 0, 40);
INSERT INTO dashboard_panel (panel_id, dashboard_id, title, entity_slug, grid_row, grid_column, sort_order) VALUES
('p1000055-0001-4001-8001-000000000055', 'd1000006-0001-4001-8001-000000000006', 'Clock Modes', 'simulation-clock-mode-lkp', 1, 1, 50);
INSERT INTO dashboard_panel (panel_id, dashboard_id, title, entity_slug, grid_row, grid_column, sort_order) VALUES
('p1000056-0001-4001-8001-000000000056', 'd1000006-0001-4001-8001-000000000006', 'Run Status', 'simulation-run-status-lkp', 1, 2, 60);

-- Users panels
INSERT INTO dashboard_panel (panel_id, dashboard_id, title, entity_slug, grid_row, grid_column, sort_order) VALUES
('p1000061-0001-4001-8001-000000000061', 'd1000007-0001-4001-8001-000000000007', 'Users', 'users', 0, 0, 10);
INSERT INTO dashboard_panel (panel_id, dashboard_id, title, entity_slug, grid_row, grid_column, sort_order) VALUES
('p1000062-0001-4001-8001-000000000062', 'd1000007-0001-4001-8001-000000000007', 'Permissions', 'user-permissions', 0, 1, 20);
INSERT INTO dashboard_panel (panel_id, dashboard_id, title, entity_slug, grid_row, grid_column, sort_order) VALUES
('p1000063-0001-4001-8001-000000000063', 'd1000007-0001-4001-8001-000000000007', 'Role Permissions', 'role-permission', 0, 2, 30);
INSERT INTO dashboard_panel (panel_id, dashboard_id, title, entity_slug, grid_row, grid_column, sort_order) VALUES
('p1000064-0001-4001-8001-000000000064', 'd1000007-0001-4001-8001-000000000007', 'User Roles', 'user-role-lookup', 1, 0, 40);

-- Ground ops panels
INSERT INTO dashboard_panel (panel_id, dashboard_id, title, entity_slug, grid_row, grid_column, sort_order) VALUES
('p1000071-0001-4001-8001-000000000071', 'd1000008-0001-4001-8001-000000000008', 'Activities', 'ground-operation-activity', 0, 0, 10);
INSERT INTO dashboard_panel (panel_id, dashboard_id, title, entity_slug, grid_row, grid_column, sort_order) VALUES
('p1000072-0001-4001-8001-000000000072', 'd1000008-0001-4001-8001-000000000008', 'Logs', 'ground-operation-log', 0, 1, 20);
INSERT INTO dashboard_panel (panel_id, dashboard_id, title, entity_slug, grid_row, grid_column, sort_order) VALUES
('p1000073-0001-4001-8001-000000000073', 'd1000008-0001-4001-8001-000000000008', 'Activity Types', 'ground-operation-activity-type-lkp', 1, 0, 30);
INSERT INTO dashboard_panel (panel_id, dashboard_id, title, entity_slug, grid_row, grid_column, sort_order) VALUES
('p1000074-0001-4001-8001-000000000074', 'd1000008-0001-4001-8001-000000000008', 'Status Codes', 'ground-operation-status-lkp', 1, 1, 40);

-- Lookup panels
INSERT INTO dashboard_panel (panel_id, dashboard_id, title, entity_slug, grid_row, grid_column, sort_order) VALUES
('p1000081-0001-4001-8001-000000000081', 'd1000009-0001-4001-8001-000000000009', 'Order Status', 'order-status-lkp', 0, 0, 10);
INSERT INTO dashboard_panel (panel_id, dashboard_id, title, entity_slug, grid_row, grid_column, sort_order) VALUES
('p1000082-0001-4001-8001-000000000082', 'd1000009-0001-4001-8001-000000000009', 'Quote Status', 'quote-status-lkp', 0, 1, 20);

-- Schedule dashboard (special panel slug)
INSERT INTO dashboard_panel (panel_id, dashboard_id, title, entity_slug, grid_row, grid_column, grid_row_span, grid_column_span, sort_order) VALUES
('p1000091-0001-4001-8001-000000000091', 'd1000010-0001-4001-8001-000000000010', 'Schedules', '__simulation-schedule__', 0, 0, 2, 3, 10);

-- Sample scripted schedule
INSERT INTO simulation_schedule (schedule_id, schedule_code, title, description) VALUES
('s1000001-0001-4001-8001-000000000001', 'DAY_ONE_SCRIPT', 'Day One Scenario Script', 'Sample timeline injections for the operational day');

INSERT INTO simulation_schedule_event (schedule_event_id, schedule_id, occurred_at_sim_utc, action_code, entity_slug, summary, payload_json, sort_order) VALUES
('e1000001-0001-4001-8001-000000000001', 's1000001-0001-4001-8001-000000000001',
 TIMESTAMP '2026-06-23 08:00:00', 'TIMELINE_NOTE', NULL,
 'Morning ops briefing', NULL, 10);

INSERT INTO simulation_schedule_event (schedule_event_id, schedule_id, occurred_at_sim_utc, action_code, entity_slug, summary, payload_json, sort_order) VALUES
('e1000002-0001-4001-8001-000000000002', 's1000001-0001-4001-8001-000000000001',
 TIMESTAMP '2026-06-23 14:30:00', 'TIMELINE_NOTE', NULL,
 'Afternoon weather watch', '{"category":"WEATHER","status":"WATCH"}', 20);

-- Web operator console (same chords as Unity, platform WEB)
INSERT INTO dashboard_key_mapping (key_mapping_id, dashboard_id, key_chord, platform_code) VALUES
('w1000001-0001-4001-8001-000000000001', 'd1000001-0001-4001-8001-000000000001', 'Shift+A', 'WEB');
INSERT INTO dashboard_key_mapping (key_mapping_id, dashboard_id, key_chord, platform_code) VALUES
('w1000002-0001-4001-8001-000000000002', 'd1000002-0001-4001-8001-000000000002', 'Shift+P', 'WEB');
INSERT INTO dashboard_key_mapping (key_mapping_id, dashboard_id, key_chord, platform_code) VALUES
('w1000003-0001-4001-8001-000000000003', 'd1000003-0001-4001-8001-000000000003', 'Shift+M', 'WEB');
INSERT INTO dashboard_key_mapping (key_mapping_id, dashboard_id, key_chord, platform_code) VALUES
('w1000004-0001-4001-8001-000000000004', 'd1000004-0001-4001-8001-000000000004', 'Shift+F', 'WEB');
INSERT INTO dashboard_key_mapping (key_mapping_id, dashboard_id, key_chord, platform_code) VALUES
('w1000005-0001-4001-8001-000000000005', 'd1000005-0001-4001-8001-000000000005', 'Shift+W', 'WEB');
INSERT INTO dashboard_key_mapping (key_mapping_id, dashboard_id, key_chord, platform_code) VALUES
('w1000006-0001-4001-8001-000000000006', 'd1000006-0001-4001-8001-000000000006', 'Shift+S', 'WEB');
INSERT INTO dashboard_key_mapping (key_mapping_id, dashboard_id, key_chord, platform_code) VALUES
('w1000007-0001-4001-8001-000000000007', 'd1000007-0001-4001-8001-000000000007', 'Shift+U', 'WEB');
INSERT INTO dashboard_key_mapping (key_mapping_id, dashboard_id, key_chord, platform_code) VALUES
('w1000008-0001-4001-8001-000000000008', 'd1000008-0001-4001-8001-000000000008', 'Shift+G', 'WEB');
INSERT INTO dashboard_key_mapping (key_mapping_id, dashboard_id, key_chord, platform_code) VALUES
('w1000009-0001-4001-8001-000000000009', 'd1000009-0001-4001-8001-000000000009', 'Shift+L', 'WEB');
INSERT INTO dashboard_key_mapping (key_mapping_id, dashboard_id, key_chord, platform_code) VALUES
('w1000010-0001-4001-8001-000000000010', 'd1000010-0001-4001-8001-000000000010', 'Shift+T', 'WEB');

COMMIT;
