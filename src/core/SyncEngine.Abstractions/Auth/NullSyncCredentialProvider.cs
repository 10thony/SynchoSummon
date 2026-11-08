namespace SyncEngine.Abstractions.Auth;

public sealed class NullSyncCredentialProvider : ISyncCredentialProvider
{
    public static NullSyncCredentialProvider Instance { get; } = new();

    public Task<string?> GetAccessTokenAsync(CancellationToken cancellationToken = default)
        => Task.FromResult<string?>(null);
}
