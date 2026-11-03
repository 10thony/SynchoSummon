using Microsoft.AspNetCore.SignalR;
using SyncEngine.Abstractions.Telemetry;
using SyncEngine.Server.Telemetry;

namespace SyncEngine.Server.Hubs;

public sealed class SyncHub(ISyncTelemetry telemetry) : Hub
{
    public const string SyncClientsGroup = "sync-clients";

    public async Task RegisterSyncClient(string? clientId = null)
    {
        var id = string.IsNullOrWhiteSpace(clientId) ? Context.ConnectionId : clientId;
        Context.Items["clientId"] = id;
        await Groups.AddToGroupAsync(Context.ConnectionId, SyncClientsGroup);
        telemetry.Record(new SyncTelemetryEvent
        {
            Kind = SyncTelemetryKind.ClientConnected,
            ClientId = id,
            Direction = "client→server",
            Summary = $"Sync client registered: {id}",
        });
    }

    public override Task OnDisconnectedAsync(Exception? exception)
    {
        var id = Context.Items.TryGetValue("clientId", out var value)
            ? value?.ToString()
            : Context.ConnectionId;
        telemetry.Record(new SyncTelemetryEvent
        {
            Kind = SyncTelemetryKind.ClientDisconnected,
            ClientId = id,
            Direction = "client→server",
            Summary = $"Sync client disconnected: {id}",
        });
        return base.OnDisconnectedAsync(exception);
    }
}
