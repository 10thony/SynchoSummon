using Aviation.Server.Services;
using Aviation.Shared.Entities;
using SyncEngine.Abstractions.Ledger;
using SyncEngine.Providers.Oracle;
using SyncEngine.Server.Hosting;
using SyncEngine.Server.Ledger;
using SyncEngine.Server.Offline;

var builder = WebApplication.CreateBuilder(args);

builder.WebHost.ConfigureKestrel(options =>
{
    // Load packages intentionally send fat MemoryPack-bound JSON payloads.
    options.Limits.MaxRequestBodySize = 512L * 1024 * 1024; // 512 MB
});

builder.Services.Configure<Microsoft.AspNetCore.Http.Features.FormOptions>(options =>
{
    options.MultipartBodyLengthLimit = 512L * 1024 * 1024;
});

builder.Services.AddSyncEngineServer();

var useInMemory = builder.Configuration.GetValue("SyncEngine:UseInMemoryLedger", true);
if (useInMemory)
{
    builder.Services.AddSingleton<InMemoryChangeLedger>();
    builder.Services.AddSingleton<IChangeLedger>(sp => sp.GetRequiredService<InMemoryChangeLedger>());
}
else
{
    builder.Services.Configure<OracleOptions>(builder.Configuration.GetSection(OracleOptions.SectionName));
    builder.Services.AddSyncEngineOracle();
}

builder.Services.AddSingleton<InMemoryAviationStore>();
builder.Services.AddSingleton<LoadPackageService>();
builder.Services.AddSingleton<LoadRunService>();
builder.Services.AddSingleton<SyncEngine.Server.Telemetry.ITelemetryListener>(sp =>
    sp.GetRequiredService<LoadRunService>());
builder.Services.AddSingleton<IOfflineEntityApplicator, OfflineAviationApplicator>();
builder.Services.AddCors(options =>
{
    options.AddPolicy("AviationDev", policy =>
        policy.AllowAnyHeader().AllowAnyMethod().AllowCredentials().SetIsOriginAllowed(_ => true));
});

var app = builder.Build();

app.UseCors("AviationDev");
app.UseDefaultFiles();
app.UseStaticFiles();
app.MapSyncEngine();

app.MapGet("/api/facilities", (InMemoryAviationStore store) => Results.Ok(store.ListFacilities()));
app.MapPost("/api/facilities", async (Facility facility, InMemoryAviationStore store, CancellationToken ct) =>
    Results.Ok(await store.UpsertFacilityAsync(facility, ct)));

app.MapGet("/api/equipment", (InMemoryAviationStore store) => Results.Ok(store.ListEquipment()));
app.MapPost("/api/equipment", async (Equipment equipment, InMemoryAviationStore store, CancellationToken ct) =>
    Results.Ok(await store.UpsertEquipmentAsync(equipment, ct)));

app.MapGet("/api/maintenance-logs", (InMemoryAviationStore store) => Results.Ok(store.ListLogs()));
app.MapPost("/api/maintenance-logs", async (MaintenanceLog log, InMemoryAviationStore store, CancellationToken ct) =>
    Results.Ok(await store.UpsertLogAsync(log, ct)));

app.MapPost("/api/load/packages", async (LoadPackageRequest package, LoadPackageService loader, CancellationToken ct) =>
    Results.Ok(await loader.ApplyAsync(package, ct)));

app.MapGet("/api/load/summary", (InMemoryAviationStore store) => Results.Ok(new
{
    facilities = store.ListFacilities().Count(),
    equipment = store.ListEquipment().Count(),
    maintenanceLogs = store.ListLogs().Count(),
}));

app.MapGet("/api/load/profiles", (LoadRunService runner) => Results.Ok(runner.DescribeProfiles()));

app.MapPost("/api/load/run", async (HttpContext ctx, LoadRunService runner, string? profile, CancellationToken ct) =>
{
    var resolved = profile;
    if (string.IsNullOrWhiteSpace(resolved)
        && (ctx.Request.ContentLength ?? 0) > 0
        && ctx.Request.HasJsonContentType())
    {
        var body = await ctx.Request.ReadFromJsonAsync<LoadRunRequest>(ct);
        resolved = body?.Profile;
    }

    resolved = string.IsNullOrWhiteSpace(resolved) ? "smoke" : resolved;

    try
    {
        var result = await runner.RunAsync(resolved, ct);
        return Results.Ok(result);
    }
    catch (ArgumentOutOfRangeException ex)
    {
        return Results.BadRequest(new { error = ex.Message });
    }
    catch (InvalidOperationException ex)
    {
        return Results.Conflict(new { error = ex.Message });
    }
});

app.MapPost("/api/load/ping", async (LoadRunService runner, CancellationToken ct) =>
    Results.Ok(await runner.PingAsync(ct)));

app.MapGet("/api/load/runs", (LoadRunService runner) => Results.Ok(runner.ListRuns()));

app.MapGet("/api/load/runs/current", (LoadRunService runner) =>
{
    var current = runner.GetCurrent();
    return current is null ? Results.NoContent() : Results.Ok(current);
});

app.MapGet("/api/load/runs/{runId}", (string runId, LoadRunService runner) =>
{
    var report = runner.GetRun(runId);
    return report is null ? Results.NotFound(new { error = $"Run '{runId}' not found." }) : Results.Ok(report);
});

app.MapGet("/", () => Results.Ok(new
{
    service = "Aviation.Server",
    sync = "/sync",
    telemetry = "/telemetry",
    load = new
    {
        packages = "/api/load/packages",
        run = "/api/load/run?profile=smoke|hard|crush",
        profiles = "/api/load/profiles",
        ping = "/api/load/ping",
        summary = "/api/load/summary",
        runs = "/api/load/runs",
        currentRun = "/api/load/runs/current",
        runReport = "/api/load/runs/{runId}",
    },
}));

using (var scope = app.Services.CreateScope())
{
    var store = scope.ServiceProvider.GetRequiredService<InMemoryAviationStore>();
    await store.SeedDemoAsync();
}

app.Run();

public partial class Program;
