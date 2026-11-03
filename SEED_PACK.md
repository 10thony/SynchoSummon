# Dio aviation dummy seed — infra pack

Drop-in `infra/` for a new project: Oracle Free via Docker + the NAS / aviation schema and dummy seed scripts that power Dio (NasSim).

## Contents

```
infra/
  docker-compose.yml     # gvenzl/oracle-free:23-slim, port 1522
  .env.example           # ORACLE_* defaults (copy to .env)
  README.md              # Seed index / connection details (from Dio)
  oracle/
    init/                # DDL 01–09 + seeds 99–126 (auto-run on first boot)
    verify-seed-counts.sql
    seed-dev-user.sql
    patch-*.sql
  scripts/
    seed-oracle-linux.sh # Optional re-apply helper used on Dio/Spark
```

**Not included:** SoterixAutoGenerator, live `.env`, FAA NASR bulk downloads (overlays `107`–`111` are already committed SQL).

## Quick start

```bash
unzip dio-aviation-seed-infra.zip
cp -R infra /path/to/your-project/
cd /path/to/your-project/infra
cp .env.example .env
docker compose up -d
# First boot: 5–15 min while init scripts create nas_sim + seed
docker compose ps
```

Connection: `localhost:1522/FREEPDB1`, user `nas_sim` / `NasSim_Dev1`.

## What the seeds cover

| Scripts | Role |
|---------|------|
| `01`–`09`, `08b` | Schema (facilities, runways, equipment, flights, weather, auth, NOTAMs, dashboards) |
| `99` | Reference / lookup seed |
| `100`–`106` | Hand-authored Upper Midwest NAS corridor scenario (DSM hub, flights, ground ops, equipment stack) |
| `107`–`111` | FAA overlay seeds (baseline, equipment, TAF ops, NOTAM/WXL, safety) |
| `112`–`126` | Facility assets, staffing, grid layout, parts logistics, sim assets, ADS-B ops, etc. |

Scenario day narrative centers on **23 Jun 2026 UTC** (DSM ILS failure corridor story). See `infra/README.md`.

## Notes for a new project

- Rename `name:` / `container_name` in `docker-compose.yml` if you already run Dio’s stack on the same host.
- Change `ORACLE_PORT` in `.env` if 1522 is taken.
- Init scripts only run on an empty volume; reset with `docker compose down -v && docker compose up -d`.
