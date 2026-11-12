using PlugAndPlay.Generated.Client;
using PlugAndPlay.Generated.Server;
using SyncEngine.Auth;
using SyncEngine.Client;
using SyncEngine.Server.Hosting;

var builder = WebApplication.CreateBuilder(args);

// Server — InMemoryChangeLedger is auto-registered by AddSyncEngineServer (TryAdd).
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
builder.Services.AddGeneratedSyncServer();

// Client — builder pattern wires session + credentials.
builder.Services.AddSyncEngineClient(options =>
{
    options.ServerBaseAddress = builder.Configuration["SyncEngine:ServerBaseAddress"] ?? "http://localhost:5090";
    options.ClientId = "sample-dev";
    options.EnableSignalR = true;
    options.EnableDeltaStreaming = true;
    options.AllowInsecureHttp = true;
})
    .WithSession(runAsHostedService: true)
    .WithCredentials(o =>
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
