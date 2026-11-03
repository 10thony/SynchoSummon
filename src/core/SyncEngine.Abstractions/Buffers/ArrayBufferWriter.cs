using System.Buffers;

namespace SyncEngine.Abstractions.Buffers;

/// <summary>
/// Growable <see cref="IBufferWriter{T}"/> backed by <see cref="ArrayPool{T}"/>.
/// </summary>
public sealed class PooledArrayBufferWriter : IBufferWriter<byte>, IDisposable
{
    private byte[] _buffer;
    private int _index;

    public PooledArrayBufferWriter(int initialCapacity = 4096)
    {
        ArgumentOutOfRangeException.ThrowIfNegativeOrZero(initialCapacity);
        _buffer = ArrayPool<byte>.Shared.Rent(initialCapacity);
    }

    public ReadOnlyMemory<byte> WrittenMemory => _buffer.AsMemory(0, _index);

    public ReadOnlySpan<byte> WrittenSpan => _buffer.AsSpan(0, _index);

    public int WrittenCount => _index;

    public void Advance(int count)
    {
        ArgumentOutOfRangeException.ThrowIfNegative(count);
        if (_index + count > _buffer.Length)
        {
            throw new InvalidOperationException("Cannot advance past the end of the buffer.");
        }

        _index += count;
    }

    public Memory<byte> GetMemory(int sizeHint = 0)
    {
        CheckAndResize(sizeHint);
        return _buffer.AsMemory(_index);
    }

    public Span<byte> GetSpan(int sizeHint = 0)
    {
        CheckAndResize(sizeHint);
        return _buffer.AsSpan(_index);
    }

    public PooledBuffer DetachWritten()
    {
        var written = _index;
        var buffer = _buffer;
        _buffer = ArrayPool<byte>.Shared.Rent(4096);
        _index = 0;
        return PooledBuffer.FromWritten(buffer, written);
    }

    public void Clear() => _index = 0;

    public void Dispose()
    {
        var buffer = Interlocked.Exchange(ref _buffer!, null!);
        if (buffer is not null)
        {
            ArrayPool<byte>.Shared.Return(buffer);
        }
    }

    private void CheckAndResize(int sizeHint)
    {
        if (sizeHint < 0)
        {
            sizeHint = 0;
        }

        var available = _buffer.Length - _index;
        if (sizeHint == 0)
        {
            sizeHint = 1;
        }

        if (sizeHint <= available)
        {
            return;
        }

        var growBy = Math.Max(sizeHint, _buffer.Length);
        var newSize = checked(_buffer.Length + growBy);
        var newBuffer = ArrayPool<byte>.Shared.Rent(newSize);
        _buffer.AsSpan(0, _index).CopyTo(newBuffer);
        ArrayPool<byte>.Shared.Return(_buffer);
        _buffer = newBuffer;
    }
}
