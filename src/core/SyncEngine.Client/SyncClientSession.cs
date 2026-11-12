using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using SyncEngine.Abstractions.Client;
using SyncEngine.Abstractions.Protocol;
using SyncEngine.Client.Offline;

namespace SyncEngine.Client;

/// <summary>
/// Options for <see cref="SyncClientSession"/>. Hosts opt into a safety-net periodic pull
/// (MAUI demo) without forcing it on every adopter.
/// </summary>
public sealed class SyncClientSessionOptions
{
    public const string SectionName = "SyncEngine:ClientSession";

    /// <summary>
    /// When set, runs a background HTTP pull on this interval as a SignalR safety net.
    /// Null (default) disables periodic pull.
    /// </summary>
    public TimeSpan? PeriodicPullInterval { get; set; }
}

/// <summary>
/// Shared client sync session state machine. Replaces duplicated MAUI/Blazor host loops.
/// </summary>
public sealed class SyncClientSession : ISyncSession
{
    private readonly SyncPullService _pullService;
    private readonly ISyncWakeListener _wakeListener;
    private readonly SyncClientOptions _clientOptions;
    private readonly SyncClientSessionOptions _sessionOptions;
    private readonly ILogger<SyncClientSession> _logger;

    private readonly object _gate = new();
    private CancellationTokenSource? _cts;
    private Task? _runLoop;
    private int _started;
    private SyncSessionSnapshot _snapshot;
    private bool _hubFailed;

    private readonly ClientOutbox? _outbox;

    public SyncClientSession(
        SyncPullService pullService,
        ISyncWakeListener wakeListener,
        IOptions<SyncClientOptions> clientOptions,
        IOptions<SyncClientSessionOptions> sessionOptions,
        ILogger<SyncClientSession> logger,
        ClientOutbox? outbox = null)
    {
        _pullService = pullService;
        _wakeListener = wakeListener;
        _clientOptions = clientOptions.Value;
        _sessionOptions = sessionOptions.Value;
        _logger = logger;
        _outbox = outbox;
        _snapshot = SyncSessionDisplay.Create(
            SyncSessionPhase.Stopped,
            wakeListener.LinkState,
            _clientOptions.ResolveTransportMode());
    }

    public SyncSessionSnapshot Snapshot
    {
        get
        {
            lock (_gate)
            {
                return _snapshot;
            }
        }
    }

    public event Action<SyncSessionSnapshot>? SnapshotChanged;

    public event Action? SyncCompleted;

    public event Action<Exception?>? ErrorRaised;

    public Task StartAsync(CancellationToken cancellationToken = default)
    {
        if (Interlocked.Exchange(ref _started, 1) == 1)
        {
            return Task.CompletedTask;
        }

        _cts = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
        var token = _cts.Token;
        _runLoop = Task.Run(() => RunAsync(token), CancellationToken.None);
        return Task.CompletedTask;
    }

    public async Task StopAsync(CancellationToken cancellationToken = default)
    {
        Publish(SyncSessionPhase.Stopping);

        var cts = _cts;
        if (cts is null)
        {
            Interlocked.Exchange(ref _started, 0);
            Publish(SyncSessionPhase.Stopped);
            return;
        }

        try
        {
            await cts.CancelAsync().ConfigureAwait(false);
            if (_runLoop is not null)
            {
                try
                {
                    await _runLoop.ConfigureAwait(false);
                }
                catch (OperationCanceledException)
                {
                }
            }
        }
        finally
        {
            _wakeListener.LinkStateChanged -= OnHubLinkStateChanged;
            _wakeListener.WakeReceived -= OnWakeReceived;
            _wakeListener.DeltaReceived -= OnDeltaReceived;
            _pullService.ApplyPhaseChanged -= OnApplyPhaseChanged;
            cts.Dispose();
            _cts = null;
            Interlocked.Exchange(ref _started, 0);
            Publish(SyncSessionPhase.Stopped);
        }
    }

    public Task TriggerPullAsync(CancellationToken cancellationToken = default)
        => SafePullAsync(SyncSessionPhase.Syncing, cancellationToken);

