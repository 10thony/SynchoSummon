using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using SyncEngine.Abstractions.Auth;
using SyncEngine.Abstractions.Client;
using SyncEngine.Abstractions.Codec;
using SyncEngine.Client.Auth;
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

        services.TryAddSingleton<ISyncCredentialProvider, NullSyncCredentialProvider>();
        services.AddTransient<SyncAuthDelegatingHandler>();
        services.AddHttpClient<ISyncTransport, HttpSyncTransport>()
            .AddHttpMessageHandler<SyncAuthDelegatingHandler>();
        services.AddHttpClient(nameof(ClientTelemetryReporter))
            .AddHttpMessageHandler<SyncAuthDelegatingHandler>();
        services.AddHttpClient(nameof(ClientCredentialsTokenProvider));
        services.AddSingleton<ClientTelemetryReporter>();
        services.AddSingleton<IDeltaCodec, MemoryPackDeltaCodec>();
        services.AddSingleton<ICheckpointStore, InMemoryCheckpointStore>();
        services.AddSingleton<InMemoryEntityStore>();
        services.AddSingleton<ClientOutbox>();
        services.AddSingleton<ISyncWakeListener, SignalRSyncWakeListener>();
        services.AddSingleton<SyncPullService>();
        services.AddOptions<SyncClientSessionOptions>();
        services.TryAddSingleton<SyncClientSession>();
        services.TryAddSingleton<ISyncSession>(sp => sp.GetRequiredService<SyncClientSession>());
        services.AddSingleton<IClientDeltaApplier>(sp =>
        {
            var handlers = sp.GetServices<IEntityDeltaHandler>();
            return new CompositeDeltaApplier(handlers);
        });

        return services;
    }

    /// <summary>
    /// Configures the shared <see cref="SyncClientSession"/> (periodic pull, etc.).
    /// Call after <see cref="AddSyncEngineClient"/>.
    /// Set <paramref name="runAsHostedService"/> when the generic
    /// <see cref="SyncSessionHostedService"/> should own Start/Stop (recommended for samples
    /// and headless clients). UI hosts with custom status mapping can leave it false.
    /// </summary>
    public static IServiceCollection AddSyncEngineClientSession(
        this IServiceCollection services,
        Action<SyncClientSessionOptions>? configure = null,
        bool runAsHostedService = false)
    {
        if (configure is not null)
        {
            services.Configure(configure);
        }

        services.TryAddSingleton<SyncClientSession>();
        services.TryAddSingleton<ISyncSession>(sp => sp.GetRequiredService<SyncClientSession>());
        if (runAsHostedService)
        {
            services.AddHostedService<SyncSessionHostedService>();
        }

        return services;
    }

    public static IServiceCollection AddSyncEngineClientCredentials(
        this IServiceCollection services,
        Action<SyncClientCredentialOptions> configure)
    {
        services.Configure(configure);
        services.RemoveAll<ISyncCredentialProvider>();
        services.AddSingleton<ISyncCredentialProvider, ClientCredentialsTokenProvider>();
        return services;
    }
}
