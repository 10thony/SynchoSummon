namespace SyncEngine.Abstractions.Store;

/// <summary>Explicit org-store connection/transaction lifecycle.</summary>
public enum OrgStoreSessionState
{
    Idle = 0,
    Open = 1,
    TransactionOpen = 2,
    Disposed = 3,
}

/// <summary>
/// Org-database abstraction. Oracle is the first provider; others plug in here.
/// </summary>
public interface IOrgStore : IAsyncDisposable
{
    Task EnsureLedgerAsync(CancellationToken cancellationToken = default);

    Task<IOrgTransaction> BeginTransactionAsync(CancellationToken cancellationToken = default);

    /// <summary>True when <see cref="SessionState"/> is <see cref="OrgStoreSessionState.TransactionOpen"/>.</summary>
    bool HasActiveTransaction { get; }

    /// <summary>Named session state for wake deferral and agent-safe edits.</summary>
    OrgStoreSessionState SessionState { get; }

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
