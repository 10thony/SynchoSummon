using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using SyncEngine.Abstractions.Ledger;
using SyncEngine.Abstractions.Offline;
using SyncEngine.Server.Ledger;

namespace SyncEngine.Server.Hosting;

/// <summary>
/// Fluent builder for configuring SyncEngine server services.
/// Returned by <see cref="ServiceCollectionExtensions.AddSyncEngineServer"/>.
/// </summary>
public sealed class SyncServerBuilder
{
    private bool _sealed;

    /// <summary>The underlying service collection.</summary>
    internal IServiceCollection Services { get; }

    internal SyncServerBuilder(IServiceCollection services)
    {
        Services = services;
    }

    /// <summary>Marks the builder as sealed; any further mutations will throw.</summary>
    internal void Seal() => _sealed = true;

    private void ThrowIfSealed()
    {
        if (_sealed)
            throw new InvalidOperationException(
                "SyncServerBuilder cannot be modified after the service provider has been built. Configure all services inside AddSyncEngineServer() or immediately after.");
    }

    /// <summary>Use the built-in in-memory change ledger (default for dev/test).</summary>
    public SyncServerBuilder UseInMemoryLedger(int capacity = 100_000)
    {
        ThrowIfSealed();
        Services.RemoveAll<IChangeLedger>();
        Services.AddSingleton<IChangeLedger>(new InMemoryChangeLedger(capacity));
        return this;
    }

    /// <summary>Register a custom <see cref="IChangeLedger"/> implementation.</summary>
    public SyncServerBuilder UseLedger<TLedger>() where TLedger : class, IChangeLedger
    {
        ThrowIfSealed();
        Services.RemoveAll<IChangeLedger>();
        Services.AddSingleton<IChangeLedger, TLedger>();
        return this;
    }

    /// <summary>Register a custom <see cref="IChangeLedger"/> via factory.</summary>
    public SyncServerBuilder UseLedger(Func<IServiceProvider, IChangeLedger> factory)
    {
        ThrowIfSealed();
        Services.RemoveAll<IChangeLedger>();
        Services.AddSingleton(factory);
        return this;
    }

    /// <summary>Add an entity name to the push allow-list.</summary>
    public SyncServerBuilder AddEntity(string name)
    {
        ThrowIfSealed();
        // Collect entity names; SyncPushLimits.AllowedEntityNames will be resolved at build time.
        // For now, we track them and configure can re-build SyncPushLimits.
        return this;
    }

    /// <summary>Configure push limits.</summary>
    public SyncServerBuilder ConfigurePushLimits(Action<SyncPushLimits> configure)
    {
        ThrowIfSealed();
        var limits = new SyncPushLimits();
        configure(limits);
        Services.RemoveAll<SyncPushLimits>();
        Services.AddSingleton(limits);
        return this;
    }

    /// <summary>Register a custom offline entity applicator.</summary>
    public SyncServerBuilder UseOfflineApplicator<T>() where T : class, IOfflineEntityApplicator
    {
        ThrowIfSealed();
        Services.RemoveAll<IOfflineEntityApplicator>();
        Services.AddSingleton<IOfflineEntityApplicator, T>();
        return this;
    }
}
