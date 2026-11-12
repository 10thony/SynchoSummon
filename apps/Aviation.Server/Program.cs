using Aviation.Server.Services;
using Aviation.Shared.Entities;
using SyncEngine.Abstractions.Ledger;
using SyncEngine.Auth;
using SyncEngine.Providers.Oracle;
using SyncEngine.Server.Hosting;
using SyncEngine.Server.Ledger;
using SyncEngine.Abstractions.Offline;

var builder = WebApplication.CreateBuilder(args);

builder.WebHost.ConfigureKestrel(options =>
{
    // Sync push is capped separately; load packages may still be large when EnableLoadApi is on.
    options.Limits.MaxRequestBodySize = builder.Configuration.GetValue("SyncEngine:EnableLoadApi", false)
        ? 512L * 1024 * 1024
        : 2L * 1024 * 1024;
});

builder.Services.Configure<Microsoft.AspNetCore.Http.Features.FormOptions>(options =>
{
    options.MultipartBodyLengthLimit = builder.Configuration.GetValue("SyncEngine:EnableLoadApi", false)
        ? 512L * 1024 * 1024
        : 2L * 1024 * 1024;
});

builder.Services.AddSyncEngineServer();
builder.Services.AddSyncEngineAuth(o =>
{
    o.SigningKey = builder.Configuration["SyncEngine:Auth:SigningKey"]
        ?? "AviationDevSigningKey-ChangeMe-32c!";
    o.Issuer = builder.Configuration["SyncEngine:Auth:Issuer"] ?? "syncengine";
    o.Audience = builder.Configuration["SyncEngine:Auth:Audience"] ?? "syncengine";
});

builder.Services.AddSyncEngineDevClients(clients =>
{
    var section = builder.Configuration.GetSection("SyncEngine:Auth:Clients");
    if (section.Exists() && section.GetChildren().Any())
    {
        foreach (var child in section.GetChildren())
        {
            var id = child["ClientId"];
            var secret = child["ClientSecret"];
            if (string.IsNullOrWhiteSpace(id) || string.IsNullOrWhiteSpace(secret))
            {
                continue;
            }

            clients.Add(id, secret, child["TenantId"] ?? "demo");
        }
    }
    else
    {
        // Development defaults — override via SyncEngine:Auth:Clients / user-secrets.
        clients.Add("maui-dev", "maui-dev-secret", "demo");
        clients.Add("blazor-dev", "blazor-dev-secret", "demo");
        clients.Add("loadgen-dev", "loadgen-dev-secret", "demo");
        clients.Add("e2e-dev", "e2e-dev-secret", "demo");
    }
});

