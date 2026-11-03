using MemoryPack;
using SyncEngine.Abstractions.Buffers;
using SyncEngine.Abstractions.Codec;
using SyncEngine.Abstractions.Protocol;

namespace SyncEngine.Client.Codec;

public sealed class MemoryPackDeltaCodec : IDeltaCodec
{
    public PooledBuffer EncodeBatch(in DeltaBatch batch) => Encode(batch);

    public DeltaBatch DecodeBatch(ReadOnlySpan<byte> data) => Decode<DeltaBatch>(data);

    public PooledBuffer EncodeWake(in SyncWake wake) => Encode(wake);

    public SyncWake DecodeWake(ReadOnlySpan<byte> data) => Decode<SyncWake>(data);

    public PooledBuffer EncodeVersion(in SyncVersion version) => Encode(version);

    public SyncVersion DecodeVersion(ReadOnlySpan<byte> data) => Decode<SyncVersion>(data);

    public PooledBuffer Encode<T>(in T value)
    {
        using var writer = new PooledArrayBufferWriter(1024);
        MemoryPackSerializer.Serialize(writer, value);
        return writer.DetachWritten();
    }

    public T Decode<T>(ReadOnlySpan<byte> data)
    {
        return MemoryPackSerializer.Deserialize<T>(data)
            ?? throw new InvalidOperationException($"Failed to deserialize {typeof(T).Name}.");
    }
}
