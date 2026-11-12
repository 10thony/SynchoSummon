using System.Collections.Concurrent;
using System.Diagnostics;
using System.Net.Http.Json;
using System.Security.Cryptography;
using Aviation.Server.Services;
using Aviation.Shared.Entities;
using Aviation.Shared.Seed;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.SignalR.Client;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;
using SyncEngine.Abstractions;
using SyncEngine.Abstractions.Client;
using SyncEngine.Abstractions.Codec;
using SyncEngine.Abstractions.Protocol;
using SyncEngine.Client;
using SyncEngine.Abstractions.Codec;
using SyncEngine.Client.Offline;
using SyncEngine.Client.Sqlite;
using SyncEngine.Client.Transport;
using SyncEngine.Tests.Fixtures;
using Xunit;
using Xunit.Abstractions;

namespace SyncEngine.Tests;

/// <summary>
/// Phone-shaped org sync validation:
/// nested proprietary payloads, byte-level integrity across 3 clients,
/// offline mutation round-trip, and measured throughput.
///
/// Scale with env SYNCENGINE_PHONE_SYNC_TARGET_MB (default 48 for CI; use 3072 for ~3GiB soak).
/// </summary>
public sealed class PhoneOrgSyncIntegrityTests : IClassFixture<WebApplicationFactory<Program>>, IAsyncLifetime
{
    private readonly WebApplicationFactory<Program> _factory;
    private readonly ITestOutputHelper _output;
    private readonly List<string> _tempFiles = [];

    public PhoneOrgSyncIntegrityTests(WebApplicationFactory<Program> factory, ITestOutputHelper output)
    {
        _factory = factory.WithWebHostBuilder(_ => { });
        _output = output;
    }

