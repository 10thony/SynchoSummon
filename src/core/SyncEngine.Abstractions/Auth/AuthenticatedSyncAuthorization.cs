using SyncEngine.Abstractions.Protocol;

namespace SyncEngine.Abstractions.Auth;

/// <summary>
/// Allows any authenticated principal to read/push any entity.
/// Replace with <see cref="TenantScopedSyncAuthorization"/> for multi-tenant hosts.
/// </summary>
public sealed class AuthenticatedSyncAuthorization : ISyncAuthorization
{
    public bool CanRead(
        SyncPrincipal principal,
        string entityName,
        ReadOnlySpan<byte> keyBytes,
        string? tenantId = null)
        => principal.IsAuthenticated;

    public bool CanPush(
        SyncPrincipal principal,
        string entityName,
        ReadOnlySpan<byte> keyBytes,
        DeltaOperation operation,
        string? tenantId = null)
        => principal.IsAuthenticated;
}