var useInMemory = builder.Configuration.GetValue("SyncEngine:UseInMemoryLedger", true);
if (useInMemory)
{
    // Phone-scale nested sync (~3GiB) exceeds the prior 100k ring and silently shed history.
    var ledgerCapacity = builder.Configuration.GetValue("SyncEngine:InMemoryLedgerCapacity", 1_000_000);
    builder.Services.AddSingleton(new InMemoryChangeLedger(ledgerCapacity));
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
builder.Services.AddSingleton(new SyncPushLimits
{
    MaxBodyBytes = 1024 * 1024,
    MaxChanges = 1000,
    AllowedEntityNames = AviationEntityNames.All.ToHashSet(StringComparer.OrdinalIgnoreCase),
});

builder.Services.AddCors(options =>
{
    options.AddPolicy("AviationDev", policy =>
        policy
            .WithOrigins(
                "http://localhost:5080",
                "http://localhost:5280",
                "http://127.0.0.1:5080",
                "http://127.0.0.1:5280",
                "https://localhost:5081",
                "https://localhost:7280")
            .AllowAnyHeader()
            .AllowAnyMethod()
            .AllowCredentials());
});

var app = builder.Build();

app.UseCors("AviationDev");
app.UseAuthentication();
app.UseAuthorization();
app.UseRateLimiter();
app.UseDefaultFiles();
app.UseStaticFiles();
app.MapSyncEngineAuth();
app.MapSyncEngine();

app.MapGet("/api/facilities", (InMemoryAviationStore store) => Results.Ok(store.ListFacilities()))
    .RequireAuthorization(SyncEngine.Abstractions.Auth.SyncAuthPolicies.SyncClient);
app.MapPost("/api/facilities", async (Facility facility, InMemoryAviationStore store, CancellationToken ct) =>
    Results.Ok(await store.UpsertFacilityAsync(facility, ct)))
    .RequireAuthorization(SyncEngine.Abstractions.Auth.SyncAuthPolicies.SyncClient);

app.MapGet("/api/equipment", (InMemoryAviationStore store) => Results.Ok(store.ListEquipment()))
    .RequireAuthorization(SyncEngine.Abstractions.Auth.SyncAuthPolicies.SyncClient);
app.MapPost("/api/equipment", async (Equipment equipment, InMemoryAviationStore store, CancellationToken ct) =>
    Results.Ok(await store.UpsertEquipmentAsync(equipment, ct)))
    .RequireAuthorization(SyncEngine.Abstractions.Auth.SyncAuthPolicies.SyncClient);

app.MapGet("/api/maintenance-logs", (InMemoryAviationStore store) => Results.Ok(store.ListLogs()))
    .RequireAuthorization(SyncEngine.Abstractions.Auth.SyncAuthPolicies.SyncClient);
app.MapPost("/api/maintenance-logs", async (MaintenanceLog log, InMemoryAviationStore store, CancellationToken ct) =>
    Results.Ok(await store.UpsertLogAsync(log, ct)))
    .RequireAuthorization(SyncEngine.Abstractions.Auth.SyncAuthPolicies.SyncClient);

var enableLoadApi = app.Configuration.GetValue("SyncEngine:EnableLoadApi", app.Environment.IsDevelopment());
if (enableLoadApi)
{
    var load = app.MapGroup("/api/load").RequireAuthorization(SyncEngine.Abstractions.Auth.SyncAuthPolicies.SyncClient);

    load.MapPost("/packages", async (LoadPackageRequest package, LoadPackageService loader, CancellationToken ct) =>
        Results.Ok(await loader.ApplyAsync(package, ct)));

    load.MapGet("/summary", (InMemoryAviationStore store) => Results.Ok(new
    {
        facilities = store.ListFacilities().Count(),
        equipment = store.ListEquipment().Count(),
        maintenanceLogs = store.ListLogs().Count(),
    }));

    load.MapGet("/profiles", (LoadRunService runner) => Results.Ok(runner.DescribeProfiles()));

    load.MapPost("/run", async (HttpContext ctx, LoadRunService runner, string? profile, CancellationToken ct) =>
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

    load.MapPost("/ping", async (LoadRunService runner, CancellationToken ct) =>
        Results.Ok(await runner.PingAsync(ct)));

    load.MapGet("/runs", (LoadRunService runner) => Results.Ok(runner.ListRuns()));

    load.MapGet("/runs/current", (LoadRunService runner) =>
    {
        var current = runner.GetCurrent();
        return current is null ? Results.NoContent() : Results.Ok(current);
    });

    load.MapGet("/runs/{runId}", (string runId, LoadRunService runner) =>
    {
        var report = runner.GetRun(runId);
        return report is null ? Results.NotFound(new { error = $"Run '{runId}' not found." }) : Results.Ok(report);
    });
}

app.MapGet("/", () => Results.Ok(new
{
    service = "Aviation.Server",
    sync = "/sync",
    auth = "/sync/auth/token",
    telemetry = "/telemetry",
    loadEnabled = enableLoadApi,
})).AllowAnonymous();

using (var scope = app.Services.CreateScope())
{
    var store = scope.ServiceProvider.GetRequiredService<InMemoryAviationStore>();
    await store.SeedDemoAsync();
}

app.Run();

public partial class Program;