    private async Task RunAsync(CancellationToken cancellationToken)
    {
        _hubFailed = false;
        _wakeListener.LinkStateChanged += OnHubLinkStateChanged;
        _wakeListener.WakeReceived += OnWakeReceived;
        _wakeListener.DeltaReceived += OnDeltaReceived;
        _pullService.ApplyPhaseChanged += OnApplyPhaseChanged;

        Publish(SyncSessionPhase.Connecting, hub: _wakeListener.LinkState);

        try
        {
            await _wakeListener.StartAsync(cancellationToken).ConfigureAwait(false);
            if (_wakeListener.LinkState is SyncHubLinkState.Disabled)
            {
                // SignalR opted out — treat as intentional poll mode, not a failure.
                Publish(SyncSessionPhase.CatchingUp, hub: SyncHubLinkState.Disabled);
            }
            else
            {
                Publish(SyncSessionPhase.CatchingUp, hub: _wakeListener.LinkState);
            }
        }
        catch (OperationCanceledException)
        {
            return;
        }
        catch (Exception ex)
        {
            _hubFailed = true;
            _logger.LogWarning(ex, "SignalR hub listener failed to start; falling back to periodic/HTTP pull.");
            RaiseError(ex);
            Publish(SyncSessionPhase.OfflinePolling, hub: SyncHubLinkState.Failed, lastError: ex);
        }

        _ = Task.Run(() => SafePullAsync(SyncSessionPhase.CatchingUp, cancellationToken), cancellationToken);

        var streamLoop = Task.Run(async () =>
        {
            try
            {
                await _pullService.RunStreamLoopAsync(cancellationToken).ConfigureAwait(false);
            }
            catch (OperationCanceledException)
            {
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Stream loop exited unexpectedly.");
                RaiseError(ex);
                Publish(SyncSessionPhase.Degraded, lastError: ex);
            }
        }, cancellationToken);

        var wakeLoop = Task.Run(async () =>
        {
            try
            {
                await _pullService.RunWakeLoopAsync(cancellationToken).ConfigureAwait(false);
            }
            catch (OperationCanceledException)
            {
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Wake loop exited unexpectedly.");
                RaiseError(ex);
                Publish(SyncSessionPhase.Degraded, lastError: ex);
            }
        }, cancellationToken);

        Task? periodicLoop = null;
        var interval = ResolvePeriodicInterval();
        if (interval is { } period)
        {
            periodicLoop = Task.Run(async () =>
            {
                try
                {
                    while (!cancellationToken.IsCancellationRequested)
                    {
                        await Task.Delay(period, cancellationToken).ConfigureAwait(false);
                        await SafePullAsync(busyPhase: null, cancellationToken).ConfigureAwait(false);
                    }
                }
                catch (OperationCanceledException)
                {
                }
            }, cancellationToken);
        }

        // When the hub fails to start (or automatic reconnect gives up), HTTP polling alone
        // leaves the session stuck in OfflinePolling forever. Retry SignalR until it sticks.
        var hubRecoveryLoop = Task.Run(
            () => RunHubRecoveryAsync(interval ?? TimeSpan.FromSeconds(5), cancellationToken),
            cancellationToken);

        _logger.LogInformation(
            "Sync client session started (transport={Mode}, periodicPull={Periodic}).",
            _clientOptions.ResolveTransportMode(),
            interval?.ToString() ?? "off");

        if (periodicLoop is null)
        {
            await Task.WhenAll(streamLoop, wakeLoop, hubRecoveryLoop).ConfigureAwait(false);
        }
        else
        {
            await Task.WhenAll(streamLoop, wakeLoop, periodicLoop, hubRecoveryLoop).ConfigureAwait(false);
        }
    }

