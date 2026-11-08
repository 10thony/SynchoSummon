namespace SyncEngine.Abstractions.Client;

/// <summary>
/// User-facing sync session phase. Prefer this over free-form status strings.
/// </summary>
public enum SyncSessionPhase
{
    Stopped = 0,
    Connecting = 1,
    CatchingUp = 2,
    Syncing = 3,
    Live = 4,
    OfflinePolling = 5,
    Reconnecting = 6,
    Degraded = 7,
    Stopping = 8,
}

/// <summary>SignalR hub link lifecycle for <see cref="ISyncWakeListener"/>.</summary>
public enum SyncHubLinkState
{
    Disabled = 0,
    Disconnected = 1,
    Connecting = 2,
    Connected = 3,
    Reconnecting = 4,
    Failed = 5,
}

/// <summary>Effective client transport mode derived from options flags.</summary>
public enum SyncTransportMode
{
    HttpPollOnly = 0,
    WakeAndPull = 1,
    StreamAndWake = 2,
}

/// <summary>Internal apply/catch-up phase inside <c>SyncPullService</c>.</summary>
public enum SyncApplyPhase
{
    Idle = 0,
    ApplyingStream = 1,
    HttpCatchUp = 2,
    GapRepair = 3,
}

/// <summary>Credential cache lifecycle for token providers.</summary>
public enum SyncCredentialState
{
    Unconfigured = 0,
    Valid = 1,
    Refreshing = 2,
    Expired = 3,
    Failed = 4,
}

/// <summary>Client outbox flush lifecycle.</summary>
public enum SyncOutboxPhase
{
    Empty = 0,
    Pending = 1,
    Flushing = 2,
    Failed = 3,
}

/// <summary>Immutable snapshot of the client sync session for UI, logs, and agents.</summary>
public sealed record SyncSessionSnapshot(
    SyncSessionPhase Phase,
    SyncHubLinkState Hub,
    SyncTransportMode TransportMode,
    long? Checkpoint,
    string DisplayStatus,
    string? Detail = null,
    Exception? LastError = null,
    DateTimeOffset? LastSuccessUtc = null);

/// <summary>
/// Explicit sync session state machine. Adopter hosts should bind UI to
/// <see cref="Snapshot"/> / <see cref="SnapshotChanged"/> instead of inventing status strings.
/// </summary>
public interface ISyncSession
{
    SyncSessionSnapshot Snapshot { get; }

    event Action<SyncSessionSnapshot>? SnapshotChanged;

    /// <summary>Raised after a successful pull/apply that advanced or confirmed the checkpoint.</summary>
    event Action? SyncCompleted;

    /// <summary>Raised when a background sync operation throws. Null means the error cleared.</summary>
    event Action<Exception?>? ErrorRaised;

    Task StartAsync(CancellationToken cancellationToken = default);

    Task StopAsync(CancellationToken cancellationToken = default);

    Task TriggerPullAsync(CancellationToken cancellationToken = default);
}

/// <summary>Formats <see cref="SyncSessionSnapshot"/> for human-facing status labels.</summary>
public static class SyncSessionDisplay
{
    public static string Format(SyncSessionPhase phase, long? checkpoint = null, string? detail = null)
        => phase switch
        {
            SyncSessionPhase.Stopped => "Stopped",
            SyncSessionPhase.Connecting => "Connecting…",
            SyncSessionPhase.CatchingUp => "Catching up…",
            SyncSessionPhase.Syncing => "Syncing…",
            SyncSessionPhase.Live when checkpoint is { } v => $"Connected (v{v})",
            SyncSessionPhase.Live => "Connected",
            SyncSessionPhase.OfflinePolling => "Offline (polling)",
            SyncSessionPhase.Reconnecting => "Reconnecting…",
            SyncSessionPhase.Degraded => string.IsNullOrWhiteSpace(detail)
                ? "Sync error – retrying"
                : detail!,
            SyncSessionPhase.Stopping => "Stopping…",
            _ => phase.ToString(),
        };

    public static SyncSessionSnapshot Create(
        SyncSessionPhase phase,
        SyncHubLinkState hub,
        SyncTransportMode transportMode,
        long? checkpoint = null,
        string? detail = null,
        Exception? lastError = null,
        DateTimeOffset? lastSuccessUtc = null)
        => new(
            phase,
            hub,
            transportMode,
            checkpoint,
            Format(phase, checkpoint, detail),
            detail,
            lastError,
            lastSuccessUtc);
}
