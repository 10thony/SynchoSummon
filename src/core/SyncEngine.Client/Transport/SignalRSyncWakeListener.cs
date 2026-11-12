using Microsoft.AspNetCore.SignalR.Client;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using SyncEngine.Abstractions;
using SyncEngine.Abstractions.Auth;
using SyncEngine.Abstractions.Client;
using SyncEngine.Abstractions.Protocol;

namespace SyncEngine.Client.Transport;

public sealed class SignalRSyncWakeListener : ISyncWakeListener
{
    private readonly SyncClientOptions _options;
    private readonly ILogger<SignalRSyncWakeListener> _logger;
    private readonly ISyncCredentialProvider? _credentials;
    private readonly object _stateGate = new();
    private HubConnection? _connection;
    private SyncHubLinkState _linkState = SyncHubLinkState.Disconnected;

    public SignalRSyncWakeListener(
        IOptions<SyncClientOptions> options,
        ILogger<SignalRSyncWakeListener> logger,
        IServiceProvider services)
    {
        _options = options.Value;
        _logger = logger;
        _credentials = services.GetService<ISyncCredentialProvider>();
        if (!_options.EnableSignalR)
        {
            _linkState = SyncHubLinkState.Disabled;
        }
    }

    public event Func<SyncWake, CancellationToken, Task>? WakeReceived;

    public event Func<ReadOnlyMemory<byte>, CancellationToken, Task>? DeltaReceived;

    public event Action<SyncHubLinkState>? LinkStateChanged;

    public SyncHubLinkState LinkState
    {
        get
        {
            lock (_stateGate)
            {
                return _linkState;
            }
        }
    }

    public async Task StartAsync(CancellationToken cancellationToken = default)
    {
        if (!_options.EnableSignalR)
        {
            SetLinkState(SyncHubLinkState.Disabled);
            return;
        }

        if (_connection is not null)
        {
            throw new InvalidOperationException("SignalR sync hub listener is already started.");
        }

        _options.ValidateTransportSecurity();
        SetLinkState(SyncHubLinkState.Connecting);

        var hubUrl = _options.ServerBaseAddress.TrimEnd('/') + SyncRoutes.Hub;
        try
        {
            _connection = new HubConnectionBuilder()
                .WithUrl(hubUrl, options =>
                {
                    // Backpressure buffers for inbound SyncDelta pages (not HubOptions.MaximumReceiveMessageSize).
                    // Keep aligned with server MapHub TransportMaxBufferSize; oversized pages wake→HTTP instead.
                    options.TransportMaxBufferSize = 2 * 1024 * 1024;
                    options.ApplicationMaxBufferSize = 2 * 1024 * 1024;
                    if (_credentials is not null)
                    {
                        options.AccessTokenProvider = async () =>
                            await _credentials.GetAccessTokenAsync(CancellationToken.None);
                    }
                })
                .WithAutomaticReconnect()
                .Build();

            if (_options.EnableDeltaStreaming)
            {
                _connection.On<byte[]>(SyncHubEvents.SyncDelta, async bytes =>
                {
                    var handlers = DeltaReceived;
                    if (handlers is null || bytes is null || bytes.Length == 0)
                    {
                        return;
                    }

                    await handlers(bytes, CancellationToken.None);
                });
            }

            _connection.On<SyncWake>(SyncHubEvents.SyncWake, async wake =>
            {
                // Always deliver wakes. Streaming clients still need HTTP catch-up when a
                // SyncDelta page is skipped (oversized), dropped, or races the checkpoint.
                var handlers = WakeReceived;
                if (handlers is null)
                {
                    return;
                }

                await handlers(wake, CancellationToken.None);
            });

            _connection.Reconnecting += _ =>
            {
                SetLinkState(SyncHubLinkState.Reconnecting);
                return Task.CompletedTask;
            };

            _connection.Closed += error =>
            {
                SetLinkState(error is null ? SyncHubLinkState.Disconnected : SyncHubLinkState.Failed);
                return Task.CompletedTask;
            };

            _connection.Reconnected += async _ =>
            {
                SetLinkState(SyncHubLinkState.Connected);
                await _connection.InvokeAsync(
                    SyncHubEvents.RegisterSyncClient,
                    string.IsNullOrWhiteSpace(_options.ClientId) ? _connection.ConnectionId ?? "client" : _options.ClientId,
                    CancellationToken.None);
                // Force HTTP catch-up after reconnect; stream resumes for subsequent mutations.
                if (WakeReceived is not null)
                {
                    await WakeReceived(new SyncWake { LatestVersion = 0, EntityNames = [] }, CancellationToken.None);
                }
            };

            await _connection.StartAsync(cancellationToken);
            var clientId = string.IsNullOrWhiteSpace(_options.ClientId)
                ? _connection.ConnectionId ?? "client"
                : _options.ClientId;
            await _connection.InvokeAsync(SyncHubEvents.RegisterSyncClient, clientId, cancellationToken);
            SetLinkState(SyncHubLinkState.Connected);
            _logger.LogInformation("SignalR sync hub connected at {HubUrl} as {ClientId}", hubUrl, clientId);
        }
        catch
        {
            SetLinkState(SyncHubLinkState.Failed);
            if (_connection is not null)
            {
                await _connection.DisposeAsync();
                _connection = null;
            }

            throw;
        }
    }

    public async Task ReconnectAsync(CancellationToken cancellationToken = default)
    {
        if (!_options.EnableSignalR)
        {
            SetLinkState(SyncHubLinkState.Disabled);
            return;
        }

        if (_connection is not null)
        {
            try
            {
                await _connection.DisposeAsync().ConfigureAwait(false);
            }
            catch (Exception ex)
            {
                _logger.LogDebug(ex, "Disposing prior SignalR hub connection during reconnect.");
            }

            _connection = null;
        }

        // Allow StartAsync to run again after a failed or exhausted connection.
        await StartAsync(cancellationToken).ConfigureAwait(false);
    }

    public async ValueTask DisposeAsync()
    {
        if (_connection is not null)
        {
            await _connection.DisposeAsync();
            _connection = null;
        }

        if (_linkState is not SyncHubLinkState.Disabled)
        {
            SetLinkState(SyncHubLinkState.Disconnected);
        }
    }

    private void SetLinkState(SyncHubLinkState state)
    {
        lock (_stateGate)
        {
            if (_linkState == state)
            {
                return;
            }

            _linkState = state;
        }

        try
        {
            LinkStateChanged?.Invoke(state);
        }
        catch (Exception ex)
        {
            _logger.LogDebug(ex, "LinkStateChanged subscriber threw.");
        }
    }
}
