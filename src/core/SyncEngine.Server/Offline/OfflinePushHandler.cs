using SyncEngine.Abstractions.Auth;
using SyncEngine.Abstractions.Codec;
using SyncEngine.Abstractions.Ledger;
using SyncEngine.Abstractions.Offline;
using SyncEngine.Abstractions.Protocol;

namespace SyncEngine.Server.Offline;

/// <summary>
/// Accepts client outbox batches (MemoryPack DeltaBatch) and applies server-wins: append to ledger as authoritative.
/// Entity persistence into org DB is delegated via <see cref="IOfflineEntityApplicator"/>.
/// </summary>
public sealed class OfflinePushHandler(
    IDeltaCodec codec,
    IChangeLedgerWriter ledgerWriter,
    IOfflineEntityApplicator applicator,
    ISyncAuthorization authorization,
    SyncPushLimits limits)
{
    private readonly SyncPushLimits _limits = limits;

    public async Task<OfflinePushResult> HandleAsync(
        ReadOnlyMemory<byte> body,
        SyncPrincipal principal,
        CancellationToken cancellationToken)
    {
        if (body.Length > _limits.MaxBodyBytes)
        {
            throw new SyncPushRejectedException(
                $"Push body exceeds {_limits.MaxBodyBytes} bytes.");
        }

        DeltaBatch batch;
        try
        {
            batch = codec.DecodeBatch(body.Span);
        }
        catch (Exception ex)
        {
            throw new SyncPushRejectedException("Invalid MemoryPack delta batch.", ex);
        }

        if (batch.Changes is null)
        {
            return new OfflinePushResult(0, 0);
        }

        if (batch.Changes.Length > _limits.MaxChanges)
        {
            throw new SyncPushRejectedException(
                $"Push exceeds {_limits.MaxChanges} changes.");
        }

        var applied = 0;
        long lastVersion = 0;
        var allowedEntities = _limits.AllowedEntityNames;

        foreach (var change in batch.Changes.OrderBy(c => c.Version))
        {
            cancellationToken.ThrowIfCancellationRequested();

            if (string.IsNullOrWhiteSpace(change.EntityName))
            {
                throw new SyncPushRejectedException("Change is missing EntityName.");
            }

            if (allowedEntities is { Count: > 0 }
                && !allowedEntities.Contains(change.EntityName))
            {
                throw new SyncPushRejectedException(
                    $"Entity '{change.EntityName}' is not allowed for push.");
            }

            if (change.KeyBytes is null || change.KeyBytes.Length == 0)
            {
                throw new SyncPushRejectedException("Change is missing KeyBytes.");
            }

            if (change.KeyBytes.Length > _limits.MaxKeyBytes)
            {
                throw new SyncPushRejectedException(
                    $"KeyBytes exceeds {_limits.MaxKeyBytes} bytes.");
            }

            if (change.PayloadBytes is { Length: var payloadLen }
                && payloadLen > _limits.MaxPayloadBytes)
            {
                throw new SyncPushRejectedException(
                    $"PayloadBytes exceeds {_limits.MaxPayloadBytes} bytes.");
            }

            if (!authorization.CanPush(
                    principal,
                    change.EntityName,
                    change.KeyBytes,
                    change.Operation,
                    principal.TenantId))
            {
                throw new SyncPushRejectedException(
                    $"Principal '{principal.ClientId}' cannot push '{change.EntityName}'.");
            }

            var scoped = change;
            if (!string.IsNullOrWhiteSpace(principal.TenantId))
            {
                scoped.TenantId = principal.TenantId;
            }

            await applicator.ApplyFromClientAsync(scoped, cancellationToken);

            lastVersion = scoped.Operation == DeltaOperation.Delete
                ? await ledgerWriter.RecordDeleteAsync(
                    scoped.EntityName,
                    scoped.KeyBytes,
                    cancellationToken: cancellationToken)
                : await ledgerWriter.RecordUpsertAsync(
                    scoped.EntityName,
                    scoped.KeyBytes,
                    scoped.PayloadBytes ?? Array.Empty<byte>(),
                    cancellationToken: cancellationToken);

            applied++;
        }

        return new OfflinePushResult(applied, lastVersion);
    }
}

public sealed class NoOpOfflineEntityApplicator : IOfflineEntityApplicator
{
    public Task ApplyFromClientAsync(DeltaChange change, CancellationToken cancellationToken = default)
        => Task.CompletedTask;
}

public sealed record OfflinePushResult(int AppliedCount, long LatestVersion);

public sealed class SyncPushRejectedException : InvalidOperationException
{
    public SyncPushRejectedException(string message) : base(message)
    {
    }

    public SyncPushRejectedException(string message, Exception inner) : base(message, inner)
    {
    }
}
