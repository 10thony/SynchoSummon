using System.Diagnostics;
using Aviation.Shared.Entities;
using SyncEngine.Abstractions.Codec;
using SyncEngine.Abstractions.Ledger;
using SyncEngine.Server.Ledger;

namespace Aviation.Server.Services;

public sealed class LoadPackageService(
    InMemoryAviationStore store,
    IChangeLedger ledger,
    IDeltaCodec codec)
{
    public async Task<LoadPackageResult> ApplyAsync(
        LoadPackageRequest package,
        CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(package);
        var sw = Stopwatch.StartNew();
        var fromVersion = await ledger.GetCurrentVersionAsync(cancellationToken);
        long approxBytes = 0;

        foreach (var facility in package.Facilities)
        {
            approxBytes += Estimate(facility.MetadataJson) + (facility.Name?.Length ?? 0);
            await store.UpsertFacilityAsync(facility, cancellationToken);
        }

        foreach (var equipment in package.Equipment)
        {
            approxBytes += Estimate(equipment.MetadataJson) + (equipment.Name?.Length ?? 0);
            await store.UpsertEquipmentAsync(equipment, cancellationToken);
        }

        foreach (var log in package.MaintenanceLogs)
        {
            approxBytes += Estimate(log.MetadataJson) + (log.Message?.Length ?? 0);
            await store.UpsertLogAsync(log, cancellationToken);
        }

        sw.Stop();
        var toVersion = await ledger.GetCurrentVersionAsync(cancellationToken);

        // Touch codec so MemoryPack path stays warm for large pads.
        _ = codec;

        return new LoadPackageResult
        {
            PackageId = package.PackageId,
            Tier = package.Tier,
            FacilityCount = package.Facilities.Count,
            EquipmentCount = package.Equipment.Count,
            MaintenanceLogCount = package.MaintenanceLogs.Count,
            ApproximatePayloadBytes = approxBytes,
            ServerApplyMs = sw.Elapsed.TotalMilliseconds,
            FromVersion = fromVersion,
            ToVersion = toVersion,
        };
    }

    private static long Estimate(string? value) => value?.Length ?? 0;
}
