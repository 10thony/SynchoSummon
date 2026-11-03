using Microsoft.AspNetCore.SignalR;

namespace SyncEngine.Server.Hubs;

public sealed class TelemetryHub : Hub
{
    public const string ViewersGroup = "telemetry-viewers";

    public Task SubscribeTelemetry()
    {
        return Groups.AddToGroupAsync(Context.ConnectionId, ViewersGroup);
    }
}
