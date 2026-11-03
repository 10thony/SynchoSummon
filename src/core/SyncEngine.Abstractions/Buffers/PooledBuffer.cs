using System.Buffers;

namespace SyncEngine.Abstractions.Buffers;

/// <summary>
/// Rents an <see cref="ArrayPool{T}"/> buffer and returns it on dispose.
/// </summary>
public sealed class PooledBuffer : IMemoryOwner<byte>
{
    private byte[]? _array;
    private readonly int _length;

    private PooledBuffer(byte[] array, int length)
    {
        _array = array;
        _length = length;
    }

    public Memory<byte> Memory =>
        _array is null
            ? throw new ObjectDisposedException(nameof(PooledBuffer))
            : _array.AsMemory(0, _length);

    public static PooledBuffer Rent(int minimumLength)
    {
        ArgumentOutOfRangeException.ThrowIfNegativeOrZero(minimumLength);
        var array = ArrayPool<byte>.Shared.Rent(minimumLength);
        return new PooledBuffer(array, minimumLength);
    }

    public static PooledBuffer FromWritten(byte[] rented, int writtenLength)
    {
        ArgumentNullException.ThrowIfNull(rented);
        ArgumentOutOfRangeException.ThrowIfNegative(writtenLength);
        return new PooledBuffer(rented, writtenLength);
    }

    public void Dispose()
    {
        var array = Interlocked.Exchange(ref _array, null);
        if (array is not null)
        {
            ArrayPool<byte>.Shared.Return(array);
        }
    }
}
