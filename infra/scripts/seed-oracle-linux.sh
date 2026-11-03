#!/usr/bin/env bash
# Re-apply Oracle seeds in correct order after fresh Docker init.
# Docker runs init scripts alphabetically, so 99 runs after 100-114.
# Also creates missing tables (facility_staff_assignment, entra_group_role_mapping).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ORACLE_CONTAINER="${ORACLE_CONTAINER:-syncengine-oracle}"
SCHEMA_USER="${SCHEMA_USER:-nas_sim/NasSim_Dev1@FREEPDB1}"

run_sql() {
  local file="$1"
  echo "==> $(basename "$file")"
  docker exec -i "$ORACLE_CONTAINER" sqlplus -s "$SCHEMA_USER" < "$file" 2>&1 | tail -3
}

echo "Waiting for syncengine-oracle healthy..."
deadline=$(( $(date +%s) + 1200 ))
while [ "$(date +%s)" -lt "$deadline" ]; do
  status=$(docker inspect -f '{{.State.Health.Status}}' "$ORACLE_CONTAINER" 2>/dev/null || echo "starting")
  if [ "$status" = "healthy" ]; then break; fi
  sleep 10
done

ORACLE_DIR="$REPO_ROOT/infra/oracle"

run_sql "$ORACLE_DIR/patch-entra-group-role-mapping.sql"

# Create facility_staff_assignment if missing (02c fails on fresh init due to FK order)
docker exec -i "$ORACLE_CONTAINER" sqlplus -s "$SCHEMA_USER" <<'SQL' 2>&1 | tail -5
SET FEEDBACK OFF
DECLARE v_count NUMBER;
BEGIN
  SELECT COUNT(*) INTO v_count FROM user_tables WHERE table_name = 'FACILITY_STAFF_ASSIGNMENT';
  IF v_count = 0 THEN
    EXECUTE IMMEDIATE q'[
      CREATE TABLE facility_staff_assignment (
        assignment_id VARCHAR2(36) NOT NULL,
        facility_id VARCHAR2(36) NOT NULL,
        user_id VARCHAR2(36) NOT NULL,
        role_code VARCHAR2(32) NOT NULL,
        is_lead CHAR(1) DEFAULT 'N' NOT NULL,
        shift_metadata_json CLOB,
        assigned_at TIMESTAMP(6) DEFAULT SYSTIMESTAMP NOT NULL,
        assigned_by_user_id VARCHAR2(36),
        CONSTRAINT pk_facility_staff_assignment PRIMARY KEY (assignment_id),
        CONSTRAINT uq_facility_staff_assignment UNIQUE (facility_id, user_id, role_code),
        CONSTRAINT fk_fac_staff_facility FOREIGN KEY (facility_id) REFERENCES facility (facility_id),
        CONSTRAINT fk_fac_staff_user FOREIGN KEY (user_id) REFERENCES users (user_id),
        CONSTRAINT fk_fac_staff_role FOREIGN KEY (role_code) REFERENCES facility_personnel_role_lkp (role_code),
        CONSTRAINT fk_fac_staff_assigned_by FOREIGN KEY (assigned_by_user_id) REFERENCES users (user_id)
      )]';
    EXECUTE IMMEDIATE 'CREATE INDEX idx_fac_staff_facility ON facility_staff_assignment (facility_id)';
    EXECUTE IMMEDIATE 'CREATE INDEX idx_fac_staff_user ON facility_staff_assignment (user_id)';
    EXECUTE IMMEDIATE 'CREATE INDEX idx_fac_staff_role ON facility_staff_assignment (role_code)';
  END IF;
END;
/
EXIT;
SQL

SEEDS=(
  init/09a_seed_reference.sql
  init/09b_seed_dashboards.sql
  init/09e_seed_eval.sql
  init/09f_seed_clear_operational.sql
  init/100_seed_operational_nas.sql
  init/101_seed_operational_nas_extended.sql
  init/102_seed_operational_nas_deep.sql
  init/103_seed_data_enrichment.sql
  init/104_seed_operational_day.sql
  init/105_seed_ground_operations.sql
  init/106_seed_nas_equipment_full_stack.sql
  init/107_seed_faa_baseline_overlay.sql
  init/108_seed_faa_equipment_overlay.sql
  init/109_seed_faa_taf_ops_overlay.sql
  init/110_seed_faa_notam_wxl_overlay.sql
  init/111_seed_faa_safety_enrichment.sql
  init/112_seed_facility_type_assets.sql
  init/113_seed_facility_staff_and_atct.sql
  init/114_seed_facility_dashboard_panels.sql
  init/115_seed_grid_layout.sql
  init/117_seed_part_logistics.sql
  init/118_seed_manufacturer_dashboard.sql
  init/119_seed_parts_facilities_dashboards.sql
  init/120_seed_simulation_assets_v3.sql
  init/122_layout_overrides_json.sql
  init/124_seed_nas_cascade_schedule.sql
  init/125_seed_adsbx_ops_overlay.sql
  init/126_widen_grid_cell.sql
  init/127_seed_location_aware_logs.sql
)

for seed in "${SEEDS[@]}"; do
  run_sql "$ORACLE_DIR/$seed"
done

echo ""
echo "Seed complete. Verify:"
echo "  curl http://cobec-spark:5000/api/operations/readiness"
echo "  docker exec -i $ORACLE_CONTAINER sqlplus -s $SCHEMA_USER < $ORACLE_DIR/verify-seed-counts.sql"
