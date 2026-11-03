using SyncEngine.Abstractions.Ledger;
using SyncEngine.Abstractions.Protocol;
using SyncEngine.Abstractions.Store;

namespace SyncEngine.Providers.Oracle;

public sealed class OracleChangeLedger(IOrgStore store) : IChangeLedger
{
    public async Task<long> GetCurrentVersionAsync(CancellationToken cancellationToken = default)
    {
        var rows = await store.QueryAsync<VersionRow>(
            "SELECT COALESCE(MAX(sync_version), 0) AS Version FROM sync_change",
            cancellationToken: cancellationToken);
        return rows.FirstOrDefault()?.Version ?? 0;
    }

    public async Task<long> AppendAsync(
        string entityName,
        DeltaOperation operation,
        ReadOnlyMemory<byte> keyBytes,
        ReadOnlyMemory<byte>? payloadBytes,
        string? correlationId = null,
        CancellationToken cancellationToken = default)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(entityName);
        if (keyBytes.IsEmpty)
        {
            throw new ArgumentException("Key bytes are required.", nameof(keyBytes));
        }

        var operationName = operation == DeltaOperation.Delete ? "DELETE" : "UPSERT";
        var keyArray = keyBytes.ToArray();
        var payloadArray = payloadBytes is { Length: > 0 } p ? p.ToArray() : null;

        // Oracle identity: insert then return via RETURNING into bind.
        await store.ExecuteAsync(
            """
            INSERT INTO sync_change (
                entity_name,
                operation_name,
                entity_key_bytes,
                payload_bytes,
                correlation_id)
            VALUES (
                :entityName,
                :operationName,
                :entityKeyBytes,
                :payloadBytes,
                :correlationId)
            RETURNING sync_version INTO :syncVersion
            """,
            new Dictionary<string, object?>
            {
                ["entityName"] = entityName,
                ["operationName"] = operationName,
                ["entityKeyBytes"] = keyArray,
                ["payloadBytes"] = payloadArray is null ? DBNull.Value : payloadArray,
                ["correlationId"] = correlationId,
                ["syncVersion"] = 0L,
            },
            cancellationToken);

        // ODP.NET RETURNING into input dictionary is awkward without out-params on our thin store.
        // Fall back to MAX after insert (same transaction sees the row).
        return await GetCurrentVersionAsync(cancellationToken);
    }

    public async Task<DeltaBatch> GetDeltasAsync(
        long sinceVersion,
        int limit,
        CancellationToken cancellationToken = default)
    {
        ArgumentOutOfRangeException.ThrowIfNegative(sinceVersion);
        ArgumentOutOfRangeException.ThrowIfNegativeOrZero(limit);

        // Fetch limit+1 to infer HasMore without a second COUNT round-trip.
        var fetch = limit + 1;
        var rows = await store.QueryAsync<ChangeRow>(
            """
            SELECT
                sync_version AS Version,
                entity_name AS EntityName,
                operation_name AS OperationName,
                entity_key_bytes AS KeyBytes,
                payload_bytes AS PayloadBytes
            FROM sync_change
            WHERE sync_version > :sinceVersion
            ORDER BY sync_version
            FETCH NEXT :limit ROWS ONLY
            """,
            new Dictionary<string, object?>
            {
                ["sinceVersion"] = sinceVersion,
                ["limit"] = fetch,
            },
            cancellationToken);

        var hasMore = rows.Count > limit;
        var page = hasMore ? rows.Take(limit).ToArray() : rows.ToArray();
        var changes = page.Select(static row => new DeltaChange
        {
            Version = row.Version,
            EntityName = row.EntityName,
            Operation = row.OperationName.Equals("DELETE", StringComparison.OrdinalIgnoreCase)
                ? DeltaOperation.Delete
                : DeltaOperation.Upsert,
            KeyBytes = row.KeyBytes ?? Array.Empty<byte>(),
            PayloadBytes = row.PayloadBytes,
        }).ToArray();

        return new DeltaBatch
        {
            FromVersion = sinceVersion,
            ToVersion = changes.Length == 0 ? sinceVersion : changes[^1].Version,
            HasMore = hasMore,
            Changes = changes,
        };
    }

    private sealed class VersionRow
    {
        public long Version { get; set; }
    }

    private sealed class ChangeRow
    {
        public long Version { get; set; }

        public string EntityName { get; set; } = string.Empty;

        public string OperationName { get; set; } = string.Empty;

        public byte[]? KeyBytes { get; set; }

        public byte[]? PayloadBytes { get; set; }
    }
}
