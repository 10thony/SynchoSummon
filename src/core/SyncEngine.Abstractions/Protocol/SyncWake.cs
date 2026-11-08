using MemoryPack;

namespace SyncEngine.Abstractions.Protocol;

[MemoryPackable]
public partial struct SyncWake
{
    public long LatestVersion { get; set; }

    public string[] EntityNames { get; set; }

    /// <summary>Optional tenant scope for the wake (null = broadcast).</summary>
    public string? TenantId { get; set; }
}
