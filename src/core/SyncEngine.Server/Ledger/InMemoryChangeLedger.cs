using System.Collections.Concurrent;
using SyncEngine.Abstractions.Ledger;
using SyncEngine.Abstractions.Protocol;

namespace SyncEngine.Server.Ledger;

/// <summary>
/// Process-local ledger for benchmarks and tests without an org DB.
/// Bounded ring retains the newest <see cref="Capacity"/> changes.
/// Requests that need versions older than the ring throw rather than silently omitting history.
/// </summary>
public sealed class InMemoryChangeLedger : IChangeLedger
{
    private readonly ConcurrentQueue<DeltaChange> _changes = new();
    private long _version;
    private int _count;

    public int Capacity { get; }

    public InMemoryChangeLedger(int capacity = 100_000)
    {
        ArgumentOutOfRangeException.ThrowIfLessThan(capacity, 1);
        Capacity = capacity;
    }

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

        var count = Interlocked.Increment(ref _count);
        while (count > Capacity && _changes.TryDequeue(out _))
        {
            count = Interlocked.Decrement(ref _count);
        }

        return Task.FromResult(version);
    }

    public Task<DeltaBatch> GetDeltasAsync(
        long sinceVersion,
        int limit,
        CancellationToken cancellationToken = default)
    {
        ArgumentOutOfRangeException.ThrowIfNegative(sinceVersion);
        ArgumentOutOfRangeException.ThrowIfLessThan(limit, 1);

        // Snapshot first so truncation checks and paging see a consistent set.
        var snapshot = _changes.ToArray();
        if (snapshot.Length > 0)
        {
            // Min version, not queue[0]: concurrent Append can enqueue out of version order.
            var oldest = snapshot[0].Version;
            for (var i = 1; i < snapshot.Length; i++)
            {
                if (snapshot[i].Version < oldest)
                {
                    oldest = snapshot[i].Version;
                }
            }

            if (sinceVersion + 1 < oldest)
            {
                throw new InvalidOperationException(
                    $"InMemoryChangeLedger truncated: oldest retained v{oldest}, requested since={sinceVersion}, capacity={Capacity}. " +
                    "Increase capacity (phone-scale soak) or bootstrap from a snapshot.");
            }
        }

        var page = snapshot
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

        Interlocked.Exchange(ref _count, 0);
        Interlocked.Exchange(ref _version, 0);
    }
}
