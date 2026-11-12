using SyncEngine.Abstractions.Protocol;

namespace SyncEngine.Abstractions.Client;

/// <summary>
/// Notifies subscribers when a delta batch has been applied to the client store.
/// Implemented by <c>SyncPullService</c> and <c>SqliteBatchApplier</c>.
/// </summary>
public interface ISyncBatchNotifier
{
    /// <summary>Raised after a batch of changes has been applied.</summary>
    event Action<DeltaBatch>? BatchApplied;
}
