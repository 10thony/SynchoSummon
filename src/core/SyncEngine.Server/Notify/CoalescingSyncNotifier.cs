using System.Threading.Channels;
using Microsoft.AspNetCore.SignalR;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using SyncEngine.Abstractions;
using SyncEngine.Abstractions.Codec;
using SyncEngine.Abstractions.Ledger;
using SyncEngine.Abstractions.Notify;
using SyncEngine.Abstractions.Protocol;
using SyncEngine.Abstractions.Telemetry;
using SyncEngine.Server.Hubs;
using SyncEngine.Server.Telemetry;

namespace SyncEngine.Server.Notify;

/// <summary>
/// Coalesces change notifications, then pushes MemoryPack <see cref="DeltaBatch"/> bytes over SignalR
/// (<see cref="SyncHubEvents.SyncDelta"/>). Also emits a lightweight <see cref="SyncWake"/> for
/// clients that disable streaming. HTTP <c>/sync/deltas</c> remains the catch-up path.
/// </summary>
public sealed class CoalescingSyncNotifier : BackgroundService, ISyncNotifier
{
    private readonly Channel<WakeEvent> _channel =
        Channel.CreateBounded<WakeEvent>(new BoundedChannelOptions(10_000)
        {
            SingleReader = true,
            SingleWriter = false,
            FullMode = BoundedChannelFullMode.DropOldest,
        });

    private readonly IHubContext<SyncHub> _hubContext;
    private readonly IChangeLedger _ledger;
    private readonly IDeltaCodec _codec;
    private readonly ISyncTelemetry _telemetry;
    private readonly ILogger<CoalescingSyncNotifier> _logger;
    private readonly TimeSpan _coalesceWindow;
    private readonly int _batchSize;
    private readonly int _maxStreamMessageBytes;
    private long _lastStreamedVersion = -1;

    public CoalescingSyncNotifier(
        IHubContext<SyncHub> hubContext,
        IChangeLedger ledger,
        IDeltaCodec codec,
        ISyncTelemetry telemetry,
        ILogger<CoalescingSyncNotifier> logger,
        TimeSpan? coalesceWindow = null,
        int batchSize = 500,
        int maxStreamMessageBytes = 1024 * 1024)
    {
        _hubContext = hubContext;
        _ledger = ledger;
        _codec = codec;
        _telemetry = telemetry;
        _logger = logger;
        _coalesceWindow = coalesceWindow ?? TimeSpan.FromMilliseconds(25);
        _batchSize = Math.Clamp(batchSize, 1, 1000);
        // Prefer HTTP catch-up over blowing client SignalR buffers (MS guidance: avoid huge hub payloads).
        _maxStreamMessageBytes = Math.Max(32 * 1024, maxStreamMessageBytes);
    }

    public ValueTask EnqueueWakeAsync(
        long version,
        string entityName,
        CancellationToken cancellationToken = default,
        string? tenantId = null)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(entityName);
        return _channel.Writer.WriteAsync(new WakeEvent(version, entityName, tenantId), cancellationToken);
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        // Only stream changes that land after this process starts; cold clients HTTP catch up.
        try
        {
            _lastStreamedVersion = await _ledger.GetCurrentVersionAsync(stoppingToken);
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Failed to seed stream high-water mark; starting at 0.");
            _lastStreamedVersion = 0;
        }

        // tenantKey → (entities, latestVersion). Never coalesce across tenants into one group send.
        var pendingByTenant = new Dictionary<string, TenantCoalesce>(StringComparer.Ordinal);

        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                if (!await _channel.Reader.WaitToReadAsync(stoppingToken))
                {
                    break;
                }

                pendingByTenant.Clear();

                while (_channel.Reader.TryRead(out var wake))
                {
                    Accumulate(pendingByTenant, wake);
                }

                using var windowCts = CancellationTokenSource.CreateLinkedTokenSource(stoppingToken);
                windowCts.CancelAfter(_coalesceWindow);
                try
                {
                    while (await _channel.Reader.WaitToReadAsync(windowCts.Token))
                    {
                        while (_channel.Reader.TryRead(out var wake))
                        {
                            Accumulate(pendingByTenant, wake);
                        }
                    }
                }
                catch (OperationCanceledException) when (!stoppingToken.IsCancellationRequested)
                {
                    // coalesce window elapsed
                }

