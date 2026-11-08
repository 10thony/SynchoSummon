namespace SyncEngine.Server.Hosting;

/// <summary>
/// Marker registered by SyncEngine.Auth when authenticated clients are required.
/// </summary>
public sealed class SyncAuthFeature
{
    public bool RequireAuthenticatedClients { get; init; } = true;
}
