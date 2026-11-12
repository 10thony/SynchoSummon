using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace SyncEngine.Client;

/// <summary>
/// Seals the <see cref="SyncClientBuilder"/> at startup, and auto-warns when a co-hosted
/// client's ServerBaseAddress appears to point at the server's own URL.
/// </summary>
internal sealed class SyncClientBuilderSealHostedService(
    SyncClientBuilder builder,
    IOptions<SyncClientOptions> clientOptions,
    IConfiguration configuration,
    ILogger<SyncClientBuilderSealHostedService> logger) : IHostedService
{
    public Task StartAsync(CancellationToken cancellationToken)
    {
        builder.Seal();

        // Auto-detect co-hosted client+server self-URL trap
        var opts = clientOptions.Value;
        var hostUrls = ResolveHostUrls();
        if (hostUrls.Count > 0 && opts.IsPotentialSelfReference(hostUrls))
        {
            logger.LogWarning(
                "SyncEngine: Client ServerBaseAddress '{ServerBaseAddress}' appears to point at this server's own URL. " +
                "The client will call itself instead of an upstream sync server. " +
                "Set a different ServerBaseAddress or use separate server/client hosts.",
                opts.ServerBaseAddress);
        }

        return Task.CompletedTask;
    }

    public Task StopAsync(CancellationToken cancellationToken) => Task.CompletedTask;

    private List<string> ResolveHostUrls()
    {
        var urls = new List<string>();

        // ASPNETCORE_URLS / --urls from configuration
        var configUrls = configuration["urls"] ?? configuration["ASPNETCORE_URLS"];
        if (!string.IsNullOrWhiteSpace(configUrls))
        {
            urls.AddRange(configUrls.Split(';', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries));
        }

        // Kestrel:Endpoints section (common in appsettings.json)
        var kestrelEndpoints = configuration.GetSection("Kestrel:Endpoints");
        if (kestrelEndpoints.Exists())
        {
            foreach (var endpoint in kestrelEndpoints.GetChildren())
            {
                var url = endpoint["Url"];
                if (!string.IsNullOrWhiteSpace(url))
                {
                    urls.Add(url);
                }
            }
        }

        return urls;
    }
}
