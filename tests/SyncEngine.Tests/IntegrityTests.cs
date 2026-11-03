using Aviation.Shared.Entities;
using SyncEngine.Abstractions.Protocol;
using SyncEngine.Client.Sqlite;
using SyncEngine.Server.Codec;
using SyncEngine.Server.Ledger;
using Microsoft.Extensions.Options;
using Xunit;

namespace SyncEngine.Tests;

public sealed class IntegrityTests
{
    [Fact]
    public async Task Ledger_VersionsAreStrictlyMonotonic_AndPagesAreContiguous()
    {
        var ledger = new InMemoryChangeLedger();
        var codec = new MemoryPackDeltaCodec();
        var versions = new List<long>();

        for (var i = 0; i < 100; i++)
        {
            using var key = codec.Encode(new FacilityKey { FacilityId = $"f-{i}" });
            using var payload = codec.Encode(new Facility
            {
                FacilityId = $"f-{i}",
                FacilityCode = $"C{i}",
                Name = $"N{i}",
                FacilityTypeCode = "AIRPORT",
                City = "X",
                StateCode = "IA",
                ZipCode = "50000",
                Latitude = 1,
                Longitude = 2,
            });
            versions.Add(await ledger.AppendAsync(
                AviationEntityNames.Facility,
                DeltaOperation.Upsert,
                key.Memory,
                payload.Memory));
        }

        Assert.Equal(Enumerable.Range(1, 100).Select(i => (long)i), versions);

        long cursor = 0;
        var seen = new List<long>();
        while (true)
        {
            var page = await ledger.GetDeltasAsync(cursor, limit: 17);
            if (page.Changes.Length == 0)
            {
                break;
            }

            foreach (var change in page.Changes)
            {
                seen.Add(change.Version);
                Assert.True(change.Version > cursor);
            }

            cursor = page.ToVersion;
            if (!page.HasMore)
            {
                break;
            }
        }

        Assert.Equal(100, seen.Count);
        Assert.Equal(seen.OrderBy(v => v), seen);
        Assert.Equal(100, await ledger.GetCurrentVersionAsync());
    }

    [Fact]
    public async Task SqliteApply_UpsertThenDelete_IsIdempotentAndOrdered()
    {
        var dbPath = Path.Combine(Path.GetTempPath(), $"sync-integrity-{Guid.NewGuid():N}.db");
        try
        {
            var options = Options.Create(new SqliteSyncOptions { ConnectionString = $"Data Source={dbPath}" });
            var factory = new SqliteConnectionFactory(options);
            var checkpoint = new SqliteCheckpointStore(factory);
            var applier = new SqliteBatchApplier(factory, [new SqliteEntityDeltaHandler("Facility", factory)]);
            var codec = new MemoryPackDeltaCodec();

            await checkpoint.SetVersionAsync(0);

            using var key = codec.Encode(new FacilityKey { FacilityId = "fac-1" });
            using var payload = codec.Encode(new Facility
            {
                FacilityId = "fac-1",
                FacilityCode = "DSM",
                Name = "Des Moines",
                FacilityTypeCode = "AIRPORT",
                City = "Des Moines",
                StateCode = "IA",
                ZipCode = "50321",
                Latitude = 41.5m,
                Longitude = -93.6m,
            });

            var upsert = new DeltaBatch
            {
                FromVersion = 0,
                ToVersion = 1,
                HasMore = false,
                Changes =
                [
                    new DeltaChange
                    {
                        Version = 1,
                        EntityName = "Facility",
                        Operation = DeltaOperation.Upsert,
                        KeyBytes = key.Memory.ToArray(),
                        PayloadBytes = payload.Memory.ToArray(),
                    },
                ],
            };
            await applier.ApplyAsync(upsert);
            await applier.ApplyAsync(upsert); // idempotent
            await checkpoint.SetVersionAsync(1);

            await using (var connection = await factory.OpenAsync())
            await using (var command = connection.CreateCommand())
            {
                command.CommandText = "SELECT COUNT(*) FROM sync_entity";
                Assert.Equal(1L, Convert.ToInt64(await command.ExecuteScalarAsync()));
            }

            var delete = new DeltaBatch
            {
                FromVersion = 1,
                ToVersion = 2,
                HasMore = false,
                Changes =
                [
                    new DeltaChange
                    {
                        Version = 2,
                        EntityName = "Facility",
                        Operation = DeltaOperation.Delete,
                        KeyBytes = key.Memory.ToArray(),
                        PayloadBytes = null,
                    },
                ],
            };
            await applier.ApplyAsync(delete);
            await checkpoint.SetVersionAsync(2);

            await using var connection2 = await factory.OpenAsync();
            await using var command2 = connection2.CreateCommand();
            command2.CommandText = "SELECT COUNT(*) FROM sync_entity";
            Assert.Equal(0L, Convert.ToInt64(await command2.ExecuteScalarAsync()));
            Assert.Equal(2, await checkpoint.GetVersionAsync());
        }
        finally
        {
            try { File.Delete(dbPath); } catch { /* ignore */ }
        }
    }

    [Fact]
    public void MemoryPack_KeyAndPayload_SurviveEncodeDecode_WithoutCorruption()
    {
        var codec = new MemoryPackDeltaCodec();
        var facility = new Facility
        {
            FacilityId = "fac-corrupt-check",
            FacilityCode = "CHK",
            Name = "Integrity Check — unicode ✓",
            FacilityTypeCode = "AIRPORT",
            City = "Cedar Rapids",
            StateCode = "IA",
            ZipCode = "52404",
            Latitude = 41.8847m,
            Longitude = -91.7108m,
            OperationalStatus = "OPERATIONAL",
        };

        // Force wide unicode payload.
        facility.Name = new string('航', 200) + facility.Name;

        using var key = codec.Encode(new FacilityKey { FacilityId = facility.FacilityId });
        using var payload = codec.Encode(facility);
        var batch = new DeltaBatch
        {
            FromVersion = 0,
            ToVersion = 1,
            HasMore = true,
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
        var decoded = codec.DecodeBatch(encoded.Memory.Span);
        Assert.True(decoded.HasMore);
        var roundTrip = codec.Decode<Facility>(decoded.Changes[0].PayloadBytes);
        Assert.Equal(facility.FacilityId, roundTrip.FacilityId);
        Assert.Equal(facility.Name, roundTrip.Name);
        Assert.Equal(facility.Latitude, roundTrip.Latitude);
        Assert.Equal(facility.Longitude, roundTrip.Longitude);
    }
}
