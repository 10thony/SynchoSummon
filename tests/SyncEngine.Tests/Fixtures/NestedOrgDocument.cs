using System.Security.Cryptography;
using System.Text.Json;
using MemoryPack;

namespace SyncEngine.Tests.Fixtures;

/// <summary>
/// Proprietary-shaped nested org payload — the kind of graph a field phone would sync
/// (site → systems → components → calibrations → binary annex).
/// </summary>
[MemoryPackable]
public partial class NestedOrgDocument
{
    public string DocumentId { get; set; } = "";
    public string SchemaVersion { get; set; } = "org.sync.v1";
    public string TenantScope { get; set; } = "demo";
    public NestedSite Site { get; set; } = new();
    public List<NestedSystem> Systems { get; set; } = [];
    public Dictionary<string, string> Attributes { get; set; } = new(StringComparer.Ordinal);
    public byte[] BinaryAnnex { get; set; } = [];
}

[MemoryPackable]
public partial class NestedSite
{
    public string SiteCode { get; set; } = "";
    public string DisplayName { get; set; } = "";
    public NestedGeoPoint Location { get; set; } = new();
    public List<string> Tags { get; set; } = [];
}

[MemoryPackable]
public partial class NestedGeoPoint
{
    public double Lat { get; set; }
    public double Lon { get; set; }
    public double? ElevMeters { get; set; }
}

[MemoryPackable]
public partial class NestedSystem
{
    public string SystemId { get; set; } = "";
    public string Kind { get; set; } = "";
    public List<NestedComponent> Components { get; set; } = [];
}

[MemoryPackable]
public partial class NestedComponent
{
    public string ComponentId { get; set; } = "";
    public string PartNumber { get; set; } = "";
    public List<NestedCalibration> Calibrations { get; set; } = [];
}

[MemoryPackable]
public partial class NestedCalibration
{
    public string CalibrationId { get; set; } = "";
    public DateTimeOffset PerformedAt { get; set; }
    public double[] Samples { get; set; } = [];
    public string Technician { get; set; } = "";
}

public static class NestedOrgFactory
{
    public static NestedOrgDocument Create(string documentId, int annexBytes, int systems = 4, int componentsPerSystem = 5)
    {
        var doc = new NestedOrgDocument
        {
            DocumentId = documentId,
            TenantScope = "demo",
            Site = new NestedSite
            {
                SiteCode = documentId.Length >= 6 ? documentId[^6..] : documentId,
                DisplayName = $"Org nest {documentId}",
                Location = new NestedGeoPoint { Lat = 41.53 + (documentId.GetHashCode() % 100) * 0.001, Lon = -93.65, ElevMeters = 294 },
                Tags = ["NAS", "FIELD", "PHONE-SYNC"],
            },
            Attributes =
            {
                ["classification"] = "ops",
                ["channel"] = "maui",
                ["nesting"] = "site/system/component/calibration",
            },
            BinaryAnnex = annexBytes <= 0 ? [] : RandomNumberGenerator.GetBytes(annexBytes),
        };

        for (var s = 0; s < systems; s++)
        {
            var system = new NestedSystem
            {
                SystemId = $"{documentId}-sys-{s:D2}",
                Kind = s % 2 == 0 ? "ILS" : "RADAR",
            };
            for (var c = 0; c < componentsPerSystem; c++)
            {
                var component = new NestedComponent
                {
                    ComponentId = $"{system.SystemId}-cmp-{c:D2}",
                    PartNumber = $"PN-{1000 + s * 10 + c}",
                    Calibrations =
                    [
                        new NestedCalibration
                        {
                            CalibrationId = $"{system.SystemId}-cal-{c:D2}",
                            PerformedAt = DateTimeOffset.UtcNow.AddDays(-c),
                            Technician = $"T{(s + c) % 40:D2}",
                            Samples = Enumerable.Range(0, 16).Select(i => Math.Sin(i + s + c)).ToArray(),
                        },
                    ],
                };
                system.Components.Add(component);
            }

            doc.Systems.Add(system);
        }

        return doc;
    }

    public static string ToMetadataEnvelope(NestedOrgDocument doc)
    {
        var bytes = MemoryPackSerializer.Serialize(doc);
        return JsonSerializer.Serialize(new
        {
            kind = "NestedOrgDocument",
            schema = doc.SchemaVersion,
            sha256 = Convert.ToHexString(SHA256.HashData(bytes)),
            payloadBase64 = Convert.ToBase64String(bytes),
        });
    }

    public static NestedOrgDocument FromMetadataEnvelope(string metadataJson)
    {
        using var doc = JsonDocument.Parse(metadataJson);
        var b64 = doc.RootElement.GetProperty("payloadBase64").GetString()
                  ?? throw new InvalidOperationException("Missing payloadBase64.");
        var bytes = Convert.FromBase64String(b64);
        return MemoryPackSerializer.Deserialize<NestedOrgDocument>(bytes)
               ?? throw new InvalidOperationException("NestedOrgDocument deserialize failed.");
    }

    public static string Sha256Hex(ReadOnlySpan<byte> payload)
        => Convert.ToHexString(SHA256.HashData(payload));
}
