using SyncEngine.Abstractions.Protocol;

namespace SyncEngine.Abstractions.Auth;

/// <summary>
/// Permits every read/push. Only register via explicit anonymous-access opt-in.
/// </summary>
[System.ComponentModel.EditorBrowsable(System.ComponentModel.EditorBrowsableState.Never)]
public sealed class UnsafeAllowAllSyncAuthorization : ISyncAuthorization
{
    public bool CanRead(
        SyncPrincipal principal,
        string entityName,
        ReadOnlySpan<byte> keyBytes,
        string? tenantId = null) => true;

    public bool CanPush(
        SyncPrincipal principal,
        string entityName,
        ReadOnlySpan<byte> keyBytes,
        DeltaOperation operation,
        string? tenantId = null) => true;
}
