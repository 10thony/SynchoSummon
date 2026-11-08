using System.Buffers;
using System.Diagnostics;
using System.Text;
using System.Text.Json;
using System.Threading.RateLimiting;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.DependencyInjection;
using SyncEngine.Abstractions;
using SyncEngine.Abstractions.Auth;
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
        var requireAuth = endpoints.ServiceProvider.GetService<SyncAuthFeature>()?.RequireAuthenticatedClients == true;

        RouteHandlerBuilder Secure(RouteHandlerBuilder builder)
        {
            if (requireAuth)
            {
                builder.RequireAuthorization(SyncAuthPolicies.SyncClient);
            }

            return builder;
        }

        Secure(endpoints.MapGet(SyncRoutes.Version, async (
            IChangeLedger ledger,
            IDeltaCodec codec,
            CancellationToken cancellationToken) =>
        {
            var version = await ledger.GetCurrentVersionAsync(cancellationToken);
            using var buffer = codec.EncodeVersion(new SyncVersion { Version = version });
            return Results.Bytes(buffer.Memory.ToArray(), SyncContentTypes.MemoryPack);
        }));

        Secure(endpoints.MapGet(SyncRoutes.Deltas, async (
            HttpRequest request,
            long since,
            int? limit,
            IChangeLedger ledger,
            IDeltaCodec codec,
            ISyncAuthorization authorization,
            ISyncAuthenticator authenticator,
            ISyncTelemetry telemetry,
            CancellationToken cancellationToken) =>
        {
            var sw = Stopwatch.StartNew();
            var principal = authenticator.GetPrincipal(request.HttpContext.User);
            var effectiveLimit = Math.Clamp(limit ?? 500, 1, 1000);
            var batch = await ledger.GetDeltasAsync(since, effectiveLimit, cancellationToken);
            var ledgerToVersion = batch.ToVersion;

            if (batch.Changes is { Length: > 0 })
            {
                var filtered = batch.Changes
                    .Where(change => authorization.CanRead(
                        principal,
                        change.EntityName,
                        change.KeyBytes ?? Array.Empty<byte>(),
                        change.TenantId))
                    .ToArray();

                batch = new DeltaBatch
                {
                    FromVersion = batch.FromVersion,
                    // Always advance the cursor with the ledger window so filtered-out
                    // rows cannot strand clients or rewind ToVersion.
                    ToVersion = ledgerToVersion,
                    HasMore = batch.HasMore,
                    Changes = filtered,
                };
            }

            using var buffer = codec.EncodeBatch(batch);
            var bytes = buffer.Memory.ToArray();
            sw.Stop();

            var clientId = principal.IsAuthenticated
                ? principal.ClientId
                : request.Headers.TryGetValue("X-Sync-Client-Id", out var header)
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
        }));

        var push = Secure(endpoints.MapPost(SyncRoutes.Push, async (
            HttpRequest request,
            OfflinePushHandler pushHandler,
            ISyncAuthenticator authenticator,
            ISyncTelemetry telemetry,
            SyncPushLimits limits,
            CancellationToken cancellationToken) =>
        {
            if (request.ContentLength is > 0 and var contentLength && contentLength > limits.MaxBodyBytes)
            {
                return Results.StatusCode(StatusCodes.Status413PayloadTooLarge);
            }

            // Bound chunked bodies while reading — Content-Length may be absent.
            var body = await ReadBoundedBodyAsync(request.Body, limits.MaxBodyBytes, cancellationToken);
            if (body is null)
            {
                return Results.StatusCode(StatusCodes.Status413PayloadTooLarge);
            }
            var principal = authenticator.GetPrincipal(request.HttpContext.User);
            var sw = Stopwatch.StartNew();
            try
            {
                var result = await pushHandler.HandleAsync(body, principal, cancellationToken);
                sw.Stop();

                telemetry.Record(new SyncTelemetryEvent
                {
                    Kind = SyncTelemetryKind.OfflinePush,
                    Direction = "client→server",
                    ClientId = principal.ClientId,
                    Bytes = body.LongLength,
                    ChangeCount = result.AppliedCount,
                    ToVersion = result.LatestVersion,
                    LatencyMs = sw.Elapsed.TotalMilliseconds,
                    Summary = $"OfflinePush applied={result.AppliedCount} latest={result.LatestVersion} bytes={body.Length}",
                });

                return Results.Json(result);
            }
            catch (SyncPushRejectedException ex)
            {
                return Results.BadRequest(new { error = ex.Message });
            }
        }));

        if (requireAuth)
        {
            push.RequireRateLimiting("sync-push");
        }

        Secure(endpoints.MapGet(SyncTelemetryRoutes.Events, (ISyncTelemetry telemetry, int? take) =>
            Results.Json(telemetry.GetRecent(take ?? 200), JsonOptions)));

        Secure(endpoints.MapGet(SyncTelemetryRoutes.Stats, (ISyncTelemetry telemetry) =>
            Results.Json(telemetry.GetStats(), JsonOptions)));

        Secure(endpoints.MapPost(SyncTelemetryRoutes.Report, async (
            ClientTelemetryReport report,
            ISyncAuthenticator authenticator,
            HttpContext httpContext,
            ISyncTelemetry telemetry) =>
        {
            var principal = authenticator.GetPrincipal(httpContext.User);
            telemetry.Record(new SyncTelemetryEvent
            {
                Kind = report.Kind,
                ClientId = principal.IsAuthenticated ? principal.ClientId : report.ClientId,
                Direction = "client",
                EntityName = report.EntityName,
                EntityNames = report.EntityNames,
                FromVersion = report.FromVersion,
                ToVersion = report.ToVersion,
                ChangeCount = report.ChangeCount,
                Bytes = report.Bytes,
                LatencyMs = report.LatencyMs,
                Summary = Truncate(report.Summary ?? $"{report.Kind} from {principal.ClientId}", 500),
                PayloadPreview = Truncate(report.PayloadPreview, 500),
                CorrelationId = report.CorrelationId,
            });
            return Results.Accepted();
        }));

        endpoints.MapGet(SyncTelemetryRoutes.Page, async (HttpContext context) =>
        {
            var path = Path.Combine(AppContext.BaseDirectory, "wwwroot", "telemetry.html");
            if (!File.Exists(path))
            {
                path = Path.Combine(
                    context.RequestServices.GetRequiredService<Microsoft.AspNetCore.Hosting.IWebHostEnvironment>().ContentRootPath,
                    "wwwroot",
                    "telemetry.html");
            }

            if (!File.Exists(path))
            {
                return Results.NotFound("telemetry.html missing");
            }

            var html = await File.ReadAllTextAsync(path);
            return Results.Content(html, "text/html; charset=utf-8");
        });

        // Align server outbound buffers with phone-scale SyncDelta pages (default 64KB backpressures early).
        // https://learn.microsoft.com/en-us/aspnet/core/signalr/configuration
        var syncHub = endpoints.MapHub<SyncHub>(SyncRoutes.Hub, options =>
        {
            options.ApplicationMaxBufferSize = 64 * 1024 * 1024;
            options.TransportMaxBufferSize = 64 * 1024 * 1024;
        });
        var telemetryHub = endpoints.MapHub<TelemetryHub>(SyncTelemetryRoutes.Hub, options =>
        {
            options.ApplicationMaxBufferSize = 1024 * 1024;
            options.TransportMaxBufferSize = 1024 * 1024;
        });
        if (requireAuth)
        {
            syncHub.RequireAuthorization(SyncAuthPolicies.SyncClient);
            telemetryHub.RequireAuthorization(SyncAuthPolicies.SyncClient);
        }

        return endpoints;
    }

    public static IServiceCollection AddSyncEnginePushRateLimiter(this IServiceCollection services)
    {
        services.AddRateLimiter(options =>
        {
            options.AddPolicy("sync-push", httpContext =>
                RateLimitPartition.GetFixedWindowLimiter(
                    partitionKey: httpContext.User.Identity?.Name
                        ?? httpContext.Connection.RemoteIpAddress?.ToString()
                        ?? "anonymous",
                    factory: _ => new FixedWindowRateLimiterOptions
                    {
                        PermitLimit = 60,
                        Window = TimeSpan.FromMinutes(1),
                        QueueLimit = 0,
                    }));
        });
        return services;
    }

    /// <summary>
    /// Reads the request body with an incremental size ceiling so chunked uploads
    /// cannot allocate unbounded memory before a post-hoc length check.
    /// Returns null when the body would exceed <paramref name="maxBytes"/>.
    /// </summary>
    private static async Task<byte[]?> ReadBoundedBodyAsync(
        Stream body,
        long maxBytes,
        CancellationToken cancellationToken)
    {
        var max = checked((int)Math.Min(maxBytes, int.MaxValue));
        using var ms = new MemoryStream(Math.Min(max, 64 * 1024));
        var scratch = ArrayPool<byte>.Shared.Rent(64 * 1024);
        try
        {
            while (true)
            {
                var read = await body.ReadAsync(scratch.AsMemory(0, scratch.Length), cancellationToken);
                if (read == 0)
                {
                    break;
                }

                if (ms.Length > max - read)
                {
                    return null;
                }

                ms.Write(scratch, 0, read);
            }

            return ms.ToArray();
        }
        finally
        {
            ArrayPool<byte>.Shared.Return(scratch);
        }
    }

    private static string Truncate(string? value, int max)
    {
        if (string.IsNullOrEmpty(value) || value.Length <= max)
        {
            return value ?? string.Empty;
        }

        return value[..max];
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
