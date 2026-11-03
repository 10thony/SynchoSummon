using SyncEngine.Abstractions.Ledger;
using SyncEngine.Abstractions.Notify;
using SyncEngine.Abstractions.Protocol;
using SyncEngine.Abstractions.Store;
using SyncEngine.Abstractions.Telemetry;
using SyncEngine.Server.Telemetry;

namespace SyncEngine.Server.Ledger;

/// <summary>
/// Records entity changes into the durable ledger and enqueues coalesced wakes.
/// </summary>
public sealed class ChangeLedgerWriter(
    IChangeLedger ledger,
    IOrgStore orgStore,
    ISyncNotifier notifier,
    ISyncTelemetry telemetry)
{
    public async Task<long> RecordUpsertAsync(
        string entityName,
        ReadOnlyMemory<byte> keyBytes,
        ReadOnlyMemory<byte> payloadBytes,
        string? correlationId = null,
        CancellationToken cancellationToken = default)
    {
        return await RecordAsync(
            entityName,
            DeltaOperation.Upsert,
            keyBytes,
            payloadBytes,
            correlationId,
            cancellationToken);
    }

    public async Task<long> RecordDeleteAsync(
        string entityName,
        ReadOnlyMemory<byte> keyBytes,
        string? correlationId = null,
        CancellationToken cancellationToken = default)
    {
        return await RecordAsync(
            entityName,
            DeltaOperation.Delete,
            keyBytes,
            payloadBytes: null,
            correlationId,
            cancellationToken);
    }

    private async Task<long> RecordAsync(
        string entityName,
        DeltaOperation operation,
        ReadOnlyMemory<byte> keyBytes,
        ReadOnlyMemory<byte>? payloadBytes,
        string? correlationId,
        CancellationToken cancellationToken)
    {
        var version = await ledger.AppendAsync(
            entityName,
            operation,
            keyBytes,
            payloadBytes,
            correlationId,
            cancellationToken);

        var payloadLen = payloadBytes?.Length ?? 0;
        telemetry.Record(new SyncTelemetryEvent
        {
            Kind = SyncTelemetryKind.Write,
            Direction = "app→ledger",
            EntityName = entityName,
            ToVersion = version,
            ChangeCount = 1,
            Bytes = keyBytes.Length + payloadLen,
            CorrelationId = correlationId,
            Summary = $"{operation} {entityName} → sync_version={version}",
            PayloadPreview = $"keyBytes={keyBytes.Length}, payloadBytes={payloadLen}",
        });

        if (orgStore.HasActiveTransaction)
        {
            orgStore.RegisterPostCommitAction(token =>
                notifier.EnqueueWakeAsync(version, entityName, token).AsTask());
        }
        else
        {
            await notifier.EnqueueWakeAsync(version, entityName, cancellationToken);
        }

        return version;
    }
}
