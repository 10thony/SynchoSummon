using System.Net.Http.Headers;
using SyncEngine.Abstractions;
using SyncEngine.Abstractions.Auth;
using SyncEngine.Abstractions.Client;
using SyncEngine.Abstractions.Codec;
using SyncEngine.Abstractions.Protocol;

namespace SyncEngine.Client.Offline;

/// <summary>
/// Offline outbox: queues local mutations and pushes them when connectivity returns (server-wins on server).
/// Single-flight flush; versions assigned under the same lock as enqueue order.
/// </summary>
public sealed class ClientOutbox(ISyncCredentialProvider? credentials = null) : IAsyncDisposable
{
    private readonly List<DeltaChange> _pending = [];
    private readonly object _gate = new();
    private readonly SemaphoreSlim _flushLock = new(1, 1);
    private long _localVersion;
    private SyncOutboxPhase _phase = SyncOutboxPhase.Empty;

    public int PendingCount
    {
        get
        {
            lock (_gate)
            {
                return _pending.Count;
            }
        }
    }

    /// <summary>Explicit outbox lifecycle. Prefer this over inferring state from <see cref="PendingCount"/> alone.</summary>
    public SyncOutboxPhase Phase
    {
        get
        {
            lock (_gate)
            {
                return _phase;
            }
        }
    }

    public event Action<SyncOutboxPhase>? PhaseChanged;

    public void EnqueueUpsert(string entityName, ReadOnlyMemory<byte> keyBytes, ReadOnlyMemory<byte> payloadBytes)
    {
        lock (_gate)
        {
            _pending.Add(new DeltaChange
            {
                Version = ++_localVersion,
                EntityName = entityName,
                Operation = DeltaOperation.Upsert,
                KeyBytes = keyBytes.ToArray(),
                PayloadBytes = payloadBytes.ToArray(),
            });
            SetPhase_NoLock(SyncOutboxPhase.Pending);
        }
    }

    public void EnqueueDelete(string entityName, ReadOnlyMemory<byte> keyBytes)
    {
        lock (_gate)
        {
            _pending.Add(new DeltaChange
            {
                Version = ++_localVersion,
                EntityName = entityName,
                Operation = DeltaOperation.Delete,
                KeyBytes = keyBytes.ToArray(),
                PayloadBytes = null,
            });
            SetPhase_NoLock(SyncOutboxPhase.Pending);
        }
    }

    public async Task<int> FlushAsync(
        HttpClient httpClient,
        string serverBaseAddress,
        IDeltaCodec codec,
        CancellationToken cancellationToken = default,
        int maxChangesPerPush = 1000)
    {
        ArgumentOutOfRangeException.ThrowIfLessThan(maxChangesPerPush, 1);
        await _flushLock.WaitAsync(cancellationToken);
        SetPhase(SyncOutboxPhase.Flushing);
        try
        {
            var totalFlushed = 0;
            while (true)
            {
                DeltaChange[] snapshot;
                lock (_gate)
                {
                    if (_pending.Count == 0)
                    {
                        SetPhase_NoLock(SyncOutboxPhase.Empty);
                        return totalFlushed;
                    }

                    var take = Math.Min(maxChangesPerPush, _pending.Count);
                    snapshot = _pending.GetRange(0, take).ToArray();
                }

                var batch = new DeltaBatch
                {
                    FromVersion = 0,
                    ToVersion = snapshot[^1].Version,
                    HasMore = false,
                    Changes = snapshot,
                };

                using var buffer = codec.EncodeBatch(batch);
                using var content = new ByteArrayContent(buffer.Memory.ToArray());
                content.Headers.ContentType = new MediaTypeHeaderValue(SyncContentTypes.MemoryPack);

                using var request = new HttpRequestMessage(HttpMethod.Post, serverBaseAddress.TrimEnd('/') + SyncRoutes.Push)
                {
                    Content = content,
                };

                if (credentials is not null)
                {
                    var token = await credentials.GetAccessTokenAsync(cancellationToken);
                    if (!string.IsNullOrWhiteSpace(token))
                    {
                        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);
                    }
                }

                using var response = await httpClient.SendAsync(request, cancellationToken);
                response.EnsureSuccessStatusCode();

                lock (_gate)
                {
                    // Single-flight + append-only: flushed items remain the prefix.
                    if (_pending.Count < snapshot.Length
                        || !PrefixMatches(_pending, snapshot))
                    {
                        throw new InvalidOperationException(
                            "Outbox prefix changed during flush; concurrent mutation of pending list is not supported.");
                    }

                    _pending.RemoveRange(0, snapshot.Length);
                }

                totalFlushed += snapshot.Length;
                if (snapshot.Length < maxChangesPerPush)
                {
                    SetPhase(PendingCount == 0 ? SyncOutboxPhase.Empty : SyncOutboxPhase.Pending);
                    return totalFlushed;
                }
            }
        }
        catch
        {
            SetPhase(PendingCount == 0 ? SyncOutboxPhase.Empty : SyncOutboxPhase.Failed);
            throw;
        }
        finally
        {
            _flushLock.Release();
        }
    }

    private void SetPhase(SyncOutboxPhase phase)
    {
        var raise = false;
        lock (_gate)
        {
            if (_phase != phase)
            {
                _phase = phase;
                raise = true;
            }
        }

        if (raise)
        {
            PhaseChanged?.Invoke(phase);
        }
    }

    private void SetPhase_NoLock(SyncOutboxPhase phase)
    {
        // Caller holds _gate. Defer PhaseChanged until after the lock when possible;
        // enqueue paths invoke while still holding the lock (same as prior PendingCount usage).
        if (_phase == phase)
        {
            return;
        }

        _phase = phase;
        PhaseChanged?.Invoke(phase);
    }

    private static bool PrefixMatches(List<DeltaChange> pending, DeltaChange[] snapshot)
    {
        for (var i = 0; i < snapshot.Length; i++)
        {
            var a = pending[i];
            var b = snapshot[i];
            if (a.Version != b.Version
                || !string.Equals(a.EntityName, b.EntityName, StringComparison.Ordinal)
                || a.Operation != b.Operation
                || !BytesEqual(a.KeyBytes, b.KeyBytes))
            {
                return false;
            }
        }

        return true;
    }

    private static bool BytesEqual(byte[]? left, byte[]? right)
    {
        if (ReferenceEquals(left, right))
        {
            return true;
        }

        if (left is null || right is null || left.Length != right.Length)
        {
            return false;
        }

        return left.AsSpan().SequenceEqual(right);
    }

    public ValueTask DisposeAsync()
    {
        _flushLock.Dispose();
        return ValueTask.CompletedTask;
    }
}
