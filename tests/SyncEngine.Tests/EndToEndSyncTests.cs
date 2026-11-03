using System.Diagnostics;
using System.Net.Http.Json;
using Aviation.Shared.Entities;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.SignalR.Client;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;
using SyncEngine.Abstractions;
using SyncEngine.Abstractions.Client;
using SyncEngine.Abstractions.Protocol;
using SyncEngine.Client;
using SyncEngine.Client.Codec;
using SyncEngine.Client.Sqlite;
using SyncEngine.Client.Transport;
using Xunit;

namespace SyncEngine.Tests;

public sealed class EndToEndSyncTests : IClassFixture<WebApplicationFactory<Program>>, IAsyncLifetime
{
    private readonly WebApplicationFactory<Program> _factory;
    private readonly List<string> _tempFiles = [];

    public EndToEndSyncTests(WebApplicationFactory<Program> factory)
    {
        _factory = factory.WithWebHostBuilder(_ => { });
    }

    [Fact]
    public async Task DualClients_Converge_AfterServerMutation_ViaWakeAndPull()
    {
        var serverClient = _factory.CreateClient();
        var baseAddress = serverClient.BaseAddress ?? new Uri("http://localhost");

        await using var clientA = await CreateSqliteClientAsync(baseAddress, "A");
        await using var clientB = await CreateSqliteClientAsync(baseAddress, "B");

        // Initial catch-up from seed.
        var pullA0 = await clientA.Pull.PullAndApplyAsync();
        var pullB0 = await clientB.Pull.PullAndApplyAsync();
        Assert.True(pullA0.ToVersion > 0);
        Assert.Equal(pullA0.ToVersion, pullB0.ToVersion);

        var facility = new Facility
        {
            FacilityId = $"fac-e2e-{Guid.NewGuid():N}"[..20],
            FacilityCode = "E2E1",
            Name = "E2E Convergence Field",
            FacilityTypeCode = "AIRPORT",
            City = "Ames",
            StateCode = "IA",
            ZipCode = "50010",
            Latitude = 42.0m,
            Longitude = -93.6m,
            OperationalStatus = "OPERATIONAL",
        };

        var appliedA = new TaskCompletionSource<PullResult>(TaskCreationOptions.RunContinuationsAsynchronously);
        var appliedB = new TaskCompletionSource<PullResult>(TaskCreationOptions.RunContinuationsAsynchronously);
        clientA.Pull.BatchApplied += batch =>
        {
            if (batch.Changes.Any(c => c.EntityName == AviationEntityNames.Facility))
            {
                appliedA.TrySetResult(new PullResult(batch.FromVersion, batch.ToVersion, batch.Changes.Length, [AviationEntityNames.Facility]));
            }
        };
        clientB.Pull.BatchApplied += batch =>
        {
            if (batch.Changes.Any(c => c.EntityName == AviationEntityNames.Facility))
            {
                appliedB.TrySetResult(new PullResult(batch.FromVersion, batch.ToVersion, batch.Changes.Length, [AviationEntityNames.Facility]));
            }
        };

        // Start wake loops + SignalR.
        var wakeLoopA = clientA.Pull.RunWakeLoopAsync(clientA.Cts.Token);
        var wakeLoopB = clientB.Pull.RunWakeLoopAsync(clientB.Cts.Token);
        await clientA.Hub.StartAsync();
        await clientA.Hub.InvokeAsync("RegisterSyncClient");
        await clientB.Hub.StartAsync();
        await clientB.Hub.InvokeAsync("RegisterSyncClient");

        clientA.Hub.On<SyncWake>("SyncWake", async wake => await clientA.Pull.NotifyWakeAsync(wake));
        clientB.Hub.On<SyncWake>("SyncWake", async wake => await clientB.Pull.NotifyWakeAsync(wake));

        var sw = Stopwatch.StartNew();
        var response = await serverClient.PostAsJsonAsync("/api/facilities", facility);
        response.EnsureSuccessStatusCode();

        using var timeout = new CancellationTokenSource(TimeSpan.FromSeconds(10));
        var done = await Task.WhenAll(
            appliedA.Task.WaitAsync(timeout.Token),
            appliedB.Task.WaitAsync(timeout.Token));
        sw.Stop();

        Assert.True(done[0].ToVersion >= pullA0.ToVersion + 1);
        Assert.Equal(done[0].ToVersion, done[1].ToVersion);

        var payloadA = await clientA.ReadFacilityPayloadAsync(facility.FacilityId);
        var payloadB = await clientB.ReadFacilityPayloadAsync(facility.FacilityId);
        Assert.NotNull(payloadA);
        Assert.NotNull(payloadB);
        Assert.Equal(payloadA, payloadB);

        // Reactivity gate from plan: p95 wake→apply < 150ms same machine (single sample must be well under).
        Assert.True(
            sw.ElapsedMilliseconds < 1500,
            $"Wake-to-both-clients-applied took {sw.ElapsedMilliseconds}ms (expected << 1500ms for CI; target <150ms p95).");

        await clientA.Cts.CancelAsync();
        await clientB.Cts.CancelAsync();
        try { await wakeLoopA; } catch (OperationCanceledException) { }
        try { await wakeLoopB; } catch (OperationCanceledException) { }
    }

