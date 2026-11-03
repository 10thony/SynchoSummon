using MemoryPack;

namespace SyncEngine.Abstractions.Protocol;

[MemoryPackable]
public partial struct DeltaBatch
{
    public long FromVersion { get; set; }

    public long ToVersion { get; set; }

    public bool HasMore { get; set; }

    public DeltaChange[] Changes { get; set; }
}
