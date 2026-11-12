namespace SyncEngine.Abstractions.Ledger;

/// <summary>
/// Abstraction over ledger write operations. Server code and generated stores
/// should depend on this interface rather than concrete ChangeLedgerWriter.
/// </summary>
public interface IChangeLedgerWriter
{
    /// <summary>Record an upsert (insert or update) for the given entity and key.</summary>
    Task<long> RecordUpsertAsync(
        string entityName,
        ReadOnlyMemory<byte> keyBytes,
        ReadOnlyMemory<byte> payloadBytes,
        string? correlationId = null,
        CancellationToken cancellationToken = default);

    /// <summary>Record a delete for the given entity and key.</summary>
    Task<long> RecordDeleteAsync(
        string entityName,
        ReadOnlyMemory<byte> keyBytes,
        string? correlationId = null,
        CancellationToken cancellationToken = default);

    /// <summary>Enqueue a single coalesced wake after a silent multi-row batch.</summary>
    ValueTask EnqueueWakeAsync(
        long version,
        string entityName,
        string? tenantId = null,
        CancellationToken cancellationToken = default);
}
