using Aviation.Shared.Entities;

namespace Aviation.Shared.Seed;

/// <summary>
/// Builds related-entity sync graphs that mirror SEED_PACK corridor depth (not Facility-only toys).
/// </summary>
public static class CorridorSyncSeed
{
    /// <summary>
    /// Startup / demo corridor: multi-facility NAS slice with full equipment stacks and location-aware logs.
    /// </summary>
    public static SyncSeedGraph BuildDemoCorridor(DateTimeOffset? now = null)
    {
        var stamped = now ?? DateTimeOffset.UtcNow;
        var facilities = new List<Facility>();
        var equipment = new List<Equipment>();
        var logs = new List<MaintenanceLog>();

        AddSite(
            facilities, equipment, logs, stamped,
            facilityId: "fac-dsm",
            code: "DSM",
            name: "Des Moines International",
            type: "AIRPORT",
            city: AviationSeedCatalog.Cities[0],
            stack: ["ILS", "GLIDESLOPE", "LOCALIZER", "MALSR", "AWOS", "ASR"]);

        AddSite(
            facilities, equipment, logs, stamped,
            facilityId: "fac-cid",
            code: "CID",
            name: "The Eastern Iowa Airport",
            type: "AIRPORT",
            city: AviationSeedCatalog.Cities[1],
            stack: ["ILS", "VOR", "DME", "AWOS", "LOCALIZER"]);

        AddSite(
            facilities, equipment, logs, stamped,
            facilityId: "fac-dsm-tracon",
            code: "DSM-T",
            name: "Des Moines TRACON",
            type: "TRACON",
            city: AviationSeedCatalog.Cities[0],
            stack: ["ASR", "ASDE", "RVR"]);

        AddSite(
            facilities, equipment, logs, stamped,
            facilityId: "fac-dbq",
            code: "DBQ",
            name: "Dubuque Regional",
            type: "AIRPORT",
            city: AviationSeedCatalog.Cities[2],
            stack: ["VOR", "DME", "AWOS"]);

        AddSite(
            facilities, equipment, logs, stamped,
            facilityId: "fac-alo",
            code: "ALO",
            name: "Waterloo Regional",
            type: "AIRPORT",
            city: AviationSeedCatalog.Cities[3],
            stack: ["ILS", "GLIDESLOPE", "LOCALIZER", "AWOS"]);

        return new SyncSeedGraph(facilities, equipment, logs, Deletes: []);
    }

    /// <summary>
    /// Scaled production-shaped graph for benchmarks / load stress.
    /// Parents first, then children; optional trailing log deletes simulate churn.
    /// </summary>
    public static SyncSeedGraph BuildScaled(
        int facilities,
        int equipmentPerFacility,
        int logsPerEquipment,
        int deleteLogPercent = 5,
        string runId = "bench",
        DateTimeOffset? now = null)
    {
        ArgumentOutOfRangeException.ThrowIfNegativeOrZero(facilities);
        ArgumentOutOfRangeException.ThrowIfNegative(equipmentPerFacility);
        ArgumentOutOfRangeException.ThrowIfNegative(logsPerEquipment);
        deleteLogPercent = Math.Clamp(deleteLogPercent, 0, 100);

        var stamped = now ?? DateTimeOffset.UtcNow;
        var facilityList = new List<Facility>(facilities);
        var equipmentList = new List<Equipment>(facilities * equipmentPerFacility);
        var logList = new List<MaintenanceLog>(facilities * equipmentPerFacility * logsPerEquipment);
        var corridor = $"NAS-{runId}";

        for (var f = 0; f < facilities; f++)
        {
            var city = AviationSeedCatalog.Cities[f % AviationSeedCatalog.Cities.Length];
            var type = AviationSeedCatalog.FacilityTypes[f % AviationSeedCatalog.FacilityTypes.Length];
            var facilityId = $"{runId}-fac-{f:D4}";
            var code = MakeCode(runId, f);

            facilityList.Add(new Facility
            {
                FacilityId = facilityId,
                FacilityCode = code,
                Name = $"{city.Name} {type} Hub #{f}",
                FacilityTypeCode = type,
                City = city.Name,
                StateCode = city.State,
                ZipCode = city.Zip,
                Latitude = city.Lat + (f % 50) * 0.001m,
                Longitude = city.Lon - (f % 50) * 0.001m,
                OperationalStatus = f % 7 == 0 ? "MAINTENANCE" : "OPERATIONAL",
                MetadataJson = AviationSeedCatalog.BuildFacilityMetadata(code, corridor, f),
            });

            for (var e = 0; e < equipmentPerFacility; e++)
            {
                var eqType = AviationSeedCatalog.EquipmentTypes[e % AviationSeedCatalog.EquipmentTypes.Length];
                var manufacturer = AviationSeedCatalog.Manufacturers[e % AviationSeedCatalog.Manufacturers.Length];
                var equipmentId = $"{facilityId}-eq-{e:D3}";

                equipmentList.Add(new Equipment
                {
                    EquipmentId = equipmentId,
                    FacilityId = facilityId,
                    EquipmentTypeCode = eqType,
                    Identifier = $"{eqType}-{f:D3}-{e:D2}",
                    Name = $"{eqType} cabinet {e} at {city.Name}",
                    OperationalStatus = e % 5 == 0 ? "DEGRADED" : "OPERATIONAL",
                    Manufacturer = manufacturer,
                    Model = $"MK-{20 + (e % 10)}",
                    MetadataJson = AviationSeedCatalog.BuildEquipmentMetadata(eqType, manufacturer, e),
                });

                for (var l = 0; l < logsPerEquipment; l++)
                {
                    var location = AviationSeedCatalog.LocationLabels[(f + e + l) % AviationSeedCatalog.LocationLabels.Length];
                    logList.Add(new MaintenanceLog
                    {
                        MaintenanceLogId = $"{equipmentId}-log-{l:D3}",
                        MaintenanceActivityId = $"{runId}-act-{f:D4}-{e:D3}",
                        LogEntryType = AviationSeedCatalog.LogTypes[l % AviationSeedCatalog.LogTypes.Length],
                        Message = AviationSeedCatalog.BuildLogMessage(city.Name, eqType, location, l),
                        LoggedAt = stamped.AddMinutes(-(f * 10 + e + l)),
                        FacilityId = facilityId,
                        EquipmentId = equipmentId,
                        LocationLabel = location,
                        MetadataJson =
                            $$"""{"severity":"{{(l % 4) + 1}}","shift":"{{(l % 3) + 1}}","tech":"T{{(f + e + l) % 40:D2}}"}""",
                    });
                }
            }
        }

        var deletes = new List<SyncSeedDelete>();
        if (deleteLogPercent > 0 && logList.Count > 0)
        {
            var deleteCount = Math.Max(1, logList.Count * deleteLogPercent / 100);
            for (var i = 0; i < deleteCount; i++)
            {
                var log = logList[(i * 17) % logList.Count];
                deletes.Add(new SyncSeedDelete(AviationEntityNames.MaintenanceLog, log.MaintenanceLogId));
            }
        }

        return new SyncSeedGraph(facilityList, equipmentList, logList, deletes);
    }

