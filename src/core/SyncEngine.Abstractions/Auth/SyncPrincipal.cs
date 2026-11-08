namespace SyncEngine.Abstractions.Auth;

/// <summary>
/// Authenticated sync caller resolved by <see cref="ISyncAuthenticator"/>.
/// </summary>
public sealed class SyncPrincipal
{
    public static SyncPrincipal Anonymous { get; } = new()
    {
        Subject = "anonymous",
        ClientId = "anonymous",
        IsAuthenticated = false,
    };

    public required string Subject { get; init; }

    public required string ClientId { get; init; }

    public string? TenantId { get; init; }

    public bool IsAuthenticated { get; init; } = true;

    public IReadOnlyList<string> Roles { get; init; } = [];

    public IReadOnlyDictionary<string, string> Claims { get; init; }
        = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
}
