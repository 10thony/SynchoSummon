using SyncEngine.Abstractions.Protocol;

namespace SyncEngine.Abstractions.Auth;

/// <summary>
/// Authenticated principals may only read/push within their tenant.
/// Changes with a null TenantId are treated as shared (readable by all authenticated clients).
/// </summary>
public sealed class TenantScopedSyncAuthorization : ISyncAuthorization
{
    public bool CanRead(
        SyncPrincipal principal,
        string entityName,
        ReadOnlySpan<byte> keyBytes,
        string? tenantId = null)
    {
        if (!principal.IsAuthenticated)
        {
            return false;
        }

        if (string.IsNullOrWhiteSpace(principal.TenantId) || string.IsNullOrWhiteSpace(tenantId))
        {
            return true;
        }

        return string.Equals(principal.TenantId, tenantId, StringComparison.Ordinal);
    }

    public bool CanPush(
        SyncPrincipal principal,
        string entityName,
        ReadOnlySpan<byte> keyBytes,
        DeltaOperation operation,
        string? tenantId = null)
    {
        if (!principal.IsAuthenticated)
        {
            return false;
        }

        if (string.IsNullOrWhiteSpace(principal.TenantId))
        {
            return true;
        }

        if (string.IsNullOrWhiteSpace(tenantId))
        {
            return true;
        }

        return string.Equals(principal.TenantId, tenantId, StringComparison.Ordinal);
    }
}
