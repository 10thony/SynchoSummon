using Aviation.Shared.Seed;
using BenchmarkDotNet.Attributes;
using Microsoft.Extensions.Options;
using SyncEngine.Abstractions.Protocol;
using SyncEngine.Client.Sqlite;
using SyncEngine.Server.Codec;

namespace SyncEngine.Benchmarks;

/// <summary>
/// Throughput benches against production-shaped related-entity graphs (not Facility-only toys).
/// </summary>
[MemoryDiagnoser]
[SimpleJob(warmupCount: 1, iterationCount: 3)]
public class DeltaApplyBenchmarks
{
    private readonly MemoryPackDeltaCodec _codec = new();
    private SqliteBatchApplier _applier = null!;
    private string _dbPath = null!;
    private DeltaBatch _batch = default!;
    private SyncSeedGraph _graph = null!;

    /// <summary>medium ≈ 2k mixed F/E/L + deletes; large ≈ 10k.</summary>
    [Params("medium", "large")]
    public string GraphScale { get; set; } = "medium";

    [GlobalSetup]
    public void Setup()
    {
        _dbPath = Path.Combine(Path.GetTempPath(), $"sync-bench-{Guid.NewGuid():N}.db");
        var options = Options.Create(new SqliteSyncOptions { ConnectionString = $"Data Source={_dbPath}" });
        var factory = new SqliteConnectionFactory(options);
        _applier = new SqliteBatchApplier(factory, ProductionBatchFactory.CreateHandlers(factory));

        _graph = GraphScale switch
        {
            "large" => ProductionBatchFactory.LargeGraph(),
            _ => ProductionBatchFactory.MediumGraph(),
        };
        _batch = ProductionBatchFactory.ToBatch(_codec, _graph);

        // Warm schema once outside timed iterations.
        _applier.ApplyAsync(_batch).GetAwaiter().GetResult();
    }

    [Benchmark(Description = "Apply production F→E→L graph (+deletes) to SQLite")]
    public Task ApplyBatchToSqlite() => _applier.ApplyAsync(_batch);

    [Benchmark(Description = "Encode+decode production DeltaBatch")]
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
