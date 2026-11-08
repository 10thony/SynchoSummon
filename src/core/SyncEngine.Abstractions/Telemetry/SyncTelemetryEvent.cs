namespace SyncEngine.Abstractions.Telemetry;

public enum SyncTelemetryKind
{
    Write = 1,
    Wake = 2,
    DeltaPull = 3,
    OfflinePush = 4,
    ClientApply = 5,
    ClientConnected = 6,
    ClientDisconnected = 7,
    DeltaStream = 8,
}

public sealed class SyncTelemetryEvent
{
    public Guid Id { get; init; } = Guid.NewGuid();

    public DateTimeOffset TimestampUtc { get; init; } = DateTimeOffset.UtcNow;

    public SyncTelemetryKind Kind { get; init; }

    public string? ClientId { get; init; }

    public string? Direction { get; init; }

    public string? EntityName { get; init; }

    public string[]? EntityNames { get; init; }

    public long? FromVersion { get; init; }

    public long? ToVersion { get; init; }

    public int? ChangeCount { get; init; }

    public long? Bytes { get; init; }

    public double? LatencyMs { get; init; }

    public string? Summary { get; init; }

    public string? PayloadPreview { get; init; }

    public string? CorrelationId { get; init; }
}

public sealed class ClientTelemetryReport
{
    public string ClientId { get; set; } = "unknown";

    public SyncTelemetryKind Kind { get; set; } = SyncTelemetryKind.ClientApply;

    public string? EntityName { get; set; }

    public string[]? EntityNames { get; set; }

    public long? FromVersion { get; set; }

    public long? ToVersion { get; set; }

    public int? ChangeCount { get; set; }

    public long? Bytes { get; set; }

    public double? LatencyMs { get; set; }

    public string? Summary { get; set; }

    public string? PayloadPreview { get; set; }

    public string? CorrelationId { get; set; }
}

public static class SyncTelemetryRoutes
{
    public const string Events = "/sync/telemetry/events";
    public const string Report = "/sync/telemetry/report";
    public const string Hub = "/sync/telemetry/hub";
    public const string Stats = "/sync/telemetry/stats";
    public const string Page = "/telemetry";
}
