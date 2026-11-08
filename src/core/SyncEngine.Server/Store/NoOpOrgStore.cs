using SyncEngine.Abstractions.Store;

namespace SyncEngine.Server.Store;

public sealed class NoOpOrgStore : IOrgStore
{
    public bool HasActiveTransaction => false;

    public OrgStoreSessionState SessionState => OrgStoreSessionState.Idle;

    public Task EnsureLedgerAsync(CancellationToken cancellationToken = default) => Task.CompletedTask;

    public Task<IOrgTransaction> BeginTransactionAsync(CancellationToken cancellationToken = default)
        => throw new NotSupportedException("NoOpOrgStore does not support transactions.");

    public void RegisterPostCommitAction(Func<CancellationToken, Task> action)
    {
    }

    public Task<int> ExecuteAsync(
        string sql,
        IReadOnlyDictionary<string, object?>? parameters = null,
        CancellationToken cancellationToken = default)
        => Task.FromResult(0);

    public Task<IReadOnlyList<T>> QueryAsync<T>(
        string sql,
        IReadOnlyDictionary<string, object?>? parameters = null,
        CancellationToken cancellationToken = default)
        where T : class, new()
        => Task.FromResult<IReadOnlyList<T>>(Array.Empty<T>());

    public Task<T?> QuerySingleOrDefaultAsync<T>(
        string sql,
        IReadOnlyDictionary<string, object?>? parameters = null,
        CancellationToken cancellationToken = default)
        where T : class, new()
        => Task.FromResult<T?>(null);

    public ValueTask DisposeAsync() => ValueTask.CompletedTask;
}
