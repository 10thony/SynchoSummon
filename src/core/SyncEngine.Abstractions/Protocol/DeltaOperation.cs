namespace SyncEngine.Abstractions.Protocol;

public enum DeltaOperation : byte
{
    Upsert = 1,
    Delete = 2,
}
