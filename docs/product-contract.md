# SyncEngine product contract

## What SyncEngine is

A plug-and-play .NET sync engine that moves org data to reactive clients using:

1. **HTTP delta catch-up** — `GET /sync/deltas?since=&limit=` (MemoryPack `DeltaBatch`)
2. **SignalR streamed deltas** — hub event `SyncDelta` (MemoryPack-encoded `DeltaBatch` bytes)
3. **Offline push** — `POST /sync/push` (MemoryPack `DeltaBatch`, server-wins)
4. **Programmatic schema generation** — `syncengine-gen` reads any supported database and emits server + client plug-in code (deterministic; never LLM)

Traditional REST CRUD is **host-owned** or **generator-emitted** beside the sync protocol (`MapGeneratedSyncRest`), not a substitute for the delta ledger.

## Protocol

| Surface | Role |
|---|---|
| `GET /sync/version` | Current ledger tip |
| `GET /sync/deltas` | Catch-up / cold start / reconnect |
| `POST /sync/push` | Client outbox → server ledger |
| `POST /sync/auth/token` | Client-credentials token (first-party auth) |
| Hub `/sync/hub` | Realtime channel |
| Hub `SyncDelta` | Live MemoryPack `DeltaBatch` bytes after coalesce |
| Hub `SyncWake` | Lightweight tip notification (legacy / non-streaming clients) |

### Streaming rules

- Server coalesces mutations (~25ms), loads the new ledger window since the last streamed version, and pushes `SyncDelta`.
- On process start the streamer seeds its high-water mark to the current ledger tip (no history dump).
- Clients apply when `checkpoint >= FromVersion` and `ToVersion > checkpoint` (idempotent).
- If `FromVersion > checkpoint` (gap), client HTTP-pulls to tip, then resumes streaming.
- On SignalR reconnect, client HTTP-pulls once, then re-registers.

### Content type

Sync payloads use `application/x-memorypack`. REST CRUD from the generator uses JSON.

## Generator contract

```text
syncengine-gen
  --provider oracle|sqlserver|postgres|manifest
  --connection <cs>          # or SYNCENGINE_CONNECTION
  --manifest <path>          # provider=manifest
  --schema <name>
  --include / --exclude
  --out <dir>
  --namespace <ns>
```

Emits under `--out`:

| Artifact | Purpose |
|---|---|
| `manifest.json` | Stable IR |
| `EntityNames.cs` | Entity constants |
| `Models/*.cs` | MemoryPack entities + keys |
| `Server/GeneratedEntityStore.cs` | Org projection + ledger writes |
| `Server/GeneratedOfflineApplicator.cs` | Offline push apply |
| `Server/GeneratedRestEndpoints.cs` | `MapGeneratedSyncRest` |
| `Server/GeneratedSyncServerExtensions.cs` | `AddGeneratedSyncServer` |
| `Client/GeneratedSyncClientExtensions.cs` | `AddGeneratedSyncClient` / Sqlite |
| `*.csproj` | Compilable package |

Adopter wiring:

```csharp
builder.Services.AddSyncEngineServer();
builder.Services.AddGeneratedSyncServer();
app.MapSyncEngine();
app.MapGeneratedSyncRest();

builder.Services.AddSyncEngineClient(...);
builder.Services.AddSyncEngineClientSession(runAsHostedService: true); // ISyncSession lifecycle
builder.Services.AddGeneratedSyncClient();
```

Client session status lives on `ISyncSession` / `SyncSessionSnapshot` (not free-form host strings). UI apps may keep a thin adapter and call `AddSyncEngineClientSession()` without `runAsHostedService`, then start/stop the session themselves.

Shared `SyncHub` is infrastructure — generation registers against it; it does not emit per-entity hubs.

## Engine vs Aviation demo

| Path | Role |
|---|---|
| `src/core/*` | Reusable engine |
| `src/autogen/SyncEngine.Generator` | Schema → code CLI |
| `samples/PlugAndPlay` | Minimal generated adopter proof |
| `apps/Aviation.*` | Domain demo (NAS / facilities) |
| `infra/` | Aviation Oracle seed (not required for the engine) |

## Auth

Production hosts should call `AddSyncEngineAuth` (or WorkOS). Lab-only anonymous access: `AddSyncEngineAnonymousAccess()`.

## Phone / org-scale sync

Field clients (MAUI phone) are expected to sync a tenant-relevant org slice that can approach **~3 GiB**, including nested proprietary payloads.

| Concern | Contract |
|---|---|
| Bulk / cold start | HTTP `GET /sync/deltas` paging (`BatchSize`, `MaxResponseBytes` default 64 MiB/page) |
| Live updates | SignalR `SyncDelta` (hub max message size 64 MiB) |
| Integrity | Payload bytes are authoritative; clients must converge to identical SHA-256 catalogs |
| Nested docs | App payloads may embed MemoryPack graphs (e.g. site→system→component→calibration + binary annex) |

Soak test: `PhoneOrgSyncIntegrityTests` — scale with `SYNCENGINE_PHONE_SYNC_TARGET_MB` (default 48 in CI; `3072` ≈ 3 GiB).