    private async Task RunHubRecoveryAsync(TimeSpan retryInterval, CancellationToken cancellationToken)
    {
        if (!_clientOptions.EnableSignalR)
        {
            return;
        }

        try
        {
            while (!cancellationToken.IsCancellationRequested)
            {
                await Task.Delay(retryInterval, cancellationToken).ConfigureAwait(false);

                var link = _wakeListener.LinkState;
                if (link is SyncHubLinkState.Connected or SyncHubLinkState.Connecting
                    or SyncHubLinkState.Reconnecting or SyncHubLinkState.Disabled)
                {
                    continue;
                }

                // Failed / Disconnected — attempt a full reconnect (dispose + StartAsync).
                _logger.LogInformation(
                    "SignalR hub is {Link}; attempting reconnect to recover from OfflinePolling.",
                    link);
                try
                {
                    await _wakeListener.ReconnectAsync(cancellationToken).ConfigureAwait(false);
                    _hubFailed = false;
                    Publish(SyncSessionPhase.CatchingUp, hub: _wakeListener.LinkState, lastError: null);
                    RaiseError(null);
                    await SafePullAsync(SyncSessionPhase.CatchingUp, cancellationToken).ConfigureAwait(false);
                    _logger.LogInformation("SignalR hub recovered; session catching up.");
                }
                catch (OperationCanceledException)
                {
                    throw;
                }
                catch (Exception ex)
                {
                    _hubFailed = true;
                    _logger.LogDebug(ex, "SignalR hub reconnect attempt failed; will retry.");
                }
            }
        }
        catch (OperationCanceledException)
        {
        }
    }

    private TimeSpan? ResolvePeriodicInterval()
    {
        if (_sessionOptions.PeriodicPullInterval is { } configured)
        {
            return configured;
        }

        // Hub start failure without an explicit interval still needs a poll safety net.
        if (_hubFailed)
        {
            return TimeSpan.FromSeconds(5);
        }

        return null;
    }

    private async Task SafePullAsync(SyncSessionPhase? busyPhase, CancellationToken cancellationToken)
    {
        if (busyPhase is { } phase)
        {
            Publish(phase);
        }

        try
        {
            var result = await _pullService.PullAndApplyAsync(cancellationToken).ConfigureAwait(false);
            RaiseError(null);
            var livePhase = _hubFailed
                || _wakeListener.LinkState is SyncHubLinkState.Failed or SyncHubLinkState.Disconnected
                ? SyncSessionPhase.OfflinePolling
                : SyncSessionPhase.Live;
            Publish(
                livePhase,
                checkpoint: result.ToVersion,
                lastError: null,
                lastSuccessUtc: DateTimeOffset.UtcNow);
            try
            {
                SyncCompleted?.Invoke();
            }
            catch (Exception ex)
            {
                _logger.LogDebug(ex, "SyncCompleted subscriber threw.");
            }
        }
        catch (OperationCanceledException)
        {
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Pull failed; will retry.");
            RaiseError(ex);
            Publish(SyncSessionPhase.Degraded, lastError: ex, detail: "Sync error – retrying");
        }
    }

    private void OnHubLinkStateChanged(SyncHubLinkState state)
    {
        if (state is SyncHubLinkState.Reconnecting)
        {
            Publish(SyncSessionPhase.Reconnecting, hub: state);
            return;
        }

        if (state is SyncHubLinkState.Failed or SyncHubLinkState.Disconnected)
        {
            _hubFailed = true;
            Publish(SyncSessionPhase.OfflinePolling, hub: state);
            return;
        }

        if (state is SyncHubLinkState.Connected)
        {
            _hubFailed = false;
            var current = Snapshot.Phase;
            if (current is SyncSessionPhase.OfflinePolling or SyncSessionPhase.Reconnecting or SyncSessionPhase.Degraded)
            {
                Publish(SyncSessionPhase.CatchingUp, hub: state);
            }
            else
            {
                Publish(current, hub: state);
            }
        }
    }

    private void OnApplyPhaseChanged(SyncApplyPhase phase)
    {
        var current = Snapshot.Phase;
        if (current is SyncSessionPhase.Stopped or SyncSessionPhase.Stopping or SyncSessionPhase.Connecting)
        {
            return;
        }

        switch (phase)
        {
            case SyncApplyPhase.GapRepair:
            case SyncApplyPhase.HttpCatchUp when current is not SyncSessionPhase.Live:
                Publish(SyncSessionPhase.CatchingUp);
                break;
            case SyncApplyPhase.ApplyingStream:
                if (current is SyncSessionPhase.Live or SyncSessionPhase.CatchingUp or SyncSessionPhase.OfflinePolling)
                {
                    Publish(SyncSessionPhase.Syncing);
                }

                break;
        }
    }

