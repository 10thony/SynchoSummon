namespace SyncEngine.Abstractions.Offline;

/// <summary>Limits applied to client push operations.</summary>
public class SyncPushLimits
{
    /// <summary>Default limits suitable for most deployments.</summary>
    public static SyncPushLimits Default { get; } = new();

    /// <summary>Maximum total body size in bytes.</summary>
    public int MaxBodyBytes { get; init; } = 1024 * 1024;

    /// <summary>Maximum number of changes per push.</summary>
    public int MaxChanges { get; init; } = 1000;

    /// <summary>Maximum key size in bytes per change.</summary>
    public int MaxKeyBytes { get; init; } = 16 * 1024;

    /// <summary>Maximum payload size in bytes per change.</summary>
    public int MaxPayloadBytes { get; init; } = 512 * 1024;

    /// <summary>If non-null, only these entity names are accepted; all others are rejected.</summary>
    public IReadOnlySet<string>? AllowedEntityNames { get; init; }
}
