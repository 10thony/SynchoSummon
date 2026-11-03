using Aviation.Shared.Entities;
using SyncEngine.Abstractions.Codec;
using SyncEngine.Abstractions.Protocol;
using SyncEngine.Server.Offline;

namespace Aviation.Server.Services;

public sealed class OfflineAviationApplicator(
    InMemoryAviationStore store,
    IDeltaCodec codec) : IOfflineEntityApplicator
{
    public Task ApplyFromClientAsync(DeltaChange change, CancellationToken cancellationToken = default)
    {
        // Server-wins org projection only. OfflinePushHandler records the ledger afterward.
        if (change.Operation == DeltaOperation.Upsert && change.PayloadBytes is { Length: > 0 } payload)
        {
            switch (change.EntityName)
            {
                case AviationEntityNames.Facility:
                    store.PutFacility(codec.Decode<Facility>(payload));
                    break;
                case AviationEntityNames.Equipment:
                    store.PutEquipment(codec.Decode<Equipment>(payload));
                    break;
                case AviationEntityNames.MaintenanceLog:
                    store.PutLog(codec.Decode<MaintenanceLog>(payload));
                    break;
            }
        }

        return Task.CompletedTask;
    }
}
