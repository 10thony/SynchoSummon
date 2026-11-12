using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Logging.Abstractions;
using SyncEngine.Abstractions.Client;
using SyncEngine.Abstractions.Protocol;

namespace SyncEngine.Client;

public enum UnknownEntityBehavior
{
    /// <summary>Log a warning and skip the entity. Default for agent safety.</summary>
    SkipAndWarn,

    /// <summary>Throw an <see cref="InvalidOperationException"/>. Use when handler coverage must be exhaustive.</summary>
    Throw,
}

public sealed class CompositeDeltaApplier : IClientDeltaApplier
{
    private readonly Dictionary<string, IEntityDeltaHandler> _handlers;
    private readonly UnknownEntityBehavior _unknownEntityBehavior;
    private readonly ILogger<CompositeDeltaApplier> _logger;
    private readonly HashSet<string> _warnedEntities = new(StringComparer.OrdinalIgnoreCase);

    public CompositeDeltaApplier(
        IEnumerable<IEntityDeltaHandler> handlers,
        UnknownEntityBehavior unknownEntityBehavior = UnknownEntityBehavior.SkipAndWarn,
        ILogger<CompositeDeltaApplier>? logger = null)
    {
        _handlers = handlers.ToDictionary(h => h.EntityName, StringComparer.OrdinalIgnoreCase);
        _unknownEntityBehavior = unknownEntityBehavior;
        _logger = logger ?? NullLogger<CompositeDeltaApplier>.Instance;
    }

    public async Task ApplyAsync(DeltaBatch batch, CancellationToken cancellationToken = default)
    {
        foreach (var change in batch.Changes.OrderBy(c => c.Version))
        {
            cancellationToken.ThrowIfCancellationRequested();
            if (!_handlers.TryGetValue(change.EntityName, out var handler))
            {
                if (_unknownEntityBehavior == UnknownEntityBehavior.Throw)
                {
                    throw new InvalidOperationException(
                        $"No delta handler registered for entity '{change.EntityName}'.");
                }

                if (_warnedEntities.Add(change.EntityName))
                {
                    _logger.LogWarning(
                        "SyncEngine: No delta handler registered for entity '{EntityName}'. " +
                        "Skipping. Register an IEntityDeltaHandler or call AddSyncEntity<T>() for this entity.",
                        change.EntityName);
                }

                continue;
            }

            await handler.ApplyAsync(change, cancellationToken);
        }
    }
}
