using SyncEngine.Abstractions.Buffers;
using SyncEngine.Abstractions.Protocol;

namespace SyncEngine.Abstractions.Client;

public interface ISyncTransport
{
    Task<long> GetVersionAsync(CancellationToken cancellationToken = default);

    Task<PooledBuffer> GetDeltasBytesAsync(
        long sinceVersion,
        int limit,
        CancellationToken cancellationToken = default);
}

public interface ISyncWakeListener : IAsyncDisposable
{
    event Func<SyncWake, CancellationToken, Task>? WakeReceived;

    /// <summary>Raised when the hub pushes MemoryPack-encoded <see cref="DeltaBatch"/> bytes.</summary>
    event Func<ReadOnlyMemory<byte>, CancellationToken, Task>? DeltaReceived;

    /// <summary>Current SignalR hub link state. Prefer this over inferring connectivity from status strings.</summary>
    SyncHubLinkState LinkState { get; }

    /// <summary>Raised whenever <see cref="LinkState"/> changes.</summary>
    event Action<SyncHubLinkState>? LinkStateChanged;

    Task StartAsync(CancellationToken cancellationToken = default);

    /// <summary>
    /// Tear down any existing hub connection and start fresh.
    /// Used when the initial connect failed or automatic reconnect gave up,
    /// so the session can recover once the server is reachable again.
    /// </summary>
    Task ReconnectAsync(CancellationToken cancellationToken = default);
}
