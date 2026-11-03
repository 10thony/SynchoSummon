using System.Collections.Concurrent;
using SyncEngine.Abstractions.Client;
using SyncEngine.Abstractions.Codec;
using SyncEngine.Abstractions.Protocol;

namespace SyncEngine.Client;

/// <summary>
/// Process-local entity bag used by Blazor demos and unit tests.
/// </summary>
public sealed class InMemoryEntityStore
{
    private readonly ConcurrentDictionary<string, ConcurrentDictionary<string, byte[]>> _entities = new(StringComparer.OrdinalIgnoreCase);

    public event Action<string>? EntityChanged;

    public IReadOnlyDictionary<string, byte[]> GetAll(string entityName)
    {
        if (_entities.TryGetValue(entityName, out var map))
        {
            return map;
        }

        return new Dictionary<string, byte[]>();
    }

    public void Upsert(string entityName, string key, byte[] payload)
    {
        var map = _entities.GetOrAdd(entityName, _ => new ConcurrentDictionary<string, byte[]>(StringComparer.Ordinal));
        map[key] = payload;
        EntityChanged?.Invoke(entityName);
    }

    public void Delete(string entityName, string key)
    {
        if (_entities.TryGetValue(entityName, out var map))
        {
            map.TryRemove(key, out _);
            EntityChanged?.Invoke(entityName);
        }
    }
}

public sealed class InMemoryEntityDeltaHandler(string entityName, InMemoryEntityStore store)
    : IEntityDeltaHandler
{
    public string EntityName { get; } = entityName;

    public Task ApplyAsync(DeltaChange change, CancellationToken cancellationToken = default)
    {
        var key = Convert.ToHexString(change.KeyBytes);
        if (change.Operation == DeltaOperation.Delete)
        {
            store.Delete(EntityName, key);
        }
        else
        {
            store.Upsert(EntityName, key, change.PayloadBytes ?? Array.Empty<byte>());
        }

        return Task.CompletedTask;
    }
}
