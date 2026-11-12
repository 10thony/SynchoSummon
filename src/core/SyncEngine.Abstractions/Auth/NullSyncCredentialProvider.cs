namespace SyncEngine.Abstractions.Auth;

[System.ComponentModel.EditorBrowsable(System.ComponentModel.EditorBrowsableState.Never)]
public sealed class NullSyncCredentialProvider : ISyncCredentialProvider
{
    public static NullSyncCredentialProvider Instance { get; } = new();

    public Task<string?> GetAccessTokenAsync(CancellationToken cancellationToken = default)
        => Task.FromResult<string?>(null);
}
