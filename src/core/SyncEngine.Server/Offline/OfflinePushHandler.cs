using SyncEngine.Abstractions.Codec;
using SyncEngine.Abstractions.Protocol;
using SyncEngine.Server.Ledger;

namespace SyncEngine.Server.Offline;

/// <summary>
/// Accepts client outbox batches (MemoryPack DeltaBatch) and applies server-wins: append to ledger as authoritative.
/// Entity persistence into org DB is delegated via <see cref="IOfflineEntityApplicator"/>.
/// </summary>
public sealed class OfflinePushHandler(
    IDeltaCodec codec,
    ChangeLedgerWriter ledgerWriter,
    IOfflineEntityApplicator applicator)
{
    public async Task<OfflinePushResult> HandleAsync(ReadOnlyMemory<byte> body, CancellationToken cancellationToken)
    {
        var batch = codec.DecodeBatch(body.Span);
        var applied = 0;
        long lastVersion = 0;

        foreach (var change in batch.Changes.OrderBy(c => c.Version))
        {
            cancellationToken.ThrowIfCancellationRequested();

            // Server-wins: org DB apply first, then ledger.
            await applicator.ApplyFromClientAsync(change, cancellationToken);

            lastVersion = change.Operation == DeltaOperation.Delete
                ? await ledgerWriter.RecordDeleteAsync(
                    change.EntityName,
                    change.KeyBytes,
                    cancellationToken: cancellationToken)
                : await ledgerWriter.RecordUpsertAsync(
                    change.EntityName,
                    change.KeyBytes,
                    change.PayloadBytes ?? Array.Empty<byte>(),
                    cancellationToken: cancellationToken);

            applied++;
        }

        return new OfflinePushResult(applied, lastVersion);
    }
}

public interface IOfflineEntityApplicator
{
    Task ApplyFromClientAsync(DeltaChange change, CancellationToken cancellationToken = default);
}

public sealed class NoOpOfflineEntityApplicator : IOfflineEntityApplicator
{
    public Task ApplyFromClientAsync(DeltaChange change, CancellationToken cancellationToken = default)
        => Task.CompletedTask;
}

public sealed record OfflinePushResult(int AppliedCount, long LatestVersion);
