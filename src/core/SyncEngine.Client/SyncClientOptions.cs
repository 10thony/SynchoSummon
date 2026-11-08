using SyncEngine.Abstractions.Client;

namespace SyncEngine.Client;

public sealed class SyncClientOptions
{
    public const string SectionName = "SyncEngine:Client";

    public string ServerBaseAddress { get; set; } = "http://localhost:5080";

    public string ClientId { get; set; } = "client";

    public int BatchSize { get; set; } = 500;

    public bool EnableSignalR { get; set; } = true;

    /// <summary>
    /// When true (default), apply hub-pushed <c>SyncDelta</c> batches directly.
    /// HTTP <c>/sync/deltas</c> is used for cold start, reconnect, and version gaps.
    /// </summary>
    public bool EnableDeltaStreaming { get; set; } = true;

    public bool EnableTelemetryReporting { get; set; } = true;

    public string CheckpointScope { get; set; } = "default";

    /// <summary>When false (default), non-localhost HTTP base addresses are rejected.</summary>
    public bool AllowInsecureHttp { get; set; }

    /// <summary>
    /// Max HTTP delta page size. Phone org sync needs headroom beyond tiny demo batches.
    /// </summary>
    public int MaxResponseBytes { get; set; } = 64 * 1024 * 1024;

    public int MaxPullIterations { get; set; } = 10_000;

    /// <summary>
    /// Named operating mode derived from <see cref="EnableSignalR"/> + <see cref="EnableDeltaStreaming"/>.
    /// Prefer this in session snapshots over reading the booleans independently.
    /// </summary>
    public SyncTransportMode ResolveTransportMode()
    {
        if (!EnableSignalR)
        {
            return SyncTransportMode.HttpPollOnly;
        }

        return EnableDeltaStreaming
            ? SyncTransportMode.StreamAndWake
            : SyncTransportMode.WakeAndPull;
    }

    public void ValidateTransportSecurity()
    {
        if (!Uri.TryCreate(ServerBaseAddress, UriKind.Absolute, out var uri))
        {
            throw new InvalidOperationException($"Invalid ServerBaseAddress '{ServerBaseAddress}'.");
        }

        if (uri.Scheme.Equals(Uri.UriSchemeHttps, StringComparison.OrdinalIgnoreCase))
        {
            return;
        }

        if (AllowInsecureHttp)
        {
            return;
        }

        if (uri.Scheme.Equals(Uri.UriSchemeHttp, StringComparison.OrdinalIgnoreCase)
            && IsLoopback(uri))
        {
            return;
        }

        throw new InvalidOperationException(
            $"ServerBaseAddress '{ServerBaseAddress}' must use HTTPS unless AllowInsecureHttp is set or the host is loopback.");
    }

    private static bool IsLoopback(Uri uri)
        => uri.IsLoopback
           || string.Equals(uri.Host, "localhost", StringComparison.OrdinalIgnoreCase)
           || string.Equals(uri.Host, "127.0.0.1", StringComparison.OrdinalIgnoreCase)
           || string.Equals(uri.Host, "::1", StringComparison.OrdinalIgnoreCase);
}
