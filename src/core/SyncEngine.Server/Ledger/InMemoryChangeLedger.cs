using System.Collections.Concurrent;
using SyncEngine.Abstractions.Ledger;
using SyncEngine.Abstractions.Protocol;

namespace SyncEngine.Server.Ledger;

/// <summary>
/// Process-local ledger for benchmarks and tests without an org DB.
/// </summary>
public sealed class InMemoryChangeLedger : IChangeLedger
{
    private readonly ConcurrentQueue<DeltaChange> _changes = new();
    private long _version;

    public Task<long> GetCurrentVersionAsync(CancellationToken cancellationToken = default)
        => Task.FromResult(Interlocked.Read(ref _version));

    public Task<long> AppendAsync(
        string entityName,
        DeltaOperation operation,
        ReadOnlyMemory<byte> keyBytes,
        ReadOnlyMemory<byte>? payloadBytes,
        string? correlationId = null,
        CancellationToken cancellationToken = default)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(entityName);
        var version = Interlocked.Increment(ref _version);
        _changes.Enqueue(new DeltaChange
        {
            Version = version,
            EntityName = entityName,
            Operation = operation,
            KeyBytes = keyBytes.ToArray(),
            PayloadBytes = payloadBytes is { Length: > 0 } p ? p.ToArray() : null,
        });
        return Task.FromResult(version);
    }

    public Task<DeltaBatch> GetDeltasAsync(
        long sinceVersion,
        int limit,
        CancellationToken cancellationToken = default)
    {
        var page = _changes
            .Where(c => c.Version > sinceVersion)
            .OrderBy(c => c.Version)
            .Take(limit + 1)
            .ToArray();

        var hasMore = page.Length > limit;
        if (hasMore)
        {
            page = page.Take(limit).ToArray();
        }

        return Task.FromResult(new DeltaBatch
        {
            FromVersion = sinceVersion,
            ToVersion = page.Length == 0 ? sinceVersion : page[^1].Version,
            HasMore = hasMore,
            Changes = page,
        });
    }

    public void Clear()
    {
        while (_changes.TryDequeue(out _))
        {
        }

        Interlocked.Exchange(ref _version, 0);
    }
}
