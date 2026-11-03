using MemoryPack;

namespace SyncEngine.Abstractions.Protocol;

[MemoryPackable]
public partial struct SyncVersion
{
    public long Version { get; set; }
}
