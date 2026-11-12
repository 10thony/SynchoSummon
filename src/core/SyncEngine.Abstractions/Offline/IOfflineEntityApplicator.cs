using SyncEngine.Abstractions.Protocol;

namespace SyncEngine.Abstractions.Offline;

/// <summary>
/// Applies offline client pushes into the org/entity store.
/// Generated code implements this; the push handler delegates to it.
/// </summary>
public interface IOfflineEntityApplicator
{
    /// <summary>Apply a single change pushed from an offline client.</summary>
    Task ApplyFromClientAsync(DeltaChange change, CancellationToken cancellationToken = default);
}
