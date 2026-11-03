using System.Threading.Channels;
using SyncEngine.Abstractions;
using SyncEngine.Abstractions.Buffers;
using SyncEngine.Abstractions.Codec;
using SyncEngine.Abstractions.Protocol;

namespace SyncEngine.Client.Offline;

/// <summary>
/// Offline outbox: queues local mutations and pushes them when connectivity returns (server-wins on server).
/// </summary>
public sealed class ClientOutbox
{
    private readonly Channel<DeltaChange> _channel = Channel.CreateUnbounded<DeltaChange>();
    private readonly List<DeltaChange> _pending = [];
    private readonly object _gate = new();
    private long _localVersion;

    public void EnqueueUpsert(string entityName, ReadOnlyMemory<byte> keyBytes, ReadOnlyMemory<byte> payloadBytes)
    {
        Enqueue(new DeltaChange
        {
            Version = Interlocked.Increment(ref _localVersion),
            EntityName = entityName,
            Operation = DeltaOperation.Upsert,
            KeyBytes = keyBytes.ToArray(),
            PayloadBytes = payloadBytes.ToArray(),
        });
    }

    public void EnqueueDelete(string entityName, ReadOnlyMemory<byte> keyBytes)
    {
        Enqueue(new DeltaChange
        {
            Version = Interlocked.Increment(ref _localVersion),
            EntityName = entityName,
            Operation = DeltaOperation.Delete,
            KeyBytes = keyBytes.ToArray(),
            PayloadBytes = null,
        });
    }

    public async Task<int> FlushAsync(
        HttpClient httpClient,
        string serverBaseAddress,
        IDeltaCodec codec,
        CancellationToken cancellationToken = default)
    {
        DeltaChange[] snapshot;
        lock (_gate)
        {
            while (_channel.Reader.TryRead(out var item))
            {
                _pending.Add(item);
            }

            snapshot = _pending.ToArray();
        }

        if (snapshot.Length == 0)
        {
            return 0;
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
        content.Headers.ContentType = new System.Net.Http.Headers.MediaTypeHeaderValue(SyncContentTypes.MemoryPack);

        var url = serverBaseAddress.TrimEnd('/') + SyncRoutes.Push;
        using var response = await httpClient.PostAsync(url, content, cancellationToken);
        response.EnsureSuccessStatusCode();

        lock (_gate)
        {
            _pending.Clear();
        }

        return snapshot.Length;
    }

    private void Enqueue(DeltaChange change)
    {
        lock (_gate)
        {
            _pending.Add(change);
        }

        _channel.Writer.TryWrite(change);
    }
}
