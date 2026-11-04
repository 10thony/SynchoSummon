using Microsoft.AspNetCore.SignalR;
using SyncEngine.Abstractions.Telemetry;
using SyncEngine.Server.Telemetry;

namespace SyncEngine.Server.Hubs;

public sealed class SyncHub(ISyncTelemetry telemetry) : Hub
{
    public const string SyncClientsGroup = "sync-clients";

    /// <summary>
    /// SignalR does not support optional parameters or overloads — always pass a client id
    /// (connection id is fine if the caller has nothing better).
    /// </summary>
    public async Task RegisterSyncClient(string clientId)
    {
        var id = string.IsNullOrWhiteSpace(clientId) ? Context.ConnectionId : clientId;
        Context.Items["clientId"] = id;
        await Groups.AddToGroupAsync(Context.ConnectionId, SyncClientsGroup);
        try
        {
            telemetry.Record(new SyncTelemetryEvent
            {
                Kind = SyncTelemetryKind.ClientConnected,
                ClientId = id,
                Direction = "client→server",
                Summary = $"Sync client registered: {id}",
            });
        }
        catch
        {
            // Telemetry must never fail client registration / sync.
        }
    }

    public override Task OnDisconnectedAsync(Exception? exception)
    {
        var id = Context.Items.TryGetValue("clientId", out var value)
            ? value?.ToString()
            : Context.ConnectionId;
        try
        {
            telemetry.Record(new SyncTelemetryEvent
            {
                Kind = SyncTelemetryKind.ClientDisconnected,
                ClientId = id,
                Direction = "client→server",
                Summary = $"Sync client disconnected: {id}",
            });
        }
        catch
        {
            // ignore
        }

        return base.OnDisconnectedAsync(exception);
    }
}
