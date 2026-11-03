using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using SyncEngine.Abstractions.Client;
using SyncEngine.Abstractions.Codec;
using SyncEngine.Abstractions.Notify;
using SyncEngine.Abstractions.Store;
using SyncEngine.Server.Codec;
using SyncEngine.Server.Ledger;
using SyncEngine.Server.Notify;
using SyncEngine.Server.Offline;
using SyncEngine.Server.Store;
using SyncEngine.Server.Telemetry;

namespace SyncEngine.Server.Hosting;

public static class ServiceCollectionExtensions
{
    public static IServiceCollection AddSyncEngineServer(this IServiceCollection services)
    {
        services.AddSingleton<IDeltaCodec, MemoryPackDeltaCodec>();
        services.AddSingleton<ISyncAuthorization, AllowAllSyncAuthorization>();
        services.TryAddSingleton<IOrgStore, NoOpOrgStore>();
        services.AddSingleton<ISyncTelemetry, SyncTelemetryStore>();
        services.AddSingleton<CoalescingSyncNotifier>();
        services.AddSingleton<ISyncNotifier>(sp => sp.GetRequiredService<CoalescingSyncNotifier>());
        services.AddHostedService(sp => sp.GetRequiredService<CoalescingSyncNotifier>());
        services.AddSingleton<ChangeLedgerWriter>();
        services.AddSingleton<IOfflineEntityApplicator, NoOpOfflineEntityApplicator>();
        services.AddSingleton<OfflinePushHandler>();
        services.AddSignalR();
        return services;
    }
}

public sealed class AllowAllSyncAuthorization : ISyncAuthorization
{
    public bool CanReadChange(string entityName) => true;
}
