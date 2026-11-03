namespace SyncEngine.Abstractions.Store;

/// <summary>
/// Org-database abstraction. Oracle is the first provider; others plug in here.
/// </summary>
public interface IOrgStore : IAsyncDisposable
{
    Task EnsureLedgerAsync(CancellationToken cancellationToken = default);

    Task<IOrgTransaction> BeginTransactionAsync(CancellationToken cancellationToken = default);

    bool HasActiveTransaction { get; }

    void RegisterPostCommitAction(Func<CancellationToken, Task> action);

    Task<int> ExecuteAsync(
        string sql,
        IReadOnlyDictionary<string, object?>? parameters = null,
        CancellationToken cancellationToken = default);

    Task<IReadOnlyList<T>> QueryAsync<T>(
        string sql,
        IReadOnlyDictionary<string, object?>? parameters = null,
        CancellationToken cancellationToken = default)
        where T : class, new();

    Task<T?> QuerySingleOrDefaultAsync<T>(
        string sql,
        IReadOnlyDictionary<string, object?>? parameters = null,
        CancellationToken cancellationToken = default)
        where T : class, new();
}

public interface IOrgTransaction : IAsyncDisposable
{
    Task CommitAsync(CancellationToken cancellationToken = default);

    Task RollbackAsync(CancellationToken cancellationToken = default);
}
