using System.Diagnostics;
using Microsoft.Extensions.Options;
using SyncEngine.Client.Sqlite;
using SyncEngine.Abstractions.Codec;

namespace SyncEngine.Benchmarks;

/// <summary>
/// CI speed gates against production-shaped Facility→Equipment→MaintenanceLog graphs.
/// Thresholds are honest floors for mixed related-entity batches — not Facility-only toys.
/// </summary>
public static class GateRunner
{
    // Calibrated against production-shaped F→E→L graphs (+churn deletes) on a typical agent box.
    // Floors keep ~3–4× headroom for CI variance — not the old Facility-only cosplay numbers.
    private const double MinMediumApplyChangesPerSec = 15_000;
    private const double MaxLargeColdMs = 2_000;
    private const double MaxMediumEncodeDecodeAllocBytes = 3_000_000;

    public static async Task<int> RunAsync()
    {
        var codec = new MemoryPackDeltaCodec();
        var dbPath = Path.Combine(Path.GetTempPath(), $"sync-gate-{Guid.NewGuid():N}.db");
        try
        {
            var options = Options.Create(new SqliteSyncOptions { ConnectionString = $"Data Source={dbPath}" });
            var factory = new SqliteConnectionFactory(options);
            var applier = new SqliteBatchApplier(factory, ProductionBatchFactory.CreateHandlers(factory));

            var mediumGraph = ProductionBatchFactory.MediumGraph();
            var batchMedium = ProductionBatchFactory.ToBatch(codec, mediumGraph);
            Console.WriteLine(
                $"GRAPH medium upserts={mediumGraph.UpsertCount} deletes={mediumGraph.Deletes.Count} total={mediumGraph.ChangeCount} " +
                $"(F={mediumGraph.Facilities.Count} E={mediumGraph.Equipment.Count} L={mediumGraph.Logs.Count})");

            // --- Gate: medium production graph apply throughput ---
            await applier.ApplyAsync(batchMedium); // warm
            var sw = Stopwatch.StartNew();
            const int iters = 10;
            for (var i = 0; i < iters; i++)
            {
                await applier.ApplyAsync(batchMedium);
            }

            sw.Stop();
            var applyPerSec = (mediumGraph.ChangeCount * (double)iters) / sw.Elapsed.TotalSeconds;
            Console.WriteLine(
                $"GATE apply_medium_production_changes_per_sec={applyPerSec:F0} (need >= {MinMediumApplyChangesPerSec})");
            if (applyPerSec < MinMediumApplyChangesPerSec)
            {
                Console.Error.WriteLine("FAIL: medium production apply throughput gate");
                return 1;
            }

            // --- Gate: cold large production snapshot ---
            var dbLarge = Path.Combine(Path.GetTempPath(), $"sync-gate-large-{Guid.NewGuid():N}.db");
            try
            {
                var optLarge = Options.Create(new SqliteSyncOptions { ConnectionString = $"Data Source={dbLarge}" });
                var factoryLarge = new SqliteConnectionFactory(optLarge);
                var applierLarge = new SqliteBatchApplier(factoryLarge, ProductionBatchFactory.CreateHandlers(factoryLarge));
                var largeGraph = ProductionBatchFactory.LargeGraph();
                var batchLarge = ProductionBatchFactory.ToBatch(codec, largeGraph);
                Console.WriteLine(
                    $"GRAPH large upserts={largeGraph.UpsertCount} deletes={largeGraph.Deletes.Count} total={largeGraph.ChangeCount}");

                var cold = Stopwatch.StartNew();
                await applierLarge.ApplyAsync(batchLarge);
                cold.Stop();
                Console.WriteLine(
                    $"GATE cold_large_production_ms={cold.Elapsed.TotalMilliseconds:F0} (need < {MaxLargeColdMs})");
                if (cold.Elapsed.TotalMilliseconds >= MaxLargeColdMs)
                {
                    Console.Error.WriteLine("FAIL: cold large production snapshot gate");
                    return 1;
                }
            }
            finally
            {
                try { File.Delete(dbLarge); } catch { /* ignore */ }
            }

            // --- Gate: encode/decode allocations for medium production batch ---
            long before = GC.GetAllocatedBytesForCurrentThread();
            for (var i = 0; i < 50; i++)
            {
                using var buf = codec.EncodeBatch(batchMedium);
                _ = codec.DecodeBatch(buf.Memory.Span);
            }

            long after = GC.GetAllocatedBytesForCurrentThread();
            var avgAlloc = (after - before) / 50.0;
            Console.WriteLine(
                $"GATE encode_decode_alloc_bytes_avg={avgAlloc:F0} (need < {MaxMediumEncodeDecodeAllocBytes})");
            if (avgAlloc >= MaxMediumEncodeDecodeAllocBytes)
            {
                Console.Error.WriteLine("FAIL: allocation gate");
                return 1;
            }

            Console.WriteLine("ALL PRODUCTION-SHAPED SPEED GATES PASSED");
            return 0;
        }
        finally
        {
            try { File.Delete(dbPath); } catch { /* ignore */ }
        }
    }
}
