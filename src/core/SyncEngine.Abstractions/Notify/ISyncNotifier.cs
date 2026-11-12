namespace SyncEngine.Abstractions.Notify;

public interface ISyncNotifier
{
    ValueTask EnqueueWakeAsync(
        long version,
        string entityName,
        string? tenantId = null,
        CancellationToken cancellationToken = default);
}
