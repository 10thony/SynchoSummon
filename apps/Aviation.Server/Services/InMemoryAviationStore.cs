using System.Collections.Concurrent;
using Aviation.Shared.Entities;
using Aviation.Shared.Seed;
using SyncEngine.Abstractions.Codec;
using SyncEngine.Server.Ledger;

namespace Aviation.Server.Services;

public sealed class InMemoryAviationStore(ChangeLedgerWriter ledgerWriter, IDeltaCodec codec)
{
    private readonly ConcurrentDictionary<string, Facility> _facilities = new(StringComparer.OrdinalIgnoreCase);
    private readonly ConcurrentDictionary<string, Equipment> _equipment = new(StringComparer.OrdinalIgnoreCase);
    private readonly ConcurrentDictionary<string, MaintenanceLog> _logs = new(StringComparer.OrdinalIgnoreCase);

    public IEnumerable<Facility> ListFacilities() => _facilities.Values.OrderBy(f => f.FacilityCode);

    public IEnumerable<Equipment> ListEquipment() => _equipment.Values.OrderBy(e => e.Identifier);

    public IEnumerable<MaintenanceLog> ListLogs() => _logs.Values.OrderByDescending(l => l.LoggedAt);

    public void PutFacility(Facility facility) => _facilities[facility.FacilityId] = facility;

    public void PutEquipment(Equipment equipment) => _equipment[equipment.EquipmentId] = equipment;

    public void PutLog(MaintenanceLog log) => _logs[log.MaintenanceLogId] = log;

    public async Task<Facility> UpsertFacilityAsync(Facility facility, CancellationToken cancellationToken = default)
    {
        PutFacility(facility);
        using var key = codec.Encode(new FacilityKey { FacilityId = facility.FacilityId });
        using var payload = codec.Encode(facility);
        await ledgerWriter.RecordUpsertAsync(
            AviationEntityNames.Facility,
            key.Memory,
            payload.Memory,
            cancellationToken: cancellationToken);
        return facility;
    }

    public async Task<Equipment> UpsertEquipmentAsync(Equipment equipment, CancellationToken cancellationToken = default)
    {
        PutEquipment(equipment);
        using var key = codec.Encode(new EquipmentKey { EquipmentId = equipment.EquipmentId });
        using var payload = codec.Encode(equipment);
        await ledgerWriter.RecordUpsertAsync(
            AviationEntityNames.Equipment,
            key.Memory,
            payload.Memory,
            cancellationToken: cancellationToken);
        return equipment;
    }

    public async Task<MaintenanceLog> UpsertLogAsync(MaintenanceLog log, CancellationToken cancellationToken = default)
    {
        PutLog(log);
        using var key = codec.Encode(new MaintenanceLogKey { MaintenanceLogId = log.MaintenanceLogId });
        using var payload = codec.Encode(log);
        await ledgerWriter.RecordUpsertAsync(
            AviationEntityNames.MaintenanceLog,
            key.Memory,
            payload.Memory,
            cancellationToken: cancellationToken);
        return log;
    }

    public async Task SeedDemoAsync(CancellationToken cancellationToken = default)
    {
        if (!_facilities.IsEmpty)
        {
            return;
        }

        // Production-shaped corridor graph. Silent ledger appends + one wake (avoid N SignalR floods on boot).
        var graph = CorridorSyncSeed.BuildDemoCorridor();
        long lastVersion = 0;

        foreach (var facility in graph.Facilities)
        {
            PutFacility(facility);
            using var key = codec.Encode(new FacilityKey { FacilityId = facility.FacilityId });
            using var payload = codec.Encode(facility);
            lastVersion = await ledgerWriter.RecordUpsertAsync(
                AviationEntityNames.Facility,
                key.Memory,
                payload.Memory,
                cancellationToken: cancellationToken,
                enqueueWake: false,
                recordTelemetry: false);
        }

        foreach (var equipment in graph.Equipment)
        {
            PutEquipment(equipment);
            using var key = codec.Encode(new EquipmentKey { EquipmentId = equipment.EquipmentId });
            using var payload = codec.Encode(equipment);
            lastVersion = await ledgerWriter.RecordUpsertAsync(
                AviationEntityNames.Equipment,
                key.Memory,
                payload.Memory,
                cancellationToken: cancellationToken,
                enqueueWake: false,
                recordTelemetry: false);
        }

        foreach (var log in graph.Logs)
        {
            PutLog(log);
            using var key = codec.Encode(new MaintenanceLogKey { MaintenanceLogId = log.MaintenanceLogId });
            using var payload = codec.Encode(log);
            lastVersion = await ledgerWriter.RecordUpsertAsync(
                AviationEntityNames.MaintenanceLog,
                key.Memory,
                payload.Memory,
                cancellationToken: cancellationToken,
                enqueueWake: false,
                recordTelemetry: false);
        }

        if (lastVersion > 0)
        {
            await ledgerWriter.EnqueueWakeAsync(lastVersion, AviationEntityNames.Facility, cancellationToken: cancellationToken);
        }
    }
}