                foreach (var (tenantKey, coalesce) in pendingByTenant)
                {
                    if (coalesce.Entities.Count == 0 || coalesce.LatestVersion <= 0)
                    {
                        continue;
                    }

                    var tenantId = tenantKey.Length == 0 ? null : tenantKey;
                    var group = tenantId is null
                        ? SyncHub.SyncClientsGroup
                        : SyncHub.TenantGroup(tenantId);

                    var notification = new SyncWake
                    {
                        LatestVersion = coalesce.LatestVersion,
                        EntityNames = coalesce.Entities.ToArray(),
                        TenantId = tenantId,
                    };

                    await FlushDeltasAsync(group, notification, stoppingToken);
                }
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                break;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to flush coalesced SyncDelta/SyncWake.");
            }
        }
    }

    private static void Accumulate(Dictionary<string, TenantCoalesce> pending, WakeEvent wake)
    {
        var key = wake.TenantId ?? string.Empty;
        if (!pending.TryGetValue(key, out var coalesce))
        {
            coalesce = new TenantCoalesce();
            pending[key] = coalesce;
        }

        coalesce.Entities.Add(wake.EntityName);
        if (wake.Version > coalesce.LatestVersion)
        {
            coalesce.LatestVersion = wake.Version;
        }
    }

    private async Task FlushDeltasAsync(
        string group,
        SyncWake wake,
        CancellationToken cancellationToken)
    {
        var since = Math.Max(0, Interlocked.Read(ref _lastStreamedVersion));
        var pages = 0;

        while (true)
        {
            var batch = await _ledger.GetDeltasAsync(since, _batchSize, cancellationToken);
            if (batch.ToVersion <= since && (batch.Changes is null || batch.Changes.Length == 0))
            {
                break;
            }

            using var buffer = _codec.EncodeBatch(batch);
            var byteLength = buffer.Memory.Length;

            if (byteLength > _maxStreamMessageBytes)
            {
                _logger.LogInformation(
                    "SyncDelta page v{From}→{To} is {Bytes} bytes > MaxStreamMessageBytes={Max}; wake-only (HTTP catch-up).",
                    batch.FromVersion,
                    batch.ToVersion,
                    byteLength,
                    _maxStreamMessageBytes);
                since = batch.ToVersion;
                Interlocked.Exchange(ref _lastStreamedVersion, since);
                // Stop paging hub payloads; remaining tip is covered by SyncWake below.
                break;
            }

            var bytes = buffer.Memory.ToArray();
            await _hubContext.Clients.Group(group)
                .SendAsync(SyncHubEvents.SyncDelta, bytes, cancellationToken);

            _telemetry.Record(new SyncTelemetryEvent
            {
                Kind = SyncTelemetryKind.DeltaStream,
                Direction = "server→clients",
                FromVersion = batch.FromVersion,
                ToVersion = batch.ToVersion,
                ChangeCount = batch.Changes?.Length ?? 0,
                Bytes = bytes.LongLength,
                EntityNames = batch.Changes?
                    .Select(c => c.EntityName)
                    .Distinct(StringComparer.OrdinalIgnoreCase)
                    .ToArray() ?? wake.EntityNames,
                Summary =
                    $"SyncDelta v{batch.FromVersion}→{batch.ToVersion} changes={batch.Changes?.Length ?? 0} bytes={bytes.Length}",
            });

            since = batch.ToVersion;
            Interlocked.Exchange(ref _lastStreamedVersion, since);
            pages++;

            if (!batch.HasMore || pages > 10_000)
            {
                break;
            }
        }

        // Lightweight wake for clients with EnableDeltaStreaming=false (pull path).
        await _hubContext.Clients.Group(group)
            .SendAsync(SyncHubEvents.SyncWake, wake, cancellationToken);

        _telemetry.Record(new SyncTelemetryEvent
        {
            Kind = SyncTelemetryKind.Wake,
            Direction = "server→clients",
            ToVersion = wake.LatestVersion,
            EntityNames = wake.EntityNames,
            ChangeCount = wake.EntityNames.Length,
            Summary = $"SyncWake v{wake.LatestVersion} entities=[{string.Join(',', wake.EntityNames)}]",
        });
    }

    private readonly record struct WakeEvent(long Version, string EntityName, string? TenantId);

    private sealed class TenantCoalesce
    {
        public HashSet<string> Entities { get; } = new(StringComparer.OrdinalIgnoreCase);
        public long LatestVersion { get; set; }
    }
}
