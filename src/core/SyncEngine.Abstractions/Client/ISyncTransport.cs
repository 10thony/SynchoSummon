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

    Task StartAsync(CancellationToken cancellationToken = default);
}
