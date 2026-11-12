using System.Diagnostics;
using System.Net.Http.Json;
using Aviation.Shared.Entities;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.SignalR.Client;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;
using SyncEngine.Abstractions;
using SyncEngine.Abstractions.Client;
using SyncEngine.Abstractions.Protocol;
using SyncEngine.Client;
using SyncEngine.Abstractions.Codec;
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
    public async Task DualClients_Converge_AfterServerMutation_ViaStreamedDelta()
    {
        var serverClient = _factory.CreateClient();
        await AuthTestHelpers.AuthorizeAsync(serverClient);
        var baseAddress = serverClient.BaseAddress ?? new Uri("http://localhost");

        await using var clientA = await CreateSqliteClientAsync(baseAddress, "A");
        await using var clientB = await CreateSqliteClientAsync(baseAddress, "B");

        var pullA0 = await clientA.Pull.PullAndApplyAsync();
        var pullB0 = await clientB.Pull.PullAndApplyAsync();
        Assert.True(pullA0.ToVersion > 0);
        Assert.Equal(pullA0.ToVersion, pullB0.ToVersion);

        var facility = NewFacility("e2e", "E2E1", "E2E Convergence Field");
        using var expectedKey = clientA.Codec.Encode(new FacilityKey { FacilityId = facility.FacilityId });
        var expectedKeyBytes = expectedKey.Memory.ToArray();

        var appliedA = new TaskCompletionSource<DeltaBatch>(TaskCreationOptions.RunContinuationsAsynchronously);
        var appliedB = new TaskCompletionSource<DeltaBatch>(TaskCreationOptions.RunContinuationsAsynchronously);
        var streamPagesA = 0;
        var streamPagesB = 0;

        clientA.Pull.BatchApplied += batch =>
        {
            if (ContainsFacilityKey(batch, expectedKeyBytes))
            {
                appliedA.TrySetResult(batch);
            }
        };
        clientB.Pull.BatchApplied += batch =>
        {
            if (ContainsFacilityKey(batch, expectedKeyBytes))
            {
                appliedB.TrySetResult(batch);
            }
        };

        var streamLoopA = clientA.Pull.RunStreamLoopAsync(clientA.Cts.Token);
        var streamLoopB = clientB.Pull.RunStreamLoopAsync(clientB.Cts.Token);

        // Handlers MUST be registered before StartAsync.
        clientA.Hub.On<byte[]>(SyncHubEvents.SyncDelta, async bytes =>
        {
            Interlocked.Increment(ref streamPagesA);
            AssertValidMemoryPackBatch(clientA.Codec, bytes);
            await clientA.Pull.NotifyStreamedDeltaAsync(bytes);
        });
        clientB.Hub.On<byte[]>(SyncHubEvents.SyncDelta, async bytes =>
        {
            Interlocked.Increment(ref streamPagesB);
            AssertValidMemoryPackBatch(clientB.Codec, bytes);
            await clientB.Pull.NotifyStreamedDeltaAsync(bytes);
        });

        await clientA.Hub.StartAsync();
        await clientA.Hub.InvokeAsync(SyncHubEvents.RegisterSyncClient, "e2e-A");
        await clientB.Hub.StartAsync();
        await clientB.Hub.InvokeAsync(SyncHubEvents.RegisterSyncClient, "e2e-B");

        var sw = Stopwatch.StartNew();
        (await serverClient.PostAsJsonAsync("/api/facilities", facility)).EnsureSuccessStatusCode();

        using var timeout = new CancellationTokenSource(TimeSpan.FromSeconds(10));
        var done = await Task.WhenAll(
            appliedA.Task.WaitAsync(timeout.Token),
            appliedB.Task.WaitAsync(timeout.Token));
        sw.Stop();

        Assert.True(done[0].ToVersion >= pullA0.ToVersion + 1);
        Assert.Equal(done[0].ToVersion, done[1].ToVersion);
        Assert.True(streamPagesA >= 1, "Client A never received SyncDelta bytes.");
        Assert.True(streamPagesB >= 1, "Client B never received SyncDelta bytes.");
        Assert.Equal(await clientA.Checkpoint.GetVersionAsync(), await clientB.Checkpoint.GetVersionAsync());

        var payloadA = await clientA.ReadFacilityPayloadAsync(facility.FacilityId);
        var payloadB = await clientB.ReadFacilityPayloadAsync(facility.FacilityId);
        Assert.NotNull(payloadA);
        Assert.NotNull(payloadB);
        Assert.Equal(payloadA, payloadB);

        Assert.True(
            sw.ElapsedMilliseconds < 1500,
            $"Stream-to-both-clients-applied took {sw.ElapsedMilliseconds}ms.");

        await clientA.Cts.CancelAsync();
        await clientB.Cts.CancelAsync();
        try { await streamLoopA; } catch (OperationCanceledException) { }
        try { await streamLoopB; } catch (OperationCanceledException) { }
    }

    [Fact]
    public async Task StreamGap_TriggersHttpCatchUp_ThenApplies()
    {
        var serverClient = _factory.CreateClient();
        await AuthTestHelpers.AuthorizeAsync(serverClient);
        var baseAddress = serverClient.BaseAddress ?? new Uri("http://localhost");
        await using var client = await CreateSqliteClientAsync(baseAddress, "GAP");

        var checkpoint = (await client.Pull.PullAndApplyAsync()).ToVersion;
        var facility = NewFacility("gap", "GAP1", "Gap Catchup");
        using var key = client.Codec.Encode(new FacilityKey { FacilityId = facility.FacilityId });
        using var payload = client.Codec.Encode(facility);
        var expectedKey = key.Memory.ToArray();

        // Land the real mutation first so HTTP catch-up has durable data.
        (await serverClient.PostAsJsonAsync("/api/facilities", facility)).EnsureSuccessStatusCode();

        // Fabricate a stream page that starts AFTER the client's tip → must HTTP catch up.
        var gapBatch = new DeltaBatch
        {
            FromVersion = checkpoint + 5,
            ToVersion = checkpoint + 6,
            HasMore = false,
            Changes =
            [
                new DeltaChange
                {
                    Version = checkpoint + 6,
                    EntityName = AviationEntityNames.Facility,
                    Operation = DeltaOperation.Upsert,
                    KeyBytes = expectedKey,
                    PayloadBytes = payload.Memory.ToArray(),
                },
            ],
        };
        using var encodedGap = client.Codec.EncodeBatch(gapBatch);

        await client.Pull.ApplyStreamedBatchAsync(encodedGap.Memory);

        Assert.True(
            await client.Checkpoint.GetVersionAsync() > checkpoint,
            "Gap recovery should advance checkpoint via HTTP catch-up.");
        Assert.NotNull(await client.ReadFacilityPayloadAsync(facility.FacilityId));
    }

    [Fact]
    public async Task Reconnect_CatchUp_PullsMissedChanges()
    {
        var serverClient = _factory.CreateClient();
        await AuthTestHelpers.AuthorizeAsync(serverClient);
        var baseAddress = serverClient.BaseAddress ?? new Uri("http://localhost");
        await using var client = await CreateSqliteClientAsync(baseAddress, "R");

        var initial = await client.Pull.PullAndApplyAsync();
        var before = initial.ToVersion;

        for (var i = 0; i < 5; i++)
        {
            (await serverClient.PostAsJsonAsync("/api/facilities", NewFacility($"rc{i}", $"RC{i}", $"Reconnect {i}")))
                .EnsureSuccessStatusCode();
        }

        var catchUp = await client.Pull.PullAndApplyAsync();
        Assert.True(catchUp.ToVersion >= before + 5);
        Assert.True(catchUp.AppliedCount >= 5);
        Assert.Equal(catchUp.ToVersion, await client.Checkpoint.GetVersionAsync());
    }

    [Fact]
    public async Task BurstWrites_StreamCoalesces_AndClientsApplyWithoutHttpPull()
    {
        var serverClient = _factory.CreateClient();
        await AuthTestHelpers.AuthorizeAsync(serverClient);
        var baseAddress = serverClient.BaseAddress ?? new Uri("http://localhost");
        await using var clientA = await CreateSqliteClientAsync(baseAddress, "BA");
        await using var clientB = await CreateSqliteClientAsync(baseAddress, "BB");

        var tip = (await clientA.Pull.PullAndApplyAsync()).ToVersion;
        await clientB.Pull.PullAndApplyAsync();

        const int burst = 50;
        var ids = Enumerable.Range(0, burst)
            .Select(i => NewFacility($"burst{i}", $"B{i:D3}", $"Burst {i}"))
            .ToArray();

        var seenA = 0;
        var seenB = 0;
        var streamPages = 0;
        var doneA = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
        var doneB = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);

        clientA.Pull.BatchApplied += batch =>
        {
            var n = Interlocked.Add(ref seenA, CountFacilities(batch));
            if (n >= burst)
            {
                doneA.TrySetResult();
            }
        };
        clientB.Pull.BatchApplied += batch =>
        {
            var n = Interlocked.Add(ref seenB, CountFacilities(batch));
            if (n >= burst)
            {
                doneB.TrySetResult();
            }
        };

        var streamLoopA = clientA.Pull.RunStreamLoopAsync(clientA.Cts.Token);
        var streamLoopB = clientB.Pull.RunStreamLoopAsync(clientB.Cts.Token);

        clientA.Hub.On<byte[]>(SyncHubEvents.SyncDelta, async bytes =>
        {
            Interlocked.Increment(ref streamPages);
            AssertValidMemoryPackBatch(clientA.Codec, bytes);
            await clientA.Pull.NotifyStreamedDeltaAsync(bytes);
        });
        clientB.Hub.On<byte[]>(SyncHubEvents.SyncDelta, async bytes =>
        {
            AssertValidMemoryPackBatch(clientB.Codec, bytes);
            await clientB.Pull.NotifyStreamedDeltaAsync(bytes);
        });

        await clientA.Hub.StartAsync();
        await clientA.Hub.InvokeAsync(SyncHubEvents.RegisterSyncClient, "e2e-burst-A");
        await clientB.Hub.StartAsync();
        await clientB.Hub.InvokeAsync(SyncHubEvents.RegisterSyncClient, "e2e-burst-B");

        await Task.WhenAll(ids.Select(async facility =>
        {
            (await serverClient.PostAsJsonAsync("/api/facilities", facility)).EnsureSuccessStatusCode();
        }));

        using var timeout = new CancellationTokenSource(TimeSpan.FromSeconds(20));
        await Task.WhenAll(
            doneA.Task.WaitAsync(timeout.Token),
            doneB.Task.WaitAsync(timeout.Token));

        Assert.True(streamPages > 0, "Expected at least one SyncDelta page.");
        Assert.True(streamPages < burst, $"Expected coalesced SyncDelta pages < {burst}, got {streamPages}.");
        Assert.True(await clientA.Checkpoint.GetVersionAsync() >= tip + burst);
        Assert.Equal(await clientA.Checkpoint.GetVersionAsync(), await clientB.Checkpoint.GetVersionAsync());

        // Spot-check first/last without an HTTP pull — stream apply must have written SQLite.
        Assert.NotNull(await clientA.ReadFacilityPayloadAsync(ids[0].FacilityId));
        Assert.NotNull(await clientB.ReadFacilityPayloadAsync(ids[^1].FacilityId));

        await clientA.Cts.CancelAsync();
        await clientB.Cts.CancelAsync();
        try { await streamLoopA; } catch (OperationCanceledException) { }
        try { await streamLoopB; } catch (OperationCanceledException) { }
    }

    [Fact]
    public async Task OfflinePush_StreamsToListeningClient()
    {
        var serverClient = _factory.CreateClient();
        await AuthTestHelpers.AuthorizeAsync(serverClient);
        var baseAddress = serverClient.BaseAddress ?? new Uri("http://localhost");
        await using var online = await CreateSqliteClientAsync(baseAddress, "ON");
        await online.Pull.PullAndApplyAsync();

        var facility = NewFacility("off", "OFF1", "Offline Origin");
        using var key = online.Codec.Encode(new FacilityKey { FacilityId = facility.FacilityId });
        using var payload = online.Codec.Encode(facility);
        var expectedKey = key.Memory.ToArray();

        var applied = new TaskCompletionSource<DeltaBatch>(TaskCreationOptions.RunContinuationsAsynchronously);
        online.Pull.BatchApplied += batch =>
        {
            if (ContainsFacilityKey(batch, expectedKey))
            {
                applied.TrySetResult(batch);
            }
        };

        var streamLoop = online.Pull.RunStreamLoopAsync(online.Cts.Token);
        online.Hub.On<byte[]>(SyncHubEvents.SyncDelta, async bytes =>
        {
            AssertValidMemoryPackBatch(online.Codec, bytes);
            await online.Pull.NotifyStreamedDeltaAsync(bytes);
        });
        await online.Hub.StartAsync();
        await online.Hub.InvokeAsync(SyncHubEvents.RegisterSyncClient, "e2e-offline-listener");

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
                    KeyBytes = expectedKey,
                    PayloadBytes = payload.Memory.ToArray(),
                },
            ],
        };
        using var encoded = online.Codec.EncodeBatch(batch);
        using var content = new ByteArrayContent(encoded.Memory.ToArray());
        content.Headers.ContentType = new System.Net.Http.Headers.MediaTypeHeaderValue(SyncContentTypes.MemoryPack);
        var push = await serverClient.PostAsync(SyncRoutes.Push, content);
        push.EnsureSuccessStatusCode();

        using var timeout = new CancellationTokenSource(TimeSpan.FromSeconds(10));
        await applied.Task.WaitAsync(timeout.Token);
        Assert.NotNull(await online.ReadFacilityPayloadAsync(facility.FacilityId));

        await online.Cts.CancelAsync();
        try { await streamLoop; } catch (OperationCanceledException) { }
    }

    [Fact]
    public async Task StaleStreamBatch_IsIgnored_CheckpointUnchanged()
    {
        var serverClient = _factory.CreateClient();
        await AuthTestHelpers.AuthorizeAsync(serverClient);
        var baseAddress = serverClient.BaseAddress ?? new Uri("http://localhost");
        await using var client = await CreateSqliteClientAsync(baseAddress, "STALE");

        var tip = (await client.Pull.PullAndApplyAsync()).ToVersion;
        var facility = NewFacility("stale", "STL1", "Stale");
        using var key = client.Codec.Encode(new FacilityKey { FacilityId = facility.FacilityId });
        using var payload = client.Codec.Encode(facility);
        var stale = new DeltaBatch
        {
            FromVersion = Math.Max(0, tip - 1),
            ToVersion = tip,
            HasMore = false,
            Changes =
            [
                new DeltaChange
                {
                    Version = tip,
                    EntityName = AviationEntityNames.Facility,
                    Operation = DeltaOperation.Upsert,
                    KeyBytes = key.Memory.ToArray(),
                    PayloadBytes = payload.Memory.ToArray(),
                },
            ],
        };
        using var encoded = client.Codec.EncodeBatch(stale);
        await client.Pull.ApplyStreamedBatchAsync(encoded.Memory);

        Assert.Equal(tip, await client.Checkpoint.GetVersionAsync());
        Assert.Null(await client.ReadFacilityPayloadAsync(facility.FacilityId));
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
            EnableDeltaStreaming = true,
            AllowInsecureHttp = true,
            ClientId = $"e2e-{name}",
        });

        var factory = new SqliteConnectionFactory(sqliteOptions);
        var checkpoint = new SqliteCheckpointStore(factory);
        await checkpoint.SetVersionAsync(0);

        var codec = new MemoryPackDeltaCodec();
        var applier = new SqliteBatchApplier(
            factory,
            AviationEntityNames.All.Select(n => new SqliteEntityDeltaHandler(n, factory)));

        var tokenClient = _factory.CreateClient();
        var token = await AuthTestHelpers.GetAccessTokenAsync(tokenClient);

        var handler = _factory.Server.CreateHandler();
        var http = new HttpClient(handler) { BaseAddress = baseAddress };
        http.DefaultRequestHeaders.Authorization =
            new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", token);
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
                o.AccessTokenProvider = () => Task.FromResult<string?>(token);
            })
            .WithAutomaticReconnect()
            .Build();

        return new TestClient(pull, checkpoint, factory, codec, hub, http, new CancellationTokenSource());
    }

    private static Facility NewFacility(string idSeed, string code, string name)
    {
        var id = $"fac-{idSeed}-{Guid.NewGuid():N}";
        return new Facility
        {
            FacilityId = id.Length <= 28 ? id : id[..28],
            FacilityCode = code,
            Name = name,
            FacilityTypeCode = "AIRPORT",
            City = "Des Moines",
            StateCode = "IA",
            ZipCode = "50321",
            Latitude = 41.5m,
            Longitude = -93.6m,
            OperationalStatus = "OPERATIONAL",
        };
    }

    private static bool ContainsFacilityKey(DeltaBatch batch, byte[] expectedKey)
        => batch.Changes is { Length: > 0 } changes
           && changes.Any(c =>
               string.Equals(c.EntityName, AviationEntityNames.Facility, StringComparison.OrdinalIgnoreCase)
               && c.KeyBytes is not null
               && c.KeyBytes.AsSpan().SequenceEqual(expectedKey));

    private static int CountFacilities(DeltaBatch batch)
        => batch.Changes?.Count(c =>
               string.Equals(c.EntityName, AviationEntityNames.Facility, StringComparison.OrdinalIgnoreCase))
           ?? 0;

    private static void AssertValidMemoryPackBatch(MemoryPackDeltaCodec codec, byte[] bytes)
    {
        Assert.NotNull(bytes);
        Assert.NotEmpty(bytes);
        var batch = codec.DecodeBatch(bytes);
        Assert.True(batch.ToVersion >= batch.FromVersion);
        Assert.NotNull(batch.Changes);
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
        public MemoryPackDeltaCodec Codec { get; } = codec;
        public HubConnection Hub { get; } = hub;
        public CancellationTokenSource Cts { get; } = cts;

        public async Task<byte[]?> ReadFacilityPayloadAsync(string facilityId)
        {
            using var keyBuffer = Codec.Encode(new FacilityKey { FacilityId = facilityId });
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
