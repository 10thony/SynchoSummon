using SyncEngine.Abstractions.Client;

namespace Aviation.Blazor.Services;

/// <summary>
/// Blazor host adapter: drives <see cref="ISyncSession"/> and maps snapshots into
/// <see cref="FacilityViewService"/> so the UI shares the core session vocabulary.
/// </summary>
public sealed class AviationSyncHostedService(
    ISyncSession session,
    FacilityViewService viewService,
    ILogger<AviationSyncHostedService> logger) : IHostedService
{
    public Task StartAsync(CancellationToken cancellationToken)
    {
        session.SnapshotChanged += OnSnapshotChanged;
        session.SyncCompleted += OnSyncCompleted;
        OnSnapshotChanged(session.Snapshot);
        return session.StartAsync(cancellationToken);
    }

    public async Task StopAsync(CancellationToken cancellationToken)
    {
        session.SnapshotChanged -= OnSnapshotChanged;
        session.SyncCompleted -= OnSyncCompleted;
        await session.StopAsync(cancellationToken);
    }

    private void OnSnapshotChanged(SyncSessionSnapshot snapshot)
    {
        var (status, message) = Map(snapshot);
        viewService.SetStatus(status, message);
        if (snapshot.Phase is SyncSessionPhase.Degraded && snapshot.LastError is { } ex)
        {
            logger.LogWarning(ex, "Blazor sync session degraded: {Status}", snapshot.DisplayStatus);
        }
    }

    private void OnSyncCompleted() => viewService.MarkAppliedBatch();

    private static (FacilityViewSyncStatus Status, string? Message) Map(SyncSessionSnapshot snapshot)
        => snapshot.Phase switch
        {
            SyncSessionPhase.Stopped or SyncSessionPhase.Stopping or SyncSessionPhase.Connecting
                => (FacilityViewSyncStatus.Initializing, snapshot.DisplayStatus),
            SyncSessionPhase.CatchingUp
                => (FacilityViewSyncStatus.CatchingUp, snapshot.DisplayStatus),
            SyncSessionPhase.Syncing
                => (FacilityViewSyncStatus.Syncing, snapshot.DisplayStatus),
            SyncSessionPhase.Live
                => (FacilityViewSyncStatus.Live, snapshot.DisplayStatus),
            SyncSessionPhase.OfflinePolling
                => (FacilityViewSyncStatus.Offline, snapshot.DisplayStatus),
            SyncSessionPhase.Reconnecting
                => (FacilityViewSyncStatus.Reconnecting, snapshot.DisplayStatus),
            SyncSessionPhase.Degraded
                => (FacilityViewSyncStatus.Error, snapshot.Detail ?? snapshot.LastError?.Message ?? snapshot.DisplayStatus),
            _ => (FacilityViewSyncStatus.Initializing, snapshot.DisplayStatus),
        };
}
