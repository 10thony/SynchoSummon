using SyncEngine.Abstractions.Protocol;

namespace SyncEngine.Abstractions.Client;

public interface IClientDeltaApplier
{
    Task ApplyAsync(DeltaBatch batch, CancellationToken cancellationToken = default);
}

public interface IEntityDeltaHandler
{
    string EntityName { get; }

    Task ApplyAsync(DeltaChange change, CancellationToken cancellationToken = default);
}

public interface ICheckpointStore
{
    Task<long> GetVersionAsync(string scope = "default", CancellationToken cancellationToken = default);

    Task SetVersionAsync(long version, string scope = "default", CancellationToken cancellationToken = default);
}

public interface ISyncAuthorization
{
    bool CanReadChange(string entityName);
}
