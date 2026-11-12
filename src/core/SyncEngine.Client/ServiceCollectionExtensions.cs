using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Microsoft.Extensions.Logging;
using SyncEngine.Abstractions.Auth;
using SyncEngine.Abstractions.Client;
using SyncEngine.Abstractions.Codec;
using SyncEngine.Client.Auth;
using SyncEngine.Client.Offline;
using SyncEngine.Client.Telemetry;
using SyncEngine.Client.Transport;

namespace SyncEngine.Client;

/// <summary>
/// Extension methods for registering SyncEngine client services.
/// </summary>
public static class ServiceCollectionExtensions
{
    /// <summary>
    /// Registers core SyncEngine client services and returns a <see cref="SyncClientBuilder"/>
    /// for fluent configuration of entities, sessions, credentials, and outbox flushing.
    /// </summary>
    /// <param name="services">The service collection.</param>
    /// <param name="configure">Optional client options configurator.</param>
    /// <returns>A <see cref="SyncClientBuilder"/> for further configuration.</returns>
    public static SyncClientBuilder AddSyncEngineClient(
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
        services.AddSingleton<ISyncBatchNotifier>(sp => sp.GetRequiredService<SyncPullService>());
        services.AddSingleton<ISyncApplyNotifications>(sp => sp.GetRequiredService<SyncPullService>());
        services.AddOptions<SyncClientSessionOptions>();
        services.TryAddSingleton<SyncClientSession>();
        services.TryAddSingleton<ISyncSession>(sp => sp.GetRequiredService<SyncClientSession>());
        services.AddSingleton<IClientDeltaApplier>(sp =>
        {
            var handlers = sp.GetServices<IEntityDeltaHandler>();
            var opts = sp.GetRequiredService<Microsoft.Extensions.Options.IOptions<SyncClientOptions>>().Value;
            var logger = sp.GetRequiredService<ILoggerFactory>().CreateLogger<CompositeDeltaApplier>();
            return new CompositeDeltaApplier(handlers, opts.UnknownEntityBehavior, logger);
        });

        var clientBuilder = new SyncClientBuilder(services);
        services.AddSingleton(clientBuilder);
        services.AddHostedService<SyncClientBuilderSealHostedService>();
        return clientBuilder;
    }

    /// <summary>
    /// Registers core SyncEngine client services and invokes the builder action for fluent configuration.
    /// </summary>
    /// <param name="services">The service collection.</param>
    /// <param name="configure">Builder configuration action.</param>
    /// <returns>A <see cref="SyncClientBuilder"/> for further configuration.</returns>
    public static SyncClientBuilder AddSyncEngineClient(
        this IServiceCollection services,
        Action<SyncClientBuilder> configure)
    {
        var builder = services.AddSyncEngineClient();
        configure(builder);
        return builder;
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

    /// <summary>
    /// Configures client credentials for authenticated sync.
    /// Call after <see cref="AddSyncEngineClient"/>.
    /// </summary>
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
