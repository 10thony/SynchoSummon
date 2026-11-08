using System.Diagnostics;
using System.Net.Http.Json;
using Aviation.Shared.Entities;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.SignalR.Client;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;
using SyncEngine.Abstractions;
using SyncEngine.Abstractions.Protocol;
using SyncEngine.Client;
using SyncEngine.Client.Codec;
using SyncEngine.Client.Sqlite;
using SyncEngine.Client.Transport;
using Xunit;

namespace SyncEngine.Tests;

public sealed class ReactivityLatencyTests : IClassFixture<WebApplicationFactory<Program>>
{
    private readonly WebApplicationFactory<Program> _factory;

    public ReactivityLatencyTests(WebApplicationFactory<Program> factory)
    {
        _factory = factory;
    }

    [Fact]
    public async Task StreamToApply_P95_Under100ms_SameProcess()
    {
        var serverClient = _factory.CreateClient();
        await AuthTestHelpers.AuthorizeAsync(serverClient);
        var baseAddress = serverClient.BaseAddress ?? new Uri("http://localhost");
        var dbPath = Path.Combine(Path.GetTempPath(), $"sync-lat-{Guid.NewGuid():N}.db");

        try
        {
            var sqliteOptions = Options.Create(new SqliteSyncOptions { ConnectionString = $"Data Source={dbPath}" });
            var clientOptions = Options.Create(new SyncClientOptions
            {
                ServerBaseAddress = baseAddress.ToString().TrimEnd('/'),
                BatchSize = 500,
                AllowInsecureHttp = true,
                EnableDeltaStreaming = true,
            });
            var sqliteFactory = new SqliteConnectionFactory(sqliteOptions);
            var checkpoint = new SqliteCheckpointStore(sqliteFactory);
            await checkpoint.SetVersionAsync(0);
            var codec = new MemoryPackDeltaCodec();
            var applier = new SqliteBatchApplier(
                sqliteFactory,
                AviationEntityNames.All.Select(n => new SqliteEntityDeltaHandler(n, sqliteFactory)));
            var token = await AuthTestHelpers.GetAccessTokenAsync(serverClient);
            var http = new HttpClient(_factory.Server.CreateHandler()) { BaseAddress = baseAddress };
            http.DefaultRequestHeaders.Authorization =
                new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", token);
            var transport = new HttpSyncTransport(http, codec, clientOptions);
            var pull = new SyncPullService(
                transport, codec, applier, checkpoint, clientOptions, NullLogger<SyncPullService>.Instance);

            await pull.PullAndApplyAsync();

            await using var hub = new HubConnectionBuilder()
                .WithUrl(new Uri(baseAddress, SyncRoutes.Hub), o =>
                {
                    o.HttpMessageHandlerFactory = _ => _factory.Server.CreateHandler();
                    o.AccessTokenProvider = () => Task.FromResult<string?>(token);
                })
                .Build();

            var latencies = new List<long>();
            var cts = new CancellationTokenSource();

            TaskCompletionSource<long>? pending = null;
            var pendingStart = 0L;
            pull.BatchApplied += _ =>
            {
                if (pending is null)
                {
                    return;
                }

                var ms = (long)Stopwatch.GetElapsedTime(pendingStart).TotalMilliseconds;
                pending.TrySetResult(ms);
            };

            hub.On<byte[]>(SyncHubEvents.SyncDelta, async bytes =>
            {
                Assert.NotEmpty(bytes);
                _ = codec.DecodeBatch(bytes); // must be MemoryPack DeltaBatch
                await pull.NotifyStreamedDeltaAsync(bytes);
            });

            var streamLoop = pull.RunStreamLoopAsync(cts.Token);
            await hub.StartAsync();
            await hub.InvokeAsync(SyncHubEvents.RegisterSyncClient, "latency");

            const int samples = 20;
            for (var i = 0; i < samples; i++)
            {
                pending = new TaskCompletionSource<long>(TaskCreationOptions.RunContinuationsAsynchronously);

                var facility = new Facility
                {
                    FacilityId = $"fac-lat-{i}-{Guid.NewGuid():N}"[..24],
                    FacilityCode = $"L{i:D2}",
                    Name = $"Latency {i}",
                    FacilityTypeCode = "AIRPORT",
                    City = "Des Moines",
                    StateCode = "IA",
                    ZipCode = "50321",
                    Latitude = 41.5m,
                    Longitude = -93.6m,
                };

                pendingStart = Stopwatch.GetTimestamp();
                (await serverClient.PostAsJsonAsync("/api/facilities", facility)).EnsureSuccessStatusCode();

                using var timeout = new CancellationTokenSource(TimeSpan.FromSeconds(5));
                var ms = await pending.Task.WaitAsync(timeout.Token);
                latencies.Add(ms);
            }

            latencies.Sort();
            var p95 = latencies[(int)Math.Clamp(Math.Ceiling(latencies.Count * 0.95) - 1, 0, latencies.Count - 1)];
            var p50 = latencies[latencies.Count / 2];
            Console.WriteLine($"Stream latency ms: p50={p50} p95={p95} max={latencies[^1]} samples={string.Join(',', latencies)}");

            Assert.True(p95 < 100, $"p95 stream→apply was {p95}ms; plan gate is <100ms.");

            await cts.CancelAsync();
            try { await streamLoop; } catch (OperationCanceledException) { }
        }
        finally
        {
            try { File.Delete(dbPath); } catch { /* ignore */ }
        }
    }
}
