using System.Diagnostics;
using System.Net.Http.Json;
using System.Text.Json;
using Aviation.Shared.Entities;
using Aviation.Shared.Seed;

var server = GetArg(args, "--server") ?? "http://localhost:5080";
var profile = (GetArg(args, "--profile") ?? "crush").ToLowerInvariant();
var concurrency = int.TryParse(GetArg(args, "--concurrency"), out var c) ? Math.Clamp(c, 1, 64) : 8;
var onlyTier = GetArg(args, "--tiers")?.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
var clientId = GetArg(args, "--client-id") ?? "loadgen-dev";
var clientSecret = GetArg(args, "--client-secret") ?? "loadgen-dev-secret";

if (args.Contains("--help") || args.Contains("-h"))
{
    Console.WriteLine(
        """
        SyncEngine.LoadGen — push sized aviation data packages through Aviation.Server

          --server <url>         default http://localhost:5080
          --profile <name>       smoke | hard | crush (default crush)
          --concurrency <n>      parallel package posts (default 8)
          --tiers <a,b,c>        optional subset: tiny,small,medium,large,xlarge,mega
          --client-id <id>       sync client id (default loadgen-dev)
          --client-secret <s>    sync client secret
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

try
{
    using var tokenResponse = await http.PostAsJsonAsync("sync/auth/token", new
    {
        client_id = clientId,
        client_secret = clientSecret,
    });
    tokenResponse.EnsureSuccessStatusCode();
    using var tokenDoc = JsonDocument.Parse(await tokenResponse.Content.ReadAsStringAsync());
    var accessToken = tokenDoc.RootElement.GetProperty("access_token").GetString()
        ?? throw new InvalidOperationException("Token response missing access_token.");
    http.DefaultRequestHeaders.Authorization =
        new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", accessToken);
    Console.WriteLine($"Authenticated as {clientId}");
}
catch (Exception ex)
{
    Console.Error.WriteLine($"Auth failed: {ex.Message}");
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
    Console.WriteLine(
        $"=== TIER {tier.Name.ToUpperInvariant()} — {tier.PackageCount} packages × ~{tier.EntitiesPerPackage} related entities " +
        $"(F={tier.Facilities} E/F={tier.EquipmentPerFacility} L/E={tier.LogsPerEquipment}) ===");

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
    // Keep in lockstep with Aviation.Server LoadPackageGenerator — structural density, no pad inflation.
    "smoke" =>
    [
        new("tiny", PackageCount: 2, Facilities: 5, EquipmentPerFacility: 6, LogsPerEquipment: 4),
        new("small", PackageCount: 2, Facilities: 20, EquipmentPerFacility: 8, LogsPerEquipment: 6),
    ],
    "hard" =>
    [
        new("tiny", 4, 10, 6, 4),
        new("small", 6, 40, 8, 6),
        new("medium", 6, 80, 10, 8),
        new("large", 4, 120, 10, 10),
        new("xlarge", 2, 200, 12, 10),
    ],
    _ => // crush
    [
        new("tiny", 10, 25, 8, 6),
        new("small", 12, 60, 10, 8),
        new("medium", 10, 100, 12, 10),
        new("large", 8, 120, 12, 12),
        new("xlarge", 4, 150, 14, 12),
        new("mega", 2, 200, 16, 14),
    ],
};

static LoadPackageDto BuildPackage(string runId, TierSpec tier, int index)
{
    var packageId = $"{runId}-{tier.Name}-{index:D3}";
    var graph = CorridorSyncSeed.BuildScaled(
        facilities: tier.Facilities,
        equipmentPerFacility: tier.EquipmentPerFacility,
        logsPerEquipment: tier.LogsPerEquipment,
        deleteLogPercent: 0,
        runId: packageId);

    return new LoadPackageDto(
        packageId,
        tier.Name,
        graph.Facilities.ToList(),
        graph.Equipment.ToList(),
        graph.Logs.ToList());
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
    int LogsPerEquipment)
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

