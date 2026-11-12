using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using SyncEngine.Abstractions.Codec;
using SyncEngine.Abstractions.Ledger;
using SyncEngine.Abstractions.Notify;

namespace SyncEngine.Server.Hosting;

/// <summary>
/// Fail-fast validation: ensures critical SyncEngine services are registered at startup.
/// </summary>
public sealed class SyncEngineValidationHostedService(
    IServiceProvider services,
    ILogger<SyncEngineValidationHostedService> logger) : IHostedService
{
    public Task StartAsync(CancellationToken cancellationToken)
    {
        // Seal the server builder so post-build modifications throw with a clear message
        services.GetService<SyncServerBuilder>()?.Seal();

        var errors = new List<string>();

        Require<IChangeLedger>(errors);
        Require<IDeltaCodec>(errors);
        Require<ISyncNotifier>(errors);

        // Warn if no entity handlers are registered (common agent mistake)
        var offlineApplicator = services.GetService<SyncEngine.Abstractions.Offline.IOfflineEntityApplicator>();
        if (offlineApplicator is SyncEngine.Server.Offline.NoOpOfflineEntityApplicator)
        {
            logger.LogWarning(
                "SyncEngine: IOfflineEntityApplicator is NoOp. Client push operations will be accepted " +
                "but not persisted to any store. Register a real applicator or call AddGeneratedSyncServer().");
        }

        if (errors.Count > 0)
        {
            var message = "SyncEngine startup validation failed. Missing services:\n" +
                          string.Join("\n", errors.Select(e => $"  • {e}"));
            logger.LogCritical(message);
            throw new InvalidOperationException(message);
        }

        logger.LogInformation("SyncEngine startup validation passed.");
        return Task.CompletedTask;
    }

    public Task StopAsync(CancellationToken cancellationToken) => Task.CompletedTask;

    private void Require<T>(List<string> errors)
    {
        if (services.GetService<T>() is null)
        {
            errors.Add($"{typeof(T).FullName} is not registered. Did you call AddSyncEngineServer()?");
        }
    }

}
