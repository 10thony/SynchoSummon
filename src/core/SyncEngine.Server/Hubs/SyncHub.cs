using Microsoft.AspNetCore.SignalR;
using SyncEngine.Abstractions.Auth;
using SyncEngine.Abstractions.Telemetry;
using SyncEngine.Server.Telemetry;

namespace SyncEngine.Server.Hubs;

public sealed class SyncHub(ISyncTelemetry telemetry, ISyncAuthenticator authenticator) : Hub
{
    public const string SyncClientsGroup = "sync-clients";

    public static string TenantGroup(string tenantId) => $"sync-clients:{tenantId}";

    /// <summary>
    /// Registers the connection into the sync wake group. Client id comes from the
    /// authenticated principal when present; the parameter is ignored for identity.
    /// </summary>
    public async Task RegisterSyncClient(string clientId)
    {
        var principal = authenticator.GetPrincipal(Context.User);
        var id = principal.IsAuthenticated
            ? principal.ClientId
            : string.IsNullOrWhiteSpace(clientId) ? Context.ConnectionId : clientId;

        Context.Items["clientId"] = id;
        Context.Items["tenantId"] = principal.TenantId;

        await Groups.AddToGroupAsync(Context.ConnectionId, SyncClientsGroup);
        if (!string.IsNullOrWhiteSpace(principal.TenantId))
        {
            await Groups.AddToGroupAsync(Context.ConnectionId, TenantGroup(principal.TenantId));
        }

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
