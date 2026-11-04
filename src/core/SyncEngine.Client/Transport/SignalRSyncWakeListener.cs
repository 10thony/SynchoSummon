using Microsoft.AspNetCore.SignalR.Client;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using SyncEngine.Abstractions;
using SyncEngine.Abstractions.Client;
using SyncEngine.Abstractions.Protocol;

namespace SyncEngine.Client.Transport;

public sealed class SignalRSyncWakeListener : ISyncWakeListener
{
    private readonly SyncClientOptions _options;
    private readonly ILogger<SignalRSyncWakeListener> _logger;
    private HubConnection? _connection;

    public SignalRSyncWakeListener(
        IOptions<SyncClientOptions> options,
        ILogger<SignalRSyncWakeListener> logger)
    {
        _options = options.Value;
        _logger = logger;
    }

    public event Func<SyncWake, CancellationToken, Task>? WakeReceived;

    public async Task StartAsync(CancellationToken cancellationToken = default)
    {
        if (!_options.EnableSignalR)
        {
            return;
        }

        var hubUrl = _options.ServerBaseAddress.TrimEnd('/') + SyncRoutes.Hub;
        _connection = new HubConnectionBuilder()
            .WithUrl(hubUrl)
            .WithAutomaticReconnect()
            .Build();

        _connection.On<SyncWake>("SyncWake", async wake =>
        {
            var handlers = WakeReceived;
            if (handlers is null)
            {
                return;
            }

            await handlers(wake, CancellationToken.None);
        });

        _connection.Reconnected += async _ =>
        {
            await _connection.InvokeAsync(
                "RegisterSyncClient",
                string.IsNullOrWhiteSpace(_options.ClientId) ? _connection.ConnectionId ?? "client" : _options.ClientId,
                CancellationToken.None);
            if (WakeReceived is not null)
            {
                await WakeReceived(new SyncWake { LatestVersion = 0, EntityNames = [] }, CancellationToken.None);
            }
        };

        await _connection.StartAsync(cancellationToken);
        var clientId = string.IsNullOrWhiteSpace(_options.ClientId)
            ? _connection.ConnectionId ?? "client"
            : _options.ClientId;
        await _connection.InvokeAsync("RegisterSyncClient", clientId, cancellationToken);
        _logger.LogInformation("SignalR sync hub connected at {HubUrl} as {ClientId}", hubUrl, clientId);
    }

    public async ValueTask DisposeAsync()
    {
        if (_connection is not null)
        {
            await _connection.DisposeAsync();
            _connection = null;
        }
    }
}
