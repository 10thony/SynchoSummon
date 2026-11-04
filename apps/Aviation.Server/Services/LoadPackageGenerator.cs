using Aviation.Shared.Entities;
using Aviation.Shared.Seed;

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
/// Builds production-shaped aviation load packages (related F→E→L graphs).
/// Size comes from entity fan-out and realistic metadata — not megabyte pad blobs.
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
                "Fast sanity: dense related graphs with compact metadata (no pad inflation).",
                [
                    // PadBytes capped to compact structured metadata budget.
                    new("tiny", PackageCount: 2, Facilities: 5, EquipmentPerFacility: 6, LogsPerEquipment: 4, PadBytes: 0),
                    new("small", PackageCount: 2, Facilities: 20, EquipmentPerFacility: 8, LogsPerEquipment: 6, PadBytes: 0),
                ]),
            "hard" => new LoadProfile(
                "hard",
                "Stress run: wide Facility→Equipment→Log fan-out; realistic metadata only.",
                [
                    new("tiny", 4, 10, 6, 4, 0),
                    new("small", 6, 40, 8, 6, 0),
                    new("medium", 6, 80, 10, 8, 0),
                    new("large", 4, 120, 10, 10, 0),
                    new("xlarge", 2, 200, 12, 10, 0),
                ]),
            "crush" => new LoadProfile(
                "crush",
                "Aggressive structural crush: max related-entity density, still no megabyte pads.",
                [
                    new("tiny", 10, 25, 8, 6, 0),
                    new("small", 12, 60, 10, 8, 0),
                    new("medium", 10, 100, 12, 10, 0),
                    new("large", 8, 120, 12, 12, 0),
                    new("xlarge", 4, 150, 14, 12, 0),
                    new("mega", 2, 200, 16, 14, 0),
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
        // Reuse the shared production graph builder so load / bench / demo stay aligned.
        var graph = CorridorSyncSeed.BuildScaled(
            facilities: tier.Facilities,
            equipmentPerFacility: tier.EquipmentPerFacility,
            logsPerEquipment: tier.LogsPerEquipment,
            deleteLogPercent: 0,
            runId: packageId);

        // Optional tiny pad budget kept for backward-compatible tier field; default profiles use 0.
        if (tier.PadBytes > 0)
        {
            var pad = CreateLegacyPad(tier.PadBytes, packageId);
            foreach (var facility in graph.Facilities)
            {
                facility.MetadataJson = pad;
            }
        }

        return new LoadPackageRequest
        {
            PackageId = packageId,
            Tier = tier.Name,
            Facilities = graph.Facilities.ToList(),
            Equipment = graph.Equipment.ToList(),
            MaintenanceLogs = graph.Logs.ToList(),
        };
    }

    private static string CreateLegacyPad(int bytes, string salt)
    {
        if (bytes <= 0)
        {
            return "{}";
        }

        var token = "NAS-DSM-ILS-GS-CABINET-PARTS-QUOTE-NOTAM-WX-";
        var sb = new System.Text.StringBuilder(bytes + 64);
        sb.Append("{\"salt\":\"").Append(salt).Append("\",\"blob\":\"");
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
}
