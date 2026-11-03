using System.Diagnostics;
using System.Text;
using System.Text.Json;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.DependencyInjection;
using SyncEngine.Abstractions;
using SyncEngine.Abstractions.Client;
using SyncEngine.Abstractions.Codec;
using SyncEngine.Abstractions.Ledger;
using SyncEngine.Abstractions.Protocol;
using SyncEngine.Abstractions.Telemetry;
using SyncEngine.Server.Hubs;
using SyncEngine.Server.Offline;
using SyncEngine.Server.Telemetry;

namespace SyncEngine.Server.Hosting;

public static class SyncEndpointRouteBuilderExtensions
{
    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);

    public static IEndpointRouteBuilder MapSyncEngine(this IEndpointRouteBuilder endpoints)
    {
        endpoints.MapGet(SyncRoutes.Version, async (
            IChangeLedger ledger,
            IDeltaCodec codec,
            CancellationToken cancellationToken) =>
        {
            var version = await ledger.GetCurrentVersionAsync(cancellationToken);
            using var buffer = codec.EncodeVersion(new SyncVersion { Version = version });
            return Results.Bytes(buffer.Memory.ToArray(), SyncContentTypes.MemoryPack);
        });

        endpoints.MapGet(SyncRoutes.Deltas, async (
            HttpRequest request,
            long since,
            int? limit,
            IChangeLedger ledger,
            IDeltaCodec codec,
            ISyncAuthorization authorization,
            ISyncTelemetry telemetry,
            CancellationToken cancellationToken) =>
        {
            var sw = Stopwatch.StartNew();
            var effectiveLimit = Math.Clamp(limit ?? 500, 1, 1000);
            var batch = await ledger.GetDeltasAsync(since, effectiveLimit, cancellationToken);

            if (batch.Changes is { Length: > 0 })
            {
                var filtered = batch.Changes
                    .Where(change => authorization.CanReadChange(change.EntityName))
                    .ToArray();

                batch = new DeltaBatch
                {
                    FromVersion = batch.FromVersion,
                    ToVersion = filtered.Length == 0 ? since : filtered[^1].Version,
                    HasMore = batch.HasMore,
                    Changes = filtered,
                };
            }

            using var buffer = codec.EncodeBatch(batch);
            var bytes = buffer.Memory.ToArray();
            sw.Stop();

            var clientId = request.Headers.TryGetValue("X-Sync-Client-Id", out var header)
                ? header.ToString()
                : request.HttpContext.Connection.RemoteIpAddress?.ToString();

            telemetry.Record(new SyncTelemetryEvent
            {
                Kind = SyncTelemetryKind.DeltaPull,
                Direction = "server→client",
                ClientId = clientId,
                FromVersion = batch.FromVersion,
                ToVersion = batch.ToVersion,
                ChangeCount = batch.Changes?.Length ?? 0,
                Bytes = bytes.LongLength,
                LatencyMs = sw.Elapsed.TotalMilliseconds,
                EntityNames = batch.Changes?.Select(c => c.EntityName).Distinct(StringComparer.OrdinalIgnoreCase).ToArray(),
                Summary = $"DeltaPull since={since} → v{batch.ToVersion} changes={batch.Changes?.Length ?? 0} bytes={bytes.Length}",
                PayloadPreview = PreviewChanges(batch),
            });

            return Results.Bytes(bytes, SyncContentTypes.MemoryPack);
        });

        endpoints.MapPost(SyncRoutes.Push, async (
            HttpRequest request,
            OfflinePushHandler pushHandler,
            ISyncTelemetry telemetry,
            CancellationToken cancellationToken) =>
        {
            using var ms = new MemoryStream();
            await request.Body.CopyToAsync(ms, cancellationToken);
            var body = ms.ToArray();
            var sw = Stopwatch.StartNew();
            var result = await pushHandler.HandleAsync(body, cancellationToken);
            sw.Stop();

            telemetry.Record(new SyncTelemetryEvent
            {
                Kind = SyncTelemetryKind.OfflinePush,
                Direction = "client→server",
                Bytes = body.LongLength,
                ChangeCount = result.AppliedCount,
                ToVersion = result.LatestVersion,
                LatencyMs = sw.Elapsed.TotalMilliseconds,
                Summary = $"OfflinePush applied={result.AppliedCount} latest={result.LatestVersion} bytes={body.Length}",
            });

            return Results.Json(result);
        });

        endpoints.MapGet(SyncTelemetryRoutes.Events, (ISyncTelemetry telemetry, int? take) =>
            Results.Json(telemetry.GetRecent(take ?? 200), JsonOptions));

        endpoints.MapGet(SyncTelemetryRoutes.Stats, (ISyncTelemetry telemetry) =>
            Results.Json(telemetry.GetStats(), JsonOptions));

        endpoints.MapPost(SyncTelemetryRoutes.Report, async (
            ClientTelemetryReport report,
            ISyncTelemetry telemetry) =>
        {
            telemetry.Record(new SyncTelemetryEvent
            {
                Kind = report.Kind,
                ClientId = report.ClientId,
                Direction = "client",
                EntityName = report.EntityName,
                EntityNames = report.EntityNames,
                FromVersion = report.FromVersion,
                ToVersion = report.ToVersion,
                ChangeCount = report.ChangeCount,
                Bytes = report.Bytes,
                LatencyMs = report.LatencyMs,
                Summary = report.Summary ?? $"{report.Kind} from {report.ClientId}",
                PayloadPreview = report.PayloadPreview,
                CorrelationId = report.CorrelationId,
            });
            return Results.Accepted();
        });

        endpoints.MapGet(SyncTelemetryRoutes.Page, async (HttpContext context) =>
        {
            var path = Path.Combine(AppContext.BaseDirectory, "wwwroot", "telemetry.html");
            if (!File.Exists(path))
            {
                // Dev fallback: repo wwwroot next to content root
                path = Path.Combine(context.RequestServices.GetRequiredService<Microsoft.AspNetCore.Hosting.IWebHostEnvironment>().ContentRootPath, "wwwroot", "telemetry.html");
            }

            if (!File.Exists(path))
            {
                return Results.NotFound("telemetry.html missing");
            }

            var html = await File.ReadAllTextAsync(path);
            return Results.Content(html, "text/html; charset=utf-8");
        });

        endpoints.MapHub<SyncHub>(SyncRoutes.Hub);
        endpoints.MapHub<TelemetryHub>(SyncTelemetryRoutes.Hub);
        return endpoints;
    }

    private static string PreviewChanges(DeltaBatch batch)
    {
        if (batch.Changes is not { Length: > 0 })
        {
            return "[]";
        }

        var sb = new StringBuilder();
        sb.Append('[');
        var take = Math.Min(batch.Changes.Length, 8);
        for (var i = 0; i < take; i++)
        {
            var change = batch.Changes[i];
            if (i > 0)
            {
                sb.Append(", ");
            }

            sb.Append('{')
                .Append("v=").Append(change.Version)
                .Append(" op=").Append(change.Operation)
                .Append(" entity=").Append(change.EntityName)
                .Append(" keyBytes=").Append(change.KeyBytes?.Length ?? 0)
                .Append(" payloadBytes=").Append(change.PayloadBytes?.Length ?? 0)
                .Append('}');
        }

        if (batch.Changes.Length > take)
        {
            sb.Append(", …+").Append(batch.Changes.Length - take);
        }

        sb.Append(']');
        return sb.ToString();
    }
}
