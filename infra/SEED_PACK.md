# Dio aviation dummy seed — infra pack

Drop-in Oracle Free + NAS / aviation schema and dummy seed scripts (from Dio / NasSim).

## What the seeds cover

| Scripts | Role |
|---------|------|
| `01`–`09`, `08b`, `08c` | Schema (facilities, runways, equipment, flights, weather, auth, NOTAMs, dashboards, staff) |
| `09a` | Reference / lookup seed (renamed from upstream `99` for lexical order) |
| `09b` | Dashboard seed (renamed from upstream `10`) |
| `100`–`106` | Hand-authored Upper Midwest NAS corridor scenario (DSM hub, flights, ground ops, equipment stack) |
| `107`–`111` | FAA overlay seeds (baseline, equipment, TAF ops, NOTAM/WXL, safety) |
| `112`–`126` | Facility assets, staffing, grid layout, parts logistics, sim assets, ADS-B ops, etc. |

Scenario day narrative centers on **23 Jun 2026 UTC** (DSM ILS failure corridor story).

**Not included upstream:** SoterixAutoGenerator, live `.env`, FAA NASR bulk downloads (overlays `107`–`111` are committed SQL).
