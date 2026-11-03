using Microsoft.Extensions.Logging;
using SyncEngine.Abstractions.Client;
using SyncEngine.Abstractions.Protocol;
using SyncEngine.Client;

namespace Aviation.Maui.Services;

/// <summary>
/// Starts the MAUI sync pipeline without blocking the UI thread.
/// Runs the SignalR wake pump plus a safety-net periodic pull so the demo keeps
/// catching up even if the hub flakes.
/// </summary>
public sealed class MauiSyncBootstrapper(
    SyncPullService pullService,
    ISyncWakeListener wakeListener,
    ILogger<MauiSyncBootstrapper> logger)
{
    private static readonly TimeSpan PeriodicPullInterval = TimeSpan.FromSeconds(5);

    private readonly SyncPullService _pullService = pullService;
    private readonly ISyncWakeListener _wakeListener = wakeListener;
    private readonly ILogger<MauiSyncBootstrapper> _logger = logger;

    private CancellationTokenSource? _cts;
    private Task? _runLoop;
    private int _started;

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
        if (Interlocked.Exchange(ref _started, 1) == 1)
        {
            return Task.CompletedTask;
        }

        _cts = new CancellationTokenSource();
        var token = _cts.Token;
        _runLoop = Task.Run(() => RunAsync(token), token);
        return Task.CompletedTask;
    }

    public async Task StopAsync()
    {
        if (_cts is null)
        {
            return;
        }

        try
        {
            _cts.Cancel();
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
            _cts.Dispose();
            _cts = null;
            _started = 0;
        }
    }

    /// <summary>
    /// Forces an immediate pull. Safe to call from the UI thread; errors are reported via <see cref="ErrorRaised"/>.
    /// </summary>
    public Task TriggerPullAsync(CancellationToken cancellationToken = default)
        => SafePullAsync("Syncing…", cancellationToken);

    private async Task RunAsync(CancellationToken cancellationToken)
    {
        OnStatus("Connecting…");

        // Hook wake events up-front so no SyncWake that arrives during start-up is lost.
        _wakeListener.WakeReceived += OnWakeReceived;

        try
        {
            await _wakeListener.StartAsync(cancellationToken).ConfigureAwait(false);
            OnStatus("Connected");
        }
        catch (OperationCanceledException)
        {
            return;
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "SignalR wake listener failed to start; falling back to periodic pull.");
            OnError(ex);
            OnStatus("Offline (polling)");
        }

        // Fire a catch-up pull on the background queue. We don't await here so a huge
        // catch-up never stalls the wake loop or the UI.
        _ = Task.Run(() => SafePullAsync("Catching up…", cancellationToken), cancellationToken);

        // Pump wakes; this call blocks until the channel completes or cancellation.
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
                OnError(ex);
            }
        }, cancellationToken);

        // Safety-net periodic pull. Keeps the demo live even if SignalR silently drops wakes.
        var periodicLoop = Task.Run(async () =>
        {
            try
            {
                while (!cancellationToken.IsCancellationRequested)
                {
                    await Task.Delay(PeriodicPullInterval, cancellationToken).ConfigureAwait(false);
                    await SafePullAsync(busyStatus: null, cancellationToken).ConfigureAwait(false);
                }
            }
            catch (OperationCanceledException)
            {
            }
        }, cancellationToken);

        _logger.LogInformation("MAUI sync bootstrap complete.");

        await Task.WhenAll(wakeLoop, periodicLoop).ConfigureAwait(false);
    }

    private async Task SafePullAsync(string? busyStatus, CancellationToken cancellationToken)
    {
        if (busyStatus is not null)
        {
            OnStatus(busyStatus);
        }

        try
        {
            var result = await _pullService.PullAndApplyAsync(cancellationToken).ConfigureAwait(false);
            OnError(null);
            OnStatus($"Connected (v{result.ToVersion})");
            SyncCompleted?.Invoke();
        }
        catch (OperationCanceledException)
        {
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Pull failed; will retry.");
            OnStatus("Sync error – retrying");
            OnError(ex);
        }
    }

    private async Task OnWakeReceived(SyncWake wake, CancellationToken cancellationToken)
    {
        try
        {
            await _pullService.NotifyWakeAsync(wake, cancellationToken).ConfigureAwait(false);
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Failed to enqueue wake v{Version}.", wake.LatestVersion);
        }
    }

    private void OnStatus(string status)
    {
        try
        {
            StatusChanged?.Invoke(status);
        }
        catch (Exception ex)
        {
            _logger.LogDebug(ex, "StatusChanged subscriber threw.");
        }
    }

    private void OnError(Exception? ex)
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
