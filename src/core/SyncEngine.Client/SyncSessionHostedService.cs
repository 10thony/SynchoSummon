using Microsoft.Extensions.Hosting;
using SyncEngine.Abstractions.Client;

namespace SyncEngine.Client;

/// <summary>
/// Generic host runner for <see cref="ISyncSession"/>. Prefer this over inventing per-app sync loops.
/// UI hosts that need custom status mapping (e.g. Aviation Blazor) can keep a thin adapter instead.
/// </summary>
public sealed class SyncSessionHostedService(ISyncSession session) : IHostedService
{
    public Task StartAsync(CancellationToken cancellationToken)
        => session.StartAsync(cancellationToken);

    public Task StopAsync(CancellationToken cancellationToken)
        => session.StopAsync(cancellationToken);
}
