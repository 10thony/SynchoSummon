using MemoryPack;

namespace SyncEngine.Abstractions.Protocol;

[MemoryPackable]
public partial struct SyncWake
{
    public long LatestVersion { get; set; }

    public string[] EntityNames { get; set; }
}
