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

        if (!_httpClient.DefaultRequestHeaders.Contains("X-Sync-Client-Id"))
        {
            _httpClient.DefaultRequestHeaders.TryAddWithoutValidation("X-Sync-Client-Id", _options.ClientId);
        }
    }

    public async Task<long> GetVersionAsync(CancellationToken cancellationToken = default)
    {
        using var response = await _httpClient.GetAsync(
            Combine(_options.ServerBaseAddress, SyncRoutes.Version),
            cancellationToken);
        response.EnsureSuccessStatusCode();
        var bytes = await response.Content.ReadAsByteArrayAsync(cancellationToken);
        return _codec.DecodeVersion(bytes).Version;
    }

    public async Task<PooledBuffer> GetDeltasBytesAsync(
        long sinceVersion,
        int limit,
        CancellationToken cancellationToken = default)
    {
        var url = $"{Combine(_options.ServerBaseAddress, SyncRoutes.Deltas)}?since={sinceVersion}&limit={limit}";
        using var response = await _httpClient.GetAsync(url, cancellationToken);
        response.EnsureSuccessStatusCode();
        var bytes = await response.Content.ReadAsByteArrayAsync(cancellationToken);
        var pool = System.Buffers.ArrayPool<byte>.Shared.Rent(Math.Max(bytes.Length, 1));
        bytes.CopyTo(pool.AsSpan(0, bytes.Length));
        return PooledBuffer.FromWritten(pool, bytes.Length);
    }

    private static string Combine(string baseAddress, string path)
    {
        return baseAddress.TrimEnd('/') + path;
    }
}
