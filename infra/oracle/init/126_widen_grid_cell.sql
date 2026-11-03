-- =============================================================================
-- Widen DEFAULT render-context grid: cellSizeUnits 250 → 500.
-- Breathing room for airfield footprints (~180) on an orthogonal lattice.
-- Idempotent: safe to re-run against an existing database.
-- =============================================================================

ALTER SESSION SET CONTAINER = FREEPDB1;
ALTER SESSION SET CURRENT_SCHEMA = nas_sim;

UPDATE simulation_render_context
SET grid_config_json = q'[{"cellSizeUnits":500,"connectMode":"nearest-in-line","runwayWidthUnits":18}]',
    updated_at = SYSTIMESTAMP
WHERE context_code = 'DEFAULT';

COMMIT;
/
