using SyncEngine.Abstractions.Client;
using SyncEngine.Client;

namespace Aviation.Maui.Services;

/// <summary>
/// MAUI-facing facade over <see cref="ISyncSession"/>. Keeps the existing string/event API
/// so view models stay stable while the real state machine lives in core.
/// </summary>
public sealed class MauiSyncBootstrapper(ISyncSession session)
{
    private readonly ISyncSession _session = session;
    private int _wired;

    /// <summary>Raised on sync lifecycle changes. Subscribers must marshal to the UI thread themselves.</summary>
    public event Action<string>? StatusChanged;

    /// <summary>Raised when a background sync operation throws. Null means the error cleared.</summary>
    public event Action<Exception?>? ErrorRaised;

    /// <summary>Raised after each successful pull (so view models can refresh their timestamps).</summary>
    public event Action? SyncCompleted;

    /// <summary>
    /// Starts the sync pipeline. Returns immediately; the heavy work runs on a background task
    /// so <c>OnAppearing</c> is never blocked by SignalR negotiation or a large catch-up pull.
    /// </summary>
    public Task StartAsync()
    {
        EnsureWired();
        return _session.StartAsync();
    }

    public Task StopAsync() => _session.StopAsync();

    /// <summary>
    /// Forces an immediate pull. Safe to call from the UI thread; errors are reported via <see cref="ErrorRaised"/>.
    /// </summary>
    public Task TriggerPullAsync(CancellationToken cancellationToken = default)
        => _session.TriggerPullAsync(cancellationToken);

    private void EnsureWired()
    {
        if (Interlocked.Exchange(ref _wired, 1) == 1)
        {
            return;
        }

        _session.SnapshotChanged += snapshot =>
        {
            try
            {
                StatusChanged?.Invoke(snapshot.DisplayStatus);
            }
            catch
            {
                // View-model subscribers must not take down the session.
            }
        };

        _session.ErrorRaised += ex =>
        {
            try
            {
                ErrorRaised?.Invoke(ex);
            }
            catch
            {
            }
        };

        _session.SyncCompleted += () =>
        {
            try
            {
                SyncCompleted?.Invoke();
            }
            catch
            {
            }
        };
    }
}
