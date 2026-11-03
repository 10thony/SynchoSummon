using System.Text;
using Aviation.Shared.Entities;

namespace Aviation.Server.Services;

/// <summary>
/// Describes a single tier within a load profile — a batch of equally-sized packages.
/// Mirrors the tier shapes used by the external SyncEngine.LoadGen tool so results stay comparable.
/// </summary>
public sealed record LoadTier(
    string Name,
    int PackageCount,
    int Facilities,
    int EquipmentPerFacility,
    int LogsPerEquipment,
    int PadBytes)
{
    public int EntitiesPerPackage =>
        Facilities + Facilities * EquipmentPerFacility + Facilities * EquipmentPerFacility * LogsPerEquipment;

    public int TotalEntities => PackageCount * EntitiesPerPackage;
}

/// <summary>A named stack of tiers (smoke / hard / crush).</summary>
public sealed record LoadProfile(string Name, string Description, IReadOnlyList<LoadTier> Tiers)
{
    public int TotalPackages => Tiers.Sum(t => t.PackageCount);

    public long TotalEntities => Tiers.Sum(t => (long)t.TotalEntities);
}

/// <summary>
/// Builds aviation-flavored load packages in-process. Ported from tools/SyncEngine.LoadGen
/// so the Aviation.Server can fire load without spawning a separate process.
/// </summary>
public static class LoadPackageGenerator
{
    public static readonly IReadOnlyList<string> ProfileNames = ["smoke", "hard", "crush"];

    public static LoadProfile GetProfile(string name)
    {
        var key = (name ?? string.Empty).Trim().ToLowerInvariant();
        return key switch
        {
            "smoke" => new LoadProfile(
                "smoke",
                "Fast sanity: a couple of tiny + small packages to warm the pipeline.",
                [
                    new("tiny", PackageCount: 2, Facilities: 5, EquipmentPerFacility: 2, LogsPerEquipment: 1, PadBytes: 256),
                    new("small", PackageCount: 2, Facilities: 20, EquipmentPerFacility: 3, LogsPerEquipment: 2, PadBytes: 2_048),
                ]),
            "hard" => new LoadProfile(
                "hard",
                "Stress run: pads step up through 256 KB; mid-size catch-up pulls.",
                [
                    new("tiny", 4, 10, 2, 1, 512),
                    new("small", 6, 40, 4, 2, 4_096),
                    new("medium", 6, 80, 5, 3, 16_384),
                    new("large", 4, 120, 6, 4, 65_536),
                    new("xlarge", 2, 200, 8, 5, 262_144),
                ]),
            "crush" => new LoadProfile(
                "crush",
                "Aggressive crush: pads up to 1 MB; keeps total transfer in the hundreds of MB, not tens of GB.",
                [
                    new("tiny", 10, 25, 3, 2, 2_048),
                    new("small", 12, 60, 5, 3, 16_384),
                    new("medium", 10, 100, 6, 4, 65_536),
                    new("large", 8, 120, 8, 4, 262_144),
                    new("xlarge", 4, 150, 8, 4, 524_288),
                    new("mega", 2, 80, 6, 3, 1_048_576),
                ]),
            _ => throw new ArgumentOutOfRangeException(
                nameof(name),
                name,
                "Unknown load profile. Expected one of: smoke, hard, crush."),
        };
    }

