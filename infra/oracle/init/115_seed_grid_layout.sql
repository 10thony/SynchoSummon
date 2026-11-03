-- =============================================================================
-- Organized grid layout for the DEFAULT render context (alpha-midwest map layer).
--
-- Assigns each facility a (grid_row, grid_col) cell. Clients place facilities
-- at (grid_col * cellSizeUnits, 0, grid_row * cellSizeUnits) and derive runway
-- connections from grid adjacency (nearest occupied cell along each row/col).
--
-- Layout (col = west->east, row = south->north, KDSM at origin):
--
--            col -2       col -1        col 0     col 1        col 2         col 3
--   row  2   .            KMSP          ZMP       .            .             .
--   row  1   KOMA         KAMW          KCID      KMLI         KMKE          .
--   row  0   DSM-RCO-01   KDSM-ATCT     KDSM      DSM-TRACON   ZAU           KORD
--   row -1   .            NAS-DEPOT-IA  DSM-ASR   ZAU-RTR-01   ZAU-RCAG-01   .
--
-- Idempotent: safe to re-run against an existing database.
-- =============================================================================

ALTER SESSION SET CONTAINER = FREEPDB1;
ALTER SESSION SET CURRENT_SCHEMA = nas_sim;

UPDATE simulation_render_context
SET grid_config_json = q'[{"cellSizeUnits":500,"connectMode":"nearest-in-line","runwayWidthUnits":18}]',
    updated_at = SYSTIMESTAMP
WHERE context_code = 'DEFAULT';

DECLARE
    PROCEDURE set_cell(p_facility_code IN VARCHAR2, p_row IN NUMBER, p_col IN NUMBER) IS
    BEGIN
        UPDATE simulation_geo_location_lookup g
        SET g.grid_row = p_row,
            g.grid_col = p_col,
            g.updated_at = SYSTIMESTAMP
        WHERE g.facility_id = (SELECT f.facility_id FROM facility f WHERE f.facility_code = p_facility_code)
          AND g.render_context_id = (SELECT r.render_context_id
                                     FROM simulation_render_context r
                                     WHERE r.context_code = 'DEFAULT');
    END;
BEGIN
    -- row 2 (north)
    set_cell('KMSP',         2, -1);
    set_cell('ZMP',          2,  0);
    -- row 1
    set_cell('KOMA',         1, -2);
    set_cell('KAMW',         1, -1);
    set_cell('KCID',         1,  0);
    set_cell('KMLI',         1,  1);
    set_cell('KMKE',         1,  2);
    -- row 0 (hub row)
    set_cell('DSM-RCO-01',   0, -2);
    set_cell('KDSM-ATCT',    0, -1);
    set_cell('KDSM',         0,  0);
    set_cell('DSM-TRACON',   0,  1);
    set_cell('ZAU',          0,  2);
    set_cell('KORD',         0,  3);
    -- row -1 (south)
    set_cell('NAS-DEPOT-IA', -1, -1);
    set_cell('NAS-PARTS-DSM', -1, -2);
    set_cell('DSM-ASR',      -1,  0);
    set_cell('ZAU-RTR-01',   -1,  1);
    set_cell('ZAU-RCAG-01',  -1,  2);
    COMMIT;
END;
/
