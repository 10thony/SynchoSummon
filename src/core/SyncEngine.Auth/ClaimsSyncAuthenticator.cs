using System.Security.Claims;
using SyncEngine.Abstractions.Auth;

namespace SyncEngine.Auth;

public sealed class ClaimsSyncAuthenticator : ISyncAuthenticator
{
    public SyncPrincipal GetPrincipal(ClaimsPrincipal? user)
    {
        if (user?.Identity is not { IsAuthenticated: true })
        {
            return SyncPrincipal.Anonymous;
        }

        var clientId = user.FindFirstValue(SyncAuthClaims.ClientId)
            ?? user.FindFirstValue(ClaimTypes.NameIdentifier)
            ?? user.FindFirstValue("sub")
            ?? user.Identity.Name
            ?? "unknown";

        var tenantId = user.FindFirstValue(SyncAuthClaims.TenantId);
        var roles = user.FindAll(ClaimTypes.Role).Select(c => c.Value).ToArray();
        var claims = user.Claims
            .GroupBy(c => c.Type, StringComparer.OrdinalIgnoreCase)
            .ToDictionary(g => g.Key, g => g.First().Value, StringComparer.OrdinalIgnoreCase);

        return new SyncPrincipal
        {
            Subject = user.FindFirstValue(ClaimTypes.NameIdentifier)
                ?? user.FindFirstValue("sub")
                ?? clientId,
            ClientId = clientId,
            TenantId = tenantId,
            IsAuthenticated = true,
            Roles = roles,
            Claims = claims,
        };
    }
}
