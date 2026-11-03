using SyncEngine.Abstractions.Client;
using SyncEngine.Abstractions.Protocol;
using SyncEngine.Client;

namespace Aviation.Blazor.Services;

public sealed class AviationSyncHostedService(
    SyncPullService pullService,
    ISyncWakeListener wakeListener,
    FacilityViewService viewService,
    ILogger<AviationSyncHostedService> logger) : IHostedService
{
    private CancellationTokenSource? _cts;
    private Task? _wakeLoop;

    public Task StartAsync(CancellationToken cancellationToken)
    {
        _cts = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);

        // Wake pump: enqueue every wake into SyncPullService's channel. Also flip the UI
        // status to "Syncing" so Home can show a non-blocking indicator while a pull runs.
        wakeListener.WakeReceived += async (wake, ct) =>
        {
            viewService.SetStatus(FacilityViewSyncStatus.Syncing, "Receiving updates…");
            await pullService.NotifyWakeAsync(wake, ct);
        };

        // Each batch apply moves us back to "Live". SetStatus is a no-op when the state
        // is already Live, so this is cheap during long catch-ups.
        pullService.BatchApplied += OnBatchApplied;

        // Never block app startup / crash the host if sync is temporarily unavailable
        // or a huge catch-up pull is in flight after load-gen.
        _ = Task.Run(async () =>
        {
            try
            {
                viewService.SetStatus(FacilityViewSyncStatus.Syncing, "Starting sync…");
                await wakeListener.StartAsync(_cts.Token);
                await pullService.PullAndApplyAsync(_cts.Token);
                viewService.SetStatus(FacilityViewSyncStatus.Live);
                _wakeLoop = pullService.RunWakeLoopAsync(_cts.Token);
                logger.LogInformation("Aviation Blazor sync host started.");
            }
            catch (OperationCanceledException)
            {
                // Shutting down — leave status alone.
            }
            catch (Exception ex)
            {
                logger.LogError(ex, "Blazor sync bootstrap failed; UI will still load.");
                // Surface a lightweight error pill. UI continues to render cached data.
                viewService.SetStatus(FacilityViewSyncStatus.Error, ex.Message);
            }
        }, CancellationToken.None);

        return Task.CompletedTask;
    }

    private void OnBatchApplied(DeltaBatch batch) => viewService.MarkAppliedBatch();

    public async Task StopAsync(CancellationToken cancellationToken)
    {
        pullService.BatchApplied -= OnBatchApplied;

        if (_cts is not null)
        {
            await _cts.CancelAsync();
        }

        if (_wakeLoop is not null)
        {
            try { await _wakeLoop; } catch (OperationCanceledException) { }
        }

        await wakeListener.DisposeAsync();
    }
}
