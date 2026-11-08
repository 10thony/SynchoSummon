# SyncEngine

Plug-and-play .NET 10 sync engine: **HTTP MemoryPack delta catch-up** plus **SignalR streamed deltas**, with a deterministic schema generator for server + client plug-ins.

See [docs/product-contract.md](docs/product-contract.md) for the wire protocol and generator contract.

## Layout

```text
src/core/       Runtime packages (Abstractions, Auth, Auth.WorkOS, Server, Client, Client.Sqlite, Providers.Oracle)
src/autogen/    Schema generator CLI (syncengine-gen) — oracle | sqlserver | postgres | manifest
apps/           Aviation demo (Server, Maui, Blazor, Shared)
samples/        PlugAndPlay generated adopter proof
benchmarks/     BenchmarkDotNet gates
tests/          Correctness suite
infra/          Local Oracle Free aviation seed (demo only)
docs/           Product contract
```

## Quick adopter path (generated)

```powershell
# From a DB or a fixture manifest:
dotnet run --project src/autogen/SyncEngine.Generator -- `
  --provider manifest `
  --manifest samples/PlugAndPlay/fixture-manifest.json `
  --out samples/PlugAndPlay/Generated `
  --namespace PlugAndPlay.Generated

dotnet run --project samples/PlugAndPlay/PlugAndPlay.Host
```

Host pattern:

```csharp
builder.Services.AddSyncEngineServer();
builder.Services.AddGeneratedSyncServer();
app.MapSyncEngine();
app.MapGeneratedSyncRest();

builder.Services.AddSyncEngineClient(...);
builder.Services.AddSyncEngineClientSession(runAsHostedService: true);
builder.Services.AddGeneratedSyncClient();
```

Live providers: `--provider oracle|sqlserver|postgres --connection <cs> --schema <name>`.

## Auth (plug-and-play)

```csharp
builder.Services.AddSyncEngineServer();
builder.Services.AddSyncEngineAuth();           // first-party JWT + /sync/auth/token
// or: builder.Services.AddSyncEngineWorkOsAuth(...);

builder.Services.AddSyncEngineClientCredentials(o =>
{
    o.ClientId = "maui-dev";
    o.ClientSecret = "...";
});
```

## Aviation demo

```powershell
# Terminal 1 — sync server (in-memory ledger by default; auth required)
dotnet run --project apps/Aviation.Server

# Terminal 2 — Blazor client
dotnet run --project apps/Aviation.Blazor

# Terminal 3 — MAUI (Windows)
dotnet build apps/Aviation.Maui -f net10.0-windows10.0.19041.0
dotnet run --project apps/Aviation.Maui -f net10.0-windows10.0.19041.0
```

Add a facility in either client; the other updates after the SignalR **SyncDelta** stream (HTTP pull remains for catch-up).

Aviation demo credentials (`maui-dev`, `blazor-dev`, `e2e-dev`, `loadgen-dev`) live in `apps/Aviation.Server/appsettings.json`. Override via user-secrets beyond local demos.

## Benchmarks / tests

```powershell
dotnet test tests/SyncEngine.Tests
dotnet run --project benchmarks/SyncEngine.Benchmarks -c Release -- --gates
```
