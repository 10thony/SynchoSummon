using System.Threading.Channels;
using Microsoft.AspNetCore.SignalR;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using SyncEngine.Abstractions.Notify;
using SyncEngine.Abstractions.Protocol;
using SyncEngine.Abstractions.Telemetry;
using SyncEngine.Server.Hubs;
using SyncEngine.Server.Telemetry;

namespace SyncEngine.Server.Notify;

public sealed class CoalescingSyncNotifier : BackgroundService, ISyncNotifier
{
    private readonly Channel<WakeEvent> _channel =
        Channel.CreateUnbounded<WakeEvent>(new UnboundedChannelOptions
        {
            SingleReader = true,
            SingleWriter = false,
        });

    private readonly IHubContext<SyncHub> _hubContext;
    private readonly ISyncTelemetry _telemetry;
    private readonly ILogger<CoalescingSyncNotifier> _logger;
    private readonly TimeSpan _coalesceWindow;

    public CoalescingSyncNotifier(
        IHubContext<SyncHub> hubContext,
        ISyncTelemetry telemetry,
        ILogger<CoalescingSyncNotifier> logger,
        TimeSpan? coalesceWindow = null)
    {
        _hubContext = hubContext;
        _telemetry = telemetry;
        _logger = logger;
        _coalesceWindow = coalesceWindow ?? TimeSpan.FromMilliseconds(25);
    }

    public ValueTask EnqueueWakeAsync(long version, string entityName, CancellationToken cancellationToken = default)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(entityName);
        return _channel.Writer.WriteAsync(new WakeEvent(version, entityName), cancellationToken);
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        var pendingEntities = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        var latestVersion = 0L;

        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                if (!await _channel.Reader.WaitToReadAsync(stoppingToken))
                {
                    break;
                }

                pendingEntities.Clear();
                latestVersion = 0;

                while (_channel.Reader.TryRead(out var wake))
                {
                    pendingEntities.Add(wake.EntityName);
                    if (wake.Version > latestVersion)
                    {
                        latestVersion = wake.Version;
                    }
                }

                // Brief coalesce window for burst writes.
                using var windowCts = CancellationTokenSource.CreateLinkedTokenSource(stoppingToken);
                windowCts.CancelAfter(_coalesceWindow);
                try
                {
                    while (await _channel.Reader.WaitToReadAsync(windowCts.Token))
                    {
                        while (_channel.Reader.TryRead(out var wake))
                        {
                            pendingEntities.Add(wake.EntityName);
                            if (wake.Version > latestVersion)
                            {
                                latestVersion = wake.Version;
                            }
                        }
                    }
                }
                catch (OperationCanceledException) when (!stoppingToken.IsCancellationRequested)
                {
                    // coalesce window elapsed
                }

                if (pendingEntities.Count == 0 || latestVersion <= 0)
                {
                    continue;
                }

                var notification = new SyncWake
                {
                    LatestVersion = latestVersion,
                    EntityNames = pendingEntities.ToArray(),
                };

                await _hubContext.Clients.Group(SyncHub.SyncClientsGroup)
                    .SendAsync("SyncWake", notification, stoppingToken);

                _telemetry.Record(new SyncTelemetryEvent
                {
                    Kind = SyncTelemetryKind.Wake,
                    Direction = "server→clients",
                    ToVersion = latestVersion,
                    EntityNames = notification.EntityNames,
                    ChangeCount = notification.EntityNames.Length,
                    Summary = $"SyncWake v{latestVersion} entities=[{string.Join(',', notification.EntityNames)}]",
                });
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                break;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to flush coalesced SyncWake.");
            }
        }
    }

    private readonly record struct WakeEvent(long Version, string EntityName);
}
