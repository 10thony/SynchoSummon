-- =============================================================================
-- Server-persisted layout overrides (strip soft-hide) on render context.
--
-- Adds simulation_render_context.layout_overrides_json, delivered to WebGPU
-- viewers via /api/explorer/scenario and written by the layout editor's
-- hide/unhide. Shape: {"hiddenStrips":["airfield:KDSM:runway-13-31", ...]}.
--
-- Idempotent: add-if-missing so it can be applied to the live Spark database
-- (init scripts only auto-run on a fresh Docker volume).
-- =============================================================================

ALTER SESSION SET CONTAINER = FREEPDB1;
ALTER SESSION SET CURRENT_SCHEMA = nas_sim;

DECLARE
    v_count NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_count
    FROM user_tab_columns
    WHERE table_name = 'SIMULATION_RENDER_CONTEXT'
      AND column_name = 'LAYOUT_OVERRIDES_JSON';
    IF v_count = 0 THEN
        EXECUTE IMMEDIATE q'[
            ALTER TABLE simulation_render_context
                ADD layout_overrides_json CLOB
                    CONSTRAINT chk_render_context_layout_overrides_json
                        CHECK (layout_overrides_json IS JSON OR layout_overrides_json IS NULL)
        ]';
    END IF;
END;
/
