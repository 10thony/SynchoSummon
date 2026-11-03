using System.Collections.Concurrent;
using Aviation.Shared.Entities;
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

        await UpsertFacilityAsync(new Facility
        {
            FacilityId = "fac-dsm",
            FacilityCode = "DSM",
            Name = "Des Moines International",
            FacilityTypeCode = "AIRPORT",
            City = "Des Moines",
            StateCode = "IA",
            ZipCode = "50321",
            Latitude = 41.5340m,
            Longitude = -93.6631m,
        }, cancellationToken);

        await UpsertEquipmentAsync(new Equipment
        {
            EquipmentId = "eq-ils-09",
            FacilityId = "fac-dsm",
            EquipmentTypeCode = "ILS",
            Identifier = "ILS-09",
            Name = "ILS Runway 09",
            Manufacturer = "Raytheon",
            Model = "Mark 20",
        }, cancellationToken);

        await UpsertLogAsync(new MaintenanceLog
        {
            MaintenanceLogId = "log-1",
            MaintenanceActivityId = "act-1",
            LogEntryType = "NOTE",
            Message = "GS cabinet inspection complete",
            LoggedAt = DateTimeOffset.UtcNow,
            FacilityId = "fac-dsm",
            EquipmentId = "eq-ils-09",
            LocationLabel = "GS_CABINET",
        }, cancellationToken);
    }
}
