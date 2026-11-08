namespace SyncEngine.Abstractions.Auth;

/// <summary>
/// Supplies bearer tokens for outbound sync HTTP and SignalR calls.
/// </summary>
public interface ISyncCredentialProvider
{
    Task<string?> GetAccessTokenAsync(CancellationToken cancellationToken = default);
}
