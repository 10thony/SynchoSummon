using System.Diagnostics;
using System.Threading.Channels;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using SyncEngine.Abstractions.Client;
using SyncEngine.Abstractions.Codec;
using SyncEngine.Abstractions.Protocol;
using SyncEngine.Abstractions.Telemetry;
using SyncEngine.Client.Telemetry;

namespace SyncEngine.Client;

public sealed class SyncPullService : ISyncApplyNotifications, ISyncBatchNotifier
{
    private const int WakeChannelCapacity = 256;
    private const int DeltaChannelCapacity = 64;

    private readonly ISyncTransport _transport;
    private readonly IDeltaCodec _codec;
    private readonly IClientDeltaApplier _applier;
    private readonly ICheckpointStore _checkpointStore;
    private readonly SyncClientOptions _options;
    private readonly ClientTelemetryReporter? _telemetry;
    private readonly ILogger<SyncPullService> _logger;
    private readonly SemaphoreSlim _pullLock = new(1, 1);
    // Bounded: DropOldest — newer wakes supersede; dropped deltas trigger HTTP catch-up via gap/wake.
    private readonly Channel<SyncWake> _wakeChannel = Channel.CreateBounded<SyncWake>(
        new BoundedChannelOptions(WakeChannelCapacity)
        {
            SingleReader = true,
            SingleWriter = false,
            FullMode = BoundedChannelFullMode.DropOldest,
        });
    private readonly Channel<byte[]> _deltaChannel = Channel.CreateBounded<byte[]>(
        new BoundedChannelOptions(DeltaChannelCapacity)
        {
            SingleReader = true,
            SingleWriter = false,
            FullMode = BoundedChannelFullMode.DropOldest,
        });

    private long _wakeDropCount;
    private long _deltaDropCount;
    private long _lastStreamApplyUtcTicks;

    private int _catchUpAppliedCount = -1;
    public int? CatchUpAppliedCount => Volatile.Read(ref _catchUpAppliedCount) is var v && v < 0 ? null : (int?)v;

    public SyncPullService(
        ISyncTransport transport,
        IDeltaCodec codec,
        IClientDeltaApplier applier,
        ICheckpointStore checkpointStore,
        IOptions<SyncClientOptions> options,
        ILogger<SyncPullService> logger,
        ClientTelemetryReporter? telemetry = null)
    {
        _transport = transport;
        _codec = codec;
        _applier = applier;
        _checkpointStore = checkpointStore;
        _options = options.Value;
        _logger = logger;
        _telemetry = telemetry;
    }

    public long WakeDropCount => Interlocked.Read(ref _wakeDropCount);
    public long DeltaDropCount => Interlocked.Read(ref _deltaDropCount);

    public DateTimeOffset? LastStreamApplyUtc
    {
        get
        {
            var ticks = Interlocked.Read(ref _lastStreamApplyUtcTicks);
            return ticks == 0 ? null : new DateTimeOffset(ticks, TimeSpan.Zero);
        }
    }

    public event Action<DeltaBatch>? BatchApplied;

    /// <summary>Raised when the pull/apply pipeline enters a named phase (Idle, stream apply, HTTP catch-up, gap repair).</summary>
    public event Action<SyncApplyPhase>? ApplyPhaseChanged;

    public ValueTask NotifyWakeAsync(SyncWake wake, CancellationToken cancellationToken = default)
    {
        // BoundedChannel DropOldest drops silently; approximate tracking via count check.
        if (_wakeChannel.Reader.Count >= WakeChannelCapacity)
            Interlocked.Increment(ref _wakeDropCount);
        return _wakeChannel.Writer.WriteAsync(wake, cancellationToken);
    }

    public ValueTask NotifyStreamedDeltaAsync(ReadOnlyMemory<byte> encodedBatch, CancellationToken cancellationToken = default)
    {
        if (_deltaChannel.Reader.Count >= DeltaChannelCapacity)
            Interlocked.Increment(ref _deltaDropCount);
        return _deltaChannel.Writer.WriteAsync(encodedBatch.ToArray(), cancellationToken);
    }

