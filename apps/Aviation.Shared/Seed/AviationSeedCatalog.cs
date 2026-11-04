namespace Aviation.Shared.Seed;

/// <summary>
/// Shared aviation / Upper-Midwest corridor catalogs used by demo seed, load packages, and benchmarks.
/// Keeps production-shaped fixtures consistent across surfaces.
/// </summary>
public static class AviationSeedCatalog
{
    public sealed record City(string Name, string State, string Zip, decimal Lat, decimal Lon);

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

    public static readonly string[] EquipmentTypes =
        ["ILS", "VOR", "DME", "ASR", "ASDE", "AWOS", "GLIDESLOPE", "LOCALIZER", "MALSR", "RVR"];

    public static readonly string[] Manufacturers = ["Raytheon", "Thales", "Leonardo", "Honeywell", "Indra"];

    public static readonly string[] LogTypes = ["NOTE", "INSPECTION", "REPAIR", "ALARM", "PARTS", "CLEARANCE"];

    public static readonly string[] LocationLabels =
        ["GS_CABINET", "LLZ_SHELTER", "RADAR_TOWER", "EQUIP_ROOM", "GATE_G12", "BIN_A3", "RWY_09_THLD", "ATIS_SHELTER"];

    /// <summary>Compact structured metadata — not megabyte pad blobs.</summary>
    public static string BuildFacilityMetadata(string facilityCode, string corridor, int index) =>
        $$"""{"corridor":"{{corridor}}","facilityCode":"{{facilityCode}}","sector":{{index % 12}},"notamWatch":{{(index % 3 == 0).ToString().ToLowerInvariant()}},"wxSource":"ASOS"}""";

    public static string BuildEquipmentMetadata(string eqType, string manufacturer, int index) =>
        $$"""{"stack":"{{eqType}}","oem":"{{manufacturer}}","firmware":"{{20 + (index % 9)}}.{{index % 5}}.0","sparesBin":"{{LocationLabels[index % LocationLabels.Length]}}"}""";

    public static string BuildLogMessage(string city, string eqType, string location, int index) =>
        $"[{city}/{eqType}@{location}] entry #{index}: torque check, alarm clear, parts kit verified, tech sign-off.";
}