    public static LoadPackageRequest BuildPackage(string runId, LoadTier tier, int index)
    {
        var packageId = $"{runId}-{tier.Name}-{index:D3}";
        var package = new LoadPackageRequest
        {
            PackageId = packageId,
            Tier = tier.Name,
            Facilities = new List<Facility>(tier.Facilities),
            Equipment = new List<Equipment>(tier.Facilities * tier.EquipmentPerFacility),
            MaintenanceLogs = new List<MaintenanceLog>(tier.Facilities * tier.EquipmentPerFacility * tier.LogsPerEquipment),
        };

        // All facilities in a package share one pad string so the graph itself stays modestly sized;
        // MemoryPack still serializes the full string per entity.
        var pad = CreatePad(tier.PadBytes, packageId);
        var equipmentPad = CreatePad(Math.Max(256, tier.PadBytes / 4), packageId + "-eq");
        var logPad = CreatePad(Math.Max(256, tier.PadBytes / 8), packageId + "-log");

        for (var f = 0; f < tier.Facilities; f++)
        {
            var facilityId = $"{packageId}-fac-{f:D4}";
            var city = SeedData.Cities[f % SeedData.Cities.Length];
            var type = SeedData.FacilityTypes[f % SeedData.FacilityTypes.Length];
            package.Facilities.Add(new Facility
            {
                FacilityId = facilityId,
                FacilityCode = MakeCode(tier.Name, index, f),
                Name = $"{city.Name} {type} Hub #{f} [{packageId}]",
                FacilityTypeCode = type,
                City = city.Name,
                StateCode = city.State,
                ZipCode = city.Zip,
                Latitude = city.Lat + (f % 50) * 0.001m,
                Longitude = city.Lon - (f % 50) * 0.001m,
                OperationalStatus = f % 7 == 0 ? "MAINTENANCE" : "OPERATIONAL",
                MetadataJson = pad,
            });

            for (var e = 0; e < tier.EquipmentPerFacility; e++)
            {
                var equipmentId = $"{facilityId}-eq-{e:D3}";
                var eqType = SeedData.EquipmentTypes[e % SeedData.EquipmentTypes.Length];
                package.Equipment.Add(new Equipment
                {
                    EquipmentId = equipmentId,
                    FacilityId = facilityId,
                    EquipmentTypeCode = eqType,
                    Identifier = $"{eqType}-{f:D3}-{e:D2}",
                    Name = $"{eqType} cabinet {e} at {city.Name}",
                    OperationalStatus = e % 5 == 0 ? "DEGRADED" : "OPERATIONAL",
                    Manufacturer = SeedData.Manufacturers[e % SeedData.Manufacturers.Length],
                    Model = $"MK-{20 + e % 10}",
                    MetadataJson = equipmentPad,
                });

                for (var l = 0; l < tier.LogsPerEquipment; l++)
                {
                    package.MaintenanceLogs.Add(new MaintenanceLog
                    {
                        MaintenanceLogId = $"{equipmentId}-log-{l:D3}",
                        MaintenanceActivityId = $"{packageId}-act-{f:D4}-{e:D3}",
                        LogEntryType = SeedData.LogTypes[l % SeedData.LogTypes.Length],
                        Message = BuildLogMessage(city.Name, eqType, l, logPad),
                        LoggedAt = DateTimeOffset.UtcNow.AddMinutes(-(f * 10 + e + l)),
                        FacilityId = facilityId,
                        EquipmentId = equipmentId,
                        LocationLabel = SeedData.LocationLabels[(f + e + l) % SeedData.LocationLabels.Length],
                        MetadataJson = logPad,
                    });
                }
            }
        }

        return package;
    }

    private static string CreatePad(int bytes, string salt)
    {
        if (bytes <= 0)
        {
            return "{}";
        }

        var sb = new StringBuilder(bytes + 64);
        sb.Append("{\"salt\":\"").Append(salt).Append("\",\"blob\":\"");
        const string token = "NAS-DSM-ILS-GS-CABINET-PARTS-QUOTE-NOTAM-WX-";
        while (sb.Length < bytes)
        {
            sb.Append(token);
        }

        if (sb.Length > bytes)
        {
            sb.Length = bytes;
        }

        sb.Append("\"}");
        return sb.ToString();
    }

    private static string BuildLogMessage(string city, string eqType, int index, string pad)
    {
        var head = $"[{city}/{eqType}] inspection note #{index}: torque check, alarm clear, parts kit verified. ";
        var take = Math.Min(pad.Length, 8_192);
        return head + pad.AsSpan(0, take).ToString();
    }

    private static string MakeCode(string tier, int packageIndex, int facilityIndex)
    {
        var raw = $"{tier[0]}{packageIndex:D2}{facilityIndex:D3}";
        return raw.Length <= 16 ? raw.ToUpperInvariant() : raw[..16].ToUpperInvariant();
    }

    internal sealed record City(string Name, string State, string Zip, decimal Lat, decimal Lon);

    internal static class SeedData
    {
        // Drawn from the aviation / Upper Midwest corridor seed flavor.
        public static readonly City[] Cities =
        [
            new("Des Moines", "IA", "50321", 41.5340m, -93.6631m),
            new("Cedar Rapids", "IA", "52404", 41.8847m, -91.7108m),
            new("Dubuque", "IA", "52001", 42.4020m, -90.7095m),
            new("Waterloo", "IA", "50701", 42.5571m, -92.4003m),
            new("Ames", "IA", "50010", 41.9922m, -93.6217m),
            new("Iowa City", "IA", "52240", 41.6611m, -91.5302m),
            new("Omaha", "NE", "68110", 41.3030m, -95.8940m),
            new("Minneapolis", "MN", "55450", 44.8820m, -93.2218m),
        ];

        public static readonly string[] FacilityTypes = ["AIRPORT", "TRACON", "ARTCC", "FSS", "ATCT"];
        public static readonly string[] EquipmentTypes = ["ILS", "VOR", "DME", "ASR", "ASDE", "AWOS", "GLIDESLOPE", "LOCALIZER"];
        public static readonly string[] Manufacturers = ["Raytheon", "Thales", "Leonardo", "Honeywell", "Indra"];
        public static readonly string[] LogTypes = ["NOTE", "INSPECTION", "REPAIR", "ALARM", "PARTS"];
        public static readonly string[] LocationLabels = ["GS_CABINET", "LLZ_SHELTER", "RADAR_TOWER", "EQUIP_ROOM", "GATE_G12", "BIN_A3"];
    }
}
