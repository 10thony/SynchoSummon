using Aviation.Shared.Entities;
using Aviation.Shared.Seed;
using SyncEngine.Abstractions.Codec;
using SyncEngine.Abstractions.Protocol;
using SyncEngine.Client.Sqlite;

namespace SyncEngine.Benchmarks;

/// <summary>
/// Encodes production-shaped Facility→Equipment→MaintenanceLog graphs into delta batches.
/// Benchmarks must use this — not Facility-only flat upserts.
/// </summary>
internal static class ProductionBatchFactory
{
    /// <summary>~2k mixed changes: dense related graph + trailing log deletes.</summary>
    public static SyncSeedGraph MediumGraph() =>
        CorridorSyncSeed.BuildScaled(
            facilities: 40,
            equipmentPerFacility: 8,
            logsPerEquipment: 5,
            deleteLogPercent: 5,
            runId: "gate-med");

    /// <summary>~10k mixed changes for cold snapshot gates.</summary>
    public static SyncSeedGraph LargeGraph() =>
        CorridorSyncSeed.BuildScaled(
            facilities: 100,
            equipmentPerFacility: 10,
            logsPerEquipment: 9,
            deleteLogPercent: 5,
            runId: "gate-lg");

    public static SqliteEntityDeltaHandler[] CreateHandlers(SqliteConnectionFactory factory) =>
    [
        new SqliteEntityDeltaHandler(AviationEntityNames.Facility, factory),
        new SqliteEntityDeltaHandler(AviationEntityNames.Equipment, factory),
        new SqliteEntityDeltaHandler(AviationEntityNames.MaintenanceLog, factory),
    ];

    public static DeltaBatch ToBatch(IDeltaCodec codec, SyncSeedGraph graph)
    {
        var changes = new List<DeltaChange>(graph.ChangeCount);
        long version = 0;

        foreach (var facility in graph.Facilities)
        {
            using var key = codec.Encode(new FacilityKey { FacilityId = facility.FacilityId });
            using var payload = codec.Encode(facility);
            changes.Add(new DeltaChange
            {
                Version = ++version,
                EntityName = AviationEntityNames.Facility,
                Operation = DeltaOperation.Upsert,
                KeyBytes = key.Memory.ToArray(),
                PayloadBytes = payload.Memory.ToArray(),
            });
        }

        foreach (var equipment in graph.Equipment)
        {
            using var key = codec.Encode(new EquipmentKey { EquipmentId = equipment.EquipmentId });
            using var payload = codec.Encode(equipment);
            changes.Add(new DeltaChange
            {
                Version = ++version,
                EntityName = AviationEntityNames.Equipment,
                Operation = DeltaOperation.Upsert,
                KeyBytes = key.Memory.ToArray(),
                PayloadBytes = payload.Memory.ToArray(),
            });
        }

        foreach (var log in graph.Logs)
        {
            using var key = codec.Encode(new MaintenanceLogKey { MaintenanceLogId = log.MaintenanceLogId });
            using var payload = codec.Encode(log);
            changes.Add(new DeltaChange
            {
                Version = ++version,
                EntityName = AviationEntityNames.MaintenanceLog,
                Operation = DeltaOperation.Upsert,
                KeyBytes = key.Memory.ToArray(),
                PayloadBytes = payload.Memory.ToArray(),
            });
        }

        foreach (var delete in graph.Deletes)
        {
            ReadOnlyMemory<byte> keyBytes = delete.EntityName switch
            {
                AviationEntityNames.Facility => EncodeKey(codec, new FacilityKey { FacilityId = delete.EntityKey }),
                AviationEntityNames.Equipment => EncodeKey(codec, new EquipmentKey { EquipmentId = delete.EntityKey }),
                AviationEntityNames.MaintenanceLog => EncodeKey(codec, new MaintenanceLogKey { MaintenanceLogId = delete.EntityKey }),
                _ => throw new InvalidOperationException($"Unknown entity '{delete.EntityName}'."),
            };

            changes.Add(new DeltaChange
            {
                Version = ++version,
                EntityName = delete.EntityName,
                Operation = DeltaOperation.Delete,
                KeyBytes = keyBytes.ToArray(),
                PayloadBytes = null,
            });
        }

        return new DeltaBatch
        {
            FromVersion = 0,
            ToVersion = version,
            HasMore = false,
            Changes = changes.ToArray(),
        };
    }

    private static byte[] EncodeKey<T>(IDeltaCodec codec, T key)
    {
        using var buffer = codec.Encode(key);
        return buffer.Memory.ToArray();
    }
}
