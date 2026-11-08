using MemoryPack;

namespace SyncEngine.Abstractions.Protocol;

[MemoryPackable]
public partial struct DeltaChange
{
    public long Version { get; set; }

    public string EntityName { get; set; }

    public DeltaOperation Operation { get; set; }

    /// <summary>MemoryPack-encoded entity key bytes.</summary>
    public byte[] KeyBytes { get; set; }

    /// <summary>MemoryPack-encoded payload; null for deletes.</summary>
    public byte[]? PayloadBytes { get; set; }

    /// <summary>Optional tenant scope assigned by the server (additive wire field).</summary>
    public string? TenantId { get; set; }
}
