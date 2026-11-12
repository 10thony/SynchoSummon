namespace SyncEngine.Abstractions.Entity;

/// <summary>
/// Marker interface for sync-enabled entity types.
/// Implement on model classes to enable typed registration via <c>AddSyncEntity&lt;T&gt;()</c>.
/// </summary>
public interface ISyncEntity
{
    /// <summary>The canonical sync entity name (e.g. "Equipment"). Used for handler routing.</summary>
    static abstract string EntityName { get; }
}

/// <summary>
/// Optional convenience base class providing common sync metadata.
/// Models may implement <see cref="ISyncEntity"/> directly if they prefer not to inherit.
/// </summary>
public abstract class SyncEntityBase : ISyncEntity
{
    /// <summary>
    /// Default implementation that forces derived classes to hide with <c>new static</c>.
    /// </summary>
    public static string EntityName => throw new NotImplementedException(
        "Derived classes must hide EntityName with 'new static string EntityName'.");

    /// <summary>UTC timestamp of last sync write (set by infrastructure, not user code).</summary>
    public DateTimeOffset? SyncTimestamp { get; set; }

    /// <summary>Sync version when this entity was last written.</summary>
    public long? SyncVersion { get; set; }
}
