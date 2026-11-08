namespace SyncEngine.Abstractions;

public static class SyncContentTypes
{
    public const string MemoryPack = "application/x-memorypack";
}

public static class SyncRoutes
{
    public const string Version = "/sync/version";
    public const string Deltas = "/sync/deltas";
    public const string Hub = "/sync/hub";
    public const string Push = "/sync/push";
    public const string Token = "/sync/auth/token";
}

/// <summary>SignalR hub method / event names for the sync protocol.</summary>
public static class SyncHubEvents
{
    public const string RegisterSyncClient = "RegisterSyncClient";
    public const string SyncWake = "SyncWake";
    /// <summary>MemoryPack-encoded <c>DeltaBatch</c> bytes pushed after coalesce.</summary>
    public const string SyncDelta = "SyncDelta";
}
