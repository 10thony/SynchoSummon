# SyncEngine infrastructure

Local **Oracle Database Free** with the Dio aviation / NAS simulation schema and dummy seed.

Image: [`gvenzl/oracle-free`](https://github.com/gvenzl/oci-oracle-free) (23c slim-faststart via `oracle/Dockerfile`).

## Layout

```text
infra/
├── compose.yaml
├── .env.example          → copy to .env
├── SEED_PACK.md          # upstream pack notes
├── oracle/
│   ├── Dockerfile
│   ├── init/             # first-boot DDL + seeds (alphabetical)
│   ├── patches/          # optional post-init SQL
│   ├── verify/           # row-count checks
│   └── conf/
└── scripts/              # up, down, reset, sql, seed, verify, patch
```

## Quick start

```powershell
cd infra
copy .env.example .env
.\scripts\up.ps1
# wait until healthy (5–15 min on first boot)
.\scripts\verify.ps1
.\scripts\sql.ps1
```

## Connection

| Setting | Default |
|---------|---------|
| Host | `localhost` |
| Port | `1522` |
| Service | `FREEPDB1` |
| User | `nas_sim` |
| Password | `NasSim_Dev1` (see `.env`) |

```
User Id=nas_sim;Password=NasSim_Dev1;Data Source=localhost:1522/FREEPDB1
jdbc:oracle:thin:@localhost:1522/FREEPDB1
```

## Init script bands

| Band | Role |
|------|------|
| `01`–`09`, `08c` | Core schema (lookups → dashboards + staff) |
| `09a` | Reference / lookup seed + `scenario_clock` (MERGE / idempotent) |
| `09b` | Dashboard seed |
| `09c` / `09d` | Perf + eval DDL (promoted out of former seed-band scripts) |
| `09e` | Eval catalog seed |
| `09f` | Clears operational rows before corridor reload (idempotent re-seed) |
| `100`–`106` | Upper Midwest NAS corridor scenario (DSM hub; day from `scenario_clock`) |
| `107`–`111` | FAA overlay seeds |
| `112`–`126` | Facility assets, staffing, parts, sim assets, ADS-B |
| `127` | Location-aware logs (facility / equipment / runway / `location_label`) |

Scripts run **once** on an empty data volume. After changing DDL/seeds:

```powershell
.\scripts\reset.ps1
```

Re-apply data only (existing volume): `.\scripts\seed.ps1`  
Optional patches: `.\scripts\patch.ps1`

## Schema diagram

Open [`docs/schema-erd.html`](docs/schema-erd.html) in a browser for an interactive FK relationship diagram. Source graph: `oracle/schema-graph.json`.

## Location-aware logs

`maintenance_log`, `ground_operation_log`, and `facility_logistics_log` carry optional:

- `facility_id`, `equipment_id`, `runway_id` (FKs)
- `location_label` (section hint: `GS_CABINET`, `GATE_G12`, `BIN_A3`, …)
- `log_entry_type` → `log_entry_type_lkp`

DDL changes require a volume reset (`.\scripts\reset.ps1`). Re-seed alone is not enough after schema changes.

## SyncEngine refinements vs upstream zip

- Renamed `99_seed_reference` → `09a_seed_reference` and `10_seed_dashboards` → `09b_seed_dashboards` so lexical order matches dependency order on first boot.
- Moved `facility_staff_assignment` DDL to `08c_*` (after `users`) — upstream `02c` FKs failed on fresh init.
- Promoted perf/eval DDL to `09c`/`09d`; operational clear + MERGE reference seed for reloadable data.
- Added `scenario_clock` as the single scenario-day anchor (`2026-06-23` UTC by default).
- Location-aware operational logs (`127`) with shared `log_entry_type_lkp`.
- Compose project/container names: `syncengine` / `syncengine-oracle` (avoids clashing with Dio’s `dio-oracle`).
