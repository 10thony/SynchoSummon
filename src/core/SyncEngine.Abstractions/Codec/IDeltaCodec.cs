using SyncEngine.Abstractions.Buffers;
using SyncEngine.Abstractions.Protocol;

namespace SyncEngine.Abstractions.Codec;

public interface IDeltaCodec
{
    PooledBuffer EncodeBatch(in DeltaBatch batch);

    DeltaBatch DecodeBatch(ReadOnlySpan<byte> data);

    PooledBuffer EncodeWake(in SyncWake wake);

    SyncWake DecodeWake(ReadOnlySpan<byte> data);

    PooledBuffer EncodeVersion(in SyncVersion version);

    SyncVersion DecodeVersion(ReadOnlySpan<byte> data);

    PooledBuffer Encode<T>(in T value);

    T Decode<T>(ReadOnlySpan<byte> data);
}