    public async Task RunWakeLoopAsync(CancellationToken cancellationToken)
    {
        await foreach (var wake in _wakeChannel.Reader.ReadAllAsync(cancellationToken))
        {
            try
            {
                await PullAndApplyAsync(cancellationToken);
            }
            catch (Exception ex) when (ex is not OperationCanceledException)
            {
                _logger.LogError(ex, "Pull after SyncWake failed (version {Version}).", wake.LatestVersion);
            }
        }
    }

    public async Task RunStreamLoopAsync(CancellationToken cancellationToken)
    {
        await foreach (var bytes in _deltaChannel.Reader.ReadAllAsync(cancellationToken))
        {
            try
            {
                await ApplyStreamedBatchAsync(bytes, cancellationToken);
            }
            catch (Exception ex) when (ex is not OperationCanceledException)
            {
                _logger.LogError(ex, "Apply of streamed SyncDelta failed.");
            }
        }
    }

    public async Task ApplyStreamedBatchAsync(ReadOnlyMemory<byte> encodedBatch, CancellationToken cancellationToken = default)
    {
        DeltaBatch batch;
        try
        {
            batch = _codec.DecodeBatch(encodedBatch.Span);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to decode streamed SyncDelta; falling back to HTTP pull.");
            RaiseApplyPhase(SyncApplyPhase.HttpCatchUp);
            await PullAndApplyAsync(cancellationToken);
            RaiseApplyPhase(SyncApplyPhase.Idle);
            return;
        }

        ClientTelemetryReport? report = null;
        DeltaBatch? appliedBatch = null;
        var needsHttpCatchUp = false;

        await _pullLock.WaitAsync(cancellationToken);
        try
        {
            var checkpoint = await _checkpointStore.GetVersionAsync(_options.CheckpointScope, cancellationToken);

            if (batch.FromVersion > checkpoint)
            {
                _logger.LogInformation(
                    "Stream gap detected (checkpoint={Checkpoint}, batchFrom={From}); HTTP catch-up.",
                    checkpoint,
                    batch.FromVersion);
                needsHttpCatchUp = true;
            }
            else if (batch.ToVersion <= checkpoint)
            {
                return;
            }
            else
            {
                RaiseApplyPhase(SyncApplyPhase.ApplyingStream);
                var sw = Stopwatch.StartNew();
                if (batch.Changes is { Length: > 0 })
                {
                    await _applier.ApplyAsync(batch, cancellationToken);
                }

                await _checkpointStore.SetVersionAsync(batch.ToVersion, _options.CheckpointScope, cancellationToken);
                sw.Stop();
                appliedBatch = batch;
                Interlocked.Exchange(ref _lastStreamApplyUtcTicks, DateTimeOffset.UtcNow.Ticks);

                if (_telemetry is not null && batch.Changes is { Length: > 0 })
                {
                    report = new ClientTelemetryReport
                    {
                        ClientId = _options.ClientId,
                        Kind = SyncTelemetryKind.ClientApply,
                        FromVersion = checkpoint,
                        ToVersion = batch.ToVersion,
                        ChangeCount = batch.Changes.Length,
                        Bytes = encodedBatch.Length,
                        LatencyMs = sw.Elapsed.TotalMilliseconds,
                        EntityNames = batch.Changes
                            .Select(c => c.EntityName)
                            .Distinct(StringComparer.OrdinalIgnoreCase)
                            .ToArray(),
                        Summary = $"{_options.ClientId} stream-applied {batch.Changes.Length} changes v{checkpoint}→{batch.ToVersion}",
                    };
                }
            }
        }
        finally
        {
            _pullLock.Release();
        }

        if (needsHttpCatchUp)
        {
            RaiseApplyPhase(SyncApplyPhase.GapRepair);
            await PullAndApplyAsync(cancellationToken);
            RaiseApplyPhase(SyncApplyPhase.Idle);
            return;
        }

        if (appliedBatch is { } notified)
        {
            BatchApplied?.Invoke(notified);
        }

        RaiseApplyPhase(SyncApplyPhase.Idle);

        if (report is not null && _telemetry is not null)
        {
            try
            {
                await _telemetry.ReportAsync(report, cancellationToken);
            }
            catch (Exception ex)
            {
                _logger.LogDebug(ex, "Stream apply telemetry report failed.");
            }
        }
    }

