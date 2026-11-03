using System.Diagnostics;
using Aviation.Shared.Entities;
using Microsoft.Extensions.Options;
using SyncEngine.Abstractions.Protocol;
using SyncEngine.Client.Sqlite;
using SyncEngine.Server.Codec;

namespace SyncEngine.Benchmarks;

/// <summary>
/// Non-BDN gate runner used in CI/agent loops. Exit code 0 only if plan gates pass.
/// </summary>
public static class GateRunner
{
    public static async Task<int> RunAsync()
    {
        var codec = new MemoryPackDeltaCodec();
        var dbPath = Path.Combine(Path.GetTempPath(), $"sync-gate-{Guid.NewGuid():N}.db");
        try
        {
            var options = Options.Create(new SqliteSyncOptions { ConnectionString = $"Data Source={dbPath}" });
            var factory = new SqliteConnectionFactory(options);
            var applier = new SqliteBatchApplier(factory, [new SqliteEntityDeltaHandler(AviationEntityNames.Facility, factory)]);

            // --- Gate: 1k apply >= 5k changes/sec ---
            var batch1k = BuildBatch(codec, 1000);
            await applier.ApplyAsync(batch1k); // warm
            var sw = Stopwatch.StartNew();
            const int iters = 10;
            for (var i = 0; i < iters; i++)
            {
                await applier.ApplyAsync(batch1k);
            }

            sw.Stop();
            var applyPerSec = (1000.0 * iters) / sw.Elapsed.TotalSeconds;
            Console.WriteLine($"GATE apply_1k_changes_per_sec={applyPerSec:F0} (need >= 5000)");
            if (applyPerSec < 5000)
            {
                Console.Error.WriteLine("FAIL: apply throughput gate");
                return 1;
            }

            // --- Gate: cold 10k snapshot < 3s ---
            var db10 = Path.Combine(Path.GetTempPath(), $"sync-gate-10k-{Guid.NewGuid():N}.db");
            try
            {
                var opt10 = Options.Create(new SqliteSyncOptions { ConnectionString = $"Data Source={db10}" });
                var factory10 = new SqliteConnectionFactory(opt10);
                var applier10 = new SqliteBatchApplier(factory10, [new SqliteEntityDeltaHandler(AviationEntityNames.Facility, factory10)]);
                var batch10k = BuildBatch(codec, 10_000);
                var cold = Stopwatch.StartNew();
                await applier10.ApplyAsync(batch10k);
                cold.Stop();
                Console.WriteLine($"GATE cold_10k_ms={cold.Elapsed.TotalMilliseconds:F0} (need < 3000)");
                if (cold.Elapsed.TotalMilliseconds >= 3000)
                {
                    Console.Error.WriteLine("FAIL: cold 10k snapshot gate");
                    return 1;
                }
            }
            finally
            {
                try { File.Delete(db10); } catch { /* ignore */ }
            }

            // --- Gate: encode/decode allocations stay under 1MB for 1k batch ---
            long before = GC.GetAllocatedBytesForCurrentThread();
            for (var i = 0; i < 50; i++)
            {
                using var buf = codec.EncodeBatch(batch1k);
                _ = codec.DecodeBatch(buf.Memory.Span);
            }

            long after = GC.GetAllocatedBytesForCurrentThread();
            var avgAlloc = (after - before) / 50.0;
            Console.WriteLine($"GATE encode_decode_alloc_bytes_avg={avgAlloc:F0} (need < 1048576)");
            if (avgAlloc >= 1_048_576)
            {
                Console.Error.WriteLine("FAIL: allocation gate");
                return 1;
            }

            Console.WriteLine("ALL SPEED GATES PASSED");
            return 0;
        }
        finally
        {
            try { File.Delete(dbPath); } catch { /* ignore */ }
        }
    }

    private static DeltaBatch BuildBatch(MemoryPackDeltaCodec codec, int count)
    {
        var changes = new DeltaChange[count];
        for (var i = 0; i < count; i++)
        {
            var facility = new Facility
            {
                FacilityId = $"fac-{i}",
                FacilityCode = $"F{i:D5}",
                Name = $"Facility {i} complex payload with metadata and status text",
                FacilityTypeCode = "AIRPORT",
                City = "Des Moines",
                StateCode = "IA",
                ZipCode = "50321",
                Latitude = 41.5m + (i % 1000) * 0.0001m,
                Longitude = -93.6m - (i % 1000) * 0.0001m,
                OperationalStatus = i % 2 == 0 ? "OPERATIONAL" : "MAINTENANCE",
            };
            using var key = codec.Encode(new FacilityKey { FacilityId = facility.FacilityId });
            using var payload = codec.Encode(facility);
            changes[i] = new DeltaChange
            {
                Version = i + 1,
                EntityName = AviationEntityNames.Facility,
                Operation = DeltaOperation.Upsert,
                KeyBytes = key.Memory.ToArray(),
                PayloadBytes = payload.Memory.ToArray(),
            };
        }

        return new DeltaBatch
        {
            FromVersion = 0,
            ToVersion = count,
            HasMore = false,
            Changes = changes,
        };
    }
}
