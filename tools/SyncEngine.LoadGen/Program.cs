using System.Diagnostics;
using System.Net.Http.Json;
using System.Text;
using System.Text.Json;
using Aviation.Shared.Entities;

var server = GetArg(args, "--server") ?? "http://localhost:5080";
var profile = (GetArg(args, "--profile") ?? "crush").ToLowerInvariant();
var concurrency = int.TryParse(GetArg(args, "--concurrency"), out var c) ? Math.Clamp(c, 1, 64) : 8;
var onlyTier = GetArg(args, "--tiers")?.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);

if (args.Contains("--help") || args.Contains("-h"))
{
    Console.WriteLine(
        """
        SyncEngine.LoadGen — push sized aviation data packages through Aviation.Server

          --server <url>         default http://localhost:5080
          --profile <name>       smoke | hard | crush (default crush)
          --concurrency <n>      parallel package posts (default 8)
          --tiers <a,b,c>        optional subset: tiny,small,medium,large,xlarge,mega
          --help
        """);
    return 0;
}

using var http = new HttpClient { BaseAddress = new Uri(server.TrimEnd('/') + "/"), Timeout = TimeSpan.FromMinutes(10) };

Console.WriteLine($"Target: {server}");
Console.WriteLine($"Profile: {profile}  concurrency: {concurrency}");

try
{
    var health = await http.GetStringAsync("/");
    Console.WriteLine($"Server: {health}");
}
catch (Exception ex)
{
    Console.Error.WriteLine($"Server not reachable: {ex.Message}");
    return 1;
}

var tiers = BuildTiers(profile);
if (onlyTier is { Length: > 0 })
{
    var set = onlyTier.ToHashSet(StringComparer.OrdinalIgnoreCase);
    tiers = tiers.Where(t => set.Contains(t.Name)).ToList();
}

if (tiers.Count == 0)
{
    Console.Error.WriteLine("No tiers selected.");
    return 1;
}

var runId = DateTimeOffset.UtcNow.ToString("yyyyMMdd-HHmmss");
var overall = Stopwatch.StartNew();
long totalEntities = 0;
long totalApproxBytes = 0;
var results = new List<PackageResult>();

foreach (var tier in tiers)
{
    Console.WriteLine();
    Console.WriteLine($"=== TIER {tier.Name.ToUpperInvariant()} — {tier.PackageCount} packages × ~{tier.EntitiesPerPackage} entities, pad≈{FormatBytes(tier.PadBytes)} ===");

    var packages = Enumerable.Range(0, tier.PackageCount)
        .Select(i => BuildPackage(runId, tier, i))
        .ToArray();

    using var gate = new SemaphoreSlim(concurrency);
    var tasks = packages.Select(async package =>
    {
        await gate.WaitAsync();
        var sw = Stopwatch.StartNew();
        try
        {
            using var response = await http.PostAsJsonAsync("api/load/packages", package);
            var body = await response.Content.ReadAsStringAsync();
            sw.Stop();
            if (!response.IsSuccessStatusCode)
            {
                return new PackageResult(package.PackageId, package.Tier, false, sw.Elapsed, 0, 0, 0, body);
            }

            using var doc = JsonDocument.Parse(body);
            var root = doc.RootElement;
            return new PackageResult(
                package.PackageId,
                package.Tier,
                true,
                sw.Elapsed,
                root.GetProperty("totalEntities").GetInt32(),
                root.GetProperty("approximatePayloadBytes").GetInt64(),
                root.GetProperty("toVersion").GetInt64(),
                $"serverApplyMs={root.GetProperty("serverApplyMs").GetDouble():F1}");
        }
        catch (Exception ex)
        {
            sw.Stop();
            return new PackageResult(package.PackageId, package.Tier, false, sw.Elapsed, 0, 0, 0, ex.Message);
        }
        finally
        {
            gate.Release();
        }
    });

    var tierResults = await Task.WhenAll(tasks);
    results.AddRange(tierResults);

    var ok = tierResults.Count(r => r.Ok);
    var entities = tierResults.Sum(r => r.Entities);
    var bytes = tierResults.Sum(r => r.ApproxBytes);
    var seconds = tierResults.Max(r => r.Elapsed).TotalSeconds;
    totalEntities += entities;
    totalApproxBytes += bytes;

    Console.WriteLine($"  ok={ok}/{tierResults.Length} entities={entities:N0} approxBytes={FormatBytes(bytes)} wall={seconds:F2}s");
    if (ok < tierResults.Length)
    {
        foreach (var fail in tierResults.Where(r => !r.Ok).Take(5))
        {
            Console.WriteLine($"  FAIL {fail.PackageId}: {fail.Detail}");
        }
    }
}

overall.Stop();
Console.WriteLine();
Console.WriteLine("=== SUMMARY ===");
Console.WriteLine($"packages={results.Count} ok={results.Count(r => r.Ok)} entities={totalEntities:N0} approxBytes={FormatBytes(totalApproxBytes)}");
Console.WriteLine($"elapsed={overall.Elapsed.TotalSeconds:F2}s  entities/sec={(totalEntities / Math.Max(overall.Elapsed.TotalSeconds, 0.001)):F0}");

try
{
    var summary = await http.GetStringAsync("api/load/summary");
    Console.WriteLine($"store: {summary}");
    var stats = await http.GetStringAsync("sync/telemetry/stats");
    Console.WriteLine($"telemetry: {stats}");
}
catch
{
    // ignore
}

Console.WriteLine();
Console.WriteLine("Watch live flow: http://localhost:5080/telemetry");
Console.WriteLine("Refresh MAUI / Blazor to see catch-up pull sizes.");
return results.All(r => r.Ok) ? 0 : 2;

