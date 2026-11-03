using SyncEngine.Abstractions.Protocol;

namespace SyncEngine.Abstractions.Ledger;

public interface IChangeLedger
{
    Task<long> GetCurrentVersionAsync(CancellationToken cancellationToken = default);

    Task<long> AppendAsync(
        string entityName,
        DeltaOperation operation,
        ReadOnlyMemory<byte> keyBytes,
        ReadOnlyMemory<byte>? payloadBytes,
        string? correlationId = null,
        CancellationToken cancellationToken = default);

    Task<DeltaBatch> GetDeltasAsync(
        long sinceVersion,
        int limit,
        CancellationToken cancellationToken = default);
}