    [Fact]
    public async Task ThreePhones_NestedOrgSync_IntegrityAndThroughput()
    {
        var targetMb = ReadTargetMb();
        var targetBytes = targetMb * 1024L * 1024L;
        _output.WriteLine($"Target org slice ≈ {targetMb} MB (set SYNCENGINE_PHONE_SYNC_TARGET_MB to scale; 3072 ≈ 3GiB).");

        var server = _factory.CreateClient();
        await AuthTestHelpers.AuthorizeAsync(server);
        var baseAddress = server.BaseAddress ?? new Uri("http://localhost");

        // Expected integrity catalog: entityName|keyId → payload SHA-256
        var expected = new ConcurrentDictionary<string, string>(StringComparer.Ordinal);
        long seededPayloadBytes = 0;

        // ── Seed nested org graph in packages until we hit the target ─────
        var seedSw = Stopwatch.StartNew();
        var packageIndex = 0;
        while (seededPayloadBytes < targetBytes)
        {
            var remaining = targetBytes - seededPayloadBytes;
            var package = BuildNestedPackage(
                runId: $"phone-{packageIndex:D3}",
                targetPackageBytes: (int)Math.Min(remaining, 4L * 1024 * 1024)); // ≤4MB packages
            await IndexPackageAsync(package, expected, bytes => Interlocked.Add(ref seededPayloadBytes, bytes));

            var response = await server.PostAsJsonAsync("/api/load/packages", package);
            response.EnsureSuccessStatusCode();
            packageIndex++;

            // Safety for pathological tiny annexes.
            if (packageIndex > 50_000)
            {
                throw new InvalidOperationException("Package generation failed to reach target bytes.");
            }
        }

        seedSw.Stop();
        _output.WriteLine(
            $"Seeded {packageIndex} packages, {expected.Count} entities, ~{seededPayloadBytes / (1024.0 * 1024.0):F1} MB logical payload in {seedSw.Elapsed.TotalSeconds:F1}s");

        // ── Three phones: cold HTTP pull (bulk path), then compare catalogs ─
        var phones = await Task.WhenAll(
            CreatePhoneAsync(baseAddress, "pixel"),
            CreatePhoneAsync(baseAddress, "iphone"),
            CreatePhoneAsync(baseAddress, "fold"));
        await using var pixel = phones[0];
        await using var iphone = phones[1];
        await using var fold = phones[2];
        PhoneClient[] live = [pixel, iphone, fold];

        var pullSw = Stopwatch.StartNew();
        var pulls = await Task.WhenAll(live.Select(p => p.Pull.PullAndApplyAsync()));
        pullSw.Stop();

        var applied = pulls.Sum(p => p.AppliedCount);
        var mb = seededPayloadBytes / (1024.0 * 1024.0);
        var mbPerSec = mb / Math.Max(pullSw.Elapsed.TotalSeconds, 0.001);
        _output.WriteLine(
            $"Cold pull: applied≈{applied / 3} ents/client, {mb:F1} MB in {pullSw.Elapsed.TotalSeconds:F1}s → {mbPerSec:F1} MB/s (wall, 3-way parallel)");

        // Integrity: seeded digests must be present; phones must match each other exactly
        // (server may already hold baseline corridor rows outside this test's seed map).
        var coldCatalogs = await Task.WhenAll(live.Select(p => p.BuildCatalogAsync()));
        for (var i = 0; i < live.Length; i++)
        {
            AssertCatalogContains(expected, coldCatalogs[i], live[i].Name);
        }

        AssertCatalogsEqual(coldCatalogs[0], coldCatalogs[1], "pixel↔iphone cold");
        AssertCatalogsEqual(coldCatalogs[1], coldCatalogs[2], "iphone↔fold cold");

        // Nested decode spot-check across entity kinds (not a single facility).
        var sampleFacilityId = expected.Keys
            .First(k => k.StartsWith(AviationEntityNames.Facility + "|", StringComparison.Ordinal))
            .Split('|', 2)[1];
        var sampleEquipmentId = expected.Keys
            .First(k => k.StartsWith(AviationEntityNames.Equipment + "|", StringComparison.Ordinal))
            .Split('|', 2)[1];
        var sampleLogId = expected.Keys
            .First(k => k.StartsWith(AviationEntityNames.MaintenanceLog + "|", StringComparison.Ordinal))
            .Split('|', 2)[1];
        foreach (var phone in live)
        {
            await AssertNestedRoundTripAsync(phone, AviationEntityNames.Facility, sampleFacilityId,
                id => new FacilityKey { FacilityId = id },
                bytes => phone.Codec.Decode<Facility>(bytes).MetadataJson);
            await AssertNestedRoundTripAsync(phone, AviationEntityNames.Equipment, sampleEquipmentId,
                id => new EquipmentKey { EquipmentId = id },
                bytes => phone.Codec.Decode<Equipment>(bytes).MetadataJson);
            await AssertNestedRoundTripAsync(phone, AviationEntityNames.MaintenanceLog, sampleLogId,
                id => new MaintenanceLogKey { MaintenanceLogId = id },
                bytes => phone.Codec.Decode<MaintenanceLog>(bytes).MetadataJson);
        }

        _output.WriteLine("Cold sync integrity OK (SHA-256 catalogs + nested round-trip).");

        // ── Live phase: stream on; offline nested mutation from one phone ─
        await Task.WhenAll(live.Select(p => p.StartStreamingAsync()));

        var offlineDoc = NestedOrgFactory.Create($"fac-offline-{Guid.NewGuid():N}"[..24], annexBytes: 64 * 1024);
        var offlineFacility = new Facility
        {
            FacilityId = offlineDoc.DocumentId,
            FacilityCode = "OFF",
            Name = "Offline nested upload",
            FacilityTypeCode = "AIRPORT",
            City = "Ames",
            StateCode = "IA",
            ZipCode = "50010",
            Latitude = 42.0m,
            Longitude = -93.6m,
            OperationalStatus = "OPERATIONAL",
            MetadataJson = NestedOrgFactory.ToMetadataEnvelope(offlineDoc),
        };

        await pixel.GoOfflineAsync();
        using (var key = pixel.Codec.Encode(new FacilityKey { FacilityId = offlineFacility.FacilityId }))
        using (var payload = pixel.Codec.Encode(offlineFacility))
        {
            var payloadHash = NestedOrgFactory.Sha256Hex(payload.Memory.Span);
            expected[$"{AviationEntityNames.Facility}|{offlineFacility.FacilityId}"] = payloadHash;
            pixel.Outbox.EnqueueUpsert(AviationEntityNames.Facility, key.Memory, payload.Memory);
        }

        // Meanwhile server keeps writing so reconnect must catch stream + offline fanout.
        var liveFacility = NewLightFacility("live-while-offline");
        liveFacility.MetadataJson = NestedOrgFactory.ToMetadataEnvelope(
            NestedOrgFactory.Create(liveFacility.FacilityId, annexBytes: 8 * 1024));
        using (var payload = pixel.Codec.Encode(liveFacility))
        {
            expected[$"{AviationEntityNames.Facility}|{liveFacility.FacilityId}"] =
                NestedOrgFactory.Sha256Hex(payload.Memory.Span);
        }

        (await server.PostAsJsonAsync("/api/facilities", liveFacility)).EnsureSuccessStatusCode();

        var flushed = await pixel.Outbox.FlushAsync(pixel.Http, pixel.ServerBase, pixel.Codec);
        Assert.Equal(1, flushed);

        await pixel.ReconnectStreamingAsync();
        await pixel.Pull.PullAndApplyAsync();

        // Wait on digest integrity only — tip agreement without payload match is a false pass.
        await WaitAsync(
            "offline nested fanout + live catch-up",
            async () =>
            {
                var catalogs = await Task.WhenAll(live.Select(p => p.BuildCatalogAsync()));
                return CatalogContains(catalogs[0], expected)
                    && CatalogsEqual(catalogs[0], catalogs[1])
                    && CatalogsEqual(catalogs[1], catalogs[2]);
            },
            TimeSpan.FromSeconds(90));

        // Final: expected ⊆ each phone; phones equal each other (bidirectional SHA-256 maps).
        var finalCatalogs = await Task.WhenAll(live.Select(p => p.BuildCatalogAsync()));
        AssertCatalogContains(expected, finalCatalogs[0], "expected⊆pixel");
        AssertCatalogsEqual(finalCatalogs[0], finalCatalogs[1], "pixel↔iphone");
        AssertCatalogsEqual(finalCatalogs[1], finalCatalogs[2], "iphone↔fold");

        // Nested offline payload intact on peers.
        foreach (var phone in new[] { iphone, fold })
        {
            var bytes = await phone.ReadEntityAsync(
                AviationEntityNames.Facility,
                new FacilityKey { FacilityId = offlineFacility.FacilityId });
            Assert.NotNull(bytes);
            var facility = phone.Codec.Decode<Facility>(bytes);
            var nested = NestedOrgFactory.FromMetadataEnvelope(facility.MetadataJson!);
            Assert.Equal(offlineDoc.DocumentId, nested.DocumentId);
            Assert.Equal(offlineDoc.BinaryAnnex, nested.BinaryAnnex);
            Assert.Equal(offlineDoc.Systems.Count, nested.Systems.Count);
        }

        _output.WriteLine(
            $"PASS phone org integrity: target={targetMb}MB entities={expected.Count} coldPull={mbPerSec:F1}MB/s pages={string.Join('/', live.Select(p => p.StreamPages))}");
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

    private static int ReadTargetMb()
    {
        var raw = Environment.GetEnvironmentVariable("SYNCENGINE_PHONE_SYNC_TARGET_MB");
        if (int.TryParse(raw, out var mb) && mb > 0)
        {
            return Math.Min(mb, 3072); // hard cap ~3GiB soak
        }

        return 48; // CI default: meaningful nested volume without multi-minute soak
    }

    private static LoadPackageRequest BuildNestedPackage(string runId, int targetPackageBytes)
    {
        // Structural fan-out first; annex size fills remaining budget for proprietary blob weight.
        var facilities = Math.Clamp(targetPackageBytes / (256 * 1024), 2, 12);
        var equipmentPerFacility = 4;
        var logsPerEquipment = 3;
        var graph = CorridorSyncSeed.BuildScaled(
            facilities,
            equipmentPerFacility,
            logsPerEquipment,
            deleteLogPercent: 0,
            runId: runId);

        var entityCount = graph.Facilities.Count + graph.Equipment.Count + graph.Logs.Count;
        var annex = Math.Max(4 * 1024, targetPackageBytes / Math.Max(entityCount, 1));

        foreach (var facility in graph.Facilities)
        {
            facility.MetadataJson = NestedOrgFactory.ToMetadataEnvelope(
                NestedOrgFactory.Create(facility.FacilityId, annexBytes: annex, systems: 3, componentsPerSystem: 4));
        }

        foreach (var equipment in graph.Equipment)
        {
            equipment.MetadataJson = NestedOrgFactory.ToMetadataEnvelope(
                NestedOrgFactory.Create(equipment.EquipmentId, annexBytes: Math.Max(annex / 2, 2048), systems: 2, componentsPerSystem: 3));
        }

        foreach (var log in graph.Logs)
        {
            log.MetadataJson = NestedOrgFactory.ToMetadataEnvelope(
                NestedOrgFactory.Create(log.MaintenanceLogId, annexBytes: Math.Max(annex / 4, 1024), systems: 1, componentsPerSystem: 2));
        }

        return new LoadPackageRequest
        {
            PackageId = runId,
            Tier = "phone-nested",
            Facilities = graph.Facilities.ToList(),
            Equipment = graph.Equipment.ToList(),
            MaintenanceLogs = graph.Logs.ToList(),
        };
    }

    private static Task IndexPackageAsync(
        LoadPackageRequest package,
        ConcurrentDictionary<string, string> expected,
        Action<long> addBytes)
    {
        var codec = new MemoryPackDeltaCodec();
        void Index<T>(string entityName, string id, T entity)
        {
            using var payload = codec.Encode(entity);
            expected[$"{entityName}|{id}"] = NestedOrgFactory.Sha256Hex(payload.Memory.Span);
            addBytes(payload.Memory.Length);
        }

        foreach (var f in package.Facilities)
        {
            Index(AviationEntityNames.Facility, f.FacilityId, f);
        }

        foreach (var e in package.Equipment)
        {
            Index(AviationEntityNames.Equipment, e.EquipmentId, e);
        }

        foreach (var l in package.MaintenanceLogs)
        {
            Index(AviationEntityNames.MaintenanceLog, l.MaintenanceLogId, l);
        }

        return Task.CompletedTask;
    }

    private async Task<PhoneClient> CreatePhoneAsync(Uri baseAddress, string name)
    {
        var dbPath = Path.Combine(Path.GetTempPath(), $"sync-phone-{name}-{Guid.NewGuid():N}.db");
        _tempFiles.Add(dbPath);

        var sqliteOptions = Options.Create(new SqliteSyncOptions { ConnectionString = $"Data Source={dbPath}" });
        var clientOptions = Options.Create(new SyncClientOptions
        {
            ServerBaseAddress = baseAddress.ToString().TrimEnd('/'),
            BatchSize = 200,
            EnableSignalR = true,
            EnableDeltaStreaming = true,
            AllowInsecureHttp = true,
            ClientId = $"phone-{name}",
            MaxResponseBytes = 64 * 1024 * 1024,
        });

        var sqlite = new SqliteConnectionFactory(sqliteOptions);
        var checkpoint = new SqliteCheckpointStore(sqlite);
        await checkpoint.SetVersionAsync(0);
        var codec = new MemoryPackDeltaCodec();
        var applier = new SqliteBatchApplier(
            sqlite,
            AviationEntityNames.All.Select(n => new SqliteEntityDeltaHandler(n, sqlite)));

        var token = await AuthTestHelpers.GetAccessTokenAsync(_factory.CreateClient());
        var http = new HttpClient(_factory.Server.CreateHandler(), disposeHandler: false)
        {
            BaseAddress = baseAddress,
            Timeout = TimeSpan.FromMinutes(10),
        };
        http.DefaultRequestHeaders.Authorization =
            new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", token);

        var transport = new HttpSyncTransport(http, codec, clientOptions);
        var pull = new SyncPullService(
            transport, codec, applier, checkpoint, clientOptions, NullLogger<SyncPullService>.Instance);

        var hub = new HubConnectionBuilder()
            .WithUrl(new Uri(baseAddress, SyncRoutes.Hub), o =>
            {
                o.HttpMessageHandlerFactory = _ => _factory.Server.CreateHandler();
                o.AccessTokenProvider = () => Task.FromResult<string?>(token);
                o.TransportMaxBufferSize = 64 * 1024 * 1024;
                o.ApplicationMaxBufferSize = 64 * 1024 * 1024;
            })
            .WithAutomaticReconnect()
            .Build();

        return new PhoneClient(name, pull, checkpoint, sqlite, codec, hub, http, clientOptions.Value.ServerBaseAddress);
    }

    private static Facility NewLightFacility(string seed)
    {
        var id = $"fac-{seed}-{Guid.NewGuid():N}";
        return new Facility
        {
            FacilityId = id.Length <= 28 ? id : id[..28],
            FacilityCode = "LV",
            Name = seed,
            FacilityTypeCode = "AIRPORT",
            City = "Des Moines",
            StateCode = "IA",
            ZipCode = "50321",
            Latitude = 41.5m,
            Longitude = -93.6m,
            OperationalStatus = "OPERATIONAL",
        };
    }

    private static async Task AssertNestedRoundTripAsync<TKey>(
        PhoneClient phone,
        string entityName,
        string documentId,
        Func<string, TKey> keyFactory,
        Func<byte[], string?> metadataSelector)
    {
        var bytes = await phone.ReadEntityAsync(entityName, keyFactory(documentId));
        Assert.NotNull(bytes);
        var metadata = metadataSelector(bytes);
        Assert.False(string.IsNullOrWhiteSpace(metadata));
        var nested = NestedOrgFactory.FromMetadataEnvelope(metadata!);
        Assert.Equal(documentId, nested.DocumentId);
        Assert.NotEmpty(nested.Systems);
        Assert.NotEmpty(nested.Systems[0].Components);
        Assert.NotEmpty(nested.Systems[0].Components[0].Calibrations);
        Assert.True(nested.BinaryAnnex.Length > 0);
    }

    private static void AssertCatalogContains(
        IReadOnlyDictionary<string, string> expected,
        IReadOnlyDictionary<string, string> actual,
        string label)
    {
        Assert.True(
            CatalogContains(actual, expected),
            $"{label}: missing/mismatched seeded digests. " +
            DescribeCatalogDelta(expected, actual));
    }

    private static void AssertCatalogsEqual(
        IReadOnlyDictionary<string, string> left,
        IReadOnlyDictionary<string, string> right,
        string label)
    {
        Assert.True(
            CatalogsEqual(left, right),
            $"{label}: catalog mismatch (left={left.Count}, right={right.Count}). " +
            DescribeCatalogDelta(left, right));
    }

    private static bool CatalogContains(
        IReadOnlyDictionary<string, string> actual,
        IReadOnlyDictionary<string, string> expected)
    {
        foreach (var (key, hash) in expected)
        {
            if (!actual.TryGetValue(key, out var got)
                || !string.Equals(hash, got, StringComparison.Ordinal))
            {
                return false;
            }
        }

        return true;
    }

    private static bool CatalogsEqual(
        IReadOnlyDictionary<string, string> left,
        IReadOnlyDictionary<string, string> right)
    {
        if (left.Count != right.Count)
        {
            return false;
        }

        foreach (var (key, hash) in left)
        {
            if (!right.TryGetValue(key, out var got)
                || !string.Equals(hash, got, StringComparison.Ordinal))
            {
                return false;
            }
        }

        return true;
    }

    private static string DescribeCatalogDelta(
        IReadOnlyDictionary<string, string> left,
        IReadOnlyDictionary<string, string> right)
    {
        var missingRight = left.Keys.Where(k => !right.ContainsKey(k)).Take(5).ToArray();
        var missingLeft = right.Keys.Where(k => !left.ContainsKey(k)).Take(5).ToArray();
        var mismatch = left
            .Where(kv => right.TryGetValue(kv.Key, out var h) && !string.Equals(kv.Value, h, StringComparison.Ordinal))
            .Select(kv => kv.Key)
            .Take(5)
            .ToArray();
        return $"onlyLeft=[{string.Join(',', missingRight)}] onlyRight=[{string.Join(',', missingLeft)}] hashMismatch=[{string.Join(',', mismatch)}]";
    }

    private static async Task WaitAsync(string label, Func<Task<bool>> predicate, TimeSpan timeout)
    {
        var sw = Stopwatch.StartNew();
        while (sw.Elapsed < timeout)
        {
            if (await predicate())
            {
                return;
            }

            await Task.Delay(25);
        }

        throw new TimeoutException($"Timed out waiting for '{label}' after {timeout.TotalSeconds:F0}s.");
    }

    private sealed class PhoneClient : IAsyncDisposable
    {
        private readonly SqliteConnectionFactory _sqlite;
        private CancellationTokenSource _cts = new();
        private Task? _streamLoop;
        private Task? _wakeLoop;
        private int _streamPages;

        public PhoneClient(
            string name,
            SyncPullService pull,
            ICheckpointStore checkpoint,
            SqliteConnectionFactory sqlite,
            MemoryPackDeltaCodec codec,
            HubConnection hub,
            HttpClient http,
            string serverBase)
        {
            Name = name;
            Pull = pull;
            Checkpoint = checkpoint;
            _sqlite = sqlite;
            Codec = codec;
            Hub = hub;
            Http = http;
            ServerBase = serverBase;
            Outbox = new ClientOutbox();
        }

        public string Name { get; }
        public SyncPullService Pull { get; }
        public ICheckpointStore Checkpoint { get; }
        public MemoryPackDeltaCodec Codec { get; }
        public HubConnection Hub { get; }
        public HttpClient Http { get; }
        public string ServerBase { get; }
        public ClientOutbox Outbox { get; }
        public int StreamPages => Volatile.Read(ref _streamPages);

        public async Task StartStreamingAsync()
        {
            Hub.Remove(SyncHubEvents.SyncDelta);
            Hub.Remove(SyncHubEvents.SyncWake);
            Hub.On<byte[]>(SyncHubEvents.SyncDelta, async bytes =>
            {
                Interlocked.Increment(ref _streamPages);
                await Pull.NotifyStreamedDeltaAsync(bytes);
            });
            // Wake remains the HTTP safety net when SyncDelta is skipped (oversized page).
            Hub.On<SyncWake>(SyncHubEvents.SyncWake, async _ =>
            {
                await Pull.NotifyWakeAsync(new SyncWake { LatestVersion = 0, EntityNames = [] });
            });
            _streamLoop = Pull.RunStreamLoopAsync(_cts.Token);
            _wakeLoop = Pull.RunWakeLoopAsync(_cts.Token);
            if (Hub.State == HubConnectionState.Disconnected)
            {
                await Hub.StartAsync();
            }

            await Hub.InvokeAsync(SyncHubEvents.RegisterSyncClient, $"phone-{Name}");
        }

        public async Task GoOfflineAsync()
        {
            await _cts.CancelAsync();
            if (_streamLoop is not null)
            {
                try { await _streamLoop; } catch (OperationCanceledException) { }
            }

            if (_wakeLoop is not null)
            {
                try { await _wakeLoop; } catch (OperationCanceledException) { }
            }

            await Hub.StopAsync();
            _cts.Dispose();
            _cts = new CancellationTokenSource();
            _streamLoop = null;
            _wakeLoop = null;
        }

        public Task ReconnectStreamingAsync() => StartStreamingAsync();

        public async Task<Dictionary<string, string>> BuildCatalogAsync()
        {
            var catalog = new Dictionary<string, string>(StringComparer.Ordinal);
            await using var connection = await _sqlite.OpenAsync();
            await using var command = connection.CreateCommand();
            command.CommandText = "SELECT entity_name, entity_key, payload FROM sync_entity";
            await using var reader = await command.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                var name = reader.GetString(0);
                var keyBytes = (byte[])reader[1];
                var payload = reader.IsDBNull(2) ? Array.Empty<byte>() : (byte[])reader[2];
                var keyId = DecodeKeyId(name, keyBytes);
                catalog[$"{name}|{keyId}"] = NestedOrgFactory.Sha256Hex(payload);
            }

            return catalog;
        }

        public async Task<byte[]?> ReadEntityAsync<TKey>(string entityName, TKey key)
        {
            using var keyBuffer = Codec.Encode(key);
            await using var connection = await _sqlite.OpenAsync();
            await using var command = connection.CreateCommand();
            command.CommandText =
                "SELECT payload FROM sync_entity WHERE entity_name = $name AND entity_key = $key";
            command.Parameters.AddWithValue("$name", entityName);
            command.Parameters.AddWithValue("$key", keyBuffer.Memory.ToArray());
            return await command.ExecuteScalarAsync() as byte[];
        }

        private string DecodeKeyId(string entityName, byte[] keyBytes)
        {
            return entityName switch
            {
                AviationEntityNames.Facility => Codec.Decode<FacilityKey>(keyBytes).FacilityId,
                AviationEntityNames.Equipment => Codec.Decode<EquipmentKey>(keyBytes).EquipmentId,
                AviationEntityNames.MaintenanceLog => Codec.Decode<MaintenanceLogKey>(keyBytes).MaintenanceLogId,
                _ => Convert.ToHexString(SHA256.HashData(keyBytes)),
            };
        }

        public async ValueTask DisposeAsync()
        {
            await _cts.CancelAsync();
            if (_streamLoop is not null)
            {
                try { await _streamLoop; } catch (OperationCanceledException) { }
            }

            if (_wakeLoop is not null)
            {
                try { await _wakeLoop; } catch (OperationCanceledException) { }
            }

            await Hub.DisposeAsync();
            Http.Dispose();
            _cts.Dispose();
        }
    }
}
