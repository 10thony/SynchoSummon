using System.Security.Claims;

namespace SyncEngine.Abstractions.Auth;

/// <summary>Lab/demo authenticator that always returns an anonymous principal.</summary>
public sealed class AnonymousSyncAuthenticator : ISyncAuthenticator
{
    public SyncPrincipal GetPrincipal(ClaimsPrincipal? user) => SyncPrincipal.Anonymous;
}
