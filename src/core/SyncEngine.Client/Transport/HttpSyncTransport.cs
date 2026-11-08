using System.Buffers;
using Microsoft.Extensions.Options;
using SyncEngine.Abstractions;
using SyncEngine.Abstractions.Buffers;
using SyncEngine.Abstractions.Client;
using SyncEngine.Abstractions.Codec;

namespace SyncEngine.Client.Transport;

public sealed class HttpSyncTransport : ISyncTransport
{
    private readonly HttpClient _httpClient;
    private readonly IDeltaCodec _codec;
    private readonly SyncClientOptions _options;

    public HttpSyncTransport(
        HttpClient httpClient,
        IDeltaCodec codec,
        IOptions<SyncClientOptions> options)
    {
        _httpClient = httpClient;
        _codec = codec;
        _options = options.Value;
        _options.ValidateTransportSecurity();

        if (!_httpClient.DefaultRequestHeaders.Contains("X-Sync-Client-Id"))
        {
            _httpClient.DefaultRequestHeaders.TryAddWithoutValidation("X-Sync-Client-Id", _options.ClientId);
        }
    }

    public async Task<long> GetVersionAsync(CancellationToken cancellationToken = default)
    {
        using var response = await _httpClient.GetAsync(
            Combine(_options.ServerBaseAddress, SyncRoutes.Version),
            HttpCompletionOption.ResponseHeadersRead,
            cancellationToken);
        response.EnsureSuccessStatusCode();
        EnsureDeclaredSize(response);
        using var buffer = await ReadBoundedAsync(response, cancellationToken);
        return _codec.DecodeVersion(buffer.Memory.Span).Version;
    }

    public async Task<PooledBuffer> GetDeltasBytesAsync(
        long sinceVersion,
        int limit,
        CancellationToken cancellationToken = default)
    {
        var url = $"{Combine(_options.ServerBaseAddress, SyncRoutes.Deltas)}?since={sinceVersion}&limit={limit}";
        using var response = await _httpClient.GetAsync(url, HttpCompletionOption.ResponseHeadersRead, cancellationToken);
        response.EnsureSuccessStatusCode();
        EnsureDeclaredSize(response);
        return await ReadBoundedAsync(response, cancellationToken);
    }

    private void EnsureDeclaredSize(HttpResponseMessage response)
    {
        if (response.Content.Headers.ContentLength is long length)
        {
            EnsureByteLength(checked((int)Math.Min(length, int.MaxValue)));
        }
    }

    /// <summary>
    /// Reads the body while enforcing MaxResponseBytes even when Content-Length is absent (chunked).
    /// </summary>
    private async Task<PooledBuffer> ReadBoundedAsync(
        HttpResponseMessage response,
        CancellationToken cancellationToken)
    {
        var max = _options.MaxResponseBytes;
        await using var stream = await response.Content.ReadAsStreamAsync(cancellationToken);
        var scratch = ArrayPool<byte>.Shared.Rent(64 * 1024);
        byte[]? result = null;
        var total = 0;
        try
        {
            while (true)
            {
                var read = await stream.ReadAsync(scratch.AsMemory(0, scratch.Length), cancellationToken);
                if (read == 0)
                {
                    break;
                }

                if (total > max - read)
                {
                    throw new InvalidOperationException(
                        $"Sync response exceeds MaxResponseBytes={max} while reading body.");
                }

                if (result is null)
                {
                    result = ArrayPool<byte>.Shared.Rent(Math.Max(read, 64 * 1024));
                }
                else if (total + read > result.Length)
                {
                    var capacity = Math.Min(max, Math.Max(result.Length * 2, total + read));
                    var grown = ArrayPool<byte>.Shared.Rent(capacity);
                    result.AsSpan(0, total).CopyTo(grown);
                    ArrayPool<byte>.Shared.Return(result);
                    result = grown;
                }

                scratch.AsSpan(0, read).CopyTo(result.AsSpan(total));
                total += read;
            }

            EnsureByteLength(total);
            if (result is null)
            {
                return PooledBuffer.FromWritten(ArrayPool<byte>.Shared.Rent(1), 0);
            }

            var owned = result;
            result = null; // transferred to PooledBuffer
            return PooledBuffer.FromWritten(owned, total);
        }
        catch
        {
            if (result is not null)
            {
                ArrayPool<byte>.Shared.Return(result);
            }

            throw;
        }
        finally
        {
            ArrayPool<byte>.Shared.Return(scratch);
        }
    }

    private void EnsureByteLength(int length)
    {
        if (length > _options.MaxResponseBytes)
        {
            throw new InvalidOperationException(
                $"Sync response of {length} bytes exceeds MaxResponseBytes={_options.MaxResponseBytes}.");
        }
    }

    private static string Combine(string baseAddress, string path)
        => baseAddress.TrimEnd('/') + path;
}
