using Microsoft.Extensions.DependencyInjection;
using SyncEngine.Abstractions.Client;
using SyncEngine.Abstractions.Codec;
using SyncEngine.Client.Codec;
using SyncEngine.Client.Offline;
using SyncEngine.Client.Telemetry;
using SyncEngine.Client.Transport;

namespace SyncEngine.Client;

public static class ServiceCollectionExtensions
{
    public static IServiceCollection AddSyncEngineClient(
        this IServiceCollection services,
        Action<SyncClientOptions>? configure = null)
    {
        if (configure is not null)
        {
            services.Configure(configure);
        }
        else
        {
            services.AddOptions<SyncClientOptions>();
        }

        services.AddHttpClient<ISyncTransport, HttpSyncTransport>();
        services.AddHttpClient(nameof(ClientTelemetryReporter));
        services.AddSingleton<ClientTelemetryReporter>();
        services.AddSingleton<IDeltaCodec, MemoryPackDeltaCodec>();
        services.AddSingleton<ICheckpointStore, InMemoryCheckpointStore>();
        services.AddSingleton<InMemoryEntityStore>();
        services.AddSingleton<ClientOutbox>();
        services.AddSingleton<ISyncWakeListener, SignalRSyncWakeListener>();
        services.AddSingleton<SyncPullService>();
        services.AddSingleton<IClientDeltaApplier>(sp =>
        {
            var handlers = sp.GetServices<IEntityDeltaHandler>();
            return new CompositeDeltaApplier(handlers);
        });

        return services;
    }
}
