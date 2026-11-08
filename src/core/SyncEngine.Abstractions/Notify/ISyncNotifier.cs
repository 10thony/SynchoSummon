namespace SyncEngine.Abstractions.Notify;

public interface ISyncNotifier
{
    ValueTask EnqueueWakeAsync(
        long version,
        string entityName,
        CancellationToken cancellationToken = default,
        string? tenantId = null);
}
