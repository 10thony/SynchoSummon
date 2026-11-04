using Aviation.Shared.Entities;

namespace Aviation.Shared.Seed;

/// <summary>
/// Production-shaped related-entity graph for sync fixtures (Facility → Equipment → MaintenanceLog).
/// Deletes are intended to follow upserts in ledger/batch order (churn / catch-up realism).
/// </summary>
public sealed record SyncSeedGraph(
    IReadOnlyList<Facility> Facilities,
    IReadOnlyList<Equipment> Equipment,
    IReadOnlyList<MaintenanceLog> Logs,
    IReadOnlyList<SyncSeedDelete> Deletes)
{
    public int UpsertCount => Facilities.Count + Equipment.Count + Logs.Count;

    public int ChangeCount => UpsertCount + Deletes.Count;
}

public sealed record SyncSeedDelete(string EntityName, string EntityKey);