    public async Task<PullResult> PullAndApplyAsync(CancellationToken cancellationToken = default)
    {
        ClientTelemetryReport? report = null;
        PullResult result;
        List<DeltaBatch>? appliedBatches = null;

        RaiseApplyPhase(SyncApplyPhase.HttpCatchUp);
        Volatile.Write(ref _catchUpAppliedCount, 0);
        await _pullLock.WaitAsync(cancellationToken);
        try
        {
            var sw = Stopwatch.StartNew();
            var fromVersion = await _checkpointStore.GetVersionAsync(_options.CheckpointScope, cancellationToken);
            var applied = 0;
            var toVersion = fromVersion;
            var entities = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            long bytes = 0;
            var iterations = 0;

            while (true)
            {
                if (++iterations > _options.MaxPullIterations)
                {
                    throw new InvalidOperationException(
                        $"Pull exceeded MaxPullIterations={_options.MaxPullIterations} (possible HasMore loop).");
                }

                using var buffer = await _transport.GetDeltasBytesAsync(
                    toVersion,
                    _options.BatchSize,
                    cancellationToken);
                bytes += buffer.Memory.Length;
                var batch = _codec.DecodeBatch(buffer.Memory.Span);
                if (batch.Changes is not { Length: > 0 })
                {
                    if (batch.ToVersion > toVersion)
                    {
                        await _checkpointStore.SetVersionAsync(batch.ToVersion, _options.CheckpointScope, cancellationToken);
                        toVersion = batch.ToVersion;
                    }

                    break;
                }

                await _applier.ApplyAsync(batch, cancellationToken);
                if (batch.ToVersion < toVersion)
                {
                    throw new InvalidOperationException(
                        $"Server returned non-monotonic ToVersion {batch.ToVersion} after checkpoint {toVersion}.");
                }

                await _checkpointStore.SetVersionAsync(batch.ToVersion, _options.CheckpointScope, cancellationToken);

                applied += batch.Changes.Length;
                Volatile.Write(ref _catchUpAppliedCount, applied);
                toVersion = batch.ToVersion;
                foreach (var change in batch.Changes)
                {
                    entities.Add(change.EntityName);
                }

                (appliedBatches ??= []).Add(batch);

                if (!batch.HasMore)
                {
                    break;
                }
            }

            sw.Stop();
            var entityArray = entities.ToArray();
            if (applied > 0 && _telemetry is not null)
            {
                report = new ClientTelemetryReport
                {
                    ClientId = _options.ClientId,
                    Kind = SyncTelemetryKind.ClientApply,
                    FromVersion = fromVersion,
                    ToVersion = toVersion,
                    ChangeCount = applied,
                    Bytes = bytes,
                    LatencyMs = sw.Elapsed.TotalMilliseconds,
                    EntityNames = entityArray,
                    Summary = $"{_options.ClientId} applied {applied} changes v{fromVersion}→{toVersion}",
                    PayloadPreview = $"entities=[{string.Join(',', entities)}] bytes={bytes}",
                };
            }

            result = new PullResult(fromVersion, toVersion, applied, entityArray);
        }
        finally
        {
            _pullLock.Release();
            Volatile.Write(ref _catchUpAppliedCount, -1);
            RaiseApplyPhase(SyncApplyPhase.Idle);
        }

        if (appliedBatches is not null)
        {
            foreach (var batch in appliedBatches)
            {
                BatchApplied?.Invoke(batch);
            }
        }

        if (report is not null && _telemetry is not null)
        {
            try
            {
                await _telemetry.ReportAsync(report, cancellationToken);
            }
            catch (Exception ex)
            {
                _logger.LogDebug(ex, "Pull apply telemetry report failed.");
            }
        }

        return result;
    }

    private void RaiseApplyPhase(SyncApplyPhase phase)
    {
        try
        {
            ApplyPhaseChanged?.Invoke(phase);
        }
        catch (Exception ex)
        {
            _logger.LogDebug(ex, "ApplyPhaseChanged subscriber threw.");
        }
    }
}

public readonly record struct PullResult(
    long FromVersion,
    long ToVersion,
    int AppliedCount,
    IReadOnlyList<string> ChangedEntities);
