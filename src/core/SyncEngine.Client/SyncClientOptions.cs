namespace SyncEngine.Client;

public sealed class SyncClientOptions
{
    public const string SectionName = "SyncEngine:Client";

    public string ServerBaseAddress { get; set; } = "http://localhost:5080";

    public string ClientId { get; set; } = "client";

    public int BatchSize { get; set; } = 500;

    public bool EnableSignalR { get; set; } = true;

    public bool EnableTelemetryReporting { get; set; } = true;

    public string CheckpointScope { get; set; } = "default";
}
