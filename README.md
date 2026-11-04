# SyncEngine

Memory/Span-first, opinionated sync framework for .NET 10. Moves data from an org database (Oracle first) to reactive clients (MAUI + SQLite, Blazor) via coalesced SignalR wakes and MemoryPack delta batches.

## Layout

```text
src/core/       Runtime packages (Abstractions, Server, Client, Client.Sqlite, Providers.Oracle)
src/autogen/    Schema generator CLI (syncengine-gen)
apps/           Aviation.Server, Aviation.Maui, Aviation.Blazor, Aviation.Shared
benchmarks/     BenchmarkDotNet gates
tests/          Correctness suite
infra/          Local Oracle Free aviation seed
```

## Quick demo

```powershell
# Terminal 1 — sync server (in-memory ledger by default)
dotnet run --project apps/Aviation.Server

# Terminal 2 — Blazor client
dotnet run --project apps/Aviation.Blazor

# Terminal 3 — MAUI (Windows)
dotnet build apps/Aviation.Maui -f net10.0-windows10.0.19041.0
dotnet run --project apps/Aviation.Maui -f net10.0-windows10.0.19041.0
```

Add a facility in either client; the other updates after the SignalR wake + delta pull.

## Benchmarks / tests

Speed gates and BenchmarkDotNet runs use **production-shaped** Facility→Equipment→MaintenanceLog graphs (related entities + churn deletes), not Facility-only toys or megabyte pad blobs. Demo seed loads a multi-site corridor stack via `CorridorSyncSeed`.

```powershell
dotnet test tests/SyncEngine.Tests
dotnet run --project benchmarks/SyncEngine.Benchmarks -c Release -- --gates
dotnet run --project benchmarks/SyncEngine.Benchmarks -c Release
```

## Generator

```powershell
dotnet run --project src/autogen/SyncEngine.Generator -- --dry-run
```
