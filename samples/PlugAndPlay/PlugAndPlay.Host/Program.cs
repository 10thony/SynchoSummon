using PlugAndPlay.Generated.Client;
using PlugAndPlay.Generated.Server;
using SyncEngine.Abstractions.Ledger;
using SyncEngine.Auth;
using SyncEngine.Client;
using SyncEngine.Server.Hosting;
using SyncEngine.Server.Ledger;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddSyncEngineServer();
builder.Services.AddSyncEngineAuth(o =>
{
    o.SigningKey = builder.Configuration["SyncEngine:Auth:SigningKey"]
        ?? "PlugAndPlayDevSigningKey-ChangeMe-32c!";
    o.Issuer = "syncengine";
    o.Audience = "syncengine";
});
builder.Services.AddSyncEngineDevClients(clients =>
{
    clients.Add("sample-dev", "sample-dev-secret", "demo");
});

builder.Services.AddSingleton<InMemoryChangeLedger>();
builder.Services.AddSingleton<IChangeLedger>(sp => sp.GetRequiredService<InMemoryChangeLedger>());
builder.Services.AddGeneratedSyncServer();

builder.Services.AddSyncEngineClient(options =>
{
    options.ServerBaseAddress = builder.Configuration["SyncEngine:ServerBaseAddress"] ?? "http://localhost:5090";
    options.ClientId = "sample-dev";
    options.EnableSignalR = true;
    options.EnableDeltaStreaming = true;
    options.AllowInsecureHttp = true;
});
builder.Services.AddSyncEngineClientSession(runAsHostedService: true);
builder.Services.AddSyncEngineClientCredentials(o =>
{
    o.ClientId = "sample-dev";
    o.ClientSecret = "sample-dev-secret";
});
builder.Services.AddGeneratedSyncClient();

var app = builder.Build();

app.UseAuthentication();
app.UseAuthorization();
app.UseRateLimiter();
app.MapSyncEngineAuth();
app.MapSyncEngine();
app.MapGeneratedSyncRest();

app.MapGet("/", () => Results.Ok(new
{
    service = "PlugAndPlay.Host",
    sync = new[] { "/sync/version", "/sync/deltas", "/sync/push", "/sync/hub" },
    rest = new[] { "/api/facilities", "/api/equipments" },
    note = "Generated via syncengine-gen --provider manifest",
}));

app.Run();

public partial class Program;