    private static void AddSite(
        List<Facility> facilities,
        List<Equipment> equipment,
        List<MaintenanceLog> logs,
        DateTimeOffset stamped,
        string facilityId,
        string code,
        string name,
        string type,
        AviationSeedCatalog.City city,
        string[] stack)
    {
        facilities.Add(new Facility
        {
            FacilityId = facilityId,
            FacilityCode = code,
            Name = name,
            FacilityTypeCode = type,
            City = city.Name,
            StateCode = city.State,
            ZipCode = city.Zip,
            Latitude = city.Lat,
            Longitude = city.Lon,
            OperationalStatus = "OPERATIONAL",
            MetadataJson = AviationSeedCatalog.BuildFacilityMetadata(code, "DSM-ILS-corridor", facilities.Count),
        });

        for (var e = 0; e < stack.Length; e++)
        {
            var eqType = stack[e];
            var manufacturer = AviationSeedCatalog.Manufacturers[e % AviationSeedCatalog.Manufacturers.Length];
            var equipmentId = $"{facilityId}-eq-{eqType.ToLowerInvariant()}";
            equipment.Add(new Equipment
            {
                EquipmentId = equipmentId,
                FacilityId = facilityId,
                EquipmentTypeCode = eqType,
                Identifier = $"{eqType}-{code}",
                Name = $"{eqType} at {name}",
                OperationalStatus = e == 1 && code == "DSM" ? "DEGRADED" : "OPERATIONAL",
                Manufacturer = manufacturer,
                Model = $"MK-{20 + e}",
                MetadataJson = AviationSeedCatalog.BuildEquipmentMetadata(eqType, manufacturer, e),
            });

            var logCount = 3 + (e % 3);
            for (var l = 0; l < logCount; l++)
            {
                var location = AviationSeedCatalog.LocationLabels[(e + l) % AviationSeedCatalog.LocationLabels.Length];
                logs.Add(new MaintenanceLog
                {
                    MaintenanceLogId = $"{equipmentId}-log-{l:D2}",
                    MaintenanceActivityId = $"{facilityId}-act-{eqType.ToLowerInvariant()}",
                    LogEntryType = AviationSeedCatalog.LogTypes[l % AviationSeedCatalog.LogTypes.Length],
                    Message = AviationSeedCatalog.BuildLogMessage(city.Name, eqType, location, l),
                    LoggedAt = stamped.AddHours(-(e * 3 + l)),
                    FacilityId = facilityId,
                    EquipmentId = equipmentId,
                    LocationLabel = location,
                    MetadataJson = $$"""{"severity":"{{(l % 4) + 1}}","clearance":{{(l == 0).ToString().ToLowerInvariant()}}}""",
                });
            }
        }
    }

    private static string MakeCode(string runId, int facilityIndex)
    {
        var prefix = runId.Length >= 1 ? char.ToUpperInvariant(runId[0]) : 'X';
        var raw = $"{prefix}{facilityIndex:D4}";
        return raw.Length <= 16 ? raw : raw[..16];
    }
}
