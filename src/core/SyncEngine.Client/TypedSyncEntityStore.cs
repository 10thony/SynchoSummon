using SyncEngine.Abstractions.Client;
using SyncEngine.Abstractions.Codec;

namespace SyncEngine.Client;

/// <summary>
/// Typed entity store that wraps <see cref="InMemoryEntityStore"/> and decodes
/// entities via <see cref="IDeltaCodec"/>.
/// </summary>
/// <typeparam name="T">The sync entity type.</typeparam>
public sealed class TypedSyncEntityStore<T> : ISyncEntityStore<T> where T : class
{
    private readonly string _entityName;
    private readonly InMemoryEntityStore _store;
    private readonly IDeltaCodec _codec;

    /// <summary>Initializes a new <see cref="TypedSyncEntityStore{T}"/>.</summary>
    /// <param name="entityName">The canonical sync entity name.</param>
    /// <param name="store">The raw byte store.</param>
    /// <param name="codec">The codec used to decode entity payloads.</param>
    public TypedSyncEntityStore(string entityName, InMemoryEntityStore store, IDeltaCodec codec)
    {
        _entityName = entityName;
        _store = store;
        _codec = codec;
        _store.EntityChanged += OnEntityChanged;
    }

    /// <inheritdoc />
    public event Action<SyncEntityEvent<T>>? EntityChanged;

    /// <inheritdoc />
    public IReadOnlyList<T> GetAll()
    {
        var raw = _store.GetAll(_entityName);
        var result = new List<T>(raw.Count);
        foreach (var (key, bytes) in raw)
        {
            try
            {
                result.Add(_codec.Decode<T>(bytes));
            }
            catch
            {
                // Skip entries that fail to decode
            }
        }

        return result;
    }

    /// <inheritdoc />
    public T? GetByKey(string key)
    {
        var raw = _store.GetAll(_entityName);
        if (raw is IReadOnlyDictionary<string, byte[]> dict && dict.TryGetValue(key, out var bytes))
        {
            try
            {
                return _codec.Decode<T>(bytes);
            }
            catch
            {
                return null;
            }
        }

        return null;
    }

    /// <inheritdoc />
    public IReadOnlyList<T> Query(Func<T, bool> predicate)
    {
        var all = GetAll();
        var result = new List<T>();
        foreach (var entity in all)
        {
            if (predicate(entity))
            {
                result.Add(entity);
            }
        }

        return result;
    }

    private void OnEntityChanged(string entityName)
    {
        if (!string.Equals(entityName, _entityName, StringComparison.OrdinalIgnoreCase))
        {
            return;
        }

        EntityChanged?.Invoke(new SyncEntityEvent<T>(string.Empty, null, SyncEntityEventKind.Upserted));
    }
}