static List<TierSpec> BuildTiers(string profile) => profile switch
{
    "smoke" =>
    [
        new("tiny", PackageCount: 2, Facilities: 5, EquipmentPerFacility: 2, LogsPerEquipment: 1, PadBytes: 256),
        new("small", PackageCount: 2, Facilities: 20, EquipmentPerFacility: 3, LogsPerEquipment: 2, PadBytes: 2_048),
    ],
    "hard" =>
    [
        new("tiny", 4, 10, 2, 1, 512),
        new("small", 6, 40, 4, 2, 4_096),
        new("medium", 6, 80, 5, 3, 16_384),
        new("large", 4, 120, 6, 4, 65_536),
        new("xlarge", 2, 200, 8, 5, 262_144),
    ],
    _ => // crush — aggressive but keeps total transfer in the hundreds of MB, not tens of GB
    [
        new("tiny", 10, 25, 3, 2, 2_048),
        new("small", 12, 60, 5, 3, 16_384),
        new("medium", 10, 100, 6, 4, 65_536),
        new("large", 8, 120, 8, 4, 262_144),
        new("xlarge", 4, 150, 8, 4, 524_288),
        new("mega", 2, 80, 6, 3, 1_048_576),
    ],
};

static LoadPackageDto BuildPackage(string runId, TierSpec tier, int index)
{
    var packageId = $"{runId}-{tier.Name}-{index:D3}";
    var facilities = new List<Facility>(tier.Facilities);
    var equipment = new List<Equipment>();
    var logs = new List<MaintenanceLog>();
    var pad = CreatePad(tier.PadBytes, packageId);

    for (var f = 0; f < tier.Facilities; f++)
    {
        var facilityId = $"{packageId}-fac-{f:D4}";
        var city = SeedData.Cities[f % SeedData.Cities.Length];
        var type = SeedData.FacilityTypes[f % SeedData.FacilityTypes.Length];
        facilities.Add(new Facility
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
            // Facilities carry the full pad (largest objects in the graph).
            MetadataJson = pad,
        });

        var equipmentPad = CreatePad(Math.Max(256, tier.PadBytes / 4), packageId + "-eq");
        var logPad = CreatePad(Math.Max(256, tier.PadBytes / 8), packageId + "-log");

        for (var e = 0; e < tier.EquipmentPerFacility; e++)
        {
            var equipmentId = $"{facilityId}-eq-{e:D3}";
            var eqType = SeedData.EquipmentTypes[e % SeedData.EquipmentTypes.Length];
            equipment.Add(new Equipment
            {
                EquipmentId = equipmentId,
                FacilityId = facilityId,
                EquipmentTypeCode = eqType,
                Identifier = $"{eqType}-{f:D3}-{e:D2}",
                Name = $"{eqType} cabinet {e} at {city.Name}",
                OperationalStatus = e % 5 == 0 ? "DEGRADED" : "OPERATIONAL",
                Manufacturer = SeedData.Manufacturers[e % SeedData.Manufacturers.Length],
                Model = $"MK-{(20 + e % 10)}",
                MetadataJson = equipmentPad,
            });

            for (var l = 0; l < tier.LogsPerEquipment; l++)
            {
                logs.Add(new MaintenanceLog
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

    return new LoadPackageDto(packageId, tier.Name, facilities, equipment, logs);
}

static string CreatePad(int bytes, string salt)
{
    if (bytes <= 0)
    {
        return "{}";
    }

    var sb = new StringBuilder(bytes + 64);
    sb.Append("{\"salt\":\"").Append(salt).Append("\",\"blob\":\"");
    // Expand quickly with a repeating aviation-ish token stream.
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

static string BuildLogMessage(string city, string eqType, int index, string pad)
{
    var head = $"[{city}/{eqType}] inspection note #{index}: torque check, alarm clear, parts kit verified. ";
    // Keep message large too (independent of MetadataJson) so MemoryPack payload stays fat.
    var take = Math.Min(pad.Length, 8_192);
    return head + pad.AsSpan(0, take).ToString();
}

static string MakeCode(string tier, int packageIndex, int facilityIndex)
{
    // FacilityCode max feels unconstrained here; keep short-ish unique.
    var raw = $"{tier[0]}{packageIndex:D2}{facilityIndex:D3}";
    return raw.Length <= 16 ? raw.ToUpperInvariant() : raw[..16].ToUpperInvariant();
}

static string FormatBytes(long bytes)
{
    if (bytes < 1024) return $"{bytes} B";
    if (bytes < 1024 * 1024) return $"{bytes / 1024.0:F1} KB";
    return $"{bytes / (1024.0 * 1024.0):F2} MB";
}

static string? GetArg(string[] args, string name)
{
    for (var i = 0; i < args.Length - 1; i++)
    {
        if (string.Equals(args[i], name, StringComparison.OrdinalIgnoreCase))
        {
            return args[i + 1];
        }
    }

    return null;
}

readonly record struct TierSpec(
    string Name,
    int PackageCount,
    int Facilities,
    int EquipmentPerFacility,
    int LogsPerEquipment,
    int PadBytes)
{
    public int EntitiesPerPackage =>
        Facilities + Facilities * EquipmentPerFacility + Facilities * EquipmentPerFacility * LogsPerEquipment;
}

sealed record LoadPackageDto(
    string PackageId,
    string Tier,
    List<Facility> Facilities,
    List<Equipment> Equipment,
    List<MaintenanceLog> MaintenanceLogs);

readonly record struct PackageResult(
    string PackageId,
    string Tier,
    bool Ok,
    TimeSpan Elapsed,
    int Entities,
    long ApproxBytes,
    long ToVersion,
    string Detail);

sealed record City(string Name, string State, string Zip, decimal Lat, decimal Lon);

static class SeedData
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
