using System.Net.Http.Json;
using Microsoft.Extensions.Options;
using SyncEngine.Abstractions.Telemetry;

namespace SyncEngine.Client.Telemetry;

public sealed class ClientTelemetryReporter(
    IHttpClientFactory httpClientFactory,
    IOptions<SyncClientOptions> options)
{
    public async Task ReportAsync(ClientTelemetryReport report, CancellationToken cancellationToken = default)
    {
        if (!options.Value.EnableTelemetryReporting)
        {
            return;
        }

        report.ClientId = string.IsNullOrWhiteSpace(report.ClientId)
            ? options.Value.ClientId
            : report.ClientId;

        try
        {
            var httpClient = httpClientFactory.CreateClient(nameof(ClientTelemetryReporter));
            var url = options.Value.ServerBaseAddress.TrimEnd('/') + SyncTelemetryRoutes.Report;
            using var response = await httpClient.PostAsJsonAsync(url, report, cancellationToken);
            _ = response;
        }
        catch
        {
            // Best-effort only.
        }
    }
}