    private async Task OnWakeReceived(SyncWake wake, CancellationToken cancellationToken)
    {
        var current = Snapshot.Phase;
        if (current is SyncSessionPhase.Live or SyncSessionPhase.OfflinePolling)
        {
            Publish(SyncSessionPhase.Syncing);
        }

        try
        {
            await _pullService.NotifyWakeAsync(wake, cancellationToken).ConfigureAwait(false);
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Failed to enqueue wake v{Version}.", wake.LatestVersion);
        }
    }

    private async Task OnDeltaReceived(ReadOnlyMemory<byte> bytes, CancellationToken cancellationToken)
    {
        var current = Snapshot.Phase;
        if (current is SyncSessionPhase.Live or SyncSessionPhase.OfflinePolling)
        {
            Publish(SyncSessionPhase.Syncing);
        }

        try
        {
            await _pullService.NotifyStreamedDeltaAsync(bytes, cancellationToken).ConfigureAwait(false);
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Failed to enqueue streamed SyncDelta ({Bytes} bytes).", bytes.Length);
        }
    }

    private void Publish(
        SyncSessionPhase phase,
        SyncHubLinkState? hub = null,
        long? checkpoint = null,
        string? detail = null,
        Exception? lastError = null,
        DateTimeOffset? lastSuccessUtc = null)
    {
        SyncSessionSnapshot next;
        lock (_gate)
        {
            var resolvedError = phase is SyncSessionPhase.Degraded
                ? lastError ?? _snapshot.LastError
                : lastError;
            if (phase is not SyncSessionPhase.Degraded && lastError is null)
            {
                resolvedError = null;
            }

            next = SyncSessionDisplay.Create(
                phase,
                hub ?? _wakeListener.LinkState,
                _clientOptions.ResolveTransportMode(),
                checkpoint ?? _snapshot.Checkpoint,
                detail,
                resolvedError,
                lastSuccessUtc ?? _snapshot.LastSuccessUtc,
                outboxPhase: _outbox?.Phase,
                outboxPendingCount: _outbox?.PendingCount,
                catchUpAppliedCount: _pullService.CatchUpAppliedCount,
                lastStreamApplyUtc: _pullService.LastStreamApplyUtc,
                channelWakeDropCount: _pullService.WakeDropCount,
                channelDeltaDropCount: _pullService.DeltaDropCount);

            if (SnapshotsEqual(_snapshot, next))
            {
                return;
            }

            _snapshot = next;
        }

        try
        {
            SnapshotChanged?.Invoke(next);
        }
        catch (Exception ex)
        {
            _logger.LogDebug(ex, "SnapshotChanged subscriber threw.");
        }
    }

    private static bool SnapshotsEqual(SyncSessionSnapshot a, SyncSessionSnapshot b)
        => a.Phase == b.Phase
           && a.Hub == b.Hub
           && a.TransportMode == b.TransportMode
           && a.Checkpoint == b.Checkpoint
           && string.Equals(a.DisplayStatus, b.DisplayStatus, StringComparison.Ordinal)
           && string.Equals(a.Detail, b.Detail, StringComparison.Ordinal)
           && ReferenceEquals(a.LastError, b.LastError)
           && a.LastSuccessUtc == b.LastSuccessUtc
           && a.OutboxPhase == b.OutboxPhase
           && a.OutboxPendingCount == b.OutboxPendingCount
           && a.CatchUpAppliedCount == b.CatchUpAppliedCount
           && a.LastStreamApplyUtc == b.LastStreamApplyUtc
           && a.ChannelWakeDropCount == b.ChannelWakeDropCount
           && a.ChannelDeltaDropCount == b.ChannelDeltaDropCount;

    private void RaiseError(Exception? ex)
    {
        try
        {
            ErrorRaised?.Invoke(ex);
        }
        catch (Exception listenerEx)
        {
            _logger.LogDebug(listenerEx, "ErrorRaised subscriber threw.");
        }
    }
}
