using Microsoft.Extensions.DependencyInjection;
using SyncEngine.Abstractions.Ledger;
using SyncEngine.Abstractions.Schema;
using SyncEngine.Abstractions.Store;

namespace SyncEngine.Providers.Oracle;

public static class ServiceCollectionExtensions
{
    public static IServiceCollection AddSyncEngineOracle(
        this IServiceCollection services,
        Action<OracleOptions>? configure = null)
    {
        if (configure is not null)
        {
            services.Configure(configure);
        }
        else
        {
            services.AddOptions<OracleOptions>();
        }

        services.AddSingleton<IOrgStore, OracleOrgStore>();
        services.AddSingleton<IChangeLedger, OracleChangeLedger>();
        services.AddSingleton<ISchemaReader, OracleSchemaReader>();
        return services;
    }
}
