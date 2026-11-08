using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using SyncEngine.Abstractions.Auth;
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
        services.TryAddSingleton<ISyncAuthenticator, AnonymousSyncAuthenticator>();
        services.TryAddSingleton<ISyncAuthorization, UnsafeAllowAllSyncAuthorization>();
        services.TryAddSingleton<IOrgStore, NoOpOrgStore>();
        services.AddSingleton<ISyncTelemetry, SyncTelemetryStore>();
        services.AddSingleton<CoalescingSyncNotifier>();
        services.AddSingleton<ISyncNotifier>(sp => sp.GetRequiredService<CoalescingSyncNotifier>());
        services.AddHostedService(sp => sp.GetRequiredService<CoalescingSyncNotifier>());
        services.AddSingleton<ChangeLedgerWriter>();
        services.AddSingleton<IOfflineEntityApplicator, NoOpOfflineEntityApplicator>();
        services.TryAddSingleton(SyncPushLimits.Default);
        services.AddSingleton<OfflinePushHandler>();
        // Phone-scale SyncDelta pages can exceed SignalR's 32KB default.
        services.AddSignalR(options =>
        {
            options.MaximumReceiveMessageSize = 64 * 1024 * 1024;
            options.EnableDetailedErrors = false;
        });
        return services;
    }

    /// <summary>
    /// Explicit lab opt-in: anonymous HTTP access and allow-all entity authZ.
    /// Do not use for production-shaped hosts.
    /// </summary>
    public static IServiceCollection AddSyncEngineAnonymousAccess(this IServiceCollection services)
    {
        services.RemoveAll<SyncAuthFeature>();
        services.AddSingleton<ISyncAuthenticator, AnonymousSyncAuthenticator>();
        services.AddSingleton<ISyncAuthorization, UnsafeAllowAllSyncAuthorization>();
        return services;
    }
}
