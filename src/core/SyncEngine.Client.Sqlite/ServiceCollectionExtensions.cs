using Microsoft.Extensions.DependencyInjection;
using SyncEngine.Abstractions.Client;

namespace SyncEngine.Client.Sqlite;

public static class ServiceCollectionExtensions
{
    public static IServiceCollection AddSyncEngineSqlite(
        this IServiceCollection services,
        Action<SqliteSyncOptions>? configure = null,
        params string[] entityNames)
    {
        if (configure is not null)
        {
            services.Configure(configure);
        }
        else
        {
            services.AddOptions<SqliteSyncOptions>();
        }

        services.AddSingleton<SqliteConnectionFactory>();
        services.AddSingleton<ICheckpointStore, SqliteCheckpointStore>();
        services.AddSingleton<SqliteOutboxStore>();
        services.AddSingleton<IClientDeltaApplier, SqliteBatchApplier>();

        foreach (var entityName in entityNames.Distinct(StringComparer.OrdinalIgnoreCase))
        {
            var name = entityName;
            services.AddSingleton<IEntityDeltaHandler>(sp =>
                new SqliteEntityDeltaHandler(name, sp.GetRequiredService<SqliteConnectionFactory>()));
        }

        return services;
    }
}
