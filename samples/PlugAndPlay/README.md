# Plug-and-play sample

Proves SyncEngine generation without Aviation domain wiring.

## Regenerate

```powershell
dotnet run --project ../../src/autogen/SyncEngine.Generator -- `
  --provider manifest `
  --manifest fixture-manifest.json `
  --out Generated `
  --namespace PlugAndPlay.Generated
```

Live databases:

```powershell
dotnet run --project ../../src/autogen/SyncEngine.Generator -- `
  --provider oracle|sqlserver|postgres `
  --connection "<cs>" `
  --schema <owner> `
  --out Generated
```

## Run host

```powershell
dotnet run --project PlugAndPlay.Host
```

Host wires:

- `AddSyncEngineServer` + `AddGeneratedSyncServer`
- `MapSyncEngine` + `MapGeneratedSyncRest`
- `AddSyncEngineClient` + `AddGeneratedSyncClient` (in-proc demo client registration)
