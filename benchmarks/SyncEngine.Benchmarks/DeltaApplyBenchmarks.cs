using Aviation.Shared.Entities;
using BenchmarkDotNet.Attributes;
using Microsoft.Extensions.Options;
using SyncEngine.Abstractions.Protocol;
using SyncEngine.Client.Sqlite;
using SyncEngine.Server.Codec;

namespace SyncEngine.Benchmarks;

[MemoryDiagnoser]
[SimpleJob(warmupCount: 1, iterationCount: 3)]
public class DeltaApplyBenchmarks
{
    private readonly MemoryPackDeltaCodec _codec = new();
    private SqliteBatchApplier _applier = null!;
    private string _dbPath = null!;
    private DeltaBatch _batch = default!;

    [Params(1000)]
    public int ChangeCount { get; set; }

    [GlobalSetup]
    public void Setup()
    {
        _dbPath = Path.Combine(Path.GetTempPath(), $"sync-bench-{Guid.NewGuid():N}.db");
        var options = Options.Create(new SqliteSyncOptions { ConnectionString = $"Data Source={_dbPath}" });
        var factory = new SqliteConnectionFactory(options);
        _applier = new SqliteBatchApplier(factory, [new SqliteEntityDeltaHandler(AviationEntityNames.Facility, factory)]);

        var changes = new DeltaChange[ChangeCount];
        for (var i = 0; i < ChangeCount; i++)
        {
            var facility = new Facility
            {
                FacilityId = $"fac-{i}",
                FacilityCode = $"F{i:D4}",
                Name = $"Facility {i}",
                FacilityTypeCode = "AIRPORT",
                City = "Des Moines",
                StateCode = "IA",
                ZipCode = "50321",
                Latitude = 41.5m + (i % 100) * 0.001m,
                Longitude = -93.6m - (i % 100) * 0.001m,
                OperationalStatus = "OPERATIONAL",
            };

            using var key = _codec.Encode(new FacilityKey { FacilityId = facility.FacilityId });
            using var payload = _codec.Encode(facility);
            changes[i] = new DeltaChange
            {
                Version = i + 1,
                EntityName = AviationEntityNames.Facility,
                Operation = DeltaOperation.Upsert,
                KeyBytes = key.Memory.ToArray(),
                PayloadBytes = payload.Memory.ToArray(),
            };
        }

        _batch = new DeltaBatch
        {
            FromVersion = 0,
            ToVersion = ChangeCount,
            HasMore = false,
            Changes = changes,
        };

        // Warm schema once outside timed iterations.
        _applier.ApplyAsync(_batch).GetAwaiter().GetResult();
    }

    [Benchmark(Description = "Apply 1k MemoryPack facility upserts to SQLite")]
    public Task ApplyBatchToSqlite() => _applier.ApplyAsync(_batch);

    [Benchmark(Description = "Encode+decode DeltaBatch")]
    public DeltaBatch EncodeDecodeBatch()
    {
        using var buffer = _codec.EncodeBatch(_batch);
        return _codec.DecodeBatch(buffer.Memory.Span);
    }

    [GlobalCleanup]
    public void Cleanup()
    {
        try { File.Delete(_dbPath); } catch { /* ignore */ }
    }
}
