using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using SyncEngine.Abstractions.Auth;
using SyncEngine.Abstractions.Client;
using SyncEngine.Abstractions.Codec;
using SyncEngine.Abstractions.Entity;
using SyncEngine.Client.Auth;
using SyncEngine.Client.Offline;

namespace SyncEngine.Client;

/// <summary>
/// Fluent builder for configuring SyncEngine client services.
/// Returned by <see cref="ServiceCollectionExtensions.AddSyncEngineClient"/>.
/// </summary>
public sealed class SyncClientBuilder
{
    private bool _sealed;

    /// <summary>The underlying service collection.</summary>
    internal IServiceCollection Services { get; }

    internal SyncClientBuilder(IServiceCollection services)
    {
        Services = services;
    }

    /// <summary>Marks the builder as sealed; any further mutations will throw.</summary>
    internal void Seal() => _sealed = true;

    private void ThrowIfSealed()
    {
        if (_sealed)
            throw new InvalidOperationException(
                "SyncClientBuilder cannot be modified after the service provider has been built. Configure all services inside AddSyncEngineClient() or immediately after.");
    }

    /// <summary>Configure client options.</summary>
    public SyncClientBuilder Configure(Action<SyncClientOptions> configure)
    {
        ThrowIfSealed();
        Services.Configure(configure);
        return this;
    }

    /// <summary>
    /// Register a typed sync entity. <typeparamref name="T"/> must implement <see cref="ISyncEntity"/>.
    /// Registers <see cref="IEntityDeltaHandler"/> for the entity name and <see cref="ISyncEntityStore{T}"/>.
    /// </summary>
    /// <typeparam name="T">The sync entity type to register.</typeparam>
    public SyncClientBuilder AddSyncEntity<T>() where T : class, ISyncEntity
    {
        ThrowIfSealed();
        var entityName = T.EntityName;
        Services.AddSingleton<IEntityDeltaHandler>(sp =>
            new InMemoryEntityDeltaHandler(entityName, sp.GetRequiredService<InMemoryEntityStore>()));
        Services.AddSingleton<ISyncEntityStore<T>>(sp =>
            new TypedSyncEntityStore<T>(entityName, sp.GetRequiredService<InMemoryEntityStore>(), sp.GetRequiredService<IDeltaCodec>()));
        return this;
    }

    /// <summary>
    /// Register a sync entity by name (non-typed, for backward compat or dynamic scenarios).
    /// </summary>
    /// <param name="entityName">The canonical entity name.</param>
    public SyncClientBuilder AddEntity(string entityName)
    {
        ThrowIfSealed();
        var name = entityName;
        Services.AddSingleton<IEntityDeltaHandler>(sp =>
            new InMemoryEntityDeltaHandler(name, sp.GetRequiredService<InMemoryEntityStore>()));
        return this;
    }

    /// <summary>Configure the sync session.</summary>
    /// <param name="configure">Optional session options configurator.</param>
    /// <param name="runAsHostedService">
    /// When true, registers <see cref="SyncSessionHostedService"/> so the generic host owns Start/Stop.
    /// </param>
    public SyncClientBuilder WithSession(Action<SyncClientSessionOptions>? configure = null, bool runAsHostedService = false)
    {
        ThrowIfSealed();
        if (configure is not null)
        {
            Services.Configure(configure);
        }

        Services.TryAddSingleton<SyncClientSession>();
        Services.TryAddSingleton<ISyncSession>(sp => sp.GetRequiredService<SyncClientSession>());
        if (runAsHostedService)
        {
            Services.AddHostedService<SyncSessionHostedService>();
        }

        return this;
    }

    /// <summary>Configure client credentials for auth.</summary>
    /// <param name="configure">Credential options configurator.</param>
    public SyncClientBuilder WithCredentials(Action<SyncClientCredentialOptions> configure)
    {
        ThrowIfSealed();
        Services.Configure(configure);
        Services.RemoveAll<ISyncCredentialProvider>();
        Services.AddSingleton<ISyncCredentialProvider, ClientCredentialsTokenProvider>();
        return this;
    }

    /// <summary>
    /// Configure behavior when a delta arrives for an entity with no registered handler.
    /// Default is <see cref="UnknownEntityBehavior.SkipAndWarn"/>.
    /// </summary>
    /// <param name="behavior">The desired behavior for unknown entities.</param>
    public SyncClientBuilder WithUnknownEntityBehavior(UnknownEntityBehavior behavior)
    {
        ThrowIfSealed();
        Services.Configure<SyncClientOptions>(o => o.UnknownEntityBehavior = behavior);
        return this;
    }

    /// <summary>
    /// Shorthand: throw on unknown entities instead of skip+warn.
    /// Equivalent to <c>WithUnknownEntityBehavior(UnknownEntityBehavior.Throw)</c>.
    /// </summary>
    public SyncClientBuilder ThrowOnUnknownEntity()
        => WithUnknownEntityBehavior(UnknownEntityBehavior.Throw);

    /// <summary>Enable automatic outbox flushing.</summary>
    /// <param name="configure">Optional flush options configurator.</param>
    public SyncClientBuilder WithAutoFlush(Action<OutboxFlushOptions>? configure = null)
    {
        ThrowIfSealed();
        if (configure is not null)
        {
            Services.Configure(configure);
        }
        else
        {
            Services.AddOptions<OutboxFlushOptions>();
        }

        Services.TryAddSingleton<IOutboxFlushService, OutboxFlushService>();
        Services.AddHostedService<OutboxFlushService>(sp => (OutboxFlushService)sp.GetRequiredService<IOutboxFlushService>());
        return this;
    }
}