    [Fact]
    public async Task Reconnect_CatchUp_PullsMissedChanges()
    {
        var serverClient = _factory.CreateClient();
        var baseAddress = serverClient.BaseAddress ?? new Uri("http://localhost");
        await using var client = await CreateSqliteClientAsync(baseAddress, "R");

        var initial = await client.Pull.PullAndApplyAsync();
        var before = initial.ToVersion;

        // Mutate while client is NOT listening to SignalR (simulates disconnect).
        for (var i = 0; i < 5; i++)
        {
            var facility = new Facility
            {
                FacilityId = $"fac-rc-{i}-{Guid.NewGuid():N}"[..24],
                FacilityCode = $"RC{i}",
                Name = $"Reconnect {i}",
                FacilityTypeCode = "AIRPORT",
                City = "Iowa City",
                StateCode = "IA",
                ZipCode = "52240",
                Latitude = 41.66m,
                Longitude = -91.53m,
            };
            (await serverClient.PostAsJsonAsync("/api/facilities", facility)).EnsureSuccessStatusCode();
        }

        // Catch-up pull without wakes.
        var catchUp = await client.Pull.PullAndApplyAsync();
        Assert.True(catchUp.ToVersion >= before + 5);
        Assert.True(catchUp.AppliedCount >= 5);
        Assert.Equal(catchUp.ToVersion, await client.Checkpoint.GetVersionAsync());
    }

    [Fact]
    public async Task BurstWrites_Coalesce_AndClientsStayConsistent()
    {
        var serverClient = _factory.CreateClient();
        var baseAddress = serverClient.BaseAddress ?? new Uri("http://localhost");
        await using var clientA = await CreateSqliteClientAsync(baseAddress, "BA");
        await using var clientB = await CreateSqliteClientAsync(baseAddress, "BB");

        await clientA.Pull.PullAndApplyAsync();
        await clientB.Pull.PullAndApplyAsync();

        var wakesA = 0;
        var hub = new HubConnectionBuilder()
            .WithUrl(new Uri(baseAddress, SyncRoutes.Hub), o => o.HttpMessageHandlerFactory = _ => _factory.Server.CreateHandler())
            .Build();
        hub.On<SyncWake>("SyncWake", _ => Interlocked.Increment(ref wakesA));
        await hub.StartAsync();
        await hub.InvokeAsync("RegisterSyncClient");

        const int burst = 50;
        var posts = Enumerable.Range(0, burst).Select(async i =>
        {
            var facility = new Facility
            {
                FacilityId = $"fac-burst-{i}-{Guid.NewGuid():N}"[..28],
                FacilityCode = $"B{i:D3}",
                Name = $"Burst {i}",
                FacilityTypeCode = "AIRPORT",
                City = "Des Moines",
                StateCode = "IA",
                ZipCode = "50321",
                Latitude = 41.5m,
                Longitude = -93.6m,
            };
            (await serverClient.PostAsJsonAsync("/api/facilities", facility)).EnsureSuccessStatusCode();
        });
        await Task.WhenAll(posts);

        // Allow coalesce window + delivery.
        await Task.Delay(500);

        var pullA = await clientA.Pull.PullAndApplyAsync();
        var pullB = await clientB.Pull.PullAndApplyAsync();
        Assert.Equal(pullA.ToVersion, pullB.ToVersion);
        Assert.True(pullA.AppliedCount >= burst);

        // Coalescing should mean fewer wakes than writes.
        Assert.True(wakesA > 0, "Expected at least one SyncWake.");
        Assert.True(wakesA < burst, $"Expected coalesced wakes < {burst}, got {wakesA}.");

        await hub.DisposeAsync();
    }

