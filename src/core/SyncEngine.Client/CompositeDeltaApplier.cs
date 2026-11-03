using SyncEngine.Abstractions.Client;
using SyncEngine.Abstractions.Protocol;

namespace SyncEngine.Client;

public sealed class CompositeDeltaApplier(IEnumerable<IEntityDeltaHandler> handlers) : IClientDeltaApplier
{
    private readonly Dictionary<string, IEntityDeltaHandler> _handlers =
        handlers.ToDictionary(h => h.EntityName, StringComparer.OrdinalIgnoreCase);

    public async Task ApplyAsync(DeltaBatch batch, CancellationToken cancellationToken = default)
    {
        foreach (var change in batch.Changes.OrderBy(c => c.Version))
        {
            cancellationToken.ThrowIfCancellationRequested();
            if (!_handlers.TryGetValue(change.EntityName, out var handler))
            {
                throw new InvalidOperationException(
                    $"No delta handler registered for entity '{change.EntityName}'.");
            }

            await handler.ApplyAsync(change, cancellationToken);
        }
    }
}
