using System.Security.Claims;

namespace SyncEngine.Abstractions.Auth;

/// <summary>
/// Resolves the current sync caller from an ASP.NET / SignalR <see cref="ClaimsPrincipal"/>.
/// </summary>
public interface ISyncAuthenticator
{
    SyncPrincipal GetPrincipal(ClaimsPrincipal? user);
}