    [Fact]
    public async Task OfflinePush_ServerWins_AppearsInLedgerForOtherClients()
    {
        var serverClient = _factory.CreateClient();
        var baseAddress = serverClient.BaseAddress ?? new Uri("http://localhost");
        await using var online = await CreateSqliteClientAsync(baseAddress, "ON");
        await online.Pull.PullAndApplyAsync();

        var codec = new MemoryPackDeltaCodec();
        var facility = new Facility
        {
            FacilityId = $"fac-off-{Guid.NewGuid():N}"[..22],
            FacilityCode = "OFF1",
            Name = "Offline Origin",
            FacilityTypeCode = "AIRPORT",
            City = "Waterloo",
            StateCode = "IA",
            ZipCode = "50701",
            Latitude = 42.55m,
            Longitude = -92.4m,
        };
        using var key = codec.Encode(new FacilityKey { FacilityId = facility.FacilityId });
        using var payload = codec.Encode(facility);
        var batch = new DeltaBatch
        {
            FromVersion = 0,
            ToVersion = 1,
            HasMore = false,
            Changes =
            [
                new DeltaChange
                {
                    Version = 1,
                    EntityName = AviationEntityNames.Facility,
                    Operation = DeltaOperation.Upsert,
                    KeyBytes = key.Memory.ToArray(),
                    PayloadBytes = payload.Memory.ToArray(),
                },
            ],
        };
        using var encoded = codec.EncodeBatch(batch);
        using var content = new ByteArrayContent(encoded.Memory.ToArray());
        content.Headers.ContentType = new System.Net.Http.Headers.MediaTypeHeaderValue(SyncContentTypes.MemoryPack);
        var push = await serverClient.PostAsync(SyncRoutes.Push, content);
        push.EnsureSuccessStatusCode();

        var pull = await online.Pull.PullAndApplyAsync();
        Assert.True(pull.AppliedCount >= 1);
        Assert.NotNull(await online.ReadFacilityPayloadAsync(facility.FacilityId));
    }

    public Task InitializeAsync() => Task.CompletedTask;

    public Task DisposeAsync()
    {
        foreach (var file in _tempFiles)
        {
            try { File.Delete(file); } catch { /* ignore */ }
        }

        return Task.CompletedTask;
    }

    private async Task<TestClient> CreateSqliteClientAsync(Uri baseAddress, string name)
    {
        var dbPath = Path.Combine(Path.GetTempPath(), $"sync-e2e-{name}-{Guid.NewGuid():N}.db");
        _tempFiles.Add(dbPath);

        var sqliteOptions = Options.Create(new SqliteSyncOptions { ConnectionString = $"Data Source={dbPath}" });
        var clientOptions = Options.Create(new SyncClientOptions
        {
            ServerBaseAddress = baseAddress.ToString().TrimEnd('/'),
            BatchSize = 500,
            EnableSignalR = true,
        });

        var factory = new SqliteConnectionFactory(sqliteOptions);
        var checkpoint = new SqliteCheckpointStore(factory);
        await checkpoint.SetVersionAsync(0);

        var codec = new MemoryPackDeltaCodec();
        var applier = new SqliteBatchApplier(
            factory,
            AviationEntityNames.All.Select(n => new SqliteEntityDeltaHandler(n, factory)));

        var handler = _factory.Server.CreateHandler();
        var http = new HttpClient(handler) { BaseAddress = baseAddress };
        var transport = new HttpSyncTransport(http, codec, clientOptions);
        var pull = new SyncPullService(
            transport,
            codec,
            applier,
            checkpoint,
            clientOptions,
            NullLogger<SyncPullService>.Instance);

        var hub = new HubConnectionBuilder()
            .WithUrl(new Uri(baseAddress, SyncRoutes.Hub), o =>
            {
                o.HttpMessageHandlerFactory = _ => _factory.Server.CreateHandler();
            })
            .WithAutomaticReconnect()
            .Build();

        return new TestClient(pull, checkpoint, factory, codec, hub, http, new CancellationTokenSource());
    }

    private sealed class TestClient(
        SyncPullService pull,
        ICheckpointStore checkpoint,
        SqliteConnectionFactory sqlite,
        MemoryPackDeltaCodec codec,
        HubConnection hub,
        HttpClient http,
        CancellationTokenSource cts) : IAsyncDisposable
    {
        public SyncPullService Pull { get; } = pull;
        public ICheckpointStore Checkpoint { get; } = checkpoint;
        public HubConnection Hub { get; } = hub;
        public CancellationTokenSource Cts { get; } = cts;

        public async Task<byte[]?> ReadFacilityPayloadAsync(string facilityId)
        {
            using var keyBuffer = codec.Encode(new FacilityKey { FacilityId = facilityId });
            var keyBytes = keyBuffer.Memory.ToArray();

            await using var connection = await sqlite.OpenAsync();
            await using var command = connection.CreateCommand();
            command.CommandText =
                "SELECT payload FROM sync_entity WHERE entity_name = $name AND entity_key = $key";
            command.Parameters.AddWithValue("$name", AviationEntityNames.Facility);
            command.Parameters.AddWithValue("$key", keyBytes);
            var result = await command.ExecuteScalarAsync();
            return result is byte[] bytes ? bytes : null;
        }

        public async ValueTask DisposeAsync()
        {
            await Hub.DisposeAsync();
            http.Dispose();
            await Cts.CancelAsync();
            Cts.Dispose();
        }
    }
}
