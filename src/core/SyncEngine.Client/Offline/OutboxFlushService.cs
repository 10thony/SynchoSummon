using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using SyncEngine.Abstractions.Client;
using SyncEngine.Abstractions.Codec;

namespace SyncEngine.Client.Offline;

/// <summary>
/// Hosted service that periodically flushes the client outbox to the server.
/// Implements <see cref="IOutboxFlushService"/> for UI binding and <see cref="IHostedService"/> for lifecycle.
/// </summary>
public sealed class OutboxFlushService : IOutboxFlushService, IHostedService, IDisposable
{
    private readonly ClientOutbox _outbox;
    private readonly IHttpClientFactory _httpClientFactory;
    private readonly SyncClientOptions _clientOptions;
    private readonly IDeltaCodec _codec;
    private readonly OutboxFlushOptions _flushOptions;
    private readonly ILogger<OutboxFlushService> _logger;
    private Timer? _timer;

    /// <summary>Initializes a new <see cref="OutboxFlushService"/>.</summary>
    public OutboxFlushService(
        ClientOutbox outbox,
        IHttpClientFactory httpClientFactory,
        IOptions<SyncClientOptions> clientOptions,
        IDeltaCodec codec,
        IOptions<OutboxFlushOptions> flushOptions,
        ILogger<OutboxFlushService> logger)
    {
        _outbox = outbox;
        _httpClientFactory = httpClientFactory;
        _clientOptions = clientOptions.Value;
        _codec = codec;
        _flushOptions = flushOptions.Value;
        _logger = logger;
        _outbox.PhaseChanged += phase => PhaseChanged?.Invoke(phase);
    }

    /// <inheritdoc />
    public SyncOutboxPhase Phase => _outbox.Phase;

    /// <inheritdoc />
    public int PendingCount => _outbox.PendingCount;

    /// <inheritdoc />
    public event Action<SyncOutboxPhase>? PhaseChanged;

    /// <inheritdoc />
    public async Task<int> FlushAsync(CancellationToken cancellationToken = default)
    {
        var client = _httpClientFactory.CreateClient();
        return await _outbox.FlushAsync(
            client,
            _clientOptions.ServerBaseAddress,
            _codec,
            cancellationToken,
            _flushOptions.MaxChangesPerPush);
    }

    /// <inheritdoc />
    public Task StartAsync(CancellationToken cancellationToken)
    {
        _timer = new Timer(
            _ => _ = TryFlushAsync(),
            null,
            _flushOptions.FlushInterval,
            _flushOptions.FlushInterval);
        return Task.CompletedTask;
    }

    /// <inheritdoc />
    public Task StopAsync(CancellationToken cancellationToken)
    {
        _timer?.Change(Timeout.Infinite, 0);
        return Task.CompletedTask;
    }

    private async Task TryFlushAsync()
    {
        if (_outbox.PendingCount == 0)
        {
            return;
        }

        try
        {
            await FlushAsync();
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Outbox auto-flush failed ({Pending} pending).", _outbox.PendingCount);
        }
    }

    /// <inheritdoc />
    public void Dispose()
    {
        _timer?.Dispose();
    }
}
