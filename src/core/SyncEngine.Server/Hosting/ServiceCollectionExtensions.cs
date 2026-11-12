using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using SyncEngine.Abstractions.Auth;
using SyncEngine.Abstractions.Codec;
using SyncEngine.Abstractions.Ledger;
using SyncEngine.Abstractions.Notify;
using SyncEngine.Abstractions.Offline;
using SyncEngine.Abstractions.Store;
using SyncEngine.Abstractions.Telemetry;
using SyncEngine.Server.Ledger;
using SyncEngine.Server.Notify;
using SyncEngine.Server.Offline;
using SyncEngine.Server.Store;
using SyncEngine.Server.Telemetry;

namespace SyncEngine.Server.Hosting;

public static class ServiceCollectionExtensions
{
    public static SyncServerBuilder AddSyncEngineServer(this IServiceCollection services)
    {
        services.AddSingleton<IDeltaCodec, MemoryPackDeltaCodec>();
        services.TryAddSingleton<ISyncAuthenticator, AnonymousSyncAuthenticator>();
        services.TryAddSingleton<ISyncAuthorization, UnsafeAllowAllSyncAuthorization>();
        services.TryAddSingleton<IOrgStore, NoOpOrgStore>();
        services.AddSingleton<ISyncTelemetry, SyncTelemetryStore>();
        services.AddSingleton<CoalescingSyncNotifier>();
        services.AddSingleton<ISyncNotifier>(sp => sp.GetRequiredService<CoalescingSyncNotifier>());
        services.AddHostedService(sp => sp.GetRequiredService<CoalescingSyncNotifier>());
        // Default ledger — TryAdd so builder.UseLedger<T>() overrides
        services.TryAddSingleton<IChangeLedger, InMemoryChangeLedger>();
        // ChangeLedgerWriter + interface
        services.AddSingleton<ChangeLedgerWriter>();
        services.AddSingleton<IChangeLedgerWriter>(sp => sp.GetRequiredService<ChangeLedgerWriter>());
        services.AddSingleton<IOfflineEntityApplicator, NoOpOfflineEntityApplicator>();
        services.TryAddSingleton(SyncPushLimits.Default);
        services.AddSingleton<OfflinePushHandler>();
        // Phone-scale SyncDelta pages can exceed SignalR's 32KB default.
        services.AddSignalR(options =>
        {
            options.MaximumReceiveMessageSize = 64 * 1024 * 1024;
            options.EnableDetailedErrors = false;
        });
        services.AddHostedService<SyncEngineValidationHostedService>();
        var serverBuilder = new SyncServerBuilder(services);
        services.AddSingleton(serverBuilder);
        return serverBuilder;
    }

    /// <summary>
    /// Configures SyncEngine server services with a builder callback.
    /// </summary>
    public static SyncServerBuilder AddSyncEngineServer(this IServiceCollection services, Action<SyncServerBuilder> configure)
    {
        var builder = services.AddSyncEngineServer();
        configure(builder);
        return builder;
    }

    /// <summary>
    /// Convenience: register the in-memory change ledger with an explicit capacity.
    /// </summary>
    public static IServiceCollection AddSyncEngineInMemoryLedger(this IServiceCollection services, int capacity = 100_000)
    {
        services.RemoveAll<IChangeLedger>();
        services.AddSingleton<IChangeLedger>(new InMemoryChangeLedger(capacity));
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
