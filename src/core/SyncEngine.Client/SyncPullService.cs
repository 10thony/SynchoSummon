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

public sealed class SyncPullService
{
    private readonly ISyncTransport _transport;
    private readonly IDeltaCodec _codec;
    private readonly IClientDeltaApplier _applier;
    private readonly ICheckpointStore _checkpointStore;
    private readonly SyncClientOptions _options;
    private readonly ClientTelemetryReporter? _telemetry;
    private readonly ILogger<SyncPullService> _logger;
    private readonly SemaphoreSlim _pullLock = new(1, 1);
    private readonly Channel<SyncWake> _wakeChannel = Channel.CreateUnbounded<SyncWake>(
        new UnboundedChannelOptions { SingleReader = true, SingleWriter = false });

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

    public event Action<DeltaBatch>? BatchApplied;

    public ValueTask NotifyWakeAsync(SyncWake wake, CancellationToken cancellationToken = default)
        => _wakeChannel.Writer.WriteAsync(wake, cancellationToken);

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

    public async Task<PullResult> PullAndApplyAsync(CancellationToken cancellationToken = default)
    {
        await _pullLock.WaitAsync(cancellationToken);
        try
        {
            var sw = Stopwatch.StartNew();
            var fromVersion = await _checkpointStore.GetVersionAsync(_options.CheckpointScope, cancellationToken);
            var applied = 0;
            var toVersion = fromVersion;
            var entities = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            long bytes = 0;

            while (true)
            {
                using var buffer = await _transport.GetDeltasBytesAsync(
                    toVersion,
                    _options.BatchSize,
                    cancellationToken);
                bytes += buffer.Memory.Length;
                var batch = _codec.DecodeBatch(buffer.Memory.Span);
                if (batch.Changes is not { Length: > 0 })
                {
                    break;
                }

                await _applier.ApplyAsync(batch, cancellationToken);
                await _checkpointStore.SetVersionAsync(batch.ToVersion, _options.CheckpointScope, cancellationToken);

                applied += batch.Changes.Length;
                toVersion = batch.ToVersion;
                foreach (var change in batch.Changes)
                {
                    entities.Add(change.EntityName);
                }

                BatchApplied?.Invoke(batch);

                if (!batch.HasMore)
                {
                    break;
                }
            }

            sw.Stop();
            if (applied > 0 && _telemetry is not null)
            {
                await _telemetry.ReportAsync(new ClientTelemetryReport
                {
                    ClientId = _options.ClientId,
                    Kind = SyncTelemetryKind.ClientApply,
                    FromVersion = fromVersion,
                    ToVersion = toVersion,
                    ChangeCount = applied,
                    Bytes = bytes,
                    LatencyMs = sw.Elapsed.TotalMilliseconds,
                    EntityNames = entities.ToArray(),
                    Summary = $"{_options.ClientId} applied {applied} changes v{fromVersion}→{toVersion}",
                    PayloadPreview = $"entities=[{string.Join(',', entities)}] bytes={bytes}",
                }, cancellationToken);
            }

            return new PullResult(fromVersion, toVersion, applied, entities.ToArray());
        }
        finally
        {
            _pullLock.Release();
        }
    }
}

public readonly record struct PullResult(
    long FromVersion,
    long ToVersion,
    int AppliedCount,
    IReadOnlyList<string> ChangedEntities);
