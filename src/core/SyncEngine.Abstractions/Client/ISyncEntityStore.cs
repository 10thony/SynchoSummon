using SyncEngine.Abstractions.Entity;

namespace SyncEngine.Abstractions.Client;

/// <summary>Describes an entity change event for typed observation.</summary>
public enum SyncEntityEventKind
{
    /// <summary>An entity was inserted or updated.</summary>
    Upserted,

    /// <summary>An entity was deleted.</summary>
    Deleted,
}

/// <summary>Typed entity change event raised by <see cref="ISyncEntityStore{T}"/>.</summary>
/// <typeparam name="T">The sync entity type.</typeparam>
public readonly record struct SyncEntityEvent<T>(
    string Key,
    T? Entity,
    SyncEntityEventKind Kind) where T : class;

/// <summary>
/// Typed, queryable, observable entity store for client-side sync state.
/// Implementations wrap raw byte stores and decode via <c>IDeltaCodec</c>.
/// </summary>
/// <typeparam name="T">The sync entity type.</typeparam>
public interface ISyncEntityStore<T> where T : class
{
    /// <summary>Returns all entities of this type currently in the store.</summary>
    IReadOnlyList<T> GetAll();

    /// <summary>Returns the entity with the given key, or null if not found.</summary>
    T? GetByKey(string key);

    /// <summary>Returns all entities matching the predicate.</summary>
    IReadOnlyList<T> Query(Func<T, bool> predicate);

    /// <summary>Raised when any entity of this type is upserted or deleted.</summary>
    event Action<SyncEntityEvent<T>>? EntityChanged;
}
