using SyncEngine.Abstractions.Protocol;

namespace SyncEngine.Abstractions.Auth;

/// <summary>
/// Entity/key authorization for pull and push. Hosts replace the default
/// implementation to enforce tenant or row policies.
/// </summary>
public interface ISyncAuthorization
{
    bool CanRead(
        SyncPrincipal principal,
        string entityName,
        ReadOnlySpan<byte> keyBytes,
        string? tenantId = null);

    bool CanPush(
        SyncPrincipal principal,
        string entityName,
        ReadOnlySpan<byte> keyBytes,
        DeltaOperation operation,
        string? tenantId = null);
}
