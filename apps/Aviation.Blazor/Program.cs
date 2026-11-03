using Aviation.Blazor.Components;
using Aviation.Blazor.Services;
using Aviation.Shared.Entities;
using SyncEngine.Abstractions.Client;
using SyncEngine.Client;

var builder = WebApplication.CreateBuilder(args);
builder.Environment.EnvironmentName = Environments.Development;

builder.Services.AddRazorComponents()
    .AddInteractiveServerComponents()
    .AddCircuitOptions(options =>
    {
        // Keep more buffered render batches so bursty sync-driven re-renders (debounced
        // in FacilityViewService) do not trip the circuit into a disconnected state
        // during long catch-up pulls.
        options.MaxBufferedUnacknowledgedRenderBatches = 20;
        options.DetailedErrors = builder.Environment.IsDevelopment();
        options.DisconnectedCircuitRetentionPeriod = TimeSpan.FromMinutes(3);
    });

builder.Services.AddHttpClient();
builder.Services.AddSyncEngineClient(options =>
{
    options.ServerBaseAddress = builder.Configuration["SyncEngine:ServerBaseAddress"] ?? "http://localhost:5080";
    options.ClientId = "blazor";
    options.EnableSignalR = true;
    options.EnableTelemetryReporting = true;
});

foreach (var entity in AviationEntityNames.All)
{
    var name = entity;
    builder.Services.AddSingleton<IEntityDeltaHandler>(sp =>
        new InMemoryEntityDeltaHandler(name, sp.GetRequiredService<InMemoryEntityStore>()));
}

builder.Services.AddSingleton<AviationSyncHostedService>();
builder.Services.AddHostedService(sp => sp.GetRequiredService<AviationSyncHostedService>());
builder.Services.AddSingleton<FacilityViewService>();

var app = builder.Build();

if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Error", createScopeForErrors: true);
    app.UseHsts();
}

app.UseStatusCodePagesWithReExecute("/not-found", createScopeForStatusCodePages: true);
app.UseAntiforgery();
app.MapStaticAssets();
app.MapRazorComponents<App>()
    .AddInteractiveServerRenderMode();

app.Run();
