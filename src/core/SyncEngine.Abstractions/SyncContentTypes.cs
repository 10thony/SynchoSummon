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
}
